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
@testable import Postal

class PostalTests: XCTestCase {
    override func invokeTest() {
        if Int(ProcessInfo().environment["POSTAL_RUN_ALL_TESTS"] ?? "0") == 0 {
            return
        }
        super.invokeTest()
    }
    
    func test_icloud_connection() {
        let credential = PostalTests.credentialsFor("icloud")
        
        doConnection(.icloud(login: credential.email, password: credential.password))
    }
    
    func test_gmail_connection() {
        let credential = PostalTests.credentialsFor("gmail")
        doConnection(.gmail(login: credential.email, password: .plain(credential.password)))
    }
    
    func test_yahoo_connection() {
        let credential = PostalTests.credentialsFor("yahoo")
        
        doConnection(.yahoo(login: credential.email, password: .plain(credential.password)))
    }
    
    func test_aol_connection() {
        let credential = PostalTests.credentialsFor("aol")
        
        doConnection(.aol(login: credential.email, password: credential.password))
    }
    
    func test_outlook_connection() {
        let credential = PostalTests.credentialsFor("outlook")

        doConnection(.outlook(login: credential.email, password: credential.password))
    }
}

private extension PostalTests {
    
    func doConnection(_ configuration: Configuration) {
        let expectation = self.expectation(description: "connection and login success to provider")
        
        let postal = Postal(configuration: configuration)
        postal.connect {
            switch $0 {
            case .failure: XCTFail("an error occured while connecting to provider")
            default: break
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
}
