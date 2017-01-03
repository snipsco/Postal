//
//  The MIT License (MIT)
//
//  Copyright (c) 2017 Snips
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import XCTest

extension XCTestCase {
    static func jsonFromFile(_ filename: String) -> [String: AnyObject] {
        let jsonPath = Bundle(for: self).path(forResource: filename, ofType: "json")
        let jsonData = try? Data(contentsOf: URL(fileURLWithPath: jsonPath!))
        return try! JSONSerialization.jsonObject(with: jsonData!, options: []) as! [String: AnyObject]
    }

    static func jsonArrayFromFile(_ filename: String) -> [[String: AnyObject]] {
        let jsonPath = Bundle(for: self).path(forResource: filename, ofType: "json")
        let jsonData = try? Data(contentsOf: URL(fileURLWithPath: jsonPath!))
        return try! JSONSerialization.jsonObject(with: jsonData!, options: []) as! [[String: AnyObject]]
    }
    
    static func credentialsFor(_ provider: String) -> (email: String, password: String) {
        let json = jsonFromFile("provider_credentials")
        
        guard let providerInfo = json[provider] as? [String: String] else { fatalError("\(provider) isn't in provider.json") }
        guard let email = providerInfo["email"] else { fatalError("email not present for \(provider)") }
        guard let password = providerInfo["password"] else { fatalError("password not \(provider)") }
        
        return (email, password)
    }
}
