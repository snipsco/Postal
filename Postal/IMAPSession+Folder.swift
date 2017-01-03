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

import Foundation
import libetpan

extension IMAPSession {
    func delete(folderNamed folderName: String) throws {
        try select("INBOX")
        try mailimap_delete(imap, folderName).toIMAPError?.check()
    }
    
    func create(folderNamed folderName: String) throws {
        try select("INBOX")
        try mailimap_create(imap, folderName).toIMAPError?.check()
    }
    
    func rename(folderNamed fromFolderName: String, to toFolderName: String) throws {
        try select("INBOX")
        try mailimap_rename(imap, fromFolderName, toFolderName).toIMAPError?.check()
    }
    
    func subscribe(folderNamed folderName: String) throws {
        try select("INBOX")
        try mailimap_subscribe(imap, folderName).toIMAPError?.check()
    }
    
    func unsubscribe(folderNamed folderName: String) throws {
        try select("INBOX")
        try mailimap_unsubscribe(imap, folderName).toIMAPError?.check()
    }
    
    func expunge(folderNamed folderName: String) throws {
        try select(folderName)
        try mailimap_expunge(imap).toIMAPError?.check()
    }
}
