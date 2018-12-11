//
//  ListTableViewCell.swift
//  MyCalendar
//
//  Created by Xinyi Wang on 12/7/17.
//  Copyright © 2017 Xinyi Wang. All rights reserved.
//

import UIKit

class ListTableViewCell: UITableViewCell {
    public var dueEvent: Due = Due()
    public var date: String = ""
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: "cell")
    }
    
    required init(coder aDecoder: NSCoder) {
        //fatalError("init(coder:) has not been implemented")
        super.init(coder: aDecoder)!
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
}

