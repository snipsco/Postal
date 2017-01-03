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

enum IMAPError {
    case undefined
    case connection
    case login(description: String)
    case parse
    case certificate
    case nonExistantFolder
}

extension IMAPError: PostalErrorType {
    var asPostalError: PostalError {
        switch self {
        case .undefined: return .undefined
        case .connection: return .connection
        case .login(let description): return .login(description: description)
        case .parse: return .parse
        case .certificate: return .certificate
        case .nonExistantFolder: return .nonExistantFolder
        }
    }
}

extension IMAPError {
    func enrich(_ f: () -> IMAPError) -> IMAPError {
        if case .undefined = self {
            return f()
        }
        return self
    }
}

extension Int {
    var toIMAPError: IMAPError? {
        switch self {
        case MAILIMAP_NO_ERROR, MAILIMAP_NO_ERROR_AUTHENTICATED, MAILIMAP_NO_ERROR_NON_AUTHENTICATED: return nil
        case MAILIMAP_ERROR_STREAM: return .connection
        case MAILIMAP_ERROR_PARSE: return .parse
        default: return .undefined
        }
    }
}

extension Int32 {
    var toIMAPError: IMAPError? {
        return Int(self).toIMAPError
    }
}
