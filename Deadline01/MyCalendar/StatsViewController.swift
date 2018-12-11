//
//  StatsViewController.swift
//  MyCalendar
//
//  Created by Xinyi Wang on 12/5/17.
//  Copyright © 2017 Xinyi Wang. All rights reserved.
//

import UIKit

class StatsViewController: UIViewController {
    
    //need to be populized, from icloud or other views..
    public var eventList: Array<Due> = []
    public var completedList: Array<Due> = []
    public var overdueList: Array<Due> = []
    public var shouldCalc: Bool = false
    
    let dateFormatter = DateFormatter()

    @IBOutlet weak var progressStack: UIStackView!
    @IBOutlet weak var overdueBarWidth: NSLayoutConstraint!
    @IBOutlet weak var inprogressBarWidth: NSLayoutConstraint!
    @IBOutlet weak var finishedBarWidth: NSLayoutConstraint!
    @IBOutlet weak var finishedLabel: UILabel!
    @IBOutlet weak var overdueLabel: UILabel!
    @IBOutlet weak var inprogressLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if shouldCalc {
            calcProgress()
        }
        print(eventList)
        print(completedList)
        print(overdueList)
        
        let finished = completedList.count
        let overdue = overdueList.count
        let inprogress = eventList.count - finished - overdue
        
        finishedLabel.text = finished.description
        overdueLabel.text = overdue.description
        inprogressLabel.text = inprogress.description
        
        let totalTask = inprogress + finished + overdue
        if (totalTask != 0) {
            let length = progressStack.frame.width
            
            finishedBarWidth.constant = CGFloat(Float(length) * (Float(finished) / Float(totalTask)))
            inprogressBarWidth.constant = CGFloat(Float(length) * (Float(inprogress) / Float(totalTask)))
            overdueBarWidth.constant = CGFloat(Float(length) * (Float(overdue) / Float(totalTask)))
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        // Dispose of any resources that can be recreated.
    }
    
    private func calcProgress() {
        completedList.removeAll()
        overdueList.removeAll()
        for event : Due in eventList {
            if event.completed == "true" {
                completedList.append(event)
            }
            dateFormatter.dateFormat = "yyyy MM dd hh mm a"
            let duedate = dateFormatter.date(from: event.deadline)!
            if duedate < Date() {
                overdueList.append(event)
            }
        }
    }
}

