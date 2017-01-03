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

public typealias Logger = (String) -> ()

enum ConnectionLogType {
    /// Received data
    case dataReceived
    /// Sent data
    case dataSent
    /// Sent private data
    case dataSentPrivate
    /// Parse error
    case errorParse
    /// Error while receiving data - log() is called with a NULL buffer.
    case errorReceived
    /// Error while sending data - log() is called with a NULL buffer.
    case errorSent

    init?(rawType: Int32) {
        switch Int(rawType) {
        case MAILSTREAM_LOG_TYPE_ERROR_PARSE: self = .errorParse;
        case MAILSTREAM_LOG_TYPE_ERROR_RECEIVED: self = .errorReceived
        case MAILSTREAM_LOG_TYPE_ERROR_SENT: self = .errorSent
        case MAILSTREAM_LOG_TYPE_DATA_RECEIVED: self = .dataReceived;
        case MAILSTREAM_LOG_TYPE_DATA_SENT: self = .dataSent;
        case MAILSTREAM_LOG_TYPE_DATA_SENT_PRIVATE: self = .dataSentPrivate;
        default: return nil
        }
    }
}

extension ConnectionLogType: CustomStringConvertible {
    var description: String {
        let content: String
        switch self {
        case .dataReceived: content = "dataReceived"
        case .dataSent: content = "dataSent"
        case .dataSentPrivate: content = "sentPrivate"
        case .errorParse: content = "errorParse"
        case .errorReceived: content = "errorReceived"
        case .errorSent: content = "errorSent"
        }
        return "\(type(of: self)).\(content)"
    }
}
