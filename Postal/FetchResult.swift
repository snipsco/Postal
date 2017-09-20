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

/// The result of a fetch
public struct FetchResult {
    public fileprivate(set) var uid: UInt = 0
    public fileprivate(set) var header: MessageHeader? = nil
    public fileprivate(set) var flags: MessageFlag = []
    public fileprivate(set) var body: MailPart?
    public fileprivate(set) var rfc822Size: Int = 0
    public fileprivate(set) var internalDate: Date? = nil
    
    // MARK: Gmail specific
    
    public fileprivate(set) var gmailThreadId: UInt64? = nil
    public fileprivate(set) var gmailMessageId: UInt64? = nil
    public fileprivate(set) var gmailLabels: [String]? = nil
    
    public init(uid: UInt, header: MessageHeader?, flags: MessageFlag, body: MailPart?, rfc822Size: Int, internalDate: Date?, gmailThreadId: UInt64?, gmailMessageId: UInt64?, gmailLabels: [String]?) {
        self.uid = uid
        self.header = header
        self.flags = flags
        self.body = body
        self.rfc822Size = rfc822Size
        self.internalDate = internalDate
        self.gmailThreadId = gmailThreadId
        self.gmailMessageId = gmailMessageId
        self.gmailLabels = gmailLabels
    }
    
    internal init() {}
}

struct FetchResultBuilder {
    private let _addParsedAttribute: (MessageAttribute) -> Void
    private let _build: () -> FetchResult?
    
    init(flags: FetchFlag) {
        var builtResult = FetchResult()
        var hasUid = false
        
        _addParsedAttribute = { attribute in
            switch attribute {
            case .uid(let uid):
                hasUid = true
                builtResult.uid = uid
            case .envelope(let env): builtResult.header = env
            case .flags(let flags): builtResult.flags = flags
            case .bodySection(let sec):
                builtResult.header = sec.header
                if flags.contains(.body) {
                    builtResult.body = sec.body
                }
            case .bodyStructure(let structure):
                if !flags.contains(.body) {
                    builtResult.body = structure
                }
            case .rfc822(let rfc): builtResult.rfc822Size = rfc
            case .ext(let ext):
                switch ext {
                case .gmailLabels(let labels): builtResult.gmailLabels = labels
                case .gmailMessageId(let mid): builtResult.gmailMessageId = mid
                case .gmailThreadId(let tid): builtResult.gmailThreadId = tid
                case .modSeq:
                    break
                }
            case .internalDate(let date): builtResult.internalDate = date as Date
            }
        }
        
        _build = { return hasUid ? builtResult: nil }
    }
    
    func addParsedAttribute(_ attribute: MessageAttribute) {
        _addParsedAttribute(attribute)
    }
    
    var result: FetchResult? { return _build() }
}
