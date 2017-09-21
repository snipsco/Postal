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
import Result

/// This class is the class where every request will be performed.
open class Postal {
    fileprivate let session: IMAPSession
    fileprivate let queue: OperationQueue
    fileprivate let configuration: Configuration

    /// Setting this variable will allow user to access to the internal logger.
    open var logger: Logger? {
        set { session.logger = newValue }
        get { return session.logger }
    }
    
    /// Initialize a new instance for a given configuration
    ///
    /// - parameters
    ///     - configuration: The configuration of the new connection.
    public init(configuration: Configuration) {
        let providerName = "\(configuration)".lowercased()
        queue = OperationQueue()
        queue.name = "com.postal.\(providerName)"
        queue.qualityOfService = .utility
        queue.maxConcurrentOperationCount = 1
        self.configuration = configuration
        session = IMAPSession(configuration: configuration)
    }
}

// MARK: - Connection

public extension Postal {
    public static let defaultTimeout: TimeInterval = 30
    
    /// Attemps a connection to the server
    ///
    /// - parameters:
    ///     - timeout: A timeout for performing requests. If a request is not completed within the specified interval, the request is canceled and the completionHandler is called with an error.
    ///     - completion: The completion handler to call when the connection is done, or an error occurs. This handler is executed on the main queue.
    func connect(timeout: TimeInterval = Postal.defaultTimeout, completion: @escaping (Result<Void, PostalError>) -> ()) {
        doAsync({
            try self.session.connect(timeout: timeout)
            try self.session.login()
            try self.session.configure()
        }, completion: completion)
    }
}

// MARK: - Folders

public extension Postal {
    
    /// Retrieve list folders on the server
    ///
    /// - parameters:
    ///     - completion: The completion handler to call when the request succeed or failed.
    func listFolders(_ completion: @escaping (Result<[Folder], PostalError>) -> ()) {
        doAsync({
            try self.session.listFolders()
        }, completion: completion)
    }
    
    /// Delete a folder
    ///
    /// - Parameters:
    ///   - folderName: the folder name.
    ///   - completion: The completion handler to call when request succeed or failed.
    func delete(folderNamed folderName: String, completion: @escaping (Result<Void, PostalError>) -> ()) {
        doAsync({
            try self.session.delete(folderNamed: folderName)
        }, completion: completion)
    }
    
    /// Create a folder
    ///
    /// - Parameters:
    ///   - folderName: the folder name.
    ///   - completion: The completion handler to call when request succeed or failed.
    func create(folderNamed folderName: String, completion: @escaping (Result<Void, PostalError>) -> ()) {
        doAsync({
            try self.session.create(folderNamed: folderName)
        }, completion: completion)
    }
    
    /// Rename a folder
    ///
    /// - Parameters:
    ///   - folderName: the folder name that will be rename.
    ///   - to: the new folder name.
    ///   - completion: The completion handler to call when request succeed or failed.
    func rename(folderNamed fromFolderName: String, to toFolderName: String, completion: @escaping (Result<Void, PostalError>) -> ()) {
        doAsync({
            try self.session.rename(folderNamed: fromFolderName, to: toFolderName)
        }, completion: completion)
    }
    
    /// Subscribe a folder
    ///
    /// - Parameters:
    ///   - folderName: the folder name to be subcribed.
    ///   - completion: The completion handler to call when request succeed or failed.
    func subscribe(folderNamed folderName: String, completion: @escaping (Result<Void, PostalError>) -> ()) {
        doAsync({
            try self.session.subscribe(folderNamed: folderName)
        }, completion: completion)
    }
    
    /// Unsubscribe a folder
    ///
    /// - Parameters:
    ///   - folderName: the folder name to unsubscribe.
    ///   - completion: The completion handler to call when request succeed or failed.
    func unsubscribe(folderNamed folderName: String, completion: @escaping (Result<Void, PostalError>) -> ()) {
        doAsync({
            try self.session.unsubscribe(folderNamed: folderName)
        }, completion: completion)
    }
    
