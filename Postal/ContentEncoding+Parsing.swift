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

public enum ContentEncoding {
    case uuEncoding
    case encoding7Bit
    case encoding8Bit
    case binary
    case base64
    case quotedPrintable
    case other
}

extension ContentEncoding {
    init(rawValue: Int) {
        if rawValue < 0 {
            self = .uuEncoding
        } else {
            switch rawValue {
            case 0: self = .encoding7Bit
            case 1: self = .encoding8Bit
            case 2: self = .binary
            case 3: self = .base64
            case 4: self = .quotedPrintable
            case 5: self = .other
            default: self = .other
            }
        }
    }
}

extension ContentEncoding: CustomStringConvertible {
    public var description: String {
        switch self {
        case .uuEncoding: return "uuEncoding"
        case .encoding7Bit: return "7bit"
        case .encoding8Bit: return "8bit"
        case .binary: return "binary"
        case .base64: return "base64"
        case .quotedPrintable: return "quotedPrintable"
        case .other: return "other"
        }
    }
}

// MARK: IMAP Parsing

extension mailimap_body_fld_enc {
    var parse: ContentEncoding {
        if let value = String.fromUTF8CString(enc_value)?.lowercased() , Int(enc_type) == MAILIMAP_BODY_FLD_ENC_OTHER {
            if value == "x-uuencode" || value == "uuencode" {
                return .uuEncoding
            }
        }
        
        return ContentEncoding(rawValue: Int(enc_type))
    }
}

// MARK: IMF Parsing

extension mailmime_mechanism {
    var parse: ContentEncoding {
        switch Int(enc_type) {
        case MAILMIME_MECHANISM_ERROR: return .other
        case MAILMIME_MECHANISM_7BIT: return .encoding7Bit
        case MAILMIME_MECHANISM_8BIT: return .encoding8Bit
        case MAILMIME_MECHANISM_BINARY: return .binary
        case MAILMIME_MECHANISM_QUOTED_PRINTABLE: return .quotedPrintable
        case MAILMIME_MECHANISM_BASE64: return .base64
        case MAILMIME_MECHANISM_TOKEN:
            if String.fromUTF8CString(enc_token)?.lowercased() == "x-uuencode" { return .uuEncoding }
            return .encoding8Bit
        default: return .other
        }
    }
}
