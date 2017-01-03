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

enum MessageAttribute {
    case uid(UInt)
    case envelope(MessageHeader)
    case flags(MessageFlag)
    case bodySection(Message)
    case bodyStructure(MailPart)
    case rfc822(Int)
    case ext(MessageExtension)
    case internalDate(Date)
}

extension MessageAttribute: CustomStringConvertible {
    var description: String {
        switch self {
        case .uid(let uid): return "uid(\(uid))"
        case .envelope(let env): return "envelope(\(env))"
        case .flags(let flags): return "flags(\(flags))"
        case .bodySection(let sec): return "bodySection(\(sec))"
        case .bodyStructure(let structure): return "bodyStructure(\(structure))"
        case .rfc822(let rfc): return "rfc822(\(rfc))"
        case .ext(let ext): return "extension(\(ext))"
        case .internalDate(let date): return "internalDate(\(date))"
        }
    }
}

extension mailimap_msg_att {
    func parse(_ builder: FetchResultBuilder) -> FetchResult? {
        sequence(att_list, of: mailimap_msg_att_item.self).forEach { item in
            guard let parsed = item.parse else { return }
            builder.addParsedAttribute(parsed)
        }
        
        return builder.result
    }
}

extension mailimap_msg_att_item {
    var parse: MessageAttribute? {
        switch Int(att_type) {
        case MAILIMAP_MSG_ATT_ITEM_DYNAMIC:
            return att_data.att_dyn?.pointee.parse
        case MAILIMAP_MSG_ATT_ITEM_STATIC:
            return att_data.att_static?.pointee.parse
        case MAILIMAP_MSG_ATT_ITEM_EXTENSION:
            return att_data.att_extension_data?.pointee.parse.map { .ext($0) }
        default: return nil
        }
    }
}

extension mailimap_msg_att_static {
    var parse: MessageAttribute? {
        switch Int(att_type) {
        case MAILIMAP_MSG_ATT_UID:
            return .uid(UInt(att_data.att_uid))
        case MAILIMAP_MSG_ATT_ENVELOPE:
            return att_data.att_env?.pointee.parse.map { .envelope($0) }
        case MAILIMAP_MSG_ATT_BODY_SECTION:
            let bodySection = att_data.att_body_section?.pointee.parse("")
            return bodySection.map { .bodySection($0) }
        case MAILIMAP_MSG_ATT_BODYSTRUCTURE:
            return att_data.att_body?.pointee.parse("").map { .bodyStructure($0) }
        case MAILIMAP_MSG_ATT_RFC822_SIZE:
            return .rfc822(Int(att_data.att_rfc822_size))
        case MAILIMAP_MSG_ATT_INTERNALDATE:
            return att_data.att_internal_date?.pointee.date.flatMap { .internalDate($0) }
        default: return nil
        }
    }
}

extension mailimap_msg_att_dynamic {
    var parse: MessageAttribute? {
        guard att_list?.pointee != nil else { return nil }
        
        let flags: MessageFlag = sequence(att_list, of: mailimap_flag_fetch.self).reduce([]) { combined, flagFetch in
            guard flagFetch.fl_type != Int32(MAILIMAP_FLAG_FETCH_OTHER) else { return combined }
            guard let flag = flagFetch.fl_flag?.pointee else { return combined }
            
            return [ combined, flag.toMessageFlag ]
        }
        
        guard !flags.isEmpty else { return nil }
        
        return .flags(flags)
    }
}
