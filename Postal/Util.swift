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
    static func fromUTF8CString(_ cstring: UnsafePointer<CChar>?) -> String? {
        if let cstring = cstring {
            return String(validatingUTF8: cstring)
        }
        return nil
    }
    
    var unreleasedUTF8CString: UnsafeMutablePointer<CChar> {
        return withCString { strdup($0) }
    }
}

extension String {
    static func stringFromCStringDetectingEncoding(_ CString: UnsafePointer<CChar>, length: Int, suggestedEncodings: Set<String.Encoding> = [], disallowedEncodings: Set<String.Encoding> = []) -> (string: String, encoding: String.Encoding, lossy: Bool)? {
        
        let data = Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: CString), count: length, deallocator: .none)
        
        var outString: NSString? = nil
        var lossyConversion: ObjCBool = false
        
        var encodingOptions = [StringEncodingDetectionOptionsKey: Any]()
        if !suggestedEncodings.isEmpty {
            encodingOptions[.suggestedEncodingsKey] = suggestedEncodings
        }
        if !disallowedEncodings.isEmpty {
            encodingOptions[.disallowedEncodingsKey] = disallowedEncodings
        }
        
        let rawEncoding = NSString.stringEncoding(for: data, encodingOptions: encodingOptions, convertedString: &outString, usedLossyConversion: &lossyConversion)
        let encoding = String.Encoding(rawValue: rawEncoding)
        
        guard let foundString = outString else { return nil }
        
        return (string: foundString as String, encoding: encoding, lossy: lossyConversion.boolValue)
    }
}

extension Error {
    func check() throws { throw self }
}

extension OptionSet where Element == Self {
    func representation(_ flags: [(Self, String)]) -> String {
        var stringFlags: [String] = []
        flags.forEach {
            if self.contains($0) { stringFlags.append($1) }
        }
        return "\(type(of: self)).\(stringFlags.joined(separator: " | "))"
    }
}

extension IndexSet {
    func enumerate(batchSize: Int) -> AnySequence<IndexSet> {
        var indexGenerator = self.makeIterator()
        let accumulatorGenerator = AnyIterator<IndexSet> {
            let currentBatch = NSMutableIndexSet()
            while let nextIndex = indexGenerator.next() , currentBatch.count < batchSize {
                currentBatch.add(nextIndex)
            }
            
            guard currentBatch.count > 0 else { return nil }
            
            return currentBatch as IndexSet
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
    
    mutating func unionInPlace(_ dictionary: Dictionary) {
        dictionary.forEach { self.updateValue($1, forKey: $0) }
    }
    
    func union(_ dictionary: Dictionary) -> Dictionary {
        var dictionary = dictionary
        dictionary.unionInPlace(self)
        return dictionary
    }
}
