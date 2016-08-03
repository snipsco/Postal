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

public struct MimeType {
    public let type: String
    public let subtype: String
}

extension MimeType: CustomStringConvertible {
    public var description: String { return "\(type)/\(subtype)" }
}

// MARK: IMAP Parsing

extension mailimap_media_basic {
    var parse: MimeType? {
        guard let subtype = String.fromCString(med_subtype)?.lowercaseString else { return nil }
        switch Int(med_type) {
        case MAILIMAP_MEDIA_BASIC_APPLICATION: return MimeType(type: "application", subtype: subtype)
        case MAILIMAP_MEDIA_BASIC_AUDIO: return MimeType(type: "audio", subtype: subtype)
        case MAILIMAP_MEDIA_BASIC_IMAGE: return MimeType(type: "image", subtype: subtype)
        case MAILIMAP_MEDIA_BASIC_MESSAGE: return MimeType(type: "message", subtype: subtype)
        case MAILIMAP_MEDIA_BASIC_VIDEO: return MimeType(type: "video", subtype: subtype)
        case MAILIMAP_MEDIA_BASIC_OTHER: return String.fromUTF8CString(med_basic_type).map { MimeType(type: $0, subtype: subtype) }
        default: return nil
        }
    }
}

// MARK: IMF Parsing

extension mailmime_content {
    var parse: MimeType {
        let type: String = ct_type.optional?.parse ?? "unknown"
        let subtype = String.fromUTF8CString(ct_subtype)?.lowercaseString ?? "unknown"
        return MimeType(type: type, subtype: subtype)
    }
}

extension mailmime_type {
    var parse: String? {
        switch Int(tp_type) {
        case MAILMIME_TYPE_DISCRETE_TYPE: return tp_data.tp_discrete_type.optional?.parse
        case MAILMIME_TYPE_COMPOSITE_TYPE: return tp_data.tp_composite_type.optional?.parse
        default: return nil
        }
    }
}

extension mailmime_composite_type {
    var parse: String? {
        switch Int(ct_type) {
        case MAILMIME_COMPOSITE_TYPE_MESSAGE: return "message"
        case MAILMIME_COMPOSITE_TYPE_MULTIPART: return "multipart"
        case MAILMIME_COMPOSITE_TYPE_EXTENSION: return String.fromUTF8CString(ct_token)?.lowercaseString
        default: return nil
        }
    }
}

extension mailmime_discrete_type {
    var parse: String? {
        switch Int(dt_type) {
        case MAILMIME_DISCRETE_TYPE_TEXT: return "text"
        case MAILMIME_DISCRETE_TYPE_IMAGE: return "image"
        case MAILMIME_DISCRETE_TYPE_AUDIO: return "audio"
        case MAILMIME_DISCRETE_TYPE_VIDEO: return "video"
        case MAILMIME_DISCRETE_TYPE_APPLICATION: return "application"
        case MAILMIME_DISCRETE_TYPE_EXTENSION: return String.fromUTF8CString(dt_extension)?.lowercaseString
        default: return nil
        }
    }
}
