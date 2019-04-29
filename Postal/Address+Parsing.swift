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

public struct Address {
    public let email: String
    public let displayName: String
}

extension Address: CustomStringConvertible {
    public var description: String {
        if displayName.isEmpty {
            return "<\(email)>"
        } else {
            return "\"\(displayName)\" <\(email)>)"
        }
    }
}

// MARK: IMAP Parsing

extension mailimap_address {
    var parse: Address? {
        let displayName = String.fromZeroSizedCStringMimeHeader(ad_personal_name) ?? ""
        let hostName = String.fromZeroSizedCStringMimeHeader(ad_host_name)
        let mailbox = String.fromZeroSizedCStringMimeHeader(ad_mailbox_name)
        
        let email: String
        switch (mailbox, hostName) {
        case (.some(let mbox), .some(let host)): email = "\(mbox)@\(host)"
        case (.none, .some(let host)): email = "@\(host)"
        case (.some(let mbox), .none): email = mbox
        default: return nil
        }
        
        return Address(email: email, displayName: displayName)
    }
}

// MARK: IMF Parsing

extension mailimf_address {
    var parse: [Address] {
        switch Int(ad_type) {
        case MAILIMF_ADDRESS_MAILBOX: return [ ad_data.ad_mailbox?.pointee.parse ].compactMap { $0 }
        case MAILIMF_ADDRESS_GROUP: return ad_data.ad_group?.pointee.grp_mb_list?.pointee.parse.compactMap { $0 } ?? []
        default: return []
        }
    }
}

extension mailimf_mailbox_list {
    var parse: [Address] {
        return sequence(mb_list, of: mailimf_mailbox.self).compactMap { $0.parse }
    }
}

extension mailimf_mailbox {
    var parse: Address? {
        guard let mailbox = String.fromUTF8CString(mb_addr_spec) else { return nil }
        let displayName = String.fromZeroSizedCStringMimeHeader(mb_display_name) ?? ""
        return Address(email: mailbox, displayName: displayName)
    }
}
