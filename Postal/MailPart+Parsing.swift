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

public indirect enum MailPart {
    case single(id: String, mimeType: MimeType, mimeFields: MimeFields, data: MailData?)
    case multipart(id: String, mimeType: MimeType, parts: [MailPart])
    case message(id: String, header: MessageHeader?, message: MailPart)
}

public struct MailData {
    public let rawData: Data
    public let encoding: ContentEncoding
    
    public init(rawData: Data, encoding: ContentEncoding) {
        self.rawData = rawData
        self.encoding = encoding
    }
}

extension MailPart: CustomStringConvertible {
    public var description: String {
        switch self {
        case .single(let id, let mimeType, _, let mimeFields): return ".single(id: \(id), mimeType: \(mimeType), mimeFields: \(String(describing: mimeFields)))"
        case .multipart(let id, let mimeType, let parts): return ".multipart(id: \(id), mimeType: \(mimeType), parts: \(parts))"
        case .message(let id, let headers, let message): return ".message(id: \(id), headers: \(String(describing: headers)), message: \(message))"
        }
    }
}

// MARK: IMAP Parsing

extension mailimap_body {
    func parse(_ idPrefix: String) -> MailPart? {
        switch Int(bd_type) {
        case MAILIMAP_BODY_1PART: return bd_data.bd_body_1part?.pointee.parse(idPrefix)
        case MAILIMAP_BODY_MPART: return bd_data.bd_body_mpart?.pointee.parse(idPrefix)
        default: return nil
        }
    }
}

// multiPart
extension mailimap_body_type_mpart {
    func parse(_ idPrefix: String) -> MailPart? {
        let parts = sequence(bd_list, of: mailimap_body.self).enumerated().compactMap { index, subPart in
            subPart.parse(idPrefix.byAppendingPartId(index + 1))
        }
        
        guard let subtype = String.fromUTF8CString(bd_media_subtype) else { return nil }
        let mimeType = MimeType(type: "multipart", subtype: subtype.lowercased())
        
        return .multipart(id: idPrefix, mimeType: mimeType, parts: parts)
    }
}

// singlePart
extension mailimap_body_type_1part {
    func parse(_ idPrefix: String) -> MailPart? {
        let extensions = bd_ext_1part?.pointee.parse
        
        switch Int(bd_type) {
        case MAILIMAP_BODY_TYPE_1PART_BASIC:
            return bd_data.bd_type_basic?.pointee.parse(idPrefix, extensions: extensions)
        case MAILIMAP_BODY_TYPE_1PART_MSG:
            return bd_data.bd_type_msg?.pointee.parse(idPrefix)
        case MAILIMAP_BODY_TYPE_1PART_TEXT:
            return bd_data.bd_type_text?.pointee.parse(idPrefix, extensions: extensions)
        default: return nil
        }
    }
}

// single part data

extension MimeFields {
    static func merge(_ first: MimeFields?, _ second: MimeFields?) -> MimeFields? {
        if let first = first, let second = second {
            return MimeFields(name: first.name ?? second.name,
                              charset: first.charset ?? second.charset,
                              contentType: !first.contentType.isEmpty ? first.contentType : second.contentType,
                              contentId: first.contentId ?? second.contentId,
                              contentDescription: first.contentDescription ?? second.contentDescription,
                              contentEncoding: first.contentEncoding ?? second.contentEncoding,
                              contentLocation: first.contentLocation ?? second.contentLocation,
                              contentDisposition: first.contentDisposition ?? second.contentDisposition)
        } else {
            return first ?? second
        }
    }
}

extension mailimap_body_type_basic {
    func parse(_ idPrefix: String, extensions: MimeFields?) -> MailPart? {
        guard let mimeType = bd_media_basic?.pointee.parse,
            let bodyFields = MimeFields.merge(extensions, bd_fields?.pointee.parse) else { return nil }
        return .single(id: idPrefix.firstPartId, mimeType: mimeType, mimeFields: bodyFields, data: nil)
    }
}

