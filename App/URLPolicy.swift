import Foundation

enum AddressError: LocalizedError {
    case invalid, unsupportedScheme, credentials, rootRequired, insecureRemote

    var errorDescription: String? {
        switch self {
        case .invalid: return "请输入有效的 Raft 网页地址。"
        case .unsupportedScheme: return "服务器地址需要使用 HTTPS。"
        case .credentials: return "地址不能包含用户名或密码，请在网页中登录。"
        case .rootRequired: return "请填写部署根地址，例如 https://raft.example.com，不含频道路径或查询参数。"
        case .insecureRemote: return "远程服务器需要 HTTPS；HTTP 仅用于本地开发连接。"
        }
    }
}

enum URLPolicy {
    static func normalize(_ input: String) throws -> URL {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(where: { $0.isWhitespace }) else { throw AddressError.invalid }
        // A explicit non-network scheme must not be mistaken for a bare hostname.
        let explicitScheme = text.range(of: #"^[A-Za-z][A-Za-z0-9+.-]*:"#, options: .regularExpression)
        let hostWithPort = text.range(of: #"^[A-Za-z0-9.-]+:[0-9]+/?$"#, options: .regularExpression)
        let candidate = (explicitScheme != nil && hostWithPort == nil) ? text : "https://" + text
        guard var parts = URLComponents(string: candidate),
              let rawScheme = parts.scheme, let host = parts.host, !host.isEmpty,
              parts.url != nil else { throw AddressError.invalid }
        let scheme = rawScheme.lowercased()
        guard scheme == "https" || scheme == "http" else { throw AddressError.unsupportedScheme }
        guard parts.user == nil, parts.password == nil else { throw AddressError.credentials }
        guard (parts.path.isEmpty || parts.path == "/"), parts.query == nil, parts.fragment == nil else {
            throw AddressError.rootRequired
        }
        if let port = parts.port, !(1...65535).contains(port) { throw AddressError.invalid }
        if scheme == "http", !isLocalHost(host) { throw AddressError.insecureRemote }
        parts.scheme = scheme
        parts.host = host.lowercased()
        parts.path = ""
        if (scheme == "https" && parts.port == 443) || (scheme == "http" && parts.port == 80) { parts.port = nil }
        guard let url = parts.url else { throw AddressError.invalid }
        return url
    }

    static func isLocalHost(_ raw: String) -> Bool {
        let host = raw.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if host == "localhost" || host.hasSuffix(".localhost") || host.hasSuffix(".local") || host == "::1" { return true }
        if host.contains(":") { return host.hasPrefix("fc") || host.hasPrefix("fd") || host.hasPrefix("fe80:") }
        let components = host.split(separator: ".", omittingEmptySubsequences: false)
        let bytes = components.compactMap { UInt8($0) }
        if components.count == 4 && bytes.count == 4 {
            return bytes[0] == 127 || bytes[0] == 10 || (bytes[0] == 192 && bytes[1] == 168)
                || (bytes[0] == 172 && (16...31).contains(bytes[1])) || (bytes[0] == 169 && bytes[1] == 254)
        }
        // Bonjour/unqualified machine names; reject malformed dotted IPs.
        return !host.contains(".") && !host.isEmpty && host.contains(where: { $0.isLetter })
    }

    static func sameOrigin(_ first: URL, _ second: URL) -> Bool {
        func effectivePort(_ url: URL) -> Int? { url.port ?? (url.scheme?.lowercased() == "https" ? 443 : 80) }
        return first.scheme?.lowercased() == second.scheme?.lowercased()
            && first.host?.lowercased() == second.host?.lowercased() && effectivePort(first) == effectivePort(second)
    }

    static func restorablePath(_ url: URL, base: URL) -> String? {
        guard sameOrigin(url, base), url.query == nil, url.fragment == nil else { return nil }
        let path = url.path.isEmpty ? "/" : url.path
        let lower = path.lowercased()
        guard !lower.hasPrefix("/auth"), !lower.contains("callback"), !lower.contains("invite"),
              !lower.contains("reset-password"), !lower.contains("verify"),
              !path.hasPrefix("//"), !path.contains("\\") else { return nil }
        return path
    }
}
