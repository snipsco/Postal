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

extension Int8 {
    var boolValue: Bool { return self != 0 }
}

extension UInt8 {
    var boolValue: Bool { return self != 0 }
}

extension Int32 {
    var boolValue: Bool { return self != 0 }
}

extension Bool {
    var int8Value: Int32 { return self ? 1 : 0 }
    var int16Value: Int32 { return self ? 1 : 0 }
    var int32Value: Int32 { return self ? 1 : 0 }
    var int64Value: Int32 { return self ? 1 : 0 }
}

extension String {
    static func fromUTF8CString(cstring: UnsafePointer<CChar>) -> String? {
        if cstring == nil { return nil }
        return String(CString: cstring, encoding: NSUTF8StringEncoding)
    }
    
    var unreleasedUTF8CString: UnsafeMutablePointer<CChar> {
        return withCString { strdup($0) }
    }

    var UTF8CString: UnsafePointer<CChar> {
        return UnsafePointer((self as NSString).UTF8String)
    }
}

extension String {
    static func stringFromCStringDetectingEncoding(CString: UnsafePointer<CChar>, length: Int, suggestedEncodings: Set<NSStringEncoding> = [], disallowedEncodings: Set<NSStringEncoding> = []) -> (string: String, encoding: NSStringEncoding, lossy: Bool)? {
        
        let data = NSData(bytesNoCopy: UnsafeMutablePointer<Void>(CString), length: length, freeWhenDone: false)
        
        var outString: NSString? = nil
        var lossyConversion: ObjCBool = false
        
        var encodingOptions = [String: AnyObject]()
        if !suggestedEncodings.isEmpty {
            encodingOptions[NSStringEncodingDetectionSuggestedEncodingsKey] = Array(suggestedEncodings)
        }
        if !disallowedEncodings.isEmpty {
            encodingOptions[NSStringEncodingDetectionDisallowedEncodingsKey] = Array(disallowedEncodings)
        }
        
        
        let encoding = NSString.stringEncodingForData(data, encodingOptions: encodingOptions, convertedString: &outString, usedLossyConversion: &lossyConversion)
        
        guard let foundString = outString else { return nil }
        
        return (string: foundString as String, encoding: encoding, lossy: lossyConversion.boolValue)
    }
}

extension UnsafePointer {
    var optional: Memory? { return self == nil ? .None : memory }
}

extension UnsafeMutablePointer {
    var optional: Memory? { return self == nil ? .None : memory }
}

func bridgeUnretained<T : AnyObject>(obj : T) -> UnsafePointer<Void> {
    return UnsafePointer(Unmanaged.passUnretained(obj).toOpaque())
}

func bridgeUnretained<T : AnyObject>(obj : T) -> UnsafeMutablePointer<Void> {
    return UnsafeMutablePointer(Unmanaged.passUnretained(obj).toOpaque())
}

extension ErrorType {
    func check() throws { throw self }
}

extension OptionSetType where Element == Self {
    func representation(flags: [(Self, String)]) -> String {
        var stringFlags: [String] = []
        flags.forEach {
            if self.contains($0) { stringFlags.append($1) }
        }
        return "\(self.dynamicType).\(stringFlags.joinWithSeparator(" | "))"
    }
}

extension NSIndexSet {
    func enumerate(batchSize batchSize: Int) -> AnySequence<NSIndexSet> {
        var indexGenerator = self.generate()
        let accumulatorGenerator = AnyGenerator<NSIndexSet> {
            let currentBatch = NSMutableIndexSet()
            while let nextIndex = indexGenerator.next() where currentBatch.count < batchSize {
                currentBatch.addIndex(nextIndex)
            }
            
            guard currentBatch.count > 0 else { return nil }
            
            return currentBatch
        }
        
        return AnySequence(accumulatorGenerator)
    }
}

extension Dictionary {
    init(keys: [Key], values: [Value]) {
        self.init()
        
        for (key, value) in zip(keys, values) {
            self[key] = value
        }
    }
    
    mutating func unionInPlace(dictionary: Dictionary) {
        dictionary.forEach { self.updateValue($1, forKey: $0) }
    }
    
    func union(dictionary: Dictionary) -> Dictionary {
        var dictionary = dictionary
        dictionary.unionInPlace(self)
        return dictionary
    }
}
