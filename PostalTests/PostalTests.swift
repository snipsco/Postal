//
//  PostalTests.swift
//  PostalTests
//
//  Created by Jeremie Girault on 18/05/2016.
//  Copyright © 2016 snips. All rights reserved.
//

import XCTest
@testable import Postal

class PostalTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        let dummy = Dummy()
        dummy.test()
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}
