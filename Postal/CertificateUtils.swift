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
import Security

func checkCertificate(_ stream: UnsafeMutablePointer<mailstream>, hostname: String) -> Bool {
    let cCerts = mailstream_get_certificate_chain(stream)
    defer { mailstream_certificate_chain_free(cCerts) }
    guard let actualCCerts = cCerts else {
        print("warning: No certificate chain retrieved")
        return false
    }
    
    let certificates = sequence(actualCCerts, of: MMAPString.self)
        .map { mmapString in
            mmapString.str.withMemoryRebound(to: UInt8.self, capacity: 1, { CFDataCreate(nil, $0, mmapString.len) })
        }
        .compactMap { SecCertificateCreateWithData(nil, $0) }
    
    let policy = SecPolicyCreateSSL(true, hostname as CFString)
    var trustCallback: SecTrust?
    guard noErr == SecTrustCreateWithCertificates(certificates as CFTypeRef, policy, &trustCallback) else { return false }
    guard let trust = trustCallback else { return false }
    
    var trustResult: SecTrustResultType = .invalid
    guard noErr == SecTrustEvaluate(trust, &trustResult) else { return false }
    switch trustResult {
    case .unspecified, .proceed: return true
    default: return false
    }
}
