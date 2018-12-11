//
//  ViewController.swift
//  MyCalendar
//
//  Created by Xinyi Wang on 11/28/17.
//  Copyright © 2017 Xinyi Wang. All rights reserved.
//

import UIKit
import JTAppleCalendar
import CloudKit
import EventKit
import UserNotifications

class ViewController: UIViewController, UNUserNotificationCenterDelegate {
    @IBOutlet weak var calendarView: JTAppleCalendarView!
    @IBOutlet weak var yearTitle: UILabel!
    @IBOutlet weak var monthTitle: UILabel!
    
    @IBOutlet weak var popoverView: UIView!
    @IBOutlet weak var dimmerView: UIView!
    @IBOutlet weak var logonButton: UIButton!
    
    public var eventList: Array<Due> = []
    public var dueDates: Array<String> = []
    public var completedList: Array<Due> = []
    public var overdueList: Array<Due> = []
    public var shouldFetch: Bool = false
    public var shouldWrite: Bool = false

    // DATABASE SHOULD BE PRIVATE
    let database = CKContainer.default().publicCloudDatabase
    var eventsFromCloud: Array<CKRecord> = []
    // NOTIFICATION
    let center = UNUserNotificationCenter.current()
    private var notificationAllowed = false
    let userCalendar = NSCalendar.current
    
    private var multipleDueView: MultipleDueViewController!
    private var dateDetailView: DateDetailViewController!
    private var addDueView: AddDueViewController!
    private var todaySelected: Bool = true
    
    let dateFormatter = DateFormatter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // fetch data from iCloud or use local storage
        fetchData()
        // SetUps
        setUpCalendar()
        // set up month & year
        calendarView.visibleDates { (visibleDates) in
            let current = visibleDates.monthDates.first!.date
            
            self.dateFormatter.dateFormat = "yyyy"
            self.yearTitle.text = self.dateFormatter.string(from: current)
            self.dateFormatter.dateFormat = "MMMM"
            self.monthTitle.text = self.dateFormatter.string(from: current)
        }
        // go to today
        calendarView.scrollToDate(Date(), animateScroll: false)
        // Setup layouts
        popoverView.isHidden = true
        dimmerView.isHidden = true
        // build other views
        multipleDueBuilder()
        dateDetailBuilder()
        addDueBuilder()
        
        UNUserNotificationCenter.current().delegate = self

