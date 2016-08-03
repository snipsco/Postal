//
//  The MIT License (MIT)
//
//  Copyright (c) 2016 Snips
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

public typealias CustomHeader = (name: String, value: String)

public struct MessageHeader {
    public private(set) var id: String
    public private(set) var receivedDate: NSDate? = nil
    public private(set) var subject: String = ""
    public private(set) var senders: [Address] = []
    public private(set) var from: [Address] = []
    public private(set) var replyTo: [Address] = []
    public private(set) var to: [Address] = []
    public private(set) var cc: [Address] = []
    public private(set) var bcc: [Address] = []
    public private(set) var refs: [String] = []
    public private(set) var inReplyTo: [String] = []
    public internal(set) var customHeaders: [CustomHeader] = []
    
    private init(id: String) {
        self.id = id
    }
}

//
// MARK: IMAP Parsing
//

extension mailimap_envelope {
    var parse: MessageHeader? {
        guard let messageId = extractMessageId() else { return nil }
        
        var message = MessageHeader(id: messageId)
        
        message.receivedDate = String.fromCString(env_date).flatMap { NSDate.fromEnvelopeDate($0) }
        message.subject = String.fromZeroSizedCStringMimeHeader(env_subject) ?? ""
        message.senders = (env_sender.optional?.snd_list).map(convertAddress) ?? []
        message.from = (env_from.optional?.frm_list).map(convertAddress) ?? []
        message.replyTo = (env_reply_to.optional?.rt_list).map(convertAddress) ?? []
        message.to = (env_to.optional?.to_list).map(convertAddress) ?? []
        message.cc = (env_cc.optional?.cc_list).map(convertAddress) ?? []
        message.bcc = (env_bcc.optional?.bcc_list).map(convertAddress) ?? []
        message.inReplyTo = extractInReplyTo()
        
        return message
    }
    
    private func extractInReplyTo() -> [String] {
        guard let envInReplyTo = env_in_reply_to.optional else { return [] }
        
        var curToken: Int = 0
        var msgIdList: UnsafeMutablePointer<clist> = nil
        guard mailimf_msg_id_list_parse(env_in_reply_to, Int(strlen(env_in_reply_to)), &curToken, &msgIdList).toIMFError == nil else { return [] }
        
        defer {
            pointerSequence(msgIdList, of: CChar.self)
                .map { UnsafeMutablePointer<CChar>($0) }
                .forEach(mailimf_msg_id_free)
            clist_free(msgIdList)
        }
        
        return pointerSequence(msgIdList, of: CChar.self)
            .flatMap(String.fromCString)
    }
    
    private func extractMessageId() -> String? {
        guard let envMessageId = env_message_id.optional else { return nil }
        
        var curToken: Int = 0
        var msgId: UnsafeMutablePointer<CChar> = nil
        guard mailimf_msg_id_parse(env_message_id, Int(strlen(env_message_id)), &curToken, &msgId).toIMFError == nil else { return nil }
        
        defer { mailimf_msg_id_free(msgId) }
        
        return String.fromCString(msgId)
    }
    
    private func convertAddress(clist: UnsafeMutablePointer<clist_s>) -> [Address] {
        return sequence(clist, of: mailimap_address.self).flatMap { $0.parse }
    }
}

extension mailimap_env_from {
    var parse: [Address] {
        return sequence(frm_list, of: mailimap_address.self).flatMap { $0.parse }
    }
}

// MARK: IMF Parsing

extension mailimf_single_fields {
    var parse: MessageHeader? {
        let mid = (fld_message_id.optional?.mid_value).flatMap { String.fromUTF8CString($0) }
        guard let messageId = mid else { return nil }
        
        var header = MessageHeader(id: messageId)
        
        header.receivedDate = fld_orig_date.optional?.dt_date_time.optional?.date
        header.subject = (fld_subject.optional?.sbj_value).flatMap(String.fromZeroSizedCStringMimeHeader) ?? header.subject
        header.senders = [ fld_sender.optional?.snd_mb.optional ].flatMap { $0?.parse }
        header.from = fld_from.optional?.frm_mb_list.optional?.parse ?? []
        header.replyTo = fld_reply_to.optional?.rt_addr_list.optional?.parse ?? header.replyTo
        header.to = fld_to.optional?.to_addr_list.optional?.parse ?? header.to
        header.cc = fld_cc.optional?.cc_addr_list.optional?.parse ?? header.cc
        header.bcc = fld_bcc.optional?.bcc_addr_list.optional?.parse ?? header.bcc
        header.refs = fld_references.optional?.parse ?? header.refs
        header.inReplyTo = fld_in_reply_to.optional?.parse ?? header.inReplyTo
        
        return header
    }
}

extension mailimf_in_reply_to {
    var parse: [String] {
        return pointerSequence(mid_list, of: CChar.self).flatMap { String.fromUTF8CString($0) }
    }
}

extension mailimf_references {
    var parse: [String] {
        return pointerSequence(mid_list, of: CChar.self).flatMap { String.fromUTF8CString($0) }
    }
}

extension mailimf_address_list {
    var parse: [Address] {
        return sequence(ad_list, of: mailimf_address.self).flatMap { $0.parse }
    }
}

// MARK: - Date management

private extension NSDate {
    static func fromEnvelopeDate(envelopeDate: String) -> NSDate? {
        
        var currentToken: size_t = 0
        var imfDateTime: UnsafeMutablePointer<mailimf_date_time> = nil
        if mailimf_date_time_parse(envelopeDate, envelopeDate.characters.count, &currentToken, &imfDateTime).toIMFError == nil {
            defer { mailimf_date_time_free(imfDateTime) }
            return imfDateTime.optional?.date
        }
        
        var imapDateTime: UnsafeMutablePointer<mailimap_date_time> = nil
        if mailimap_hack_date_time_parse(envelopeDate, &imapDateTime, 0, nil).toIMAPError == nil {
            defer { mailimap_date_time_free(imapDateTime) }
            return imapDateTime.optional?.date
        }
        
        return nil
    }
}
