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
import Security

func checkCertificate(stream: UnsafeMutablePointer<mailstream>, hostname: String) -> Bool {
    var cCerts = mailstream_get_certificate_chain(stream)
    defer { mailstream_certificate_chain_free(cCerts) }
    guard cCerts.optional != nil else {
        print("warning: No certificate chain retrieved")
        return false
    }
    
    let certificates = sequence(cCerts, of: MMAPString.self)
        .map { CFDataCreate(nil, UnsafePointer($0.str), $0.len) }
        .flatMap { SecCertificateCreateWithData(nil, $0) }
    
    let policy = SecPolicyCreateSSL(true, hostname)
    var trustCallback: SecTrust?
    guard noErr == SecTrustCreateWithCertificates(certificates, policy, &trustCallback) else { return false }
    guard let trust = trustCallback else { return false }
    
    #if swift(>=2.3)
        var trustResult: SecTrustResultType = .Invalid
        guard noErr == SecTrustEvaluate(trust, &trustResult) else { return false }
        switch trustResult {
        case .Unspecified, .Proceed: return true
        default: return false
        }
    #else
        var trustResult: SecTrustResultType = UInt32(kSecTrustResultInvalid)
        guard noErr == SecTrustEvaluate(trust, &trustResult) else { return false }
        
        switch Int(trustResult) {
        case kSecTrustResultUnspecified, kSecTrustResultProceed: return true
        default: return false
        }
    #endif
}