        notificatioSetUp()

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshEverything()
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func setUpCalendar() {
        calendarView.minimumLineSpacing = 3
        calendarView.minimumInteritemSpacing = 0
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toDateDetail" {
            let dateCell = sender as! CollectionViewCell
            let detailView = segue.destination as! DateDetailViewController
            detailView.detail = dateCell.dueEvent[0]
            detailView.formattedDate = dateCell.date
            detailView.lastView = "mainCalendar"
            detailView.lastIndex = eventList.index(where: { $0.toJSON() == dateCell.dueEvent[0].toJSON() })!
        } else if segue.identifier == "add" || segue.identifier == "toAddDue" {
            let addDueView = segue.destination as! AddDueViewController
            addDueView.eventList = self.eventList
        } else if segue.identifier == "toMultipleDue" {
            let dateCell = sender as! CollectionViewCell
            let multipleDueView = segue.destination as! MultipleDueViewController
            multipleDueView.allEventList = eventList
            multipleDueView.eventList = dateCell.dueEvent
            multipleDueView.formattedDate = dateCell.date
        }
    }
    
    @IBAction func okPressed(_ sender: UIButton) {
        popoverView.isHidden = true
        dimmerView.isHidden = true
    }
    
    @IBAction func logonPressed(_ sender: UIButton) {
        let settingsUrl = NSURL(string:UIApplicationOpenSettingsURLString)! as URL
        UIApplication.shared.open(settingsUrl, options: [:], completionHandler: nil)
        popoverView.isHidden = true
        dimmerView.isHidden = true
    }
    
    @IBAction func syncPressed(_ sender: UIButton) {
        shouldFetch = true
        refreshEverything()
        popoverView.isHidden = true
        dimmerView.isHidden = true
    }
    
    @IBAction func exportPressed(sender: UIButton) {
        let eventStore = EKEventStore.init()
        eventStore.requestAccess(to: EKEntityType.event, completion: {
            (accessGranted: Bool, error: Error?) in
            
            if accessGranted == true {
                print("Calendar Access Premitted")
                self.exportDues(eventStore)
            } else {
                print("Calendar Access Denied")
            }
        })
        popoverView.isHidden = true
        dimmerView.isHidden = true
    }
    
    private func exportDues(_ eventStore: EKEventStore) {
        let calendars = eventStore.calendars(for: .event)
        let interval = TimeInterval.init(3600)
        for due in eventList {
            let event = EKEvent(eventStore: eventStore)
            event.calendar = calendars[0]
            event.title = "\(due.subject): \(due.content)"
            dateFormatter.dateFormat = "yyyy MM dd hh mm a"
            let date = dateFormatter.date(from: due.deadline)!
            event.startDate = date
            event.endDate = date.addingTimeInterval(interval)
            do {
                let _ = try eventStore.save(event, span: .thisEvent)
            } catch {
                print("ERROR IN EXPORTING: \(error)")
            }
        }
    }
    
    @IBAction func unwindToViewController(unwindSegue: UIStoryboardSegue) {
    }
    
    @IBAction func settingPressed(_ sender: UIButton) {
        popoverView.isHidden = false
        dimmerView.isHidden = false
    }
    
    private func notificatioSetUp() {
        let options: UNAuthorizationOptions = [.alert, .badge, .sound];
        center.requestAuthorization(options: options) {
            (granted, error) in
            if !granted {
                print("Notification Denied")
            } else {
                print("Notification Permitted")
            }
        }
        center.getNotificationSettings { (settings) in
            if settings.authorizationStatus != .authorized {
                self.notificationAllowed = false
            } else {
                self.notificationAllowed = true
            }
        }
    }
    
    private func getNotify() {
        if notificationAllowed {
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            for due in eventList {
                dateFormatter.dateFormat = "yyyy MM dd hh mm a"
                let deadlineDate = dateFormatter.date(from: due.deadline)
                let result = deadlineDate!.compare(Date())
                // notification content
                let content = UNMutableNotificationContent()
                content.title = due.subject
                dateFormatter.dateFormat = "yyyy MM dd hh mm a"
                let deadline = dateFormatter.string(from: deadlineDate!)
                content.body = "\(due.content) DUE AT: \(deadline)"
                content.sound = UNNotificationSound.default()
                content.badge = NSNumber.init(value: 1)
                if result == ComparisonResult.orderedDescending {
                    let periodComponents = NSDateComponents()
                    periodComponents.year = 0
                    periodComponents.hour = 0
                    periodComponents.minute = 0
                    periodComponents.second = 0
                    var resultTemp: ComparisonResult
                    // add alert 7, 5, 3, 2, and 1 day(s) ago
                    let subtract = [-7, -5, -3, -2, -1]
                    for sub in subtract {
                        periodComponents.day = sub
                        let before = userCalendar.date(byAdding: periodComponents as DateComponents, to: deadlineDate!)
                        resultTemp = before!.compare(Date())
                        if resultTemp == ComparisonResult.orderedDescending {
                            let beforeComponents = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second,], from: before!)
                            let trigger = UNCalendarNotificationTrigger(dateMatching: beforeComponents, repeats: false)
                            let identifier = "\(deadline)@\(sub)"
                            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                            center.add(request, withCompletionHandler: { (error) in
                                if let error = error {
                                    print(error)
                                }
                            })
                        }
                    }
                } else if result == ComparisonResult.orderedSame {
                    // add alert to today
                    let todayComponents = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second,], from: deadlineDate!)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: todayComponents, repeats: false)
                    let identifier = deadline
                    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                    center.add(request, withCompletionHandler: { (error) in
                        if let error = error {
                            print(error)
                        }
                    })
                }
            }
        }
