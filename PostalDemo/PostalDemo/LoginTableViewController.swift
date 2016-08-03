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
    
    var provider: MailProvider?
}

// MARK: - View lifecycle

extension LoginTableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let provider = provider, configuration = provider.preConfiguration {
            emailTextField.placeholder = "exemple@\(provider.hostname)"
            hostnameTextField.userInteractionEnabled = false
            hostnameTextField.text = configuration.hostname
            portTextField.userInteractionEnabled = false
            portTextField.text = "\(configuration.port)"
        }
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
                showAlertError("Error login", message: (error as NSError).localizedDescription)
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
        
        if let configuration = provider?.preConfiguration {
            return Configuration(hostname: configuration.hostname, port: configuration.port, login: email, password: .plain(password), connectionType: configuration.connectionType, checkCertificateEnabled: configuration.checkCertificateEnabled)
        } else {
            guard let hostname = hostnameTextField.text where !hostname.isEmpty else { throw LoginError.badHostname }
            guard let portText = portTextField.text where !portText.isEmpty else { throw LoginError.badPort }
            guard let port = UInt16(portText) else { throw LoginError.badPort }
            
            return Configuration(hostname: hostname, port: port, login: email, password: .plain(""), connectionType: .tls, checkCertificateEnabled: true)
        }
    }
}
