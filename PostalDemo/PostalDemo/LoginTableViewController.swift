//
//  LoginTableViewController.swift
//  PostalDemo
//
//  Created by Kevin Lefevre on 24/05/2016.
//  Copyright © 2016 Snips. All rights reserved.
//

import UIKit
import Postal

enum LoginError: ErrorType {
    case badEmail
    case badPassword
    case badHostname
    case badPort
}

extension LoginError: CustomStringConvertible {
    var description: String {
        switch self {
        case .badEmail: return "Bad mail"
        case .badPassword: return "Bad password"
        case .badHostname: return "Bad hostname"
        case .badPort: return "Bad port"
        }
    }
}

final class LoginTableViewController: UITableViewController {
    private let mailsSegueIdentifier = "mailsSegue"

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var hostnameTextField: UITextField!
    @IBOutlet weak var portTextField: UITextField!
    
    var provider: MailProvider!
}

// MARK: - View lifecycle

extension LoginTableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        emailTextField.placeholder = "example@\(provider.hostname)"
    }
}

// MARK: - Navigation management

extension LoginTableViewController {
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        switch (segue.identifier, segue.destinationViewController) {
        case (.Some(mailsSegueIdentifier), let vc as MailsTableViewController):
            do {
                vc.configuration = try createConfiguration()
            } catch let error as LoginError {
                let alert = UIAlertController(title: "Error", message: error.description, preferredStyle: .Alert)
                alert.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
                presentViewController(alert, animated: true, completion: nil)
            } catch {
                fatalError()
            }
            break
        default: break
        }
    }
}

// MARK: - Helpers

private extension LoginTableViewController {
    
    func createConfiguration() throws -> Configuration {
        guard let email = emailTextField.text where !email.isEmpty else { throw LoginError.badEmail  }
        guard let password = passwordTextField.text where !password.isEmpty else { throw LoginError.badPassword }
        
        switch provider! {
        case .icloud:
            return .icloud(login: email, password: password)
        case .google:
            return .gmail(login: email, password: .plain(password))
        case .yahoo:
            return .yahoo(login: email, password: .plain(password))
        case .outlook:
            return .outlook(login: email, password: password)
        case .aol:
            return .aol(login: email, password: password)
        case .other:
            guard let hostname = hostnameTextField.text where !hostname.isEmpty else { throw LoginError.badHostname }
            guard let portText = portTextField.text where !portText.isEmpty else { throw LoginError.badPort }
            guard let port = UInt16(portText) else { throw LoginError.badPort }

            return Configuration(hostname: hostname, port: port, login: email, password: .plain(password), connectionType: .TLS, checkCertificateEnabled: true)
        }
    }
}
