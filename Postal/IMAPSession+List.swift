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

extension IMAPSession {
    
    func listFolders() throws -> [Folder] {
        let prefix = defaultNamespace?.items.first?.prefix ?? MAIL_DIR_SEPARATOR_S
        var list: UnsafeMutablePointer<clist>? = nil
        if capabilities.contains(.XList) && !capabilities.contains(.Gmail) {
            // XLIST support is deprecated on Gmail. See https://developers.google.com/gmail/imap_extensions#xlist_is_deprecated
            try mailimap_xlist(imap, prefix, "*", &list).toIMAPError?.check()
        } else {
            try mailimap_list(imap, prefix, "*", &list).toIMAPError?.check()
        }
        defer { mailimap_list_result_free(list) }
        
        if let list = list {
            return makeFolders(sequence(list, of: mailimap_mailbox_list.self))
        }
        return []
    }
    
    func makeFolders<S: Sequence>(_ sequence: S) -> [Folder] where S.Iterator.Element == mailimap_mailbox_list {
        return sequence.compactMap { (folder: mailimap_mailbox_list) -> Folder? in
            guard let name = String.fromUTF8CString(folder.mb_name) else { return nil }
            var mb_delimiter: [CChar] = [ folder.mb_delimiter, 0 ]
            let delimiter = String(cString: &mb_delimiter)

            return Folder(name: name, flags: FolderFlag(flags: folder.mb_flag), delimiter: delimiter)
        }
    }
}