//        listNotification()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .badge, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
    
    private func listNotification() {
        UNUserNotificationCenter.current().getPendingNotificationRequests(completionHandler: {requests -> () in
            print("\(requests.count) Requests -------")
            for request in requests{
                print(request.content)
            }
        })
    }
    
    private func refreshEverything() {
        if shouldFetch {
            fetchData()
            shouldFetch = false
        } else {
            calendarView.reloadData()
        }
        let listView = self.tabBarController?.viewControllers?[1] as! ListViewController
        listView.eventList = self.eventList
        listView.completedList = self.completedList
        let statsView = self.tabBarController?.viewControllers?[2] as! StatsViewController
        statsView.eventList = self.eventList
        statsView.completedList = self.completedList
        statsView.overdueList = self.overdueList
        statsView.shouldCalc = false
        if shouldWrite {
            if let parsedEventList = parseEventList() {
                writeJSON(parsedEventList)
            }
        }
        getNotify()
    }
    
    private func multipleDueBuilder() {
        if multipleDueView == nil {
            multipleDueView = storyboard?.instantiateViewController(withIdentifier: "multipleDueViewController") as! MultipleDueViewController
        }
    }
    
    private func dateDetailBuilder() {
        if dateDetailView == nil {
            dateDetailView = storyboard?.instantiateViewController(withIdentifier: "dateDetailViewController") as! DateDetailViewController
        }
    }
    
    private func addDueBuilder() {
        if addDueView == nil {
            addDueView = storyboard?.instantiateViewController(withIdentifier: "addDueViewController") as! AddDueViewController
        }
    }
    
    /* Fetches data from the iCloud.
     --> If succeeds, uses the cloud data writes the cloud data to a local file (creates one if no local file exists).
     --> If fails, checks if a local file exists. If the local exists, uses the local file. If not, creates an empty local file. */
    @objc func fetchData() {
        // save the unsaved local file to the cloud
        for event in eventList {
            if event.recordName == "" {
                let colorArrTemp = event.color.components
                let colorArr = [colorArrTemp.red, colorArrTemp.green, colorArrTemp.blue]
                
                let newDue = CKRecord(recordType: "Due")
                newDue.setValue(event.subject, forKey: "subject")
                newDue.setValue(colorArr, forKey: "color")
                newDue.setValue(event.content, forKey: "content")
                newDue.setValue(event.deadline, forKey: "deadline")
                newDue.setValue(event.emergence, forKey: "priority")
                newDue.setValue(event.completed, forKey: "completed")
                
                database.save(newDue) { (record, error) in
                    guard record != nil else { return }
                    print("SAVED TO CLOUD")
                }
            }
        }
        
        let query = CKQuery(recordType: "Due", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "deadline", ascending: true)]
        
        database.perform(query, inZoneWith: nil) { (records, error) in
            if error != nil {
                print("ERROR")
                print(error!)
                // use local data
                self.chooseLocalFile()
            } else {
                print("SUCCESS")
                // use cloud data
                guard let records = records else { return }
                if let parsedData = self.parseDataFromCloud(records) {
                    self.writeJSON(parsedData)
                }
            }
            DispatchQueue.main.async {
                self.calendarView.reloadData()
                self.getNotify()
                let listView = self.tabBarController?.viewControllers?[1] as! ListViewController
                listView.eventList = self.eventList
                listView.completedList = self.completedList
                let statsView = self.tabBarController?.viewControllers?[2] as! StatsViewController
                statsView.eventList = self.eventList
                statsView.completedList = self.completedList
                statsView.overdueList = self.overdueList
                statsView.shouldCalc = false
            }
        }
    }
    
    private func parseDataFromCloud(_ records: Array<CKRecord>) -> Data? {
        // clear all previous records
        self.eventsFromCloud.removeAll()
        self.eventList.removeAll()
        self.dueDates.removeAll()
        self.completedList.removeAll()
        self.overdueList.removeAll()
        
        var eventListJsonFinal = [String: Any]()
        var eventListJson = [String: Any]()
        var i = 0
        for recordtemp : CKRecord in records {
            self.eventsFromCloud.append(recordtemp)
            
            let newSubject = recordtemp.value(forKeyPath: "subject") as! String
            let newColor = recordtemp.value(forKeyPath: "color") as! Array<Double>
            let newContent = recordtemp.value(forKeyPath: "content") as! String
            let newDeadline = recordtemp.value(forKeyPath: "deadline") as! String
            let newEmergence = recordtemp.value(forKeyPath: "priority") as! int_fast64_t
            let newCompleted = recordtemp.value(forKeyPath: "completed") as! String
            let newRecordName = recordtemp.recordID.recordName 
            
            let color = UIColor(red: CGFloat(newColor[0]), green: CGFloat(newColor[1]), blue: CGFloat(newColor[2]), alpha: 1.0)
            // add Due
            let newEvent: Due = Due.init(subject: newSubject, color: color, content: newContent, deadline: newDeadline, emergence: Int(newEmergence), completed: newCompleted, recordName: newRecordName)
            self.eventList.append(newEvent)
            self.dueDates.append(newEvent.deadline)
            if newCompleted == "true" {
                self.completedList.append(newEvent)
            }
            dateFormatter.dateFormat = "yyyy MM dd hh mm a"
            let deadlineDate = dateFormatter.date(from: newDeadline)!
            let result = deadlineDate.compare(Date())
            if newCompleted == "false" && result == ComparisonResult.orderedAscending {
                self.overdueList.append(newEvent)
            }
            // parse Due
            eventListJson["subject"] = newSubject
            eventListJson["color"] = newColor
            eventListJson["content"] = newContent
            eventListJson["deadline"] = newDeadline
            eventListJson["emergence"] = Int(newEmergence)
            eventListJson["completed"] = newCompleted
            eventListJson["recordName"] = newRecordName
            eventListJsonFinal["due\(i)"] = eventListJson
            i = i + 1
        }
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: eventListJsonFinal, options: JSONSerialization.WritingOptions.prettyPrinted)
            return jsonData
        } catch {
            print(error)
            return nil
        }
    }
    
    private func chooseLocalFile() {
        let fileManager: FileManager = FileManager.default
        var documentsDirectory: URL?
        var fileURL: URL?
        
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
        fileURL = documentsDirectory!.appendingPathComponent("Dues.json")
        if fileManager.fileExists(atPath: fileURL!.path) {
            // use new data
            print("CHOOSE: USE Dues.json")
            getLocalFile(fileURL!)
        } else {
            print("CHOOSE: File does not exist, create it")
            var documentsDirectory: URL?
            var fileURL: URL?
            documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
            fileURL = documentsDirectory!.appendingPathComponent("Dues.json")
            NSData().write(to: fileURL!, atomically: true)
        }
    }
    
    private func getLocalFile(_ filePath: URL) {
        do {
            let file: FileHandle? = try FileHandle(forReadingFrom: filePath)
            if file != nil {
                let fileData = file!.readDataToEndOfFile()
                file!.closeFile()
                parseJSON(fileData)
            }
        } catch {
            print("Error in file reading: \(error.localizedDescription)")
        }
    }
    
    private func writeJSON(_ data: Data) {
        let fileManager: FileManager = FileManager.default
        var documentsDirectory: URL?
        var fileURL: URL?
        
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
        fileURL = documentsDirectory!.appendingPathComponent("Dues.json")
        if fileManager.fileExists(atPath: fileURL!.path) {
            print("WRITE: File exists")
        } else {
            print("WRITE: File does not exist, create it")
            NSData().write(to: fileURL!, atomically: true)
        }
        do {
            let newFile: FileHandle? = try FileHandle(forWritingTo: fileURL!)
            if newFile != nil {
                newFile!.write(data)
                print("FILE WRITE")
            } else {
                print("Unable to write JSON file!")
            }
        } catch {
            print("Error in file writing: \(error.localizedDescription)")
        }
        // DEBUG
//        do {
//            let file: FileHandle? = try FileHandle(forReadingFrom: fileURL!)
//            if file != nil {
//                let fileData = file!.readDataToEndOfFile()
//                file!.closeFile()
//                let str = NSString(data: fileData, encoding: String.Encoding.utf8.rawValue)
//                print("FILE CONTENT: \(str!)")
//            }
//        } catch {
//            print("Error in file reading: \(error.localizedDescription)")
//        }
    }
    
    private func parseJSON(_ data: Data) {
        // clear all previous records
        self.eventsFromCloud.removeAll()
        self.eventList.removeAll()
        self.dueDates.removeAll()
        self.completedList.removeAll()
        self.overdueList.removeAll()
        
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
            print(json)
            let keys = Array(json.keys)
            for key in keys {
                let duedue = json[key] as! [String: Any]
                let newSubject = duedue["subject"] as! String
                let newColor = duedue["color"]! as! Array<Double>
                let newContent = duedue["content"]! as! String
                let newDeadline = duedue["deadline"]! as! String
                let newEmergence = duedue["emergence"]! as! Int
                let newCompleted = duedue["completed"]! as! String
                let newRecordName = duedue["recordName"]! as! String
                let color = UIColor(red: CGFloat(newColor[0]), green: CGFloat(newColor[1]), blue: CGFloat(newColor[2]), alpha: 1.0)
                // add Due
                let newEvent: Due = Due.init(subject: newSubject, color: color, content: newContent, deadline: newDeadline, emergence: newEmergence, completed: newCompleted, recordName: newRecordName)
                self.eventList.append(newEvent)
                self.dueDates.append(newEvent.deadline)
                if newCompleted == "true" {
                    self.completedList.append(newEvent)
                }
                dateFormatter.dateFormat = "yyyy MM dd hh mm a"
                let deadlineDate = dateFormatter.date(from: newDeadline)!
                let result = deadlineDate.compare(Date())
                if newCompleted == "false" && result == ComparisonResult.orderedAscending {
                    self.overdueList.append(newEvent)
                }
            }
        } catch {
            print("ERROR in JSON parsing: \(error)")
        }
    }
    
    private func parseEventList() -> Data? {
        var eventListJsonFinal = [String: Any]()
        var eventListJson = [String: Any]()
        var i = 0
        for event : Due in eventList {
            eventListJson["subject"] = event.subject
            let colorArrTemp = event.color.components
            let colorArr = [colorArrTemp.red, colorArrTemp.green, colorArrTemp.blue]
            eventListJson["color"] = colorArr
            eventListJson["content"] = event.content
            eventListJson["deadline"] = event.deadline
            eventListJson["emergence"] = event.emergence
            eventListJson["completed"] = event.completed
            eventListJson["recordName"] = event.recordName
            eventListJsonFinal["due\(i)"] = eventListJson
            i = i + 1
        }
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: eventListJson, options: JSONSerialization.WritingOptions.prettyPrinted)
            return jsonData
        } catch {
            print(error)
            return nil
        }
    }
}

