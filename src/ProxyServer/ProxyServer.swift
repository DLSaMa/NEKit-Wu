import Foundation
import CocoaAsyncSocket
import Resolver

/**
 The base proxy server class.
 
 This proxy does not listen on any port.
 */
open class ProxyServer: NSObject, TunnelDelegate {
    typealias TunnelArray = [Tunnel]
    public let port: Port
    public let address: IPAddress?

    /// The type of the proxy server.
    ///
    ///
    public let type: String//可以将其设置为描述代理服务器的任何内容。

    /// The description of proxy server.
    open override var description: String {
        return "<\(type) address:\(String(describing: address)) port:\(port)>"
    }

    open var observer: Observer<ProxyServerEvent>?
    var tunnels: TunnelArray = []

    /**
     创建代理服务器的实例。
     
     -参数地址：代理服务器的地址。
     -参数端口：代理服务器的端口。
     -警告：如果使用网络扩展，则必须设置地址，否则可能无法连接到代理服务器。
     */
    public init(address: IPAddress?, port: Port) {
        self.address = address
        self.port = port
        type = "\(Swift.type(of: self))"

        super.init()

        self.observer = ObserverFactory.currentFactory?.getObserverForProxyServer(self)
    }

    /**
     Start the proxy server.
     
     - throws: 启动代理服务器时发生错误。
     */
    open func start() throws {
        QueueFactory.executeOnQueueSynchronizedly {
            GlobalIntializer.initalize()
            self.observer?.signal(.started(self))
        }
    }

    /**
     Stop the proxy server.
     */
    open func stop() {
        QueueFactory.executeOnQueueSynchronizedly {
            for tunnel in tunnels {
                tunnel.forceClose()
            }

            observer?.signal(.stopped(self))
        }
    }

    /**
     Delegate method when the proxy server accepts a new ProxySocket from local.
     
     实施具体的代理服务器（例如HTTP代理服务器）时，服务器应在某个端口上侦听，然后将原始套接字包装在相应的ProxySocket子类中，然后调用此方法。
     
     - parameter socket: The accepted proxy socket.
     */
    func didAcceptNewSocket(_ socket: ProxySocket) {
        observer?.signal(.newSocketAccepted(socket, onServer: self))
        let tunnel = Tunnel(proxySocket: socket)
        tunnel.delegate = self
        tunnels.append(tunnel)
        tunnel.openTunnel()
    }

    // MARK: TunnelDelegate implementation

    /**
     Delegate method when a tunnel closed. The server will remote it internally.
     
     - parameter tunnel: The closed tunnel.
     */
    func tunnelDidClose(_ tunnel: Tunnel) {
        observer?.signal(.tunnelClosed(tunnel, onServer: self))
        guard let index = tunnels.firstIndex(of: tunnel) else {
            // things went strange
            return
        }

        tunnels.remove(at: index)
    }
}
