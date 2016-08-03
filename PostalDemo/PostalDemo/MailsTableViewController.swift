//
//  MailsTableViewController.swift
//  PostalDemo
//
//  Created by Kevin Lefevre on 06/06/2016.
//  Copyright © 2016 Snips. All rights reserved.
//

import UIKit
import Postal
import Result

class MailsTableViewController: UITableViewController {
    var configuration: Configuration!
    
    private lazy var postal: Postal = Postal(configuration: self.configuration)
    private var messages: [FetchResult] = []
}

// MARK: - View lifecycle

extension MailsTableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
     
        postal.connect(timeout: Postal.defaultTimeout, completion: { [weak self] result in
            switch result {
            case .Success:
                print("success")
            case .Failure(let error):
                print("error: \(error)")
            }
            
            self?.postal.fetchLast("INBOX", last: 50, flags: [ .headers ], onMessage: { message in
                self?.messages.append(message)
                
                }, onComplete: { error in
                    if let error = error {
                        print("fetch error: \(error)")
                        return
                    }

                    self?.tableView.reloadData()
                })
        })
    }
}

// MARK: - Table view data source

extension MailsTableViewController {

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("MailTableViewCell", forIndexPath: indexPath)

        let message = messages[indexPath.row]
        
        cell.textLabel?.text = message.header?.subject
        cell.detailTextLabel?.text = "UID: #\(message.uid)"
        
        return cell
    }
}
