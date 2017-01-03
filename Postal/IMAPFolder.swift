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

/// Representation of the folder
public struct Folder {
    public let name: String
    public let flags: FolderFlag
    
    let delimiter: String
}

// MARK: -

struct IMAPFolderInfo {
    let uidNext: UInt
    let uidValidity: UInt
    let firstUnseenUid: UInt
    let messagesCount: UInt
    let recentCount: UInt
    let unseenCount: UInt
    let allowflags: Bool
}

extension IMAPFolderInfo {
    init(selectionInfo: mailimap_selection_info) {
        uidNext = UInt(selectionInfo.sel_uidnext)
        uidValidity = UInt(selectionInfo.sel_uidvalidity)
        firstUnseenUid = UInt(selectionInfo.sel_first_unseen)
        messagesCount = selectionInfo.sel_has_exists.boolValue ? UInt(selectionInfo.sel_exists) : 0
        recentCount = selectionInfo.sel_has_recent.boolValue ? UInt(selectionInfo.sel_recent) : 0
        unseenCount = UInt(selectionInfo.sel_unseen)
        allowflags = sequence(selectionInfo.sel_perm_flags, of: mailimap_flag_perm.self).reduce(false) { combined, flag in
            return combined || Int(flag.fl_type) == MAILIMAP_FLAG_PERM_ALL
        }
    }
}

extension IMAPFolderInfo: CustomStringConvertible {
    var description: String {
        return "IMAPFolderInfo(\n"
            + "uidNext: \(uidNext),\n"
            + "uidValidity: \(uidValidity),\n"
            + "firstUnseenUid: \(firstUnseenUid),\n"
            + "messagesCount: \(messagesCount),\n"
            + "recentCount: \(recentCount),\n"
            + "unseenCount: \(unseenCount),\n"
            + "allowflags: \(allowflags))"
    }
}

// MARK: -

public struct FolderFlag: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    
    public static let None        = FolderFlag(rawValue: 0)
    public static let Marked      = FolderFlag(rawValue: 1 << 0)
    public static let Unmarked    = FolderFlag(rawValue: 1 << 1)
    public static let NoSelect    = FolderFlag(rawValue: 1 << 2)
    public static let NoInferiors = FolderFlag(rawValue: 1 << 3)
    public static let Inbox       = FolderFlag(rawValue: 1 << 4)
    public static let SentMail    = FolderFlag(rawValue: 1 << 5)
    public static let Starred     = FolderFlag(rawValue: 1 << 6)
    public static let AllMail     = FolderFlag(rawValue: 1 << 7)
    public static let Trash       = FolderFlag(rawValue: 1 << 8)
    public static let Drafts      = FolderFlag(rawValue: 1 << 9)
    public static let Spam        = FolderFlag(rawValue: 1 << 10)
    public static let Important   = FolderFlag(rawValue: 1 << 11)
    public static let Archive     = FolderFlag(rawValue: 1 << 12)
    public static let Folder: FolderFlag = [ .Inbox, .SentMail, .Starred, .AllMail, .Trash, .Drafts, .Spam, .Important, .Archive ]
}

extension FolderFlag {
    init(flags: UnsafePointer<mailimap_mbx_list_flags>?) {
        guard flags != nil else {
            rawValue = 0
            return
        }
        
        var finalFlags: FolderFlag = .None
        
        if Int((flags?.pointee.mbf_type)!) == MAILIMAP_MBX_LIST_FLAGS_SFLAG {
            switch Int((flags?.pointee.mbf_sflag)!) {
            case MAILIMAP_MBX_LIST_SFLAG_MARKED: finalFlags.formUnion(.Marked)
            case MAILIMAP_MBX_LIST_SFLAG_NOSELECT: finalFlags.formUnion(.NoSelect)
            case MAILIMAP_MBX_LIST_SFLAG_UNMARKED: finalFlags.formUnion(.Unmarked)
            default: break
            }
        }
        
        let keywordFlag: [(String, FolderFlag)] = [
            ("Inbox",     .Inbox),
            ("AllMail",   .AllMail),
            ("Sent",      .SentMail),
            ("Spam",      .Spam),
            ("Starred",   .Starred),
            ("Trash",     .Trash),
            ("Important", .Important),
            ("Drafts",    .Drafts),
            ("Archive",   .Archive),
            ("All",       .AllMail),
            ("Junk",      .Spam),
            ("Flagged",   .Starred)
        ]
        
        if let oFlags = flags?.pointee.mbf_oflags {
            for oflag in sequence(oFlags, of: mailimap_mbx_list_oflag.self) {
                switch Int(oflag.of_type) {
                case MAILIMAP_MBX_LIST_OFLAG_NOINFERIORS: finalFlags.formUnion(.NoInferiors)
                case MAILIMAP_MBX_LIST_OFLAG_FLAG_EXT:
                    let ext = String(cString: oflag.of_flag_ext).lowercased()

                    keywordFlag.forEach { flagString, flag in
                        if flagString.lowercased() == ext {
                            finalFlags.formUnion(flag)
                        }
                    }
                default: break
                }
            }
        }
        
        rawValue = finalFlags.rawValue
    }
}

extension FolderFlag: CustomStringConvertible {
    public var description: String {
        let flags: [(FolderFlag, String)] = [
            (.Marked,       "Marked"),
            (.Unmarked,     "Unmarked"),
            (.NoSelect,     "NoSelect"),
            (.NoInferiors,  "NoInferiors"),
            (.Inbox,        "Inbox"),
            (.SentMail,     "SentMail"),
            (.Starred,      "Starred"),
            (.AllMail,      "AllMail"),
            (.Trash,        "Trash"),
            (.Drafts,       "Drafts"),
            (.Spam,         "Spam"),
            (.Important,    "Important"),
            (.Archive,      "Archive")
        ]
        return representation(flags)
    }
}
