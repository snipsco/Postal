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

public struct FetchFlag: OptionSet {
    public let rawValue: Int
    
    public init(rawValue: Int) { self.rawValue = rawValue }
    
    public static let uid              = FetchFlag(rawValue: 0) // This is the default and it's always fetched
    public static let flags            = FetchFlag(rawValue: 1 << 0)
    public static let headers          = FetchFlag(rawValue: 1 << 1)
    public static let structure        = FetchFlag(rawValue: 1 << 2)
    public static let internalDate     = FetchFlag(rawValue: 1 << 3)
    public static let fullHeaders      = FetchFlag(rawValue: 1 << 4)
    public static let headerSubject    = FetchFlag(rawValue: 1 << 5)
    public static let gmailLabels      = FetchFlag(rawValue: 1 << 6)
    public static let gmailMessageID   = FetchFlag(rawValue: 1 << 7)
    public static let gmailThreadID    = FetchFlag(rawValue: 1 << 8)
    public static let size             = FetchFlag(rawValue: 1 << 9)
    public static let body             = FetchFlag(rawValue: 1 << 10)
}

extension FetchFlag: CustomStringConvertible {
    public var description: String {
        let flags: [(FetchFlag, String)] = [
            (.uid,              "Uid"),
            (.flags,            "Flags"),
            (.headers,          "Headers"),
            (.structure,        "Structure"),
            (.internalDate,     "InternalDate"),
            (.fullHeaders,      "FullHeaders"),
            (.headerSubject,    "HeaderSubject"),
            (.gmailLabels,      "GmailLabels"),
            (.gmailMessageID,   "GmailMessageID"),
            (.gmailThreadID,    "GmailThreadID"),
            (.size,             "Size")
        ]
        return representation(flags)
    }
}

private extension FetchFlag {
    func unreleasedFetchAttributeList(_ extraHeaders: Set<String>) -> UnsafeMutablePointer<mailimap_fetch_type> {
        typealias CreateAttribute = () -> UnsafeMutablePointer<mailimap_fetch_att>?
        
        let flags: [(FetchFlag, CreateAttribute)] = [
            (.uid,              mailimap_fetch_att_new_uid),
            (.flags,            mailimap_fetch_att_new_flags),
            (.headers,          mailimap_fetch_att_new_envelope),
            (.structure,        mailimap_fetch_att_new_bodystructure),
            (.internalDate,     mailimap_fetch_att_new_internaldate),
            (.gmailLabels,      mailimap_fetch_att_new_xgmlabels),
            (.gmailMessageID,   mailimap_fetch_att_new_xgmmsgid),
            (.gmailThreadID,    mailimap_fetch_att_new_xgmthrid),
            (.size,             mailimap_fetch_att_new_rfc822_size)
        ]
        
        let list = mailimap_fetch_type_new_fetch_att_list_empty()
        flags.forEach { flag, create in
            if contains(flag) {
                mailimap_fetch_type_new_fetch_att_list_add(list, create())
            }
        }
        
        // handle headers
        var headerList = Set<String>(extraHeaders)
        // TODO: Embed headerList in the FetchFlag type instead
        if contains(.fullHeaders) {
            headerList.formUnion([ "Date", "Subject", "From", "Sender", "Reply-To", "To", "Cc", "Message-ID", "References", "In-Reply-To" ])
        }
        if contains(.headers) {
            headerList.formUnion([ "References" ])
            if contains(.headerSubject) { headerList.formUnion( [ "Subject" ]) }
        }
        if !headerList.isEmpty {
            let cHeaderList = headerList.unreleasedClist { $0.unreleasedUTF8CString } // ownership of elements seems transfered to list
            let imapHeaderList = mailimap_header_list_new(cHeaderList)
            let section = mailimap_section_new_header_fields(imapHeaderList)
            let attr = mailimap_fetch_att_new_body_peek_section(section)
            mailimap_fetch_type_new_fetch_att_list_add(list, attr)
        }
        
        if contains(.body) {
            let bodySection = mailimap_section_new(nil)
            let bodyAttr = mailimap_fetch_att_new_body_peek_section(bodySection)
            mailimap_fetch_type_new_fetch_att_list_add(list, bodyAttr)
        }
        
        return list!
    }
}

extension IndexSet {
    var mailimapSet: mailimap_set {
        let imapSet = unreleasedMailimapSet
        defer { mailimap_set_free(imapSet) }
        return imapSet.pointee
    }
    
    var unreleasedMailimapSet: UnsafeMutablePointer<mailimap_set> {
        let result: UnsafeMutablePointer<mailimap_set> = mailimap_set_new_empty()
        
        rangeView.forEach { range in
            let safeFirst = UInt32(truncatingIfNeeded: range.startIndex)
            let safeLast = UInt32(truncatingIfNeeded: range.upperBound - 1)

            mailimap_set_add_interval(result, safeFirst, safeLast)
        }
        return result
    }
}

enum IMAPIndexes {
    case uid(IndexSet)
    case indexes(IndexSet)
}

private class FetchContext {
    var hasMoreMessage = false
    let handler: ((FetchResult) -> Void)
    let flags: FetchFlag

    init(flags: FetchFlag, handler: @escaping ((FetchResult) -> Void)) {
        self.flags = flags
        self.handler = handler
    }
}

