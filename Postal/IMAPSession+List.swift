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
