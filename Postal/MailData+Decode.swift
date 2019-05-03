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

extension MailData {
    public var decodedData: Data {
        switch encoding {
        case .encoding7Bit, .encoding8Bit, .binary, .other: return rawData as Data
        case .base64: return rawData.base64Decoded
        case .quotedPrintable: return rawData.quotedPrintableDecoded
        case .uuEncoding: return rawData.uudecoded
        }
    }
}

extension Data {
    var base64Decoded: Data {
        return decodeWithMechanism(MAILMIME_MECHANISM_BASE64, partial: false).decoded
    }
    
    var quotedPrintableDecoded: Data {
        return decodeWithMechanism(MAILMIME_MECHANISM_QUOTED_PRINTABLE, partial: false).decoded
    }
    
    func decodeWithMechanism(_ mechanism: Int, partial: Bool) -> (decoded: Data, remaining: Data?) {
        var curToken: size_t = 0
        var decodedBytes: UnsafeMutablePointer<Int8>? = nil
        var decodedLength: Int = 0
        let decodeFunc = partial ? mailmime_part_parse_partial : mailmime_part_parse

        let _: Int32 = withUnsafeBytes { unsafeRawBufferPointer in
            let unsafeBufferPointer = unsafeRawBufferPointer.bindMemory(to: Int8.self)
            let unsafePointer = unsafeBufferPointer.baseAddress!
            
            return decodeFunc(unsafePointer, count, &curToken, Int32(mechanism), &decodedBytes, &decodedLength)
        }
        
        let decodedData = Data(bytesNoCopy: UnsafeMutableRawPointer(decodedBytes!), count: decodedLength, deallocator: .free)
        
        let remaining: Data?
        if decodedLength < count {
            remaining = withUnsafeBytes { unsafeRawBufferPointer in
                let unsafeBufferPointer = unsafeRawBufferPointer.bindMemory(to: Int8.self)
                let unsafePointer = unsafeBufferPointer.baseAddress!

                return Data(bytes: UnsafeRawPointer(unsafePointer + curToken), count: count - curToken)
            }
        } else {
            remaining = nil
        }
        return (decoded: decodedData, remaining: remaining)
    }
    
    var uudecoded: Data {
        return uudecode(partial: false).decoded
    }
    
    func uudecode(partial: Bool) -> (decoded: Data, remaining: Data?) {
        return withUnsafeBytes { unsafeRawBufferPointer in
            let unsafeBufferPointer = unsafeRawBufferPointer.bindMemory(to: Int8.self)

            var currentPosition = unsafeBufferPointer.baseAddress!
            let accumulator = NSMutableData()
            
            while true {
                let (data, next) = getLine(currentPosition)
            
                if let next = next { // line is complete
                    accumulator.append(data.uudecodedLine)
                    currentPosition = next
                } else { // no new line
                    if !partial { // not partial, just decode remaining bytes
                        accumulator.append(data.uudecodedLine)
                        return (decoded: accumulator as Data, remaining: nil)
                    } else { // partial, return remaining bytes as remaining
                        let remainingBytesCopy: Data = data.withUnsafeBytes { unsafeRawBufferPointer in
                            let unsafeBufferPointer = unsafeRawBufferPointer.bindMemory(to: Int8.self)

                            return Data(bytes: unsafeBufferPointer.baseAddress!, count: data.count) // force copy of remaining data
                        }
                        return (decoded: accumulator as Data, remaining: remainingBytesCopy)
                    }
                }
            }
        }
    }
    
    var uudecodedLine: Data {
        return withUnsafeBytes { unsafeRawBufferPointer in
            let unsafeBufferPointer = unsafeRawBufferPointer.bindMemory(to: Int8.self)
            let bytes = unsafeBufferPointer.baseAddress!
            
            var current = bytes
            let end = current + count
            let leadingCount = Int((current[0] & 0x7f) - 0x20)
            current += 1
            
            if leadingCount < 0 { // don't process lines without leading count character
                return Data()
            }
            
            if strncasecmp(UnsafePointer<CChar>(bytes), "begin ", 6) == 0 || strncasecmp(UnsafePointer<CChar>(bytes), "end", 3) == 0 {
                return Data()
            }
            
            let decoded = NSMutableData(capacity: leadingCount)! // if we can't allocate it, let's better crash
            
            var buf = [Int8](repeating: 0, count: 3)
            while current < end && decoded.length < leadingCount {
                var v: Int8 = 0
                (0..<4).forEach { _ in // pack decoded bytes in the int
                    let c = current.pointee
                    current += 1
                    v = v << 6 | ((c - 0x20) & 0x3F)
                }
                
                for i in stride(from: 2, through: 0, by: -1) { // unpack the int in buf
                    buf[i] = v & 0xF
                    v = v >> 8
                }
                
                decoded.append(&buf, length: buf.count)
            }
            
            return decoded as Data
        }
    }
    
    func getLine(_ from: UnsafePointer<CChar>) -> (data: Data, next: UnsafePointer<CChar>?) {
        return withUnsafeBytes { unsafeRawBufferPointer in
            let unsafeBufferPointer = unsafeRawBufferPointer.bindMemory(to: Int8.self)
            let bytes = unsafeBufferPointer.baseAddress!

            let from = UnsafeMutablePointer(mutating: from)
            let bufferStart = UnsafeMutablePointer(mutating: bytes)
            
            assert(from >= bufferStart && from - bufferStart <= count)
            
            let cr: CChar = 13 //"\r".utf8.first!
            let lf: CChar = 10 //"\n".utf8.first!
            
            var lineStart = UnsafeMutablePointer<CChar>(from)
            
            // skip eols at the beginning
            while (lineStart - bufferStart < count) && (lineStart.pointee == cr || lineStart.pointee == lf) {
                lineStart += 1
            }
            
            let remainingLength = count - (lineStart - bufferStart)
            var lineSize: size_t = 0
            while lineSize < remainingLength {
                if lineStart[lineSize] == cr || lineStart[lineSize] == lf {
                    // found eol
                    let data = Data(bytesNoCopy: lineStart, count: lineSize, deallocator: .none)
                    let next = UnsafePointer<CChar>(lineStart+lineSize+1)
                    return (data: data, next: next)
                } else {
                    lineSize += 1
                }
            }
            
            let data = Data(bytesNoCopy: lineStart, count: lineSize - 1, deallocator: .none)
            return (data: data, next: nil)
        }
        
    }
}
