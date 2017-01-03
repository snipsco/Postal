//
//  LibetpanConversionTests.swift
//  Postal
//
//  Created by Kevin Lefevre on 21/09/2016.
//  Copyright © 2017 snips. All rights reserved.
//

import XCTest
import libetpan
@testable import Postal

class LibetpanConversionTests: XCTestCase {

    func test_indexset_to_imapset() {
        var givenIndexSet = IndexSet(1...5)
        givenIndexSet.remove(3)
        
        let retrievedImapSet = givenIndexSet.unreleasedMailimapSet
        defer { mailimap_set_free(retrievedImapSet) }
        
        let retrievedImapSetSequence = sequence(retrievedImapSet.pointee.set_list, of: mailimap_set_item.self)
        retrievedImapSetSequence.enumerated().forEach { (offset: Int, element: mailimap_set_item) in
            let givenRange = givenIndexSet.rangeView[offset]
            XCTAssertEqual(Int(element.set_first), givenRange.lowerBound)
            XCTAssertEqual(Int(element.set_last), givenRange.upperBound)
        }
    }
    
    func test_indexset_to_imapset_for_intmax() {
        let givenLowerBound = Int64.max - 10
        let givenUpperBoun = Int64.max
        let givenIndexSet = IndexSet(Int(givenUpperBoun)..<Int(givenUpperBoun))
        
        let retrievedImapSet = givenIndexSet.unreleasedMailimapSet
        defer { mailimap_set_free(retrievedImapSet) }

        let expectedLowerBound = UInt32.max - 10
        let expectedUpperBound = UInt32.max
        
        let retrievedImapSetSequence = sequence(retrievedImapSet.pointee.set_list, of: mailimap_set_item.self)
        retrievedImapSetSequence.enumerated().forEach { (offset: Int, element: mailimap_set_item) in
            XCTAssertEqual(element.set_first, expectedLowerBound)
            XCTAssertEqual(element.set_last, expectedUpperBound)
        }
    }
    
    func test_imapset_to_indexset() {
        var expectedIndexSet = IndexSet(1...5)
        expectedIndexSet.remove(3)

        let imapSet = expectedIndexSet.unreleasedMailimapSet
        defer { mailimap_set_free(imapSet) }
        
        let retrievedIndexSet = imapSet.pointee.indexSet

        XCTAssertEqual(expectedIndexSet, retrievedIndexSet)
    }
    
    func test_imapset_to_array() {
        var expectedIndexSet = IndexSet(1...5)
        expectedIndexSet.remove(3)
        
        let imapSet = expectedIndexSet.unreleasedMailimapSet
        defer { mailimap_set_free(imapSet) }
        
        let expectedArray = [1, 2, 4, 5]
        let retrievedArray = imapSet.pointee.array
        
        XCTAssertEqual(expectedArray, retrievedArray)
    }
}