    /// Expunge a folder
    ///
    /// - Parameters:
    ///   - folderName: the folder name to expunge
    ///   - completion: The completion handler to call when request succeed or failed.
    func expunge(folderNamed folderName: String, completion: @escaping (Result<Void, PostalError>) -> ()) {
        doAsync({
            try self.session.expunge(folderNamed: folderName)
        }, completion: completion)
    }
}

// MARK: - Fetchers

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
    func fetchLast(_ folder: String, last: UInt, flags: FetchFlag, extraHeaders: Set<String> = [], onMessage: @escaping (FetchResult) -> Void, onComplete: @escaping (PostalError?) -> Void) {
        assert(!folder.isEmpty, "folder parameter can't be empty")
        
        iterateAsync({ try self.session.fetchLast(folder, last: last, flags: flags, extraHeaders: extraHeaders, handler: $0) },
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
    func fetchMessages(_ folder: String, uids: IndexSet, flags: FetchFlag, extraHeaders: Set<String> = [], onMessage: @escaping (FetchResult) -> Void, onComplete: @escaping (PostalError?) -> Void) {
        assert(!folder.isEmpty, "folder parameter can't be empty")

        iterateAsync({ try self.session.fetchMessages(folder, set: .uid(uids), flags: flags, extraHeaders: extraHeaders, handler: $0) },
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
    func fetchAttachments(_ folder: String, uid: UInt, partId: String, onAttachment: @escaping (MailData) -> Void, onComplete: @escaping (PostalError?) -> Void) {
        assert(!folder.isEmpty, "folder parameter can't be empty")
        assert(!partId.isEmpty, "partId parameter can't be empty")

        iterateAsync({ try self.session.fetchParts(folder, uid: uid, partId: partId, handler: $0) },
                     onItem: onAttachment,
                     onComplete: onComplete)
    }
}

// MARK: - Search

public extension Postal {

    /// Search emails for a given filter. Retrieve an indexset of uids.
    ///
    /// - parameters:
    ///     - folder: The folder where the search will be performed.
    ///     - filter: The filter
    ///     - completion: The completion handler when the request is finished with or without an error.
    func search(_ folder: String, filter: SearchKind, completion: @escaping (Result<IndexSet, PostalError>) -> Void) {
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
    func search(_ folder: String, filter: SearchFilter, completion: @escaping (Result<IndexSet, PostalError>) -> Void) {
        assert(!folder.isEmpty, "folder parameter can't be empty")
        
        doAsync({
            try self.session.search(folder, filter: filter)
        }, completion: completion)
    }
}

// MARK: - Messages

public extension Postal {
    
    /// Move messages from a given folder to another folder.
    ///
    /// - parameters:
    ///     - fromFolder: The folder where the messages are.
    ///     - toFolder: The folder where messages will be move.
    ///     - uids: The message uids to be moved.
    ///     - completion: The completion handler when the request is finished with or without an error.
    ///         with the mapping between uids inside the previous folder and the new folder.
    func moveMessages(fromFolder: String, toFolder: String, uids: IndexSet, completion: @escaping (Result<[Int: Int], PostalError>) -> Void) {
        assert(!fromFolder.isEmpty, "fromFolder parameter can't be empty")
        assert(!toFolder.isEmpty, "toFolder parameter can't be empty")
        
        doAsync({
            try self.session.moveMessages(fromFolder: fromFolder, toFolder: toFolder, uids: uids)
        }, completion: completion)
    }
}

// MARK: - Privates

private extension Postal {
    
    func doAsync<T, E>(_ f: @escaping () throws -> T, completion: @escaping (Result<T, E>) -> Void) {
        queue.addOperation {
            let result = Result<T, E>(attempt: f)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    func iterateAsync<T, E: Error>(_ f: @escaping (@escaping (T) -> Void) throws -> Void, onItem: @escaping (T) -> Void, onComplete: @escaping (E?) -> Void) {
        queue.addOperation {
            do {
                try f() { item in
                    DispatchQueue.main.async {
                        onItem(item)
                    }
                }
                
                DispatchQueue.main.async {
                    onComplete(nil)
                }
            } catch let error as E {
                DispatchQueue.main.async {
                    onComplete(error)
                }
            } catch {
                //  ?
            }
        }
    }
}