extension ViewController: JTAppleCalendarViewDataSource, JTAppleCalendarViewDelegate {
    func calendar(_ calendar: JTAppleCalendarView, willDisplay cell: JTAppleCell, forItemAt date: Date, cellState: CellState, indexPath: IndexPath) {
        //        code
    }
    
    func configureCalendar(_ calendar: JTAppleCalendarView) -> ConfigurationParameters {
        // Can set these to whatever
        dateFormatter.dateFormat = "yyyy MM dd"
        dateFormatter.timeZone = Calendar.current.timeZone
        dateFormatter.locale = Calendar.current.locale
        
        // In the real app, do not do force unwrapping!!!
        let startDate = dateFormatter.date(from: "2017 01 01")!
        let endDate = dateFormatter.date(from: "2067 12 31")!
        let parameter = ConfigurationParameters(startDate: startDate, endDate: endDate)
        
        return parameter
    }
    
    func calendar(_ calendar: JTAppleCalendarView, cellForItemAt date: Date, cellState: CellState, indexPath: IndexPath) -> JTAppleCell {
        let dateCell = calendar.dequeueReusableJTAppleCell(withReuseIdentifier: "cell", for:  indexPath) as! CollectionViewCell
        // set date text
        dateCell.dateLabel.text  = cellState.text
        dateFormatter.dateFormat = "MMMM dd"
        dateCell.date = dateFormatter.string(from: cellState.date)
        // set corner radius
        dateCell.layer.cornerRadius = dateCell.frame.height / 2
        dateCell.eventIndicator.layer.cornerRadius = dateCell.eventIndicator.frame.width / 2
        // set current month display
        if cellState.dateBelongsTo != .thisMonth {
            dateCell.dateLabel.textColor = UIColor(red:0.19, green:0.47, blue:0.45, alpha:1.0)
            dateCell.alpha = 0.5
        } else {
            dateCell.dateLabel.textColor = UIColor.black
        }
        // set selected
        if !checkDate(cellState, Date()) {
            if cellState.isSelected {
                dateCell.isSelected = false
            }
            dateCell.backgroundColor = UIColor(red:0.69, green:0.93, blue:0.93, alpha:1.0)
        } else {
            dateCell.backgroundColor = UIColor(red:0.56, green:0.74, blue:0.74, alpha:1.0)
            dateCell.dateLabel.textColor = UIColor.white
        }
        // set event indicator and events corresponding to a date
        dateCell.dueEvent.removeAll()
        dateFormatter.dateFormat = "yyyy MM dd"
        let cellStateDate = dateFormatter.string(from: cellState.date)
        var onedayEvent: Array<Int> = []
        if dueDates.count >= 1 {
            for i in 0...dueDates.count - 1 {
                if dueDates[i].hasPrefix(cellStateDate) {
                    let temp = eventList[i]
                    if temp.completed == "false" {
                        onedayEvent.append(i)
                        dateCell.dueEvent.append(temp)
                    }
                }
            }
        }
        var segueTemp: UIStoryboardSegue!
        if !onedayEvent.isEmpty {
            dateCell.eventIndicator.isHidden = false
            if onedayEvent.count > 1 {
                dateCell.eventIndicator.backgroundColor = UIColor(red:0.64, green:0.00, blue:1.00, alpha:1.0)
                segueTemp = UIStoryboardSegue.init(identifier: "toMultipleDue", source: self, destination: multipleDueView)
            } else {
                dateCell.eventIndicator.backgroundColor = eventList[onedayEvent[0]].color
                segueTemp = UIStoryboardSegue.init(identifier: "toDateDetail", source: self, destination: dateDetailView)
            }
        } else {
            dateCell.eventIndicator.isHidden = true
            segueTemp = UIStoryboardSegue.init(identifier: "toAddDue", source: self, destination: addDueView)
        }
        dateCell.segueTo = segueTemp
        return dateCell
    }
    
