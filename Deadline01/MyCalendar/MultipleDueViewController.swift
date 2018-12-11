//
//  MultipleDueViewController.swift
//  MyCalendar
//
//  Created by Xinyi Wang on 12/10/17.
//  Copyright © 2017 Xinyi Wang. All rights reserved.
//

import UIKit

class MultipleDueViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var dateTitle: UILabel!
    
    public var allEventList: Array<Due> = []
    public var eventList: Array<Due> = []
    public var lastJson: String = ""
    public var formattedDate: String = ""
    public var parentShoudFetch: Bool = false

    private var items: Array<ListTableViewCell> = []
    private var dateDetailViewController: DateDetailViewController!
    
    let dateFormatter = DateFormatter()
    
    // Tableview
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return eventList.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: ListTableViewCell
        if let celltry = self.tableView.dequeueReusableCell(withIdentifier: "cell") {
            cell = celltry as! ListTableViewCell
        } else {
            cell = ListTableViewCell.init(style: UITableViewCellStyle.subtitle, reuseIdentifier: "cell")
        }
        cell.dueEvent = eventList[indexPath.row]
        dateFormatter.dateFormat = "yyyy MM dd hh mm a"
        let date = dateFormatter.date(from: cell.dueEvent.deadline)!
        dateFormatter.dateFormat = "MMMM dd"
        cell.date = dateFormatter.string(from: date)
        
        cell.textLabel?.text = self.eventList[indexPath.row].subject
        cell.textLabel?.adjustsFontSizeToFitWidth = true
        
        dateFormatter.dateFormat = "yyyy MM dd hh mm a"
        let deadlineDate = dateFormatter.date(from: self.eventList[indexPath.row].deadline)!
        dateFormatter.dateFormat = "EE',' MMM d hh':'mm a"
        let deadlineStr = dateFormatter.string(from: deadlineDate)
        
        cell.detailTextLabel?.text = ("\(self.eventList[indexPath.row].content), Due: \(deadlineStr)")
        cell.detailTextLabel?.adjustsFontSizeToFitWidth = true
        cell.backgroundColor = self.eventList[indexPath.row].color.withAlphaComponent(0.2)
        
        items.append(cell)
        return cell
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        datedetailBuilder()
        let cell = tableView.cellForRow(at: indexPath)
        performSegue(withIdentifier: "multipleToDetail", sender: cell)
    }
    
    // MultipleDueViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        self.tableView.register(ListTableViewCell.self, forCellReuseIdentifier: "cell")
        
        dateTitle.text = formattedDate
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tableView.reloadData()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "multipleToDetail" {
            let datedetailView = segue.destination as! DateDetailViewController
            let dateCell = sender as! ListTableViewCell
            datedetailView.detail = dateCell.dueEvent
            datedetailView.formattedDate = dateCell.date
            datedetailView.lastView = "multipleDueView"
        } else if segue.identifier == "unwindToMultiple" {
            let calendarView = segue.destination as! ViewController
            if let i = allEventList.index(where: { $0.toJSON() == lastJson }) {
                allEventList.remove(at: i)
                allEventList.sort(by: { $0.deadline < $1.deadline })
                calendarView.shouldWrite = parentShoudFetch
                calendarView.shouldFetch = parentShoudFetch
                calendarView.eventList = allEventList
            } else {
                calendarView.shouldFetch = false
            }
        }
    }
    
    @IBAction func unwindToMultipleViewController(segue: UIStoryboardSegue) {
    }
    
    private func datedetailBuilder() {
        if dateDetailViewController == nil {
            dateDetailViewController = storyboard?.instantiateViewController(withIdentifier: "dateDetailViewController") as! DateDetailViewController
        }
    }

}
