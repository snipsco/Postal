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

public typealias CustomHeader = (name: String, value: String)

public struct MessageHeader {
    public fileprivate(set) var id: String
    public fileprivate(set) var receivedDate: Date? = nil
    public fileprivate(set) var subject: String = ""
    public fileprivate(set) var senders: [Address] = []
    public fileprivate(set) var from: [Address] = []
    public fileprivate(set) var replyTo: [Address] = []
    public fileprivate(set) var to: [Address] = []
    public fileprivate(set) var cc: [Address] = []
    public fileprivate(set) var bcc: [Address] = []
    public fileprivate(set) var refs: [String] = []
    public fileprivate(set) var inReplyTo: [String] = []
    public internal(set) var customHeaders: [CustomHeader] = []
    
    fileprivate init(id: String) {
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
        
        message.receivedDate = Date.fromEnvelopeDate(String(cString: env_date))
        message.subject = String.fromZeroSizedCStringMimeHeader(env_subject) ?? ""
        message.senders = (env_sender?.pointee.snd_list).map(convertAddress) ?? []
        message.from = (env_from?.pointee.frm_list).map(convertAddress) ?? []
        message.replyTo = (env_reply_to?.pointee.rt_list).map(convertAddress) ?? []
        message.to = (env_to?.pointee.to_list).map(convertAddress) ?? []
        message.cc = (env_cc?.pointee.cc_list).map(convertAddress) ?? []
        message.bcc = (env_bcc?.pointee.bcc_list).map(convertAddress) ?? []
        message.inReplyTo = extractInReplyTo()
        
        return message
    }
    
    fileprivate func extractInReplyTo() -> [String] {
        guard let envInReplyTo = env_in_reply_to?.pointee else { return [] }
        
        var curToken: Int = 0
        var msgIdList: UnsafeMutablePointer<clist>? = nil
        guard mailimf_msg_id_list_parse(env_in_reply_to, Int(strlen(env_in_reply_to)), &curToken, &msgIdList).toIMFError == nil else { return [] }
        
        guard let actualMsgIdList = msgIdList else { return [] }
        
        defer {
            pointerSequence(actualMsgIdList, of: CChar.self)
                .map { UnsafeMutablePointer<CChar>(mutating: $0) }
                .forEach(mailimf_msg_id_free)
            clist_free(msgIdList)
        }
        
        return pointerSequence(actualMsgIdList, of: CChar.self)
            .compactMap(String.init(cString:))
    }
    
    fileprivate func extractMessageId() -> String? {
        guard let envMessageId = env_message_id?.pointee else { return nil }
        
        var curToken: Int = 0
        var msgId: UnsafeMutablePointer<CChar>? = nil
        guard mailimf_msg_id_parse(env_message_id, Int(strlen(env_message_id)), &curToken, &msgId).toIMFError == nil else { return nil }
        
        defer { mailimf_msg_id_free(msgId) }
        
        return String(cString: msgId!)
    }
    
    fileprivate func convertAddress(_ clist: UnsafeMutablePointer<clist_s>) -> [Address] {
        return sequence(clist, of: mailimap_address.self).compactMap { $0.parse }
    }
}

extension mailimap_env_from {
    var parse: [Address] {
        return sequence(frm_list, of: mailimap_address.self).compactMap { $0.parse }
    }
}

// MARK: IMF Parsing

extension mailimf_single_fields {
    var parse: MessageHeader? {
        let mid = (fld_message_id?.pointee.mid_value).map { UnsafePointer($0) }.flatMap(String.fromUTF8CString)
        guard let messageId = mid else { return nil }
        
        var header = MessageHeader(id: messageId)
        
        header.receivedDate = fld_orig_date?.pointee.dt_date_time?.pointee.date
        header.subject = (fld_subject?.pointee.sbj_value).flatMap(String.fromZeroSizedCStringMimeHeader) ?? header.subject
        header.senders = [ fld_sender?.pointee.snd_mb?.pointee ].compactMap { $0?.parse }
        header.from = fld_from?.pointee.frm_mb_list?.pointee.parse ?? []
        header.replyTo = fld_reply_to?.pointee.rt_addr_list?.pointee.parse ?? header.replyTo
        header.to = fld_to?.pointee.to_addr_list?.pointee.parse ?? header.to
        header.cc = fld_cc?.pointee.cc_addr_list?.pointee.parse ?? header.cc
        header.bcc = fld_bcc?.pointee.bcc_addr_list?.pointee.parse ?? header.bcc
        header.refs = fld_references?.pointee.parse ?? header.refs
        header.inReplyTo = fld_in_reply_to?.pointee.parse ?? header.inReplyTo
        
        return header
    }
}

extension mailimf_in_reply_to {
    var parse: [String] {
        return pointerSequence(mid_list, of: CChar.self).compactMap { String.fromUTF8CString($0) }
    }
}

extension mailimf_references {
    var parse: [String] {
        return pointerSequence(mid_list, of: CChar.self).compactMap { String.fromUTF8CString($0) }
    }
}

extension mailimf_address_list {
    var parse: [Address] {
        return sequence(ad_list, of: mailimf_address.self).flatMap { $0.parse }
    }
}

// MARK: - Date management

private extension Date {
    static func fromEnvelopeDate(_ envelopeDate: String) -> Date? {
        var currentToken: size_t = 0
        var imfDateTime: UnsafeMutablePointer<mailimf_date_time>? = nil
        if mailimf_date_time_parse(envelopeDate, envelopeDate.count, &currentToken, &imfDateTime).toIMFError == nil {
            defer { mailimf_date_time_free(imfDateTime) }
            return imfDateTime?.pointee.date
        }
        
        var imapDateTime: UnsafeMutablePointer<mailimap_date_time>? = nil
        if mailimap_hack_date_time_parse(envelopeDate, &imapDateTime, 0, nil).toIMAPError == nil {
            defer { mailimap_date_time_free(imapDateTime) }
            return imapDateTime?.pointee.date
        }
        
        return nil
    }
}
