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

public enum SearchKind {
    case all
    case from(value: String)
    case to(value: String)
    case cc(value: String)
    case bcc(value: String)
    case recipient(value: String) // recipient is the combination of to, cc and bcc
    case subject(value: String)
    case content(value: String)
    case body(value: String)
    case uids(uids: IndexSet)
    case numbers(numbers: IndexSet)
    case header(header: String, value: String)
    case read
    case unread
    case flagged
    case unflagged
    case answered
    case unanswered
    case draft
    case undraft
    case deleted
    case spam
    case beforeDate(date: Date)
    case onDate(date: Date)
    case sinceDate(date: Date)
    case beforeReceivedDate(date: Date)
    case onReceivedDate(date: Date)
    case sinceReceivedDate(date: Date)
    case sizeLarger(size: uint)
    case sizeSmaller(size: uint)
    case gmailThreadId(id: uint)
    case gmailMessageId(id: uint)
    case gmailRaw(string: String)
}

public indirect enum SearchFilter {
    case and(SearchFilter, SearchFilter)
    case or(SearchFilter, SearchFilter)
    case not(SearchFilter)
    case base(SearchKind)
}

// MARK: CustomStringConvertible extensions

extension SearchKind: CustomStringConvertible {
    public var description: String {
        switch self {
        case .all: return ".all"
        case .from(let value): return ".from(\(value))"
        case .to(let value): return ".to(\(value))"
        case .cc(let value): return ".cc(\(value))"
        case .bcc(let value): return ".bcc(\(value))"
        case .recipient(let value):return ".recipient(\(value))" // recipient is the combination of to, cc and bcc
        case .subject(let value): return ".subject(\(value))"
        case .content(let value): return ".content(\(value))"
        case .body(let value): return ".body(\(value))"
        case .uids(let uids): return ".uids(\(uids))"
        case .numbers(let numbers): return ".numbers(\(numbers))"
        case .header(let header, let value): return ".header(\(header), \(value))"
        case .read: return ".read"
        case .unread: return ".unread"
        case .flagged: return ".flagged"
        case .unflagged: return ".unflagged"
        case .answered: return ".answered"
        case .unanswered: return ".unanswered"
        case .draft: return ".draft"
        case .undraft: return ".undraft"
        case .deleted: return ".deleted"
        case .spam: return ".spam"
        case .beforeDate(let date): return ".beforeDate(\(date))"
        case .onDate(let date): return ".onDate(\(date))"
        case .sinceDate(let date): return ".sinceDate(\(date))"
        case .beforeReceivedDate(let date): return ".beforeReceivedDate(\(date))"
        case .onReceivedDate(let date): return ".onReceivedDate(\(date))"
        case .sinceReceivedDate(let date): return ".sinceReceivedDate(\(date))"
        case .sizeLarger(let size): return ".sizeLarger(\(size))"
        case .sizeSmaller(let size): return ".sizeSmaller(\(size))"
        case .gmailThreadId(let id): return ".gmailThreadId(\(id))"
        case .gmailMessageId(let id): return ".gmailMessageId(\(id))"
        case .gmailRaw(let raw): return ".gmailRaw(\(raw))"
        }
    }
}

extension SearchFilter: CustomStringConvertible {
    public var description: String {
        switch self {
        case .and(let lhs, let rhs): return "\(lhs) && \(rhs)"
        case .or(let lhs, let rhs): return "\(lhs) || \(rhs)"
        case .not(let val): return "!\(val)"
        case .base(let val): return "\(val)"
        }
    }
}

// MARK: Libetpan conformance

private extension SearchKind {
    func unreleasedImapSearchKey(_ configuration: Configuration) -> UnsafeMutablePointer<mailimap_search_key> {
        switch self {
        case .all:                              return mailimap_search_key_new_all()
        case .from(let value):                  return mailimap_search_key_new_from(value.unreleasedUTF8CString)
        case .to(let value):                    return mailimap_search_key_new_to(value.unreleasedUTF8CString)
        case .cc(let value):                    return mailimap_search_key_new_cc(value.unreleasedUTF8CString)
        case .bcc(let value):                   return mailimap_search_key_new_bcc(value.unreleasedUTF8CString)
        case .recipient(let value):             return (.to(value: value) || .cc(value: value) || .bcc(value: value)).unreleasedImapSearchKey(configuration)
        case .subject(let value):               return mailimap_search_key_new_subject(value.unreleasedUTF8CString)
        case .content(let value):               return mailimap_search_key_new_text(value.unreleasedUTF8CString)
        case .body(let value):                  return mailimap_search_key_new_body(value.unreleasedUTF8CString)
        case .uids(let uids):                   return mailimap_search_key_new_uid(uids.unreleasedMailimapSet)
        case .numbers(let numbers):             return mailimap_search_key_new_set(numbers.unreleasedMailimapSet)
        case .header(let header, let value):    return mailimap_search_key_new_header(header.unreleasedUTF8CString, value.unreleasedUTF8CString)
        case .beforeDate(let date):             return mailimap_search_key_new_sentbefore(date.unreleasedMailimapDate)
        case .onDate(let date):                 return mailimap_search_key_new_senton(date.unreleasedMailimapDate)
        case .sinceDate(let date):              return mailimap_search_key_new_sentsince(date.unreleasedMailimapDate)
        case .beforeReceivedDate(let date):     return mailimap_search_key_new_before(date.unreleasedMailimapDate)
        case .onReceivedDate(let date):         return mailimap_search_key_new_on(date.unreleasedMailimapDate)
        case .sinceReceivedDate(let date):      return mailimap_search_key_new_since(date.unreleasedMailimapDate)
        case .sizeLarger(let size):             return mailimap_search_key_new_larger(UInt32(size))
        case .sizeSmaller(let size):            return mailimap_search_key_new_smaller(UInt32(size))
        case .gmailThreadId(let id):            return mailimap_search_key_new_xgmthrid(UInt64(id))
        case .gmailMessageId(let id):           return mailimap_search_key_new_xgmmsgid(UInt64(id))
        case .gmailRaw(let value):              return mailimap_search_key_new_xgmraw(value.unreleasedUTF8CString)

        case .read, .unread, .flagged, .unflagged, .answered, .unanswered, .draft, .undraft, .deleted:
            return mailimap_search_key_new(Int32(imapflagValue),
                                           nil, nil, nil, nil, nil,
                                           nil, nil, nil, nil, nil,
                                           nil, nil, nil, nil, 0,
                                           nil, nil, nil, nil, nil,
                                           nil, 0, nil, nil, nil)
        case .spam:
            return mailimap_search_key_new(Int32(MAILIMAP_SEARCH_KEY_KEYWORD),
                                           nil, nil, nil, nil, nil,
                                           configuration.spamFolderName.unreleasedUTF8CString, nil, nil, nil, nil,
                                           nil, nil, nil, nil, 0,
                                           nil, nil, nil, nil, nil,
                                           nil, 0, nil, nil, nil)
        }
    }
    