extension IMAPSession {
    func fetchLast(_ folder: String, last: UInt, flags: FetchFlag, extraHeaders: Set<String> = [], handler: @escaping (FetchResult) -> Void) throws {
        let info = try select(folder)
        
        let location: Int = Int(info.messagesCount > last ? ((Int(info.messagesCount) - Int(last)) + 1) : 1)
        let length: Int = Int(info.messagesCount > last ? last : info.messagesCount)
        
        let indexSet = IndexSet(location..<(location+length))
        
        try fetchMessages(folder, set: .indexes(indexSet), flags: flags, extraHeaders: extraHeaders, handler: handler)
    }
    
    func fetchMessages(_ folder: String, set: IMAPIndexes, flags: FetchFlag, extraHeaders: Set<String> = [], handler: @escaping (FetchResult) -> Void) throws {
        let info = try select(folder)
        
        var context = FetchContext(flags: flags, handler: handler)
        mailimap_set_msg_att_handler(imap, { message, context in
            autoreleasepool {
                guard let fetchContext = context?.assumingMemoryBound(to: FetchContext.self).pointee else { return }
                let builder = FetchResultBuilder(flags: fetchContext.flags)
                
                fetchContext.hasMoreMessage = true
                
                guard let result = message?.pointee.parse(builder) else { return }
                
                fetchContext.handler(result)
            }
        }, &context)
        defer { mailimap_set_msg_att_handler(imap, nil, nil) }

        let fetchType = flags.unreleasedFetchAttributeList(extraHeaders)
        defer { mailimap_fetch_type_free(fetchType) }
        
        let givenIndexSet: IndexSet
        
        typealias FetchFunc = (UnsafeMutablePointer<mailimap>, UnsafeMutablePointer<mailimap_set>, UnsafeMutablePointer<mailimap_fetch_type>, UnsafeMutablePointer<UnsafeMutablePointer<clist>?>) -> Int32
        let fetchFunc: FetchFunc
        
        switch set {
        case .uid(let indexSet):
            givenIndexSet = indexSet
            fetchFunc = mailimap_uid_fetch
            
        case .indexes(let indexSet):
            givenIndexSet = indexSet
            fetchFunc = mailimap_fetch
        }

        for indexSet in givenIndexSet.enumerate(batchSize: configuration.batchSize) {
            let imapSet = indexSet.unreleasedMailimapSet
            defer { mailimap_set_free(imapSet) }
            
            context.hasMoreMessage = false
            
            var results: UnsafeMutablePointer<clist>? = nil
            try fetchFunc(self.imap, imapSet, fetchType, &results).toIMAPError?.check()
            defer { mailimap_fetch_list_free(results) }
            
            guard context.hasMoreMessage else { break }
        }
    }
    
    // fetch a set of attachments from an email with given uid
    func fetchParts(_ folder: String, uid: UInt, partId: String, handler: @escaping (MailData) -> Void) throws {
        let info = try select(folder)
        
        // create body peek sections for part ids
        let list = partId.unreleasedPartIdList
        let sectionPart = mailimap_section_part_new(list)
        let section = mailimap_section_new_part(sectionPart)
        let bodyPeekSection = mailimap_fetch_att_new_body_peek_section(section)
        let attList = mailimap_fetch_type_new_fetch_att(bodyPeekSection)
        defer { mailimap_fetch_type_free(attList) }
        
        var context = FetchContext(flags: [ .body ]) { fetchResult in
            // forward to handler
            fetchResult.body?.allParts.forEach { singlePart in
                guard let data = singlePart.data else { return }
                handler(data)
            }
        }
        
        mailimap_set_msg_att_handler(imap, { message, context in
            autoreleasepool {
                guard let fetchContext = context?.assumingMemoryBound(to: FetchContext.self).pointee else { return }
                
                let builder = FetchResultBuilder(flags: fetchContext.flags)
                
                guard let result = message?.pointee.parse(builder) else { return }
                
                fetchContext.handler(result)
            }
        }, &context)
        defer { mailimap_set_msg_att_handler(imap, nil, nil) }
        
        // create a set of email to fetch attachment from with the unique uid we have
        let indexSet = IndexSet(integer: Int(uid))
        let imapSet = indexSet.unreleasedMailimapSet
        defer { mailimap_set_free(imapSet) }
        
        // fetch
        var results: UnsafeMutablePointer<clist>? = nil
        try mailimap_uid_fetch(imap, imapSet, attList, &results).toIMAPError?.check()
        defer { mailimap_fetch_list_free(results) }
    }
}

extension MailPart {
    func idHierarchy(_ tabs: Int) -> String {
        let tabString = String(repeating: "\t", count: tabs)
        switch self {
        case .single(let id, _, _, _): return "\(tabString)\(id)"
        case .multipart(let id, _, let parts):
            let elements = parts.map { $0.idHierarchy(tabs+1) }.joined(separator: "\n")
            return "\(tabString)\(id)\n\(elements)"
        case .message(let id, _, let msg):
            return "\(tabString)\(id)\n\(msg.idHierarchy(tabs+1))"
        }
    }
}

private extension String {
     var unreleasedPartIdList: UnsafeMutablePointer<clist>? {
        var partIdList = [UInt32]()
        for str in components(separatedBy: ".") {
            guard let id = UInt32(str) else { return nil }
            partIdList.append(id)
        }
        
        let list = clist_new()
        partIdList.forEach { id in
            let idPtr: UnsafeMutablePointer<UInt32> = .allocate(capacity: 1)
            idPtr.pointee = id
            clist_append(list, idPtr)
        }
        
        return list
    }
}
