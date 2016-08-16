//
//  IMAPSession+List.swift
//  Postal
//
//  Created by Jeremie Girault on 16/08/2016.
//  Copyright © 2016 snips. All rights reserved.
//

import Foundation
import libetpan

extension IMAPSession {
    
    func listFolders() throws -> [Folder] {
        let prefix = defaultNamespace?.items.first?.prefix ?? MAIL_DIR_SEPARATOR_S
        var list: UnsafeMutablePointer<clist> = nil;
        if capabilities.contains(.XList) && !capabilities.contains(.Gmail) {
            // XLIST support is deprecated on Gmail. See https://developers.google.com/gmail/imap_extensions#xlist_is_deprecated
            try mailimap_xlist(imap, prefix, "*", &list).toIMAPError?.check()
        } else {
            try mailimap_list(imap, prefix, "*", &list).toIMAPError?.check()
        }
        defer { mailimap_list_result_free(list) }
        
        return makeFolders(sequence(list, of: mailimap_mailbox_list.self))
    }
    
    func makeFolders<S: SequenceType where S.Generator.Element == mailimap_mailbox_list>(sequence: S) -> [Folder] {
        return sequence.flatMap { (folder: mailimap_mailbox_list) -> Folder? in
            guard let name = String.fromCString(folder.mb_name) else { return nil }
            var mb_delimiter: [CChar] = [ folder.mb_delimiter, 0 ]
            guard let delimiter = String.fromCString(&mb_delimiter) else { return nil }
            return Folder(name: name, flags: FolderFlag(flags: folder.mb_flag), delimiter: delimiter)
        }
    }
}