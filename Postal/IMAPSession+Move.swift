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
    func moveMessages(fromFolder: String, toFolder: String, uids: IndexSet) throws -> [Int: Int] {
        guard uids.count > 0 else { return [:] }
        
        try select(fromFolder)
        
        let imapSet = uids.unreleasedMailimapSet
        defer { mailimap_set_free(imapSet) }
        
        var uidValidity: UInt32 = 0
        
        return try uids.enumerate(batchSize: 10).reduce([Int: Int]()) { combined, indexSet in
            var srcUid: UnsafeMutablePointer<mailimap_set>? = nil
            var destUid: UnsafeMutablePointer<mailimap_set>? = nil
            try mailimap_uidplus_uid_move(imap, imapSet, toFolder, &uidValidity, &srcUid, &destUid).toIMAPError?.check()
            
            let result: [Int: Int]
            if let srcUids = srcUid?.pointee.array, let destUids = destUid?.pointee.array, !srcUids.isEmpty && !destUids.isEmpty {
                result = Dictionary(keys: srcUids, values: destUids)
            } else {
                result = [:]
            }

            if srcUid != nil { mailimap_set_free(srcUid) }
            if destUid != nil { mailimap_set_free(destUid) }
            
            return combined.union(result)
        }
    }
}
