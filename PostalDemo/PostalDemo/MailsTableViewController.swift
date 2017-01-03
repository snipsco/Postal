//
//  MailsTableViewController.swift
//  PostalDemo
//
//  Created by Kevin Lefevre on 06/06/2016.
//  Copyright © 2017 Snips. All rights reserved.
//

import UIKit
import Postal
import Result

class MailsTableViewController: UITableViewController {
    var configuration: Configuration!
    
    fileprivate lazy var postal: Postal = Postal(configuration: self.configuration)
    fileprivate var messages: [FetchResult] = []
}

// MARK: - View lifecycle

extension MailsTableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
     
        // Do connection
        postal.connect(timeout: Postal.defaultTimeout, completion: { [weak self] result in
            switch result {
            case .success: // Fetch 50 last mails of the INBOX
                self?.postal.fetchLast("INBOX", last: 50, flags: [ .fullHeaders ], onMessage: { message in
                    self?.messages.insert(message, at: 0)
                    
                    }, onComplete: { error in
                        if let error = error {
                            self?.showAlertError("Fetch error", message: (error as NSError).localizedDescription)
                        } else {
                            self?.tableView.reloadData()
                        }
                })

            case .failure(let error):
                self?.showAlertError("Connection error", message: (error as NSError).localizedDescription)
            }
        })
    }
}

// MARK: - Table view data source

extension MailsTableViewController {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MailTableViewCell", for: indexPath)

        let message = messages[indexPath.row]
        
        cell.textLabel?.text = message.header?.subject
        cell.detailTextLabel?.text = "UID: #\(message.uid)"
        
        return cell
    }
}

// MARK: - Helper

private extension MailsTableViewController {
    
}
