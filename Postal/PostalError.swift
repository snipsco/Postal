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

public enum PostalError: Error {
    case undefined
    case connection
    case login(description: String)
    case parse
    case certificate
    case nonExistantFolder
}

extension PostalError: Equatable {
}

public func ==(lhs: PostalError, rhs: PostalError) -> Bool {
    switch (lhs, rhs) {
    case (.undefined, .undefined): return true
    case (.connection, .connection): return true
    case (.login(_), .login(_)): return true
    case (.parse, .parse): return true
    case (.certificate, .certificate): return true
    case (.nonExistantFolder, .nonExistantFolder): return true
    default: return false
    }
}

// MARK: - Internal error management

protocol PostalErrorType {
    var asPostalError: PostalError { get }
}

extension PostalErrorType {
    func check() throws { throw self.asPostalError }
}
