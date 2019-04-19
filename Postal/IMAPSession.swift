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

import Swift
import libetpan

private typealias Progress = @convention(c) (Int, Int, UnsafeMutableRawPointer?) -> Void

public typealias ProgressHandler = (_ current: Int, _ maximum: Int) -> ()

final class IMAPSession {
    let configuration: Configuration
    let imap: UnsafeMutablePointer<mailimap>
    
    private(set) var capabilities: IMAPCapability = []
    private(set) var defaultNamespace: IMAPNamespace? = nil
    private var serverIdentity = IMAPIdentity([:])
    
    private var selectedFolder: String = ""
    
    var logger: Logger? {
        didSet {
            if logger != nil {
                mailimap_set_logger(imap, _logger, Unmanaged.passRetained(self).toOpaque())
            } else {
                mailimap_set_logger(imap, nil, nil)
            }
        }
    }
    
    fileprivate let _logger: IMAPLogger = { (_: UnsafeMutablePointer<mailimap>?, logType: Int32, buffer: UnsafePointer<CChar>?, size: Int, context: UnsafeMutableRawPointer?) in
        guard
            size > 0,
            let context = context,
            let logType = ConnectionLogType(rawType: logType),
            let buffer = buffer
        else { return }

        let session = Unmanaged<IMAPSession>.fromOpaque(context).takeUnretainedValue()
        
        let data = Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: buffer), count: size, deallocator: .none)

        if let str = String(data: data, encoding: .utf8), !str.isEmpty {
            session.logger?("\(logType): \(str)")
        } else {
            session.logger?("\(logType)")
        }
    }
    
    init(configuration: Configuration) {
        self.imap = mailimap_new(0, nil)
        self.configuration = configuration
        
        // We need to give the progress callbacks to stream values to end user.
        let _bodyProgress: Progress = { _,_,_  in }
        let _itemsProgress: Progress = { _,_,_  in }
        mailimap_set_progress_callback(imap, _bodyProgress, _itemsProgress, nil)
    }
    
    deinit {
        if let stream = imap.pointee.imap_stream {
            mailstream_close(stream)
            imap.pointee.imap_stream = nil
        }
        mailimap_free(imap)
    }
    
    func connect(timeout: TimeInterval) throws {
        mailimap_set_timeout(imap, Int(timeout))
        
        let voipEnabled = true
        switch configuration.connectionType {
        case .startTLS:
            try mailimap_socket_connect_voip(imap, configuration.hostname, configuration.port, voipEnabled.int32Value).toIMAPError?.check()
            try mailimap_socket_starttls(imap).toIMAPError?.check()

        case .tls:
            try mailimap_ssl_connect_voip(imap, configuration.hostname, configuration.port, voipEnabled.int32Value).toIMAPError?.check()
            try checkCertificateIfNeeded()
        
        case .clear:
            try mailimap_socket_connect_voip(imap, configuration.hostname, configuration.port, voipEnabled.int32Value).toIMAPError?.check()
        }
        
        let low = mailstream_get_low(imap.pointee.imap_stream)
        let identifier = "\(configuration.login)@\(configuration.hostname):\(configuration.port)"
        mailstream_low_set_identifier(low, identifier.unreleasedUTF8CString)
        
        try checkCapabilities()
    }
    
    func checkCapabilities() throws {
        let caps = imap.pointee.imap_connection_info?.pointee.imap_capability?.pointee
        
        if caps == nil { // if capabilities are not found
            // fetch capabilities on imap
            var capabilityData: UnsafeMutablePointer<mailimap_capability_data>? = nil

            try mailimap_capability(imap, &capabilityData).toIMAPError?.check()
            mailimap_capability_data_free(capabilityData)
        }
        
        storeCapabilities()
    }
    
    func storeCapabilities() {
        typealias Check = (UnsafeMutablePointer<mailimap>) -> Int32
        typealias CheckAndCap = (check: Check, cap: IMAPCapability)
        
        let checks: [CheckAndCap] = [
            ({ mailimap_has_extension($0, "STARTTLS") }, .StartTLS),
            ({ mailimap_has_authentication($0, "PLAIN") }, .AuthPlain),
            ({ mailimap_has_authentication($0, "LOGIN") }, .AuthLogin),
            (mailimap_has_idle, .Idle),
            (mailimap_has_id, .Id),
            (mailimap_has_xlist, .XList),
            ({ mailimap_has_extension($0, "X-GM-EXT-1") }, .Gmail),
            (mailimap_has_condstore, .Condstore),
            (mailimap_has_qresync, .QResync),
            (mailimap_has_xoauth2, .XOAuth2),
            (mailimap_has_namespace, .Namespace),
            (mailimap_has_compress_deflate, .CompressDeflate),
            ({ mailimap_has_extension($0, "CHILDREN") }, .Children),
            ({ mailimap_has_extension($0, "MOVE") }, .Move),
            ({ mailimap_has_extension($0, "XYMHIGHESTMODSEQ") }, .XYMHighestModseq),
            ({ mailimap_has_extension($0, "LITERAL+") }, .LiteralPlus)
        ]
        
        capabilities = checks.reduce([]) { (memo: IMAPCapability, checkAndCap: CheckAndCap) -> IMAPCapability in
            return checkAndCap.check(imap).boolValue ? memo.union(checkAndCap.cap) : memo
        }
    }
    
    func login() throws {
        selectedFolder = "" // reset selected folder on login
        // TODO: maybe create a reset method and find the best time to call it
        let result: Int32
        
        switch configuration.password {
        case .accessToken(let accessToken):
            result = mailimap_oauth2_authenticate(imap, configuration.login, accessToken)
        case .plain(let password):
            result = mailimap_login(imap, configuration.login, password)
        }
        
        try result.toIMAPError?.enrich { return .login(description: String(cString: imap.pointee.imap_response)) }.check()
        
        try checkCapabilities()
    }
    
    func configure() throws {
        try configureNamespace()
        try configureIdentity()
    }
    
    func configureNamespace() throws {
        defaultNamespace = nil
        
        if capabilities.contains(.Namespace) {
            // fetch namespace
            var namespaceData: UnsafeMutablePointer<mailimap_namespace_data>? = nil
            
            try mailimap_namespace(imap, &namespaceData).toIMAPError?.check()
            defer { mailimap_namespace_data_free(namespaceData) }
            if let otherList = namespaceData?.pointee.ns_personal?.pointee.ns_data_list { // have a personal namespace ?
                let nsItems = sequence(otherList, of: mailimap_namespace_info.self)
                    .compactMap(IMAPNamespaceItem.init)
                defaultNamespace = IMAPNamespace(items: nsItems)
            }
        }
        
        if defaultNamespace == nil {
            var list: UnsafeMutablePointer<clist>? = nil
            try mailimap_list(imap, "", "", &list).toIMAPError?.check()
            defer { mailimap_list_result_free(list) }
            
            guard let actualList = list else { return }
            
            let initialFolders = makeFolders(sequence(actualList, of: mailimap_mailbox_list.self))
            
            guard let initialFolder = initialFolders.first else { throw IMAPError.login(description: "").asPostalError }
            
            defaultNamespace = IMAPNamespace(items: [ IMAPNamespaceItem(prefix: "", delimiter: initialFolder.delimiter) ])
        }
    }
    
    @discardableResult func select(_ folder: String) throws -> IMAPFolderInfo {
        if folder != selectedFolder {
            try mailimap_select(imap, folder).toIMAPError?.check()
        }
        
        guard let info = imap.pointee.imap_selection_info?.pointee else { throw IMAPError.nonExistantFolder.asPostalError }
        
        // store last selected folder
        selectedFolder = folder
        return IMAPFolderInfo(selectionInfo: info)
    }
    
    func configureIdentity() throws {
        guard capabilities.contains(.Id) else { return }
        
        var serverId: UnsafeMutablePointer<mailimap_id_params_list>? = nil
        try mailimap_id(imap, nil, &serverId).toIMAPError?.check()
        defer { mailimap_id_params_list_free(serverId) }
        
        guard let list = serverId?.pointee.idpa_list else { return }
        
        var dic = [String:String]()
        sequence(list, of: mailimap_id_param.self)
            .compactMap { (param: mailimap_id_param) -> (String, String)? in
                guard let key = String.fromUTF8CString(param.idpa_name) else { return nil }
                guard let value = String.fromUTF8CString(param.idpa_value) else { return nil }
                return (key, value)
            }.forEach { dic[$0] = $1 }
        
        serverIdentity = IMAPIdentity(dic)
    }
    
    fileprivate func checkCertificateIfNeeded() throws{
        guard configuration.checkCertificateEnabled else { return }
        guard checkCertificate(imap.pointee.imap_stream, hostname: configuration.hostname) else { throw IMAPError.certificate.asPostalError }
    }
}
