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

extension MailData {
    public var decodedData: NSData {
        switch encoding {
        case .encoding7Bit, .encoding8Bit, .binary, .other: return rawData
        case .base64: return rawData.base64Decoded
        case .quotedPrintable: return rawData.quotedPrintableDecoded
        case .uuEncoding: return rawData.uudecoded
        }
    }
}

extension NSData {
    var base64Decoded: NSData {
        return decodeWithMechanism(MAILMIME_MECHANISM_BASE64, partial: false).decoded
    }
    
    var quotedPrintableDecoded: NSData {
        return decodeWithMechanism(MAILMIME_MECHANISM_QUOTED_PRINTABLE, partial: false).decoded
    }
    
    func decodeWithMechanism(mechanism: Int, partial: Bool) -> (decoded: NSData, remaining: NSData?) {
        var curToken: size_t = 0
        var decodedBytes: UnsafeMutablePointer<Int8> = nil
        var decodedLength: Int = 0
        let decodeFunc = partial ? mailmime_part_parse_partial : mailmime_part_parse
        decodeFunc(UnsafePointer<Int8>(bytes), length, &curToken, Int32(mechanism), &decodedBytes, &decodedLength)
        let decodedData = NSData(bytesNoCopy: decodedBytes, length: decodedLength) { (pointer, length) in
            free(pointer)
        }
        
        let remaining: NSData?
        if decodedLength < length {
            remaining = NSData(bytes: bytes + curToken, length: length - curToken)
        } else {
            remaining = nil
        }
        return (decoded: decodedData, remaining: remaining)
    }
    
    var uudecoded: NSData {
        return uudecode(partial: false).decoded
    }
    
    func uudecode(partial partial: Bool) -> (decoded: NSData, remaining: NSData?) {
        var currentPosition = UnsafePointer<CChar>(bytes)
        let accumulator = NSMutableData()
        
        while true {
            let (data, next) = getLine(currentPosition)
        
            if let next = next { // line is complete
                accumulator.appendData(data.uudecodedLine)
                currentPosition = next
            } else { // no new line
                if !partial { // not partial, just decode remaining bytes
                    accumulator.appendData(data.uudecodedLine)
                    return (decoded: accumulator, remaining: nil)
                } else { // partial, return remaining bytes as remaining
                    let remainingBytesCopy = NSData(bytes: data.bytes, length: data.length) // force copy of remaining data
                    return (decoded: accumulator, remaining: remainingBytesCopy)
                }
            }
        }
    }
    
    var uudecodedLine: NSData {
        var current = UnsafePointer<Int8>(bytes)
        let end = current + length
        let leadingCount = Int((current[0] & 0x7f) - 0x20)
        current += 1
        
        if leadingCount < 0 { // don't process lines without leading count character
            return NSData()
        }
        
        if strncasecmp(UnsafePointer<CChar>(bytes), "begin ", 6) == 0 || strncasecmp(UnsafePointer<CChar>(bytes), "end", 3) == 0 {
            return NSData()
        }
        
        let decoded = NSMutableData(capacity: leadingCount)! // if we can't allocate it, let's better crash
        
        var buf = [Int8](count: 3, repeatedValue: 0)
        while current < end && decoded.length < leadingCount {
            var v = 0
            (0..<4).forEach { _ in // pack decoded bytes in the int
                let c = current.memory
                current += 1
                v = v << 6 | ((c - 0x20) & 0x3F)
            }
            
            for i in 2.stride(through: 0, by: -1) { // unpack the int in buf
                buf[i] = Int8(v & 0xFF)
                v = v >> 8
            }
            
            decoded.appendBytes(&buf, length: buf.count)
        }
        
        return decoded
    }
    
    func getLine(from: UnsafePointer<CChar>) -> (data: NSData, next: UnsafePointer<CChar>?) {
        let from = UnsafeMutablePointer<CChar>(from)
        let bufferStart = UnsafeMutablePointer<CChar>(bytes)
        
        assert(from >= bufferStart && from - bufferStart <= length)
        
        let cr: CChar = 13 //"\r".utf8.first!
        let lf: CChar = 10 //"\n".utf8.first!
        
        var lineStart = UnsafeMutablePointer<CChar>(from)
        
        // skip eols at the beginning
        while (lineStart - bufferStart < length) && (lineStart.memory == cr || lineStart.memory == lf) {
            lineStart += 1
        }
        
        let remainingLength = length - (lineStart - bufferStart)
        var lineSize: size_t = 0
        while lineSize < remainingLength {
            if lineStart[lineSize] == cr || lineStart[lineSize] == lf {
                // found eol
                let data = NSData(bytesNoCopy: lineStart, length: lineSize, freeWhenDone: false)
                let next = UnsafePointer<CChar>(lineStart+lineSize+1)
                return (data: data, next: next)
            } else {
                lineSize += 1
            }
        }
        
        let data = NSData(bytesNoCopy: lineStart, length: lineSize - 1, freeWhenDone: false)
        return (data: data, next: nil)
    }
}
