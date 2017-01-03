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

public struct MessageFlag: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    
    public static let seen             = MessageFlag(rawValue: 1 << 0)
    public static let answered         = MessageFlag(rawValue: 1 << 1)
    public static let flagged          = MessageFlag(rawValue: 1 << 2)
    public static let deleted          = MessageFlag(rawValue: 1 << 3)
    public static let draft            = MessageFlag(rawValue: 1 << 4)
    public static let MDNSent          = MessageFlag(rawValue: 1 << 5)
    public static let forwarded        = MessageFlag(rawValue: 1 << 6)
    public static let submitPending    = MessageFlag(rawValue: 1 << 7)
    public static let submitted        = MessageFlag(rawValue: 1 << 8)
    public static let all: MessageFlag = [ .seen, .answered, .flagged, .deleted, .draft, .MDNSent, .forwarded, .submitPending, .submitted ]
}

extension MessageFlag: CustomStringConvertible {
    public var description: String {
        let flags: [(MessageFlag, String)] = [
            (.seen,             "seen"),
            (.answered,         "answered"),
            (.flagged,          "flagged"),
            (.deleted,          "deleted"),
            (.draft,            "draft"),
            (.MDNSent,          "MDNSent"),
            (.forwarded,        "forwarded"),
            (.submitPending,    "submitPending"),
            (.submitted,        "submitted"),
            ]
        return representation(flags)
    }
}

// MARK: IMAP Parsing

extension mailimap_flag {
    var toMessageFlag: MessageFlag {
        switch Int(fl_type) {
        case MAILIMAP_FLAG_ANSWERED: return .answered
        case MAILIMAP_FLAG_FLAGGED: return .flagged
        case MAILIMAP_FLAG_DELETED: return .deleted
        case MAILIMAP_FLAG_SEEN: return .seen
        case MAILIMAP_FLAG_DRAFT: return .draft
        case MAILIMAP_FLAG_KEYWORD:
            switch String.fromUTF8CString(fl_data.fl_keyword)?.lowercased() ?? "" {
            case "$Forwarded": return .forwarded
            case "$MDNSent": return .MDNSent
            case "$SubmitPending": return .submitPending
            case "$Submitted": return .submitted
            default: return  []
            }
        default: return []
        }
    }
}
