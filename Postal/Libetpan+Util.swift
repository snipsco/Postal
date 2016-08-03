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

extension String {
    static func fromZeroSizedCStringMimeHeader(bytes: UnsafeMutablePointer<Int8>) -> String? {
        guard bytes != nil else { return nil }
        
        let length = Int(strlen(bytes))
        return fromCStringMimeHeader(bytes, length: length)
    }
    
    static func fromCStringMimeHeader(bytes: UnsafeMutablePointer<Int8>, length: Int) -> String? {
        let DEFAULT_INCOMING_CHARSET = "iso-8859-1"
        let DEFAULT_DISPLAY_CHARSET = "utf-8"
        
        guard bytes != nil else { return nil }
        if bytes[0] == 0 { return nil }
        
        var hasEncoding = false
        if strstr(bytes, "=?") != nil {
            if strcasestr(bytes, "?Q?") != nil || strcasestr(bytes, "?B?") != nil {
                hasEncoding = true
            }
        }
        
        if !hasEncoding {
            return String.stringFromCStringDetectingEncoding(bytes, length: length)?.string
        }
        
        var decoded: UnsafeMutablePointer<CChar> = nil
        var cur_token: size_t = 0
        mailmime_encoded_phrase_parse(DEFAULT_INCOMING_CHARSET, bytes, Int(strlen(bytes)), &cur_token, DEFAULT_DISPLAY_CHARSET, &decoded)
        defer { free(decoded) }
        
        if decoded != nil {
            return String.fromUTF8CString(decoded)
        }
        return nil
    }
}

// MARK: Sequences

extension SequenceType {
    func unreleasedClist<T>(@noescape transferOwnership: (Generator.Element) -> UnsafeMutablePointer<T>) -> UnsafeMutablePointer<clist> {
        let list = clist_new()
        map(transferOwnership).forEach { (item: UnsafeMutablePointer<T>) in
            clist_append(list, item)
        }
        return list
    }
}

private func pointerListGenerator<Element>(unsafeList list: UnsafePointer<clist>, of: Element.Type) -> AnyGenerator<UnsafePointer<Element>> {
    var current = list.optional?.first.optional
    return AnyGenerator<UnsafePointer<Element>> {
        while current != nil && current?.data == nil { // while data is unavailable skip to next
            current = current?.next.optional
        }
        guard let cur = current else { return nil } // if iterator is nil, list is over, just finish
        defer { current = current?.next.optional } // after returning move current to next
        return UnsafePointer<Element>(cur.data) // return current data as Element (unsafe: type cannot be checked because of C)
    }
}

private func listGenerator<Element>(unsafeList list: UnsafePointer<clist>, of: Element.Type) -> AnyGenerator<Element> {
    let gen = pointerListGenerator(unsafeList: list, of: of)
    return AnyGenerator {
        return gen.next()?.memory
    }
}

private func arrayGenerator<Element>(unsafeArray array: UnsafePointer<carray>, of: Element.Type) -> AnyGenerator<Element> {
    var idx: UInt32 = 0
    let len = carray_count(array)
    return AnyGenerator {
        guard idx < len else { return nil }
        defer { idx = idx + 1 }
        return UnsafePointer<Element>(carray_get(array, idx)).memory
    }
}

func sequence<Element>(unsafeList: UnsafePointer<clist>, of: Element.Type) -> AnySequence<Element> {
    return AnySequence { return listGenerator(unsafeList: unsafeList, of: of) }
}

func pointerSequence<Element>(unsafeList: UnsafePointer<clist>, of: Element.Type) -> AnySequence<UnsafePointer<Element>> {
    return AnySequence { return pointerListGenerator(unsafeList: unsafeList, of: of) }
}

func sequence<Element>(unsafeArray: UnsafePointer<carray>, of: Element.Type) -> AnySequence<Element> {
    return AnySequence { return arrayGenerator(unsafeArray: unsafeArray, of: of) }
}

// MARK: Dates

extension NSDate {
    var unreleasedMailimapDate: UnsafeMutablePointer<mailimap_date> {
        guard let calendar = NSCalendar(identifier: NSCalendarIdentifierGregorian) else { return nil }
        let components = calendar.components([ .Year, .Month, .Day ], fromDate: self)
        
        return mailimap_date_new(Int32(components.day), Int32(components.month), Int32(components.year))
    }
}

extension mailimf_date_time {
    var date: NSDate? {
        let dateComponent = NSDateComponents()
        dateComponent.calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)
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
        dateComponent.timeZone = NSTimeZone(forSecondsFromGMT: zoneHour * 3600 + zoneMin * 60)
        
        return dateComponent.date
    }
}

extension mailimap_date_time {
    var date: NSDate? {
        let dateComponent = NSDateComponents()
        dateComponent.calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)
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
        dateComponent.timeZone = NSTimeZone(forSecondsFromGMT: zoneHour * 3600 + zoneMin * 60)
        
        return dateComponent.date
    }
}
