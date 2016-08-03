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

import ReactiveCocoa

public extension Postal {
    func rac_connect() -> SignalProducer<Void, PostalError> {
        return SignalProducer { observer, disposable in
            self.connect(timeout: Postal.defaultTimeout) { result in
                result.analysis(
                    ifSuccess: {
                        observer.sendNext(())
                        observer.sendCompleted()
                    },
                    ifFailure: observer.sendFailed)
                }
            }
    }
    
    func rac_listFolders() -> SignalProducer<[Folder], PostalError> {
        return SignalProducer { observer, disposable in
            self.listFolders { result in
                result.analysis(
                    ifSuccess: { folders in
                        observer.sendNext(folders)
                        observer.sendCompleted()
                    },
                    ifFailure: observer.sendFailed)
                }
            }
    }
    
    func rac_findAllMailFolder() -> SignalProducer<String, PostalError> {
        return rac_listFolders()
            .map { (folders: [Folder]) -> String in
                // We want to search in the "All Mail" folder but if for any reason we can't find it,
                // we fallback in the "INBOX" folder which should always exist.
                if let allMailFolder = folders.filter({ $0.flags.contains(.AllMail) }).first {
                    return allMailFolder.name
                } else if let inboxFolder = folders.filter({ $0.flags.contains(.Inbox) }).first {
                    return inboxFolder.name
                }
                return "INBOX"
            }
    }
    
    func rac_search(folder: String, filter: SearchKind) -> SignalProducer<NSIndexSet, PostalError> {
        return rac_search(folder, filter: .base(filter))
    }
    
    func rac_search(folder: String, filter: SearchFilter) -> SignalProducer<NSIndexSet, PostalError> {
        return SignalProducer { observer, disposable in
            self.search(folder, filter: filter) { result in
                result.analysis(
                    ifSuccess: { uids in
                        observer.sendNext(uids)
                        observer.sendCompleted()
                    },
                    ifFailure: observer.sendFailed)
                }
            }
    }
    
    func rac_fetch(folder: String, uids: NSIndexSet, flags: FetchFlag, extraHeaders: Set<String> = []) -> SignalProducer<FetchResult, PostalError> {
        return SignalProducer<FetchResult, PostalError> { observer, disposable in
            self.fetchMessages(folder, uids: uids, flags: flags, extraHeaders: extraHeaders,
                onMessage: { message in
                    observer.sendNext(message)
                }, onComplete: { error in
                    if let error = error {
                        observer.sendFailed(error)
                    } else {
                        observer.sendCompleted()
                    }
                })
            }
    }
    
    func rac_fetchAttachment(folder: String, uid: UInt, partId: String) -> SignalProducer<MailData, PostalError> {
        return SignalProducer<MailData, PostalError> { observer, disposable in
            self.fetchAttachments(folder, uid: uid, partId: partId,
                onAttachment: { data in
                    observer.sendNext(data)
                },
                onComplete: { error in
                    if let error = error {
                        observer.sendFailed(error)
                    } else {
                        observer.sendCompleted()
                    }
                })
            }
    }
    
    func rac_fetchTextualMail(folder: String, uids: NSIndexSet) -> SignalProducer<FetchResult, PostalError> {
        return rac_fetch(folder, uids: uids, flags: [ .structure, .fullHeaders ])
            .flatMap(.Concat) { (fetchResult: FetchResult) -> SignalProducer<FetchResult, PostalError> in
                let inlineElements = fetchResult.body?.allParts.filter { singlePart in
                    if case .Some(.attachment) = singlePart.mimeFields.contentDisposition { return false }
                    return [ "text/html", "text/plain" ].contains("\(singlePart.mimeType)")
                    } ?? []
                
                return SignalProducer<SinglePart, PostalError>(values: inlineElements)
                    .flatMap(.Merge) { (singlePart: SinglePart) -> SignalProducer<(String, MailData), PostalError> in
                        return self.rac_fetchAttachment(folder, uid: fetchResult.uid, partId: singlePart.id).map { (singlePart.id, $0) }
                    }
                    .collect()
                    .map { fetchResult.mergeAttachments(Dictionary(elements: $0)) }
            }
    }
}

private extension Dictionary {
    init<S: SequenceType where S.Generator.Element == Element>(elements: S) {
        self.init()
        for (k, v) in elements {
            self[k] = v
        }
    }
}

private extension FetchResult {
    func mergeAttachments(attachments: [String: MailData]) -> FetchResult {
        return FetchResult(uid: uid,
                           header: header,
                           flags: flags,
                           body: body?.mergeAttachments(attachments),
                           rfc822Size: rfc822Size,
                           internalDate: internalDate,
                           gmailThreadId: gmailThreadId,
                           gmailMessageId: gmailMessageId,
                           gmailLabels: gmailLabels)
    }
}

private extension MailPart {
    func mergeAttachments(attachments: [String: MailData]) -> MailPart {
        switch self {
        case .single(let id, let mimeType, let mimeFields, let data):
            if let replacedData = attachments[id] {
                return .single(id: id, mimeType: mimeType, mimeFields: mimeFields, data: MailData(rawData: replacedData.rawData, encoding: mimeFields.contentEncoding ?? data?.encoding ?? replacedData.encoding))
            }
            return self
        case .multipart(let id, let mimeType, let parts):
            return .multipart(id: id, mimeType: mimeType, parts: parts.map { $0.mergeAttachments(attachments) })
        case .message(let id, let header, let message):
            return .message(id: id, header: header, message: message.mergeAttachments(attachments))
        }
    }
}
