//
//  DateDetailViewController.swift
//  MyCalendar
//
//  Created by Xinyi Wang on 11/29/17.
//  Copyright © 2017 Xinyi Wang. All rights reserved.
//

import UIKit
import CloudKit

class DateDetailViewController: UIViewController, UITextFieldDelegate {
    @IBOutlet weak var dateTitle: UILabel!
    @IBOutlet weak var completedLabel: UILabel!
    @IBOutlet weak var completeIndicator: UIButton!

    @IBOutlet weak var dueColor: UIButton!
    @IBOutlet weak var subject: UITextField!
    @IBOutlet weak var colorPicker: UIStackView!
    @IBOutlet weak var content: UITextField!
    @IBOutlet weak var deadline: UIButton!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var emergence: UISlider!
    
    public var detail: Due = Due.init()
    public var lastIndex: Int = 0
    public var wasCompleted: Int = 0

    public var formattedDate: String = ""
    public var lastView: String = ""
    private var selectedDate = Date()
    private var selectedColor: UIColor = UIColor.white
    private var completedTF: Bool = false
    private var originCompleted: Bool = false
    private var completeColor: UIImage = UIImage.init()
    private var uncompleteColor: UIImage = UIImage.init()
    private var changesMade: Bool = false
    
    // DATABASE SHOULD BE PRIVATE
    let database = CKContainer.default().publicCloudDatabase
    
