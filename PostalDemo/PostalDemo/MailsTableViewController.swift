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
     
        // Do connection
        postal.connect(timeout: Postal.defaultTimeout, completion: { [weak self] result in
            switch result {
            case .Success: // Fetch 50 last mails of the INBOX
                self?.postal.fetchLast("INBOX", last: 50, flags: [ .fullHeaders ], onMessage: { message in
                    self?.messages.insert(message, atIndex: 0)
                    
                    }, onComplete: { error in
                        if let error = error {
                            self?.showAlertError("Fetch error", message: (error as NSError).localizedDescription)
                        } else {
                            self?.tableView.reloadData()
                        }
                })

            case .Failure(let error):
                self?.showAlertError("Connection error", message: (error as NSError).localizedDescription)
            }
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

// MARK: - Helper

private extension MailsTableViewController {
    
}
