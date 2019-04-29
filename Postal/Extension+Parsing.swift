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

enum MessageExtension {
    case modSeq(UInt64)
    case gmailThreadId(UInt64)
    case gmailMessageId(UInt64)
    case gmailLabels([String])
}

extension MessageExtension: CustomStringConvertible {
    var description: String {
        switch self {
        case .modSeq(let seq): return "modSeq(\(seq))"
        case .gmailThreadId(let tid): return "gmailThreadId(\(tid))"
        case .gmailMessageId(let mid): return "gmailMessageId(\(mid))"
        case .gmailLabels(let labels): return "gmailLabels(\(labels))"
        }
    }
}

// MARK: IMAP Parsing

extension mailimap_extension_data {
    var parse: MessageExtension? {
        switch ext_extension {
        case &mailimap_extension_condstore:
            let modSeq = ext_data.assumingMemoryBound(to: mailimap_condstore_fetch_mod_resp.self).pointee.cs_modseq_value
            
            return .modSeq(modSeq)
        case &mailimap_extension_xgmlabels:
            guard let labelList = ext_data.assumingMemoryBound(to: mailimap_msg_att_xgmlabels.self).pointee.att_labels else { return nil }
            let labels = pointerSequence(labelList, of: CChar.self).compactMap(String.fromUTF8CString)

            return labels.count > 0 ? .gmailLabels(labels) : nil
        case &mailimap_extension_xgmthrid:
            let threadId = ext_data.assumingMemoryBound(to: UInt64.self).pointee
            
            return .gmailThreadId(threadId)
        case &mailimap_extension_xgmmsgid:
            let msgId = ext_data.assumingMemoryBound(to: UInt64.self).pointee
            
            return .gmailMessageId(msgId)
        default:
            return nil
        }
    }
}