extension mailimap_body_type_msg {
    func parse(_ idPrefix: String) -> MailPart? {
        guard let header = bd_envelope?.pointee.parse,
            let message = bd_body?.pointee.parse(idPrefix.isEmpty ? "1" : idPrefix) else { return nil }
        
        return .message(id: idPrefix, header: header, message: message)
    }
}

extension mailimap_body_type_text {
    func parse(_ idPrefix: String, extensions: MimeFields?) -> MailPart? {
        guard let subtype = String.fromUTF8CString(bd_media_text)?.lowercased(),
            let fields = MimeFields.merge(extensions, bd_fields?.pointee.parse) else { return nil }
        
        let mimeType = MimeType(type: "text", subtype: subtype)
        
        return .single(id: idPrefix.firstPartId, mimeType: mimeType, mimeFields: fields, data: nil)
    }
}

// MARK: IMF Parsing

extension mailmime {
    func parse(_ idPrefix: String) -> MailPart? {
        switch Int(mm_type) {
        case MAILMIME_SINGLE:
            var singleFields = mailmime_single_fields()
            mailmime_single_fields_init(&singleFields, mm_mime_fields, mm_content_type)

            guard let rawData = mm_data.mm_single?.pointee.parse else { return nil }
            guard let mimeType = mm_content_type?.pointee.parse else { return nil }

            let fieldsEnc = singleFields.fld_encoding?.pointee.parse
            let dtEnc = (mm_data.mm_single?.pointee.dt_encoding).map { ContentEncoding(rawValue: Int($0)) }
            guard let encoding = fieldsEnc ?? dtEnc else { return nil }
            
            let fields = singleFields.parse
            let data = MailData(rawData: rawData, encoding: encoding)
            
            return .single(id: idPrefix.firstPartId, mimeType: mimeType, mimeFields: fields, data: data)
            
        case MAILMIME_MULTIPLE:
            guard let mimeType = mm_content_type?.pointee.parse else { return nil }
            let parts = sequence(mm_data.mm_multipart.mm_mp_list, of: mailmime.self).enumerated().compactMap { index, subPart in
                subPart.parse(idPrefix.byAppendingPartId(index + 1))
            }
            
            return .multipart(id: idPrefix, mimeType: mimeType, parts: parts)
            
        case MAILMIME_MESSAGE:
            
            guard let message = mm_data.mm_message.mm_msg_mime?.pointee.parse(idPrefix.firstPartId) else { return nil }
            
            var singleFields = mailimf_single_fields()
            mailimf_single_fields_init(&singleFields, mm_data.mm_message.mm_fields)
            
            var messageHeader = singleFields.parse
            messageHeader?.customHeaders.append(contentsOf: mm_data.mm_message.mm_fields?.pointee.parseOptionalFields ?? [])
            
            return .message(id: idPrefix, header: messageHeader, message: message)
        default: return nil
        }
    }
}

extension mailmime_data {
    var parse: Data {
        return Data(bytes: UnsafeRawPointer(dt_data.dt_text.dt_data), count: dt_data.dt_text.dt_length)
    }
}

extension mailmime_parameter {
    var parse: CustomHeader? {
        guard let name = String.fromUTF8CString(pa_name),
            let value = String.fromUTF8CString(pa_value) else { return nil }
        return (name, value)
    }
}

extension mailimf_fields {
    var parseOptionalFields: [CustomHeader] {
        return sequence(fld_list, of: mailimf_field.self).compactMap { (field: mailimf_field) -> CustomHeader? in
            if Int(field.fld_type) != MAILIMF_FIELD_OPTIONAL_FIELD { return nil }
            return field.fld_data.fld_optional_field?.pointee.parse
        }
    }
}

extension mailimf_optional_field {
    var parse: CustomHeader? {
        guard let name = String.fromUTF8CString(fld_name) else { return nil }
        guard let value = String.fromZeroSizedCStringMimeHeader(fld_value) else { return nil }
        return (name, value)
    }
}
