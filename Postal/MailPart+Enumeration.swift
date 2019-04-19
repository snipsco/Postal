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

public struct SinglePart {
    public let id: String
    public let mimeType: MimeType
    public let mimeFields: MimeFields
    public let data: MailData?
    
    init(id: String, mimeType: MimeType, mimeFields: MimeFields, data: MailData?) {
        self.id = id
        self.mimeType = mimeType
        self.mimeFields = mimeFields
        self.data = data
    }
}

extension MailPart {
    public var allParts: AnyIterator<SinglePart> {
        switch self {
        case .single(let id, let mimeType, let mimeFields, let data):
            return AnyIterator(CollectionOfOne.Iterator(_elements: SinglePart(id: id, mimeType: mimeType, mimeFields: mimeFields, data: data)))
        case .multipart(_, _, let parts):
            return AnyIterator(parts.flatMap { $0.allParts }.makeIterator())
        case .message(_, _, let message):
            return message.allParts
        }
    }
}
