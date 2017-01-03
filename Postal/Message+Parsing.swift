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

struct Message {
    let header: MessageHeader?
    let body: MailPart
}

// MARK: IMF message content parsing

extension mailimap_msg_att_body_section {
    func parse(_ idPrefix: String) -> Message? {
        
        guard sec_body_part != nil else { return nil }
        
        let message = data_message_init(sec_body_part, sec_length)
        defer { mailmessage_free(message) }
        
        // parse body
        var mail: UnsafeMutablePointer<mailmime>? = nil
        mailmessage_get_bodystructure(message, &mail)
        
        guard let mainPart = mail?.pointee.parse("") else { return nil }
        
        // parse headers
        var curToken: size_t = 0
        var fields: UnsafeMutablePointer<mailimf_fields>? = nil
        guard nil == mailimf_envelope_and_optional_fields_parse(sec_body_part, sec_length, &curToken, &fields).toIMFError else { return nil }
        defer { mailimf_fields_free(fields) }
            
        var singleFields = mailimf_single_fields()
        mailimf_single_fields_init(&singleFields, fields)
            
        let headers = singleFields.parse
        
        return Message(header: headers, body: mainPart)
    }
}

extension String {
    func byAppendingPartId(_ id: Int) -> String {
        return isEmpty ? "\(id)" : "\(self).\(id)"
    }
    
    var firstPartId: String {
        return isEmpty ? "1" : self
    }
}
