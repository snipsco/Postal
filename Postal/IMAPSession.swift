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

import Swift
import libetpan

private typealias Progress = @convention(c) (Int, Int, UnsafeMutablePointer<Void>) -> Void

public typealias ProgressHandler = (current: Int, maximum: Int) -> ()

final class IMAPSession {
    let configuration: Configuration
    let imap: UnsafeMutablePointer<mailimap>
    
    private(set) var capabilities: IMAPCapability = []
    private var defaultNamespace: IMAPNamespace? = nil
    private var serverIdentity = IMAPIdentity([:])
    
    private var selectedFolder: String = ""
    
    var logger: Logger? {
        didSet {
            if logger != nil {
                mailimap_set_logger(imap, _logger, UnsafeMutablePointer(Unmanaged.passRetained(self).toOpaque()))
            } else {
                mailimap_set_logger(imap, nil, nil)
            }
        }
    }
    
    private let _logger: IMAPLogger = { (_: UnsafeMutablePointer<mailimap>, logType: Int32, buffer: UnsafePointer<Int8>, size: Int, context: UnsafeMutablePointer<Void>) in
        guard let logType = ConnectionLogType(rawType: logType) else { return }
        guard size > 0 else { return }

        let session = Unmanaged<IMAPSession>.fromOpaque(COpaquePointer(context)).takeUnretainedValue()//.takeRetainedValue()

        if let str = String(data: NSData(bytes: buffer, length: size - 1), encoding: NSUTF8StringEncoding) where !str.isEmpty {
            session.logger?("\(logType): \(str)")
        } else {
            session.logger?("\(logType)")
        }
    }
    
    init(configuration: Configuration) {
        self.imap = mailimap_new(0, nil)
        self.configuration = configuration
        
        // We need to give the progress callbacks to stream values to end user.
        let _bodyProgress: Progress = { _ in }
        let _itemsProgress: Progress = { _ in }
        mailimap_set_progress_callback(imap, _bodyProgress, _itemsProgress, nil)
    }
    
    deinit {
        if let stream = imap.optional?.imap_stream where stream != nil {
            mailstream_close(stream)
            imap.memory.imap_stream = nil
        }
        mailimap_free(imap)
    }
    
    func connect(timeout timeout: NSTimeInterval) throws {
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
        
        let low = mailstream_get_low(imap.memory.imap_stream)
        let identifier = "\(configuration.login)@\(configuration.hostname):\(configuration.port)"
        mailstream_low_set_identifier(low, identifier.unreleasedUTF8CString)
        
        if let welcome = String.fromCString(imap.memory.imap_response) {
            print("Welcome : \(welcome)")
        }
        
        try checkCapabilities()
    }
    
    func checkCapabilities() throws {
        let caps = imap.optional?.imap_connection_info.optional?.imap_capability.optional
        if caps == nil { // if capabilities are not found
            // fetch capabilities on imap
            var capabilityData = UnsafeMutablePointer<mailimap_capability_data>(nil)
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
        
        try result.toIMAPError?.enrich { return .loginError(String.fromCString(imap.memory.imap_response) ?? "") }.check()
        
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
            var namespaceData = UnsafeMutablePointer<mailimap_namespace_data>(nil)
            try mailimap_namespace(imap, &namespaceData).toIMAPError?.check()
            defer { mailimap_namespace_data_free(namespaceData) }
            if let otherList = namespaceData.optional?.ns_personal.optional?.ns_data_list { // have a personal namespace ?
                let nsItems = sequence(otherList, of: mailimap_namespace_info.self)
                    .flatMap(IMAPNamespaceItem.init)
                defaultNamespace = IMAPNamespace(items: nsItems)
            }
        }
        
        if defaultNamespace == nil {
            var list = UnsafeMutablePointer<clist>(nil)
            
            try mailimap_list(imap, "", "", &list).toIMAPError?.check()
            defer { mailimap_list_result_free(list) }
            
            let initialFolders = makeFolders(sequence(list, of: mailimap_mailbox_list.self))
            
            guard let initialFolder = initialFolders.first else { throw IMAPError.loginError("").asPostalError }
            
            defaultNamespace = IMAPNamespace(items: [ IMAPNamespaceItem(prefix: "", delimiter: initialFolder.delimiter) ])
        }
    }
    
    func listFolders() throws -> [Folder] {
        let prefix = defaultNamespace?.items.first?.prefix ?? MAIL_DIR_SEPARATOR_S
        var list: UnsafeMutablePointer<clist> = nil;
        if capabilities.contains(.XList) && !capabilities.contains(.Gmail) {
            // XLIST support is deprecated on Gmail. See https://developers.google.com/gmail/imap_extensions#xlist_is_deprecated
            try mailimap_xlist(imap, prefix, "*", &list).toIMAPError?.check()
        } else {
            try mailimap_list(imap, prefix, "*", &list).toIMAPError?.check()
        }
        defer { mailimap_list_result_free(list) }
        
        return makeFolders(sequence(list, of: mailimap_mailbox_list.self))
    }
    
    func select(folder: String) throws -> IMAPFolderInfo {
        if folder != selectedFolder {
            try mailimap_select(imap, folder).toIMAPError?.check()
        }
        
        guard let info = imap.optional?.imap_selection_info.optional else { throw IMAPError.nonExistantFolderError.asPostalError }
        
        // store last selected folder
        selectedFolder = folder
        return IMAPFolderInfo(selectionInfo: info)
    }
    
    private func makeFolders<S: SequenceType where S.Generator.Element == mailimap_mailbox_list>(sequence: S) -> [Folder] {
        return sequence.flatMap { (folder: mailimap_mailbox_list) -> Folder? in
            guard let name = String.fromCString(folder.mb_name) else { return nil }
            var mb_delimiter: [CChar] = [ folder.mb_delimiter, 0 ]
            guard let delimiter = String.fromCString(&mb_delimiter) else { return nil }
            return Folder(name: name, flags: FolderFlag(flags: folder.mb_flag), delimiter: delimiter)
        }
    }
    
    func configureIdentity() throws {
        guard capabilities.contains(.Id) else { return }
        
        var serverId: UnsafeMutablePointer<mailimap_id_params_list> = nil
        try mailimap_id(imap, nil, &serverId).toIMAPError?.check()
        defer { mailimap_id_params_list_free(serverId) }
        
        guard let list = serverId.optional?.idpa_list else { return }
        
        var dic = [String:String]()
        sequence(list, of: mailimap_id_param.self)
            .flatMap { (param: mailimap_id_param) -> (String, String)? in
                guard let key = String.fromCString(param.idpa_name) else { return nil }
                guard let value = String.fromCString(param.idpa_value) else { return nil }
                return (key, value)
            }.forEach { dic[$0] = $1 }
        
        serverIdentity = IMAPIdentity(dic)
    }
    
    private func checkCertificateIfNeeded() throws -> Bool {
        guard configuration.checkCertificateEnabled else { return true }
        guard checkCertificate(imap.memory.imap_stream, hostname: configuration.hostname) else { throw IMAPError.certificateError.asPostalError }
        return true
    }
}
