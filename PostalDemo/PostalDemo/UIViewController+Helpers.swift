//
//  UIViewController+Helpers.swift
//  PostalDemo
//
//  Created by Kevin Lefevre on 03/08/2016.
//  Copyright © 2016 Snips. All rights reserved.
//

import UIKit

extension UIViewController {
    func showAlertError(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
        presentViewController(alert, animated: true, completion: nil)
    }
}
