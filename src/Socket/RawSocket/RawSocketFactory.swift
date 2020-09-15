import Foundation
import NetworkExtension

/**
 Represents the type of the socket.

 - NW:  The socket based on `NWTCPConnection`.
 - GCD: The socket based on `GCDAsyncSocket`.
 */
public enum SocketBaseType {
    case nw, gcd
}

/// Factory to create `RawTCPSocket` based on configuration.
open class RawSocketFactory {
    ///当前活动的NETunnelProvider，它创建NWTCPConnection实例。
    ///-注意：如果使用`NWTCPSocket`或`NWUDPSocket`，则必须在创建任何连接之前进行设置。
    public static weak var TunnelProvider: NETunnelProvider?

    /**
     返回`RawTCPSocket`实例。
     -参数类型：套接字的类型。
     -返回：创建的套接字实例。
     */
    public static func getRawSocket(_ type: SocketBaseType? = nil) -> RawTCPSocketProtocol {
        switch type {
        case .some(.nw):
            return NWTCPSocket()
        case .some(.gcd):
            return GCDTCPSocket()
        case nil:
            if RawSocketFactory.TunnelProvider == nil {
                return GCDTCPSocket()
            } else {
                return NWTCPSocket()
            }
        }
    }
}
