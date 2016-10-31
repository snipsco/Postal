//
//  UIViewController+Helpers.swift
//  PostalDemo
//
//  Created by Kevin Lefevre on 03/08/2016.
//  Copyright © 2016 Snips. All rights reserved.
//

import UIKit

extension UIViewController {
    func showAlertError(_ title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}
