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

extension String {
    static func fromZeroSizedCStringMimeHeader(_ bytes: UnsafeMutablePointer<Int8>?) -> String? {
        guard let bytes = bytes else { return nil }
        
        let length = Int(strlen(bytes))
        return fromCStringMimeHeader(bytes, length: length)
    }
    
    static func fromCStringMimeHeader(_ bytes: UnsafeMutablePointer<Int8>?, length: Int) -> String? {
        let DEFAULT_INCOMING_CHARSET = "iso-8859-1"
        let DEFAULT_DISPLAY_CHARSET = "utf-8"
        
        guard let bytes = bytes, bytes[0] != 0 else { return nil }
        
        var hasEncoding = false
        if strstr(bytes, "=?") != nil {
            if strcasestr(bytes, "?Q?") != nil || strcasestr(bytes, "?B?") != nil {
                hasEncoding = true
            }
        }
        
        if !hasEncoding {
            return String.stringFromCStringDetectingEncoding(bytes, length: length)?.string
        }
        
        var decoded: UnsafeMutablePointer<CChar>? = nil
        var cur_token: size_t = 0
        mailmime_encoded_phrase_parse(DEFAULT_INCOMING_CHARSET, bytes, Int(strlen(bytes)), &cur_token, DEFAULT_DISPLAY_CHARSET, &decoded)
        defer { free(decoded) }
        
        guard let actuallyDecoded = decoded else { return nil }

        return String.fromUTF8CString(actuallyDecoded)
    }
}

// MARK: Sequences

extension Sequence {
    func unreleasedClist<T>(_ transferOwnership: (Iterator.Element) -> UnsafeMutablePointer<T>) -> UnsafeMutablePointer<clist> {
        let list = clist_new()
        map(transferOwnership).forEach { (item: UnsafeMutablePointer<T>) in
            clist_append(list, item)
        }
        return list!
    }
}

private func pointerListGenerator<Element>(unsafeList list: UnsafePointer<clist>, of: Element.Type) -> AnyIterator<UnsafePointer<Element>> {
    var current = list.pointee.first?.pointee
    return AnyIterator<UnsafePointer<Element>> {
        while current != nil && current?.data == nil { // while data is unavailable skip to next
            current = current?.next?.pointee
        }
        guard let cur = current else { return nil } // if iterator is nil, list is over, just finish
        defer { current = current?.next?.pointee } // after returning move current to next
        return UnsafePointer<Element>(cur.data.assumingMemoryBound(to: Element.self)) // return current data as Element (unsafe: type cannot be checked because of C)
    }
}

private func listGenerator<Element>(unsafeList list: UnsafePointer<clist>, of: Element.Type) -> AnyIterator<Element> {
    let gen = pointerListGenerator(unsafeList: list, of: of)
    return AnyIterator {
        return gen.next()?.pointee
    }
}

private func arrayGenerator<Element>(unsafeArray array: UnsafePointer<carray>, of: Element.Type) -> AnyIterator<Element> {
    var idx: UInt32 = 0
    let len = carray_count(array)
    return AnyIterator {
        guard idx < len else { return nil }
        defer { idx = idx + 1 }
        return carray_get(array, idx).assumingMemoryBound(to: Element.self).pointee
    }
}

func sequence<Element>(_ unsafeList: UnsafePointer<clist>, of: Element.Type) -> AnySequence<Element> {
    return AnySequence { return listGenerator(unsafeList: unsafeList, of: of) }
}

func pointerSequence<Element>(_ unsafeList: UnsafePointer<clist>, of: Element.Type) -> AnySequence<UnsafePointer<Element>> {
    return AnySequence { return pointerListGenerator(unsafeList: unsafeList, of: of) }
}

func sequence<Element>(_ unsafeArray: UnsafePointer<carray>, of: Element.Type) -> AnySequence<Element> {
    return AnySequence { return arrayGenerator(unsafeArray: unsafeArray, of: of) }
}

// MARK: Dates

extension Date {
    var unreleasedMailimapDate: UnsafeMutablePointer<mailimap_date>? {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([ .year, .month, .day ], from: self)
        
        guard let day = components.day, let month = components.month, let year = components.year else { return nil }
        
        return mailimap_date_new(Int32(day), Int32(month), Int32(year))
    }
}

extension mailimf_date_time {
    var date: Date? {
        var dateComponent = DateComponents()
        dateComponent.calendar = Calendar(identifier: .gregorian)
        dateComponent.second = Int(dt_sec)
        dateComponent.minute = Int(dt_min)
        dateComponent.hour = Int(dt_min)
        dateComponent.hour = Int(dt_hour)
        dateComponent.day = Int(dt_day)
        dateComponent.month = Int(dt_month)
        
        if dt_year < 1000 {
            // workaround when century is not given in year
            dateComponent.year = Int(dt_year + 2000)
        } else {
            dateComponent.year = Int(dt_year)
        }
        
        let zoneHour: Int
        let zoneMin: Int
        if dt_zone >= 0 {
            zoneHour = Int(dt_zone / 100)
            zoneMin = Int(dt_zone % 100)
        } else {
            zoneHour = Int(-((-dt_zone) / 100))
            zoneMin = Int(-((-dt_zone) % 100))
        }
        dateComponent.timeZone = TimeZone(secondsFromGMT: zoneHour * 3600 + zoneMin * 60)
        
        return dateComponent.date
    }
}

extension mailimap_date_time {
    var date: Date? {
        var dateComponent = DateComponents()
        dateComponent.calendar = Calendar(identifier: .gregorian)
        dateComponent.second = Int(dt_sec)
        dateComponent.minute = Int(dt_min)
        dateComponent.hour = Int(dt_min)
        dateComponent.hour = Int(dt_hour)
        dateComponent.day = Int(dt_day)
        dateComponent.month = Int(dt_month)
        
        if dt_year < 1000 {
            // workaround when century is not given in year
            dateComponent.year = Int(dt_year + 2000)
        } else {
            dateComponent.year = Int(dt_year)
        }
        
        let zoneHour: Int
        let zoneMin: Int
        if dt_zone >= 0 {
            zoneHour = Int(dt_zone / 100)
            zoneMin = Int(dt_zone % 100)
        } else {
            zoneHour = Int(-((-dt_zone) / 100))
            zoneMin = Int(-((-dt_zone) % 100))
        }
        dateComponent.timeZone = TimeZone(secondsFromGMT: zoneHour * 3600 + zoneMin * 60)
        
        return dateComponent.date
    }
}

// MARK: Set

extension mailimap_set {
    var indexSet: IndexSet {
        var result: IndexSet = IndexSet()
        
        sequence(set_list, of: mailimap_set_item.self)
            .map { (item: mailimap_set_item) -> CountableClosedRange<Int> in
                return Int(item.set_first)...Int(item.set_last)
            }
            .forEach { (range: CountableClosedRange<Int>) in
                result.insert(integersIn: range)
            }
        return result
    }
    
    var array: [Int] {
        var result: [Int] = []
        
        sequence(set_list, of: mailimap_set_item.self)
            .map { (item: mailimap_set_item) -> CountableClosedRange<Int> in
                return Int(item.set_first)...Int(item.set_last)
            }
            .forEach { (range: CountableClosedRange<Int>) in
                result.append(contentsOf: range)
            }
        return result
    }
}
