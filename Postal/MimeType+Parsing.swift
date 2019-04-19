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

public struct MimeType {
    public let type: String
    public let subtype: String
    
    public init(type: String, subtype: String) {
        self.type = type.lowercased()
        self.subtype = subtype.lowercased()
    }
}

extension MimeType: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(31 &* type.hash &+ subtype.hash)
    }
}

public func ==(lhs: MimeType, rhs: MimeType) -> Bool {
    return lhs.type == rhs.type && lhs.subtype == rhs.subtype
}

extension MimeType: CustomStringConvertible {
    public var description: String { return "\(type)/\(subtype)" }
}

public extension MimeType {
    static var applicationJavascript: MimeType { return MimeType(type: "application", subtype: "javascript") }
    static var applicationOctetStream: MimeType { return MimeType(type: "application", subtype: "octet-stream") }
    static var applicationOgg: MimeType { return MimeType(type: "application", subtype: "ogg") }
    static var applicationPdf: MimeType { return MimeType(type: "application", subtype: "pdf") }
    static var applicationXhtml: MimeType { return MimeType(type: "application", subtype: "xhtml+xml") }
    static var applicationFlash: MimeType { return MimeType(type: "application", subtype: "x-shockwave-flash") }
    static var applicationJson: MimeType { return MimeType(type: "application", subtype: "json") }
    static var applicationXml: MimeType { return MimeType(type: "application", subtype: "xml") }
    static var applicationZip: MimeType { return MimeType(type: "application", subtype: "zip") }
    
    static var audioMpeg: MimeType { return MimeType(type: "audio", subtype: "mpeg") }
    static var audioMp3: MimeType { return MimeType(type: "audio", subtype: "mp3") }
    static var audioWma: MimeType { return MimeType(type: "audio", subtype: "x-ms-wma") }
    static var audioWav: MimeType { return MimeType(type: "audio", subtype: "x-wav") }
    
    static var imageGif: MimeType { return MimeType(type: "image", subtype: "jpeg") }
    static var imageJpeg: MimeType { return MimeType(type: "image", subtype: "jpeg") }
    static var imagePng: MimeType { return MimeType(type: "image", subtype: "jpeg") }
    static var imageTiff: MimeType { return MimeType(type: "image", subtype: "jpeg") }
    static var imageIcon: MimeType { return MimeType(type: "image", subtype: "x-icon") }
    static var imageSvg: MimeType { return MimeType(type: "image", subtype: "svg+xml") }
    
    static var multipartMixed: MimeType { return MimeType(type: "multipart", subtype: "mixed") }
    static var multipartAlternative: MimeType { return MimeType(type: "multipart", subtype: "alternative") }
    static var multipartRelated: MimeType { return MimeType(type: "multipart", subtype: "related") }
    
    static var textCss: MimeType { return MimeType(type: "text", subtype: "css") }
    static var textCsv: MimeType { return MimeType(type: "text", subtype: "csv") }
    static var textHtml: MimeType { return MimeType(type: "text", subtype: "html") }
    static var textJavascript: MimeType { return MimeType(type: "text", subtype: "javascript") }
    static var textPlain: MimeType { return MimeType(type: "text", subtype: "plain") }
    static var textXml: MimeType { return MimeType(type: "text", subtype: "xml") }
    
    static var videoMpeg: MimeType { return MimeType(type: "video", subtype: "mpeg") }
    static var videoMp4: MimeType { return MimeType(type: "video", subtype: "mp4") }
    static var videoQuicktime: MimeType { return MimeType(type: "video", subtype: "quicktime") }
    static var videoWmv: MimeType { return MimeType(type: "video", subtype: "x-ms-wmv") }
    static var videoAvi: MimeType { return MimeType(type: "video", subtype: "x-msvideo") }
    static var videoFlv: MimeType { return MimeType(type: "video", subtype: "x-flv") }
    static var videoWebm: MimeType { return MimeType(type: "video", subtype: "webm") }
}

// MARK: IMAP Parsing

extension mailimap_media_basic {
    var parse: MimeType? {
        let subtype = String(cString: med_subtype).lowercased()
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
        let type: String = ct_type?.pointee.parse ?? "unknown"
        let subtype = String.fromUTF8CString(ct_subtype)?.lowercased() ?? "unknown"
        return MimeType(type: type, subtype: subtype)
    }
}

extension mailmime_type {
    var parse: String? {
        switch Int(tp_type) {
        case MAILMIME_TYPE_DISCRETE_TYPE: return tp_data.tp_discrete_type?.pointee.parse
        case MAILMIME_TYPE_COMPOSITE_TYPE: return tp_data.tp_composite_type?.pointee.parse
        default: return nil
        }
    }
}

extension mailmime_composite_type {
    var parse: String? {
        switch Int(ct_type) {
        case MAILMIME_COMPOSITE_TYPE_MESSAGE: return "message"
        case MAILMIME_COMPOSITE_TYPE_MULTIPART: return "multipart"
        case MAILMIME_COMPOSITE_TYPE_EXTENSION: return String.fromUTF8CString(ct_token)?.lowercased()
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
        case MAILMIME_DISCRETE_TYPE_EXTENSION: return String.fromUTF8CString(dt_extension)?.lowercased()
        default: return nil
        }
    }
}
