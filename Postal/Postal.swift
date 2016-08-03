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
import Result

protocol PostalErrorType {
    var asPostalError: PostalError { get }
}

extension PostalErrorType {
    func check() throws { throw self.asPostalError }
}

public enum PostalError: ErrorType {
    case imapError(IMAPError)
    case imfError(IMFError)
}

/// This class is the class where every request will be performed.
public class Postal {
    private let session: IMAPSession
    private let queue: NSOperationQueue
    private let configuration: Configuration

    /// Setting this variable will allow user to access to the internal logger.
    public var logger: Logger? {
        set { session.logger = newValue }
        get { return session.logger }
    }
    
    /// Initialize a new instance for a given configuration
    ///
    /// - parameters
    ///     - configuration: The configuration of the new connection.
    public init(configuration: Configuration) {
        let providerName = "\(configuration)".lowercaseString
        queue = NSOperationQueue()
        queue.name = "com.postal.\(providerName)"
        queue.qualityOfService = .Utility
        queue.maxConcurrentOperationCount = 1
        self.configuration = configuration
        session = IMAPSession(configuration: configuration)
    }
}

//  MARK: - Connection

public extension Postal {
    public static let defaultTimeout: NSTimeInterval = 30
    
    /// Attemps a connection to the server
    ///
    /// - parameters:
    ///     - timeout: A timeout for performing requests. If a request is not completed within the specified interval, the request is canceled and the completionHandler is called with an error.
    ///     - completion: The completion handler to call when the connection is done, or an error occurs. This handler is executed on the main queue.
    func connect(timeout timeout: NSTimeInterval = Postal.defaultTimeout, completion: (Result<Void, PostalError>) -> ()) {
        doAsync({
            try self.session.connect(timeout: timeout)
            try self.session.login()
            try self.session.configure()
        }, completion: completion)
    }
}

//  MARK: - Folders

public extension Postal {
    
    /// Retrieve list folders on the server
    ///
    /// - parameters:
    ///     - completion: The completion handler to call when the request succeed or failed.
    func listFolders(completion: (Result<[Folder], PostalError>) -> ()) {
        doAsync({
            try self.session.listFolders()
        }, completion: completion)
    }
}

//  MARK: - Fetchers

public extension Postal {

    /// Fetch a given number of last emails in a given folder
    ///
    /// - parameters: 
    ///     - folder: The folder where the search will be performed.
    ///     - last: The number of last mail that should be fetch.
    ///     - flags: The kind of information you want to retrieve.
    ///     - extraHeaders: A set of extra headers for the request
    ///     - onMessage: The completion handler called when a new message is received.
    ///     - onComplete: The completion handler when the request is finished with or without an error.
    func fetchLast(folder: String, last: UInt, flags: FetchFlag, extraHeaders: Set<String> = [], onMessage: (FetchResult) -> Void, onComplete: (PostalError?) -> Void) {
        assert(!folder.isEmpty, "folder parameter can't be empty")
        
        iterateAsync({ handler in try self.session.fetchLast(folder, last: last, flags: flags, extraHeaders: extraHeaders, handler: handler) },
            onItem: onMessage,
            onComplete: onComplete)
    }
    
    /// Fetch emails by uids in a given folder
    ///
    /// - parameters:
    ///     - folder: The folder where the search will be performed.
    ///     - uids: The uids of the emails that you want to retrieve.
    ///     - flags: The kind of information you want to retrieve.
    ///     - extraHeaders: A set of extra headers for the request
    ///     - onMessage: The completion handler called when a new message is received.
    ///     - onComplete: The completion handler when the request is finished with or without an error.
    func fetchMessages(folder: String, uids: NSIndexSet, flags: FetchFlag, extraHeaders: Set<String> = [], onMessage: (FetchResult) -> Void, onComplete: (PostalError?) -> Void) {
        assert(!folder.isEmpty, "folder parameter can't be empty")

        iterateAsync({ handler in try self.session.fetchMessages(folder, set: .uid(uids), flags: flags, extraHeaders: extraHeaders, handler: handler) },
                     onItem: onMessage,
                     onComplete: onComplete)
    }

    /// Fetch attachments of an email for a given partID in a given folder
    ///
    /// - parameters:
    ///     - folder: The folder where the search will be performed.
    ///     - uid: The uid of the email where there is the attachment
    ///     - partId: The partId you want to fetch
    ///     - onAttachment: The completion handler called when an attachment was found.
    ///     - onComplete: The completion handler when the request is finished with or without an error.
    func fetchAttachments(folder: String, uid: UInt, partId: String, onAttachment: (MailData) -> Void, onComplete: (PostalError?) -> Void) {
        assert(!folder.isEmpty, "folder parameter can't be empty")
        assert(!partId.isEmpty, "partId parameter can't be empty")

        iterateAsync({ handler in try self.session.fetchParts(folder, uid: uid, partId: partId, handler:handler) },
                     onItem: onAttachment,
                     onComplete: onComplete)
    }
}

//  MARK: - Search

public extension Postal {

    /// Search emails for a given filter. Retrieve an indexset of uids.
    ///
    /// - parameters:
    ///     - folder: The folder where the search will be performed.
    ///     - filter: The filter
    ///     - completion: The completion handler when the request is finished with or without an error.
    func search(folder: String, filter: SearchKind, completion: (Result<NSIndexSet, PostalError>) -> Void) {
        assert(!folder.isEmpty, "folder parameter can't be empty")
        
        doAsync({
            try self.session.search(folder, filter: filter)
        }, completion: completion)
    }

    /// Search emails for a given filter. Retrieve an indexset of uids.
    ///
    /// - parameters:
    ///     - folder: The folder where the search will be performed.
    ///     - filter: The filter
    ///     - completion: The completion handler when the request is finished with or without an error.
    func search(folder: String, filter: SearchFilter, completion: (Result<NSIndexSet, PostalError>) -> Void) {
        assert(!folder.isEmpty, "folder parameter can't be empty")
        
        doAsync({
            try self.session.search(folder, filter: filter)
        }, completion: completion)
    }
}

//  MARK: - Privates

private extension Postal {
    
    func doAsync<T, E: ErrorType>(f: () throws -> T, completion: (Result<T, E>) -> Void) {
        queue.addOperationWithBlock {
            let result = Result<T, E>(attempt: f)
            dispatch_async(dispatch_get_main_queue()) {
                completion(result)
            }
        }
    }
    
    func iterateAsync<T, E: ErrorType>(f: (T -> Void) throws -> Void, onItem: (T) -> Void, onComplete: (E?) -> Void) {
        queue.addOperationWithBlock {
            do {
                try f() { item in
                    dispatch_async(dispatch_get_main_queue()) {
                        onItem(item)
                    }
                }
                
                onComplete(nil)
            } catch let error as E {
                dispatch_async(dispatch_get_main_queue()) {
                    onComplete(error)
                }
            } catch {
                //  ?
            }
        }
    }
}
