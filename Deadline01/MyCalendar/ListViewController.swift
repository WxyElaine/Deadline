//
//  ListViewController.swift
//  MyCalendar
//
//  Created by Xinyi Wang on 12/5/17.
//  Copyright © 2017 Xinyi Wang. All rights reserved.
//

import UIKit
import CloudKit

class ListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
    
    public var eventList: Array<Due> = []
    public var completedList: Array<Due> = []
    public var shouldWrite: Bool = false
    // DATABASE SHOULD BE PRIVATE
    let database = CKContainer.default().publicCloudDatabase
    var eventsFromCloud: Array<CKRecord> = []
    
    private var items: Array<ListTableViewCell> = []
    private var dateDetailViewController: DateDetailViewController!
    private var displayList: Array<Due> = []

    let dateFormatter = DateFormatter()
    
    // Tableview
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayList.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // delete the row from local file perminantly
            let deleteDue = displayList[indexPath.row]
            let targetIndex = eventList.index(where: { $0.toJSON() == deleteDue.toJSON() })!
            displayList.remove(at: indexPath.row)
            eventList.remove(at: targetIndex)
            if let parsedEventList = parseEventList() {
                writeJSON(parsedEventList)
            }
            // delete the row from cloud
            if deleteDue.recordName != "" {
                let recordID = CKRecordID(recordName: deleteDue.recordName)
                database.delete(withRecordID: recordID) { record, error in
                    if error != nil {
                        print("ERROR IN DELETING: \(String(describing: error))")
                    } else {
                        print("DELETE SUCCESS")
                    }
                }
            }
            let calendarView = self.tabBarController?.viewControllers?[0] as! ViewController
            calendarView.shouldFetch = true
            let statsView = self.tabBarController?.viewControllers?[2] as! StatsViewController
            statsView.eventList = self.eventList
            statsView.shouldCalc = true
            // delete the row from table
            tableView.deleteRows(at: [indexPath], with: .left)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: ListTableViewCell
        if let celltry = self.tableView.dequeueReusableCell(withIdentifier: "cell") {
            cell = celltry as! ListTableViewCell
        } else {
            cell = ListTableViewCell.init(style: UITableViewCellStyle.subtitle, reuseIdentifier: "cell")
        }
        cell.dueEvent = displayList[indexPath.row]
        dateFormatter.dateFormat = "yyyy MM dd hh mm a"
        let date = dateFormatter.date(from: cell.dueEvent.deadline)!
        dateFormatter.dateFormat = "MMMM dd"
        cell.date = dateFormatter.string(from: date)

        cell.textLabel?.text = self.displayList[indexPath.row].subject
        cell.textLabel?.adjustsFontSizeToFitWidth = true
        
        dateFormatter.dateFormat = "yyyy MM dd hh mm a"
        let deadlineDate = dateFormatter.date(from: self.displayList[indexPath.row].deadline)!
        dateFormatter.dateFormat = "EE',' MMM d hh':'mm a"
        let deadlineStr = dateFormatter.string(from: deadlineDate)
        
        cell.detailTextLabel?.text = ("\(self.displayList[indexPath.row].content), Due: \(deadlineStr)")
        cell.detailTextLabel?.adjustsFontSizeToFitWidth = true
        if displayList[indexPath.row].completed == "false" {
            cell.backgroundColor = self.displayList[indexPath.row].color.withAlphaComponent(0.2)
        } else {
            cell.backgroundColor = UIColor(red:0.91, green:0.94, blue:0.96, alpha:1.0)
        }
        items.append(cell)
        return cell
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        datedetailBuilder()
        let cell = tableView.cellForRow(at: indexPath)
        performSegue(withIdentifier: "cellToDetail", sender: cell)
    }
    
    
    // Storyboard ViewController
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var popoverViewSub: UIView!
    @IBOutlet weak var dimmerViewSub: UIView!
    @IBOutlet weak var emergenceSwitch: UISwitch!
    @IBOutlet weak var completedSwitch: UISwitch!
    @IBOutlet weak var inprogressSwitch: UISwitch!
    @IBOutlet weak var dueDateSwitch: UISwitch!
    
    private let refreshControl = UIRefreshControl()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        self.tableView.register(ListTableViewCell.self, forCellReuseIdentifier: "cell")
        
        popoverViewSub.isHidden = true
        popoverViewSub.layer.cornerRadius = 10
        dimmerViewSub.isHidden = true
        
        if #available(iOS 10.0, *) {
            tableView.refreshControl = refreshControl
        } else {
            tableView.addSubview(refreshControl)
        }
        refreshControl.addTarget(self, action: #selector(ListViewController.refreshData(sender:)), for: .valueChanged)
        changeMode(mode: "default")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tableView.reloadData()
        if shouldWrite {
            if let parsedEventList = parseEventList() {
                writeJSON(parsedEventList)
            }
        }
    }
    
    @IBAction func editButtonClicked(_ sender: UINavigationItem) {
        if(self.tableView.isEditing == true) {
            self.tableView.isEditing = false
            sender.title = "Edit"
        } else {
            self.tableView.isEditing = true
            sender.title = "Done"
        }
    }
    
    @objc private func refreshData(sender: UIRefreshControl) {
        fetchData()
        refreshControl.endRefreshing()
    }
    
    @IBAction func settingsPressed(_ sender: UIBarButtonItem) {
        popoverViewSub.isHidden = false
        dimmerViewSub.isHidden = false
    }
    
    @IBAction func anySwitchClicked(_ sender: UISwitch) {
        emergenceSwitch.isOn = false
        completedSwitch.isOn = false
        inprogressSwitch.isOn = false
        dueDateSwitch.isOn = false
        sender.isOn = true
    }

    @IBAction func applied(_ sender: UIButton) {
        if (emergenceSwitch.isOn) {
            changeMode(mode: "emergence")
        } else if (inprogressSwitch.isOn) {
            changeMode(mode: "inprogress")
        } else if (dueDateSwitch.isOn) {
            changeMode(mode: "dueDates")
        } else if (completedSwitch.isOn) {
            changeMode(mode: "completed")
        }
        popoverViewSub.isHidden = true
        dimmerViewSub.isHidden = true
        tableView.reloadData()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "cellToDetail" {
            let datedetailView = segue.destination as! DateDetailViewController
            let dateCell = sender as! ListTableViewCell
            datedetailView.detail = dateCell.dueEvent
            datedetailView.formattedDate = dateCell.date
            datedetailView.lastView = "listView"
            datedetailView.lastIndex = eventList.index(where: { $0.toJSON() == dateCell.dueEvent.toJSON() })!
        }
    }
    
    @IBAction func unwindToListViewController(segue: UIStoryboardSegue) {
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func changeMode(mode:String) {
        switch mode {
        case "emergence":
            //TODO:asdadsf
            displayList = eventList
            displayList.sort(by: { (due1, due2) -> Bool in
                if (due1.emergence > due2.emergence) {
                    return true
                } else {
                    return false
                }
            })
        case "completed":
            //TODO:adsafd
            displayList = completedList
        case "inprogress":
            //TODO: a ds
            displayList = []
            for due : Due in eventList {
                if due.completed == "false" {
                    displayList.append(due)
                }
            }
        default:
            displayList = eventList
        }
    }
    
    private func datedetailBuilder() {
        if dateDetailViewController == nil {
            dateDetailViewController = storyboard?.instantiateViewController(withIdentifier: "dateDetailViewController") as! DateDetailViewController
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
                self.tableView.reloadData()
                let calendarView = self.tabBarController?.viewControllers?[0] as! ViewController
                calendarView.eventList = self.eventList
                calendarView.completedList = self.completedList
                calendarView.dueDates.removeAll()
                calendarView.overdueList.removeAll()
                for duedate : Due in self.eventList {
                    calendarView.dueDates.append(duedate.deadline)
                    self.dateFormatter.dateFormat = "yyyy MM dd hh mm a"
                    let deadlineDate = self.dateFormatter.date(from: duedate.deadline)!
                    let result = deadlineDate.compare(Date())
                    if result == ComparisonResult.orderedAscending {
                        calendarView.overdueList.append(duedate)
                    }
                }
                let statsView = self.tabBarController?.viewControllers?[2] as! StatsViewController
                statsView.eventList = self.eventList
                statsView.shouldCalc = true
            }
        }
    }
    
    private func parseDataFromCloud(_ records: Array<CKRecord>) -> Data? {
        // clear all previous records
        self.eventsFromCloud.removeAll()
        self.eventList.removeAll()
        self.completedList.removeAll()
        
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
            if newCompleted == "true" {
                self.completedList.append(newEvent)
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
                
                // TEST
//                let str = NSString(data: fileData, encoding: String.Encoding.utf8.rawValue)
//                print("FILE CONTENT: \(str!)")
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
    }
    
    private func parseJSON(_ data: Data) {
        // clear all previous records
        self.eventsFromCloud.removeAll()
        self.eventList.removeAll()
        self.completedList.removeAll()
        
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
                if newCompleted == "true" {
                    self.completedList.append(newEvent)
                }
                dateFormatter.dateFormat = "yyyy MM dd hh mm a"
                let deadlineDate = dateFormatter.date(from: newDeadline)!
                let result = deadlineDate.compare(Date())
                if newCompleted == "false" && result == ComparisonResult.orderedAscending {
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