    var imapflagValue: Int {
        switch self {
        case .read:         return MAILIMAP_SEARCH_KEY_SEEN
        case .unread:       return MAILIMAP_SEARCH_KEY_UNSEEN
        case .flagged:      return MAILIMAP_SEARCH_KEY_FLAGGED
        case .unflagged:    return MAILIMAP_SEARCH_KEY_UNFLAGGED
        case .answered:     return MAILIMAP_SEARCH_KEY_ANSWERED
        case .unanswered:   return MAILIMAP_SEARCH_KEY_UNANSWERED
        case .draft:        return MAILIMAP_SEARCH_KEY_DRAFT
        case .undraft:      return MAILIMAP_SEARCH_KEY_UNDRAFT
        case .deleted:      return MAILIMAP_SEARCH_KEY_DELETED
        default: return 0
        }
    }
}

private extension SearchFilter {
    func unreleasedImapSearchKey(_ configuration: Configuration) -> UnsafeMutablePointer<mailimap_search_key> {
        switch self {
        case .and(let lhs, let rhs): 	return mailimap_search_key_new_multiple([ lhs, rhs ].unreleasedClist { $0.unreleasedImapSearchKey(configuration) })
        case .or(let lhs, let rhs):     return mailimap_search_key_new_or(lhs.unreleasedImapSearchKey(configuration), rhs.unreleasedImapSearchKey(configuration))
        case .not(let val):             return mailimap_search_key_new_not(val.unreleasedImapSearchKey(configuration))
        case .base(let kind):           return kind.unreleasedImapSearchKey(configuration)
        }
    }
}

// MARK: - Operators

public func &&(lhs: SearchKind, rhs: SearchFilter) -> SearchFilter {
    return .and(.base(lhs), rhs)
}

public func &&(lhs: SearchFilter, rhs: SearchKind) -> SearchFilter {
    return .and(lhs, .base(rhs))
}

public func &&(lhs: SearchFilter, rhs: SearchFilter) -> SearchFilter {
    return .and(lhs, rhs)
}

public func &&(lhs: SearchKind, rhs: SearchKind) -> SearchFilter {
    return .and(.base(lhs), .base(rhs))
}

public func ||(lhs: SearchKind, rhs: SearchFilter) -> SearchFilter {
    return .or(.base(lhs), rhs)
}

public func ||(lhs: SearchFilter, rhs: SearchKind) -> SearchFilter {
    return .or(lhs, .base(rhs))
}

public func ||(lhs: SearchFilter, rhs: SearchFilter) -> SearchFilter {
    return .or(lhs, rhs)
}

public func ||(lhs: SearchKind, rhs: SearchKind) -> SearchFilter {
    return .or(.base(lhs), .base(rhs))
}

public prefix func !(rhs: SearchFilter) -> SearchFilter {
    return .not(rhs)
}

public prefix func !(rhs: SearchKind) -> SearchFilter {
    return .not(.base(rhs))
}

// MARK: - IMAPSession+Search

extension IMAPSession {
    
    func search(_ folder: String, filter: SearchKind) throws -> IndexSet {
        return try search(folder, filter: .base(filter))
    }
    
    func search(_ folder: String, filter: SearchFilter) throws -> IndexSet {
        let key = filter.unreleasedImapSearchKey(configuration)
        defer { mailimap_search_key_free(key) }
        
        try select(folder)
        
        let charset = "utf-8"
        var resultList: UnsafeMutablePointer<clist>? = nil
        
        if capabilities.contains(.LiteralPlus) {
            try mailimap_uid_search_literalplus(imap, charset, key, &resultList).toIMAPError?.asPostalError.check()
        } else {
            try mailimap_uid_search(imap, charset, key, &resultList).toIMAPError?.check()
        }
        defer { mailimap_search_result_free(resultList) }
        
        guard let actualResultList = resultList else { return IndexSet() }
        
        let result = sequence(actualResultList, of: UInt32.self).reduce(NSMutableIndexSet()) { combined, uid in
            combined.add(Int(uid))
            return combined
        }
        
        return IndexSet(result)
    }
}
