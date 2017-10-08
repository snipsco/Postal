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

/// The representation of the credential of the user
public enum PasswordType {
    /// Classic password
    case plain(String)
    /// OAuth2 token
    case accessToken(String)
}

/// The connection type on the server
public enum ConnectionType {
    /// Communication not encryptet
    case clear
    /// Encrypted communication
    case tls
    /// Take an existing insecure connection and upgrade it to a secure one.
    case startTLS
}

/// The configuration of the connection
public struct Configuration {
    /// The hostname of the IMAP server
    public let hostname: String
    /// The port of the IMAP server
    public let port: UInt16
    /// The login name
    public let login: String
    /// The password or the token of the connection
    public let password: PasswordType
    /// The connection type (secured or not)
    public let connectionType: ConnectionType
    /// Check if the certificate is enabled
    public let checkCertificateEnabled: Bool
    /// The batch size of heavy requests
    public let batchSize: Int
    /// The spam folder name
    public let spamFolderName: String
    
    /// Initialize a new configuration
    public init(hostname: String,
         port: UInt16,
         login: String,
         password: PasswordType,
         connectionType: ConnectionType,
         checkCertificateEnabled: Bool,
         batchSize: Int = Int.max,
         spamFolderName: String = "Junk") {
        self.hostname = hostname
        self.port = port
        self.login = login
        self.password = password
        self.connectionType = connectionType
        self.checkCertificateEnabled = checkCertificateEnabled
        self.batchSize = batchSize
        self.spamFolderName = spamFolderName
    }
}

extension Configuration {
    /// Retrieve pre-configured configuration for Gmail.
    ///
    /// - parameters:
    ///     - login: The login of the user.
    ///     - password: The credential of the connection.
    public static func gmail(login: String, password: PasswordType) -> Configuration {
        return Configuration(
            hostname: "imap.gmail.com",
            port: 993,
            login: login,
            password: password,
            connectionType: .tls,
            checkCertificateEnabled: true,
            batchSize: 1000,
            spamFolderName: "$Phishing")
    }
}

extension Configuration {
    /// Retrieve pre-configured configuration for Yahoo.
    ///
    /// - parameters:
    ///     - login: The login of the user.
    ///     - password: The credential of the connection.
    public static func yahoo(login: String, password: PasswordType) -> Configuration {
        return Configuration(
            hostname: "imap.mail.yahoo.com",
            port: 993,
            login: login,
            password: password,
            connectionType: .tls,
            checkCertificateEnabled: true,
            batchSize: 1000,
            spamFolderName: "$Junk")
    }
}

extension Configuration {
    /// Retrieve pre-configured configuration for iCloud.
    ///
    /// - parameters:
    ///     - login: The login of the user.
    ///     - password: The credential of the connection.
    public static func icloud(login: String, password: String) -> Configuration {
        return Configuration(
            hostname: "imap.mail.me.com",
            port: 993,
            login: login,
            password: .plain(password),
            connectionType: .tls,
            checkCertificateEnabled: true,
            batchSize: 500,
            spamFolderName: "Junk")
    }
}

extension Configuration {
    /// Retrieve pre-configured configuration for Outlook.
    ///
    /// - parameters:
    ///     - login: The login of the user.
    ///     - password: The credential of the connection.
    public static func outlook(login: String, password: String) -> Configuration {
        return Configuration(
            hostname: "imap-mail.outlook.com",
            port: 993,
            login: login,
            password: .plain(password),
            connectionType: .tls,
            checkCertificateEnabled: true,
            batchSize: 1000,
            spamFolderName: "Junk")
    }
}

extension Configuration {
    /// Retrieve pre-configured configuration for Aol.
    ///
    /// - parameters:
    ///     - login: The login of the user.
    ///     - password: The credential of the connection.
    public static func aol(login: String, password: String) -> Configuration {
        return Configuration(
            hostname: "imap.aol.com",
            port: 993,
            login: login,
            password: .plain(password),
            connectionType: .tls,
            checkCertificateEnabled: true,
            batchSize: 1000,
            spamFolderName: "Junk")
    }
}

extension Configuration: CustomStringConvertible {
    public var description: String {
        return "\(login)@\(hostname)"
    }
}
