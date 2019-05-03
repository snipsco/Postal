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

class IMAPSessionTests: XCTestCase {

    private lazy var __once: () = {
            let credential = PostalTests.credentialsFor("gmail")
            let configuration = Configuration.gmail(login: credential.email, password: .plain(credential.password))
            
            self.imapSession = IMAPSession(configuration: configuration)
            
            do {
                try self.imapSession.connect(timeout: 10)
                try self.imapSession.login()
                try self.imapSession.configure()
            } catch {
                print("ERROR: \(error)")
                XCTAssert(false)
            }
        }()

    fileprivate var imapSession: IMAPSession!
    fileprivate var token: Int = 0

    override func setUp() {
        super.setUp()
        
        // Connect to server only once
        _ = self.__once
    }
    
    override func invokeTest() {
        if Int(ProcessInfo().environment["POSTAL_RUN_ALL_TESTS"] ?? "0") == 0 {
            return
        }
        super.invokeTest()
    }
}

// MARK: - Folders
// TODO: Test flags

extension IMAPSessionTests {

    func test_list_folders() throws {
        let res = try imapSession.listFolders()
        
        print("folders:");
        res.forEach { print("\t\($0)") }
        
        // TODO: We should test retrieved folders names instead
        XCTAssertGreaterThan(res.count, 0, "should contains folders")
    }
}

// MARK: - Fetchers
// TODO: We should test retrieved ids as well as the number of messages count

extension IMAPSessionTests {
    
    func test_fetch_one_message_from_uid() throws {
        let indexSet = IndexSet(integer: 50)
        
        var results = [FetchResult]()
        try imapSession.fetchMessages("INBOX", set: .uid(indexSet), flags: []) { results.append($0) }
        
        print("1 messages:");
        results.forEach { print("\t\($0)") }
        
        XCTAssertEqual(results.count, 1, "should have retrieved the 1 first messages")
    }

    func test_fetch_ten_first_messages() throws {
        let indexSet = IndexSet(1...10)
        
        var results = [FetchResult]()
        try imapSession.fetchMessages("INBOX", set: .indexes(indexSet), flags: []) { results.append($0) }
        
        print("10 first messages:");
        results.forEach { print("\t\($0)") }
        
        XCTAssertEqual(results.count, 10, "should have retrieved the 10 first messages")
    }

    func test_fetch_ten_last_messages() throws {
        var results = [FetchResult]()
        try imapSession.fetchLast("INBOX", last: 10, flags: [ .structure ]) { results.append($0) }
        
        print("10 last messages:");
        results.forEach { print("\t\($0)") }
        
        XCTAssertEqual(results.count, 10, "should have retrieved the 10 last messages")
    }

    func no_test_fetch_all_messages() throws {
        let indexSet = IndexSet(0..<Int.max)

        var results = [FetchResult]()
        try imapSession.fetchMessages("INBOX", set: .indexes(indexSet), flags: [ .fullHeaders ]) { results.append($0) }
        
        print("every messages:");
        results.forEach { print("\t\($0)") }
        
        XCTAssertGreaterThan(results.count, 18, "should have retrieved all messages")
    }
    
    func test_fetch_ten_next_messages_from_a_given_uid() throws {
        let uid = 11
        let indexSet = IndexSet(uid...uid+10)
        
        var results = [FetchResult]()
        try imapSession.fetchMessages("INBOX", set: .uid(indexSet), flags: []) { results.append($0) }
        
        print("10 next uids from id #\(uid):");
        results.forEach { print("\t\($0)") }
        
        XCTAssertEqual(results.count, 4, "should have retrieved ten next uids from the uid #\(uid)")
    }
}

// MARK: - Seach
// TODO: Should unit test every kind of type search

extension IMAPSessionTests {
    
    func test_search_subject_and_from_fields() throws {
        let filter = .subject(value: "Tips for using") && .from(value: "mail-noreply@google.com")
        let res = try imapSession.search("INBOX", filter: filter)

        print("result: \(res)")

        XCTAssertEqual(res.count, 1, "should have retrieved the welcome mail of Google")
        XCTAssert(res.contains(3), "should have retrieved the welcome mail of Google")
    }

    func test_search_subject_or_cc_fields() throws {
        let filter = .subject(value: "Tips for using") || .from(value: "mail-noreply@google.com")
        let res = try imapSession.search("INBOX", filter: filter)
        
        print("result: \(res)")
        
        XCTAssertEqual(res.count, 1, "should have retrieved the welcome mail of Google")
        XCTAssert(res.contains(3), "should have retrieved the welcome mail of Google")
    }
    
    func test_search_not_subject_and_cc() throws {
        let filter = !.subject(value: "Tips for using") && .from(value: "mail-noreply@google.com")
        let res = try imapSession.search("INBOX", filter: filter)
        
        print("result: \(res)")
        
        XCTAssertEqual(res.count, 0, "should miss the welcome mail of Google because of the `not` subject filter")
    }
}