    func calendar(_ calendar: JTAppleCalendarView, didSelectDate date: Date, cell: JTAppleCell?, cellState: CellState) {
        guard let selectedCell = cell as! CollectionViewCell? else { return }
        if !checkDate(cellState, Date()) {   // if it's not today, change the background color
            selectedCell.backgroundColor = UIColor(red:0.23, green:0.84, blue:0.78, alpha:1.0)
        }
        performSegue(withIdentifier: selectedCell.segueTo.identifier!, sender: selectedCell)
    }
    
    func calendar(_ calendar: JTAppleCalendarView, didDeselectDate date: Date, cell: JTAppleCell?, cellState: CellState) {
        if !checkDate(cellState, Date()) {
            cell?.backgroundColor = UIColor(red:0.70, green:0.93, blue:0.93, alpha:1.0)
        }
    }
    
    func calendar(_ calendar: JTAppleCalendarView, didScrollToDateSegmentWith visibleDates: DateSegmentInfo) {
        let current = visibleDates.monthDates.first!.date
        
        dateFormatter.dateFormat = "yyyy"
        yearTitle.text = dateFormatter.string(from: current)
        dateFormatter.dateFormat = "MMMM"
        monthTitle.text = dateFormatter.string(from: current)
    }
    
    private func checkDate(_ cellState: CellState, _ date: Date) -> Bool {
        dateFormatter.dateFormat = "yyyy MM dd"
        let checkDate = dateFormatter.string(from: date)
        let cellStateDate = dateFormatter.string(from: cellState.date)
        return checkDate == cellStateDate ? true : false
    }
    
}

