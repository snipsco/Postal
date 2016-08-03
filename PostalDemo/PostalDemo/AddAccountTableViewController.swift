//
//  ViewController.swift
//  PostalDemo
//
//  Created by Kevin Lefevre on 23/05/2016.
//  Copyright © 2016 snips. All rights reserved.
//

import UIKit
import Postal

enum MailProvider: Int {
    case icloud
    case google
    case yahoo
    case outlook
    case aol
    
    var hostname: String {
        switch self {
        case .icloud: return "icloud.com"
        case .google: return "gmail.com"
        case .yahoo: return "yahoo.com"
        case .outlook: return "outlook.com"
        case .aol: return "aol.com"
        }
    }
    
    var preConfiguration: Configuration? {
        switch self {
        case .icloud: return .icloud(login: "", password: "")
        case .google: return .gmail(login: "", password: .plain(""))
        case .yahoo: return .yahoo(login: "", password: .plain(""))
        case .outlook: return .outlook(login: "", password: "")
        case .aol: return .aol(login: "", password: "")
        }
    }
}

final class AddAccountTableViewController: UITableViewController {
    private let loginSegueIdentifier = "loginSegue"    
}

// MARK: - View lifecycle

extension AddAccountTableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }
}


// MARK: - Navigation management

extension AddAccountTableViewController {
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        switch (segue.identifier, segue.destinationViewController, sender) {
        case (.Some(loginSegueIdentifier), let vc as LoginTableViewController, let provider as Int):
            vc.provider = MailProvider(rawValue: provider)
        default: break
        }
    }
}

// MARK: - UITableViewDelegate

extension AddAccountTableViewController {
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        guard let provider = MailProvider(rawValue: indexPath.row) else { fatalError("Unknown provider") }
        print("selected provider: \(provider)")
        
        performSegueWithIdentifier(loginSegueIdentifier, sender: provider.rawValue)
        
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
}
