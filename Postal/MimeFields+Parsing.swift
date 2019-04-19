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

public struct MimeFields {
    public fileprivate(set) var name: String? = nil
    public fileprivate(set) var charset: String? = nil
    public fileprivate(set) var contentType: [MimeType] = []
    public fileprivate(set) var contentId: String? = nil
    public fileprivate(set) var contentDescription: String? = nil
    public fileprivate(set) var contentEncoding: ContentEncoding? = nil
    public fileprivate(set) var contentLocation: String? = nil
    public fileprivate(set) var contentDisposition: ContentDisposition? = nil
}

// MARK: IMAP Parsing

extension mailimap_body_fields {
    var parse: MimeFields {
        var mimeFields = MimeFields()
        
        // TODO: bd_size
        
        if let list = bd_parameter?.pointee.pa_list {
            for param in sequence(list, of: mailimap_single_body_fld_param.self) {
                guard let name = String.fromUTF8CString(param.pa_name)?.lowercased() else { continue }
                guard let value = String.fromZeroSizedCStringMimeHeader(param.pa_value)?.lowercased() else { continue }
                
                switch name {
                case "name": mimeFields.name = value
                case "charset": mimeFields.charset = value
                default: mimeFields.contentType.append(MimeType(type: name, subtype: value)) // check this
                }
            }
        }
        
        if let encoding = bd_encoding?.pointee {
            mimeFields.contentEncoding = encoding.parse
        }
        
        if let mimeId = bd_id?.pointee {
            var curToken: size_t = 0
            var contentId: UnsafeMutablePointer<CChar>? = nil
            let result = mailimf_msg_id_parse(bd_id, Int(strlen(bd_id)), &curToken, &contentId)
            if let contentId = contentId, MAILIMF_NO_ERROR == Int(result) {
                defer { free(contentId) }
                
                if let contentId = String.fromUTF8CString(contentId) {
                    mimeFields.contentId = contentId
                }
            }
        }
        if bd_description != nil {
            if let description = String.fromUTF8CString(bd_description) {
                mimeFields.contentDescription = description
            }
        }
        
        return mimeFields
    }
}

extension mailimap_body_ext_1part {
    var parse: MimeFields {
        
        var fields = MimeFields()
        fields.contentLocation = String.fromUTF8CString(bd_loc)
        fields.contentDisposition = bd_disposition?.pointee.parse
        
        return fields
    }
}

// MARK: IMF Parsing

extension mailmime_single_fields {
    var parse: MimeFields {
        let filename = String.fromZeroSizedCStringMimeHeader(fld_disposition_filename)
        let name = String.fromZeroSizedCStringMimeHeader(fld_content_name)
        let contentId = fld_id != nil ? String.fromUTF8CString(fld_id) : nil
        let description  = fld_description != nil ? String.fromUTF8CString(fld_description) : nil
        let charset = String.fromZeroSizedCStringMimeHeader(fld_content_charset)
        let loc = fld_location != nil ? String.fromUTF8CString(fld_location) : nil
        let encoding = fld_encoding?.pointee.parse
        
        let disposition = fld_disposition?.pointee.dsp_type?.pointee.parse
        
        let content: [MimeType]
        if let parameters = fld_content?.pointee.ct_parameters {
            content = sequence(parameters, of: mailmime_parameter.self)
                .compactMap { parameter in
                    parameter.parse.map { type, subtype in
                        MimeType(type: type, subtype: subtype)
                    }
                }
        } else {
            content = []
        }

        var fields = MimeFields()
        fields.name = filename ?? name
        fields.contentId = contentId
        fields.contentDescription = description
        fields.charset = charset
        fields.contentLocation = loc
        fields.contentEncoding = encoding
        fields.contentDisposition = disposition
        fields.contentType = content
        
        return fields
    }
}