    let dateFormatter = DateFormatter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        subject.delegate = self
        content.delegate = self
        completeColor = UIImage(named: "check-icon")!
        uncompleteColor = UIImage(named: "cross-icon")!
        subject.isEnabled = false
        content.isEnabled = false
        deadline.isEnabled = false
        emergence.isEnabled = false
        dueColor.isEnabled = false
        completeIndicator.isEnabled = false
        datePicker.isHidden = true
        colorPicker.isHidden = true
        setUpLayout()
    }
    
    // Dismisses the keyboard if needed
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    @IBAction func editClicked(_ sender: UIButton) {
        if sender.title(for: .normal) == "Edit" {
            subject.isEnabled = true
            content.isEnabled = true
            deadline.isEnabled = true
            emergence.isEnabled = true
            dueColor.isEnabled = true
            completeIndicator.isEnabled = true
            sender.setTitle("Done", for: .normal)
        } else if sender.title(for: .normal) == "Done" {
            completeIndicator.isEnabled = false
            let old = detail
            editDone()
            sender.setTitle("Edit", for: .normal)
            if !(originCompleted && !completedTF) {
                if detail.toJSON() != old.toJSON() {
                    // fetch the old record from cloud and update cloud record
                    changesMade = true
                    if detail.recordName != "" {
                    let recordID = CKRecordID(recordName: detail.recordName)
                    database.fetch(withRecordID: recordID) { record, error in
                        if let myRecord = record, error == nil {
                            let colorArrTemp = self.selectedColor.components
                            let colorArr = [colorArrTemp.red, colorArrTemp.green, colorArrTemp.blue]
                            myRecord.setValue(self.detail.subject, forKey: "subject")
                            myRecord.setValue(colorArr, forKey: "color")
                            myRecord.setValue(self.detail.content, forKey: "content")
                            myRecord.setValue(self.detail.deadline, forKey: "deadline")
                            myRecord.setValue(self.detail.emergence, forKey: "priority")
                            myRecord.setValue(self.detail.completed, forKey: "completed")
                            myRecord.setValue(self.detail.recordName, forKey: "recordName")
                            self.database.save(myRecord, completionHandler: {returnedRecord, error in
                                if error != nil {
                                    print("ERROR IN MODIFY: \(String(describing: error))")
                                } else {
                                    print("MODIFY SUCCESS")
                                }
                            })
                        }
                    }
                }
                }
            } else {
                let alertController = UIAlertController(title: "Oooooops", message: "You've already completed this due!", preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                alertController.addAction(okAction)
                self.present(alertController, animated: true)
                completeIndicator.setBackgroundImage(completeColor, for: .normal)
            }
        }
    }
    
    @IBAction func colorPicked(_ sender: UIButton) {
        colorPicker.isHidden = true
        selectedColor = sender.backgroundColor!
        dueColor.setBackgroundImage(imageFromColor(color: selectedColor), for: .normal)
    }
    
    @IBAction func colorClicked(_ sender: Any) {
        colorPicker.isHidden = !colorPicker.isHidden
        self.view.endEditing(true)
    }
    
    @IBAction func deadlineClicked(_ sender: UIButton) {
        datePicker.isHidden = !datePicker.isHidden
        self.view.endEditing(true)
        completedLabel.isHidden = !completedLabel.isHidden
        completeIndicator.isHidden = !completeIndicator.isHidden
    }
    
    @IBAction func deadlineChanged(_ sender: UIDatePicker) {
        selectedDate = sender.date
        deadline.setTitle(dateFormatter.string(from: sender.date), for: .normal)
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }
    
    @objc func storeSelectedRow(){
        
    }
    
    @IBAction func completed(_ sender: UIButton) {
        if completedTF {
            sender.setBackgroundImage(uncompleteColor, for: .normal)
        } else {
            sender.setBackgroundImage(completeColor, for: .normal)
        }
        completedTF = !completedTF
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func backPressed(_ sender: UIButton) {
        if lastView == "mainCalendar" {
            self.performSegue(withIdentifier: "unwindToCalendar", sender: nil)
        } else if lastView == "listView" {
            self.performSegue(withIdentifier: "unwindToList", sender: nil)
        } else {
            self.performSegue(withIdentifier: "unwindToMultiple", sender: nil)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "unwindToCalendar" {
            if !(originCompleted && !completedTF) {
                let calendarView = segue.destination as! ViewController
                calendarView.eventList.remove(at: lastIndex)
                calendarView.dueDates.remove(at: lastIndex)
                if calendarView.eventList.isEmpty || calendarView.eventList.count == lastIndex {
                    calendarView.eventList.append(detail)
                    calendarView.dueDates.append(detail.deadline)
                } else {
                    calendarView.eventList.insert(detail, at: lastIndex)
                    calendarView.dueDates.insert(detail.deadline, at: lastIndex)
                }
                if !originCompleted && completedTF {
                    calendarView.completedList.append(detail)
                }
                calendarView.shouldWrite = true
            }
        } else if segue.identifier == "unwindToList" {
            if !(originCompleted && !completedTF) {
                let listView = segue.destination as! ListViewController
                let calendarView = listView.tabBarController?.viewControllers?[0] as! ViewController
                listView.eventList.remove(at: lastIndex)
                calendarView.eventList.remove(at: lastIndex)
                calendarView.dueDates.remove(at: lastIndex)
                if listView.eventList.isEmpty || listView.eventList.count == lastIndex {
                    listView.eventList.append(detail)
                    calendarView.eventList.append(detail)
                    calendarView.dueDates.append(detail.deadline)
                } else {
                    listView.eventList.insert(detail, at: lastIndex)
                    calendarView.eventList.insert(detail, at: lastIndex)
                    calendarView.dueDates.insert(detail.deadline, at: lastIndex)
                }
                if !originCompleted && completedTF {
                    listView.completedList.append(detail)
                    calendarView.completedList.append(detail)
                }
                listView.shouldWrite = true
            }
        } else {
            if !(originCompleted && !completedTF) {
                let multipleView = segue.destination as! MultipleDueViewController
                multipleView.lastJson = multipleView.eventList[lastIndex].toJSON()!
                multipleView.eventList.remove(at: lastIndex)
                if !completedTF && changesMade {
                    dateFormatter.dateFormat = "yyyy MM dd hh mm a"
                    let date = dateFormatter.date(from: detail.deadline)!
                    dateFormatter.dateFormat = "MMMM dd"
                    let dateStr = dateFormatter.string(from: date)
                    // the change is made to this day
                    if multipleView.formattedDate == dateStr {
                        if multipleView.eventList.isEmpty || multipleView.eventList.count == lastIndex {
                            multipleView.eventList.append(detail)
                        } else {
                            multipleView.eventList.insert(detail, at: lastIndex)
                        }
                    }
                    multipleView.allEventList.append(detail)
                }
                multipleView.parentShoudFetch = true
            }
        }

    }
    
    private func setUpLayout() {
        completeIndicator.layer.cornerRadius = completeIndicator.frame.width / 2
        dueColor.setBackgroundImage(imageFromColor(color: UIColor(red:0.99, green:0.96, blue:0.16, alpha:1.0)), for: .normal)
        dateTitle.text = formattedDate
        subject.text = detail.subject
        dueColor.setBackgroundImage(imageFromColor(color: detail.color), for: .normal)
        selectedColor = detail.color
        content.text = detail.content
        
        dateFormatter.dateFormat = "yyyy MM dd hh mm a"
        let deadlineDate = dateFormatter.date(from: detail.deadline)
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.setLocalizedDateFormatFromTemplate("EE MMM d hh mm")
        deadline.setTitle(dateFormatter.string(from: deadlineDate!), for: .normal)
        emergence.value = Float(detail.emergence)
        if detail.completed == "false" {
            completeIndicator.setBackgroundImage(uncompleteColor, for: .normal)
            originCompleted = false
        } else {
            completeIndicator.setBackgroundImage(completeColor, for: .normal)
            completedTF = true
            originCompleted = true
        }
    }
    
    private func editDone() {
        if (subject.text != "" && content.text != ""){
            detail.subject = subject.text!
            detail.color = selectedColor
            detail.content = content.text!
            dateFormatter.dateFormat = "yyyy MM dd hh mm a"
            let newDeadline = dateFormatter.string(from: selectedDate)
            detail.deadline = newDeadline
            detail.emergence = Int(emergence.value)
            detail.completed = String(describing: completedTF)
        } else {
            let alertController = UIAlertController(title: "Unable to modify this due!", message: "You have incompleted fields!", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alertController.addAction(okAction)
            self.present(alertController, animated: true)
        }
        subject.isEnabled = false
        content.isEnabled = false
        deadline.isEnabled = false
        dueColor.isEnabled = false
        emergence.isEnabled = false
        completeIndicator.isEnabled = false
        print("HIDDEN")
        colorPicker.isHidden = true
        completedLabel.isHidden = false
        completeIndicator.isHidden = false
        datePicker.isHidden = true
    }
    
    private func imageFromColor(color: UIColor) -> UIImage
    {
        let rect = CGRect.init(x: 0, y: 0, width: 1, height: 1)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        context!.setFillColor(color.cgColor)
        context!.fill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
    
}
