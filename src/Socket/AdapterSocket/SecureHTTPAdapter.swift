import Foundation

/// This adapter connects to remote host through a HTTP proxy with SSL.  该适配器通过具有SSL的HTTP代理连接到远程主机。
public class SecureHTTPAdapter: HTTPAdapter {
    override public init(serverHost: String, serverPort: Int, auth: HTTPAuthentication?) {
        super.init(serverHost: serverHost, serverPort: serverPort, auth: auth)
        secured = true
    }
}
