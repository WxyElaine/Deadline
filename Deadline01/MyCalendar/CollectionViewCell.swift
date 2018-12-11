//
//  CollectionViewCell.swift
//  MyCalendar
//
//  Created by Xinyi Wang on 11/28/17.
//  Copyright © 2017 Xinyi Wang. All rights reserved.
//

import UIKit
import JTAppleCalendar

class CollectionViewCell: JTAppleCell {
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var eventIndicator: UIView!
    
    public var dueEvent: Array<Due> = []
    public var segueTo: UIStoryboardSegue!
    public var date: String = ""
    
    // Initializer
    public override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

public struct Due {
    public var subject: String
    public var color: UIColor
    public var content: String
    public var deadline: String
    // 1 (urgent) --- 10
    public var emergence: Int
    public var completed: String
    public var recordName: String
    
    init() {
        subject = ""
        color = UIColor.white
        content = ""
        deadline = ""
        emergence = 10
        completed = ""
        recordName = ""
    }
    
    init(subject: String, color: UIColor, content: String, deadline: String, emergence: Int, completed: String, recordName: String) {
        self.subject = subject
        self.color = color
        self.content = content
        self.deadline = deadline
        self.emergence = emergence
        self.completed = completed
        self.recordName = recordName
    }
    
    func toJSON() -> String? {
        let tempColor = [self.color.components.red, self.color.components.green, self.color.components.blue]
        let temp = ["subject": self.subject, "color": tempColor, "content": self.content, "deadline": self.deadline, "emergence": self.emergence, "completed": self.completed, "recordName": self.recordName] as [String : Any]
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: temp, options: .prettyPrinted)
            return String(data: jsonData, encoding: String.Encoding.utf8)
        } catch let error {
            print("ERROR converting to json: \(error)")
            return nil
        }
    }
}

public struct DueDecodableUpper: Decodable {
    let due: [DueDecodable]
}

public struct DueDecodable: Decodable {
    let color: Array<Double>
    let content: String
    let deadline: String
    let completed: String
    // 1 (urgent) --- 10
    let emergence: Int
    let recordName: String
    let subject: String
}

extension UIColor {
    var coreImageColor: CIColor {
        return CIColor(color: self)
    }
    var components: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        let coreImageColor = self.coreImageColor
        return (coreImageColor.red, coreImageColor.green, coreImageColor.blue, coreImageColor.alpha)
    }
}

