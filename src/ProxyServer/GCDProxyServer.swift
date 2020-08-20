import Foundation
import CocoaAsyncSocket

/// Proxy server which listens on some port by GCDAsyncSocket.
///
/// This shoule be the base class for any concrete implementation of proxy server (e.g., HTTP or SOCKS5) which needs to listen on some port.
open class GCDProxyServer: ProxyServer, GCDAsyncSocketDelegate {
    fileprivate var listenSocket: GCDAsyncSocket!

    /**
    启动代理服务器，该服务器创建在特定端口上侦听的GCDAsyncSocket。
     
     - throws: The error occured when starting the proxy server.
     */
    override open func start() throws {
        try QueueFactory.executeOnQueueSynchronizedly { //在同步队列 创建
            listenSocket = GCDAsyncSocket(delegate: self, delegateQueue: QueueFactory.getQueue(), socketQueue: QueueFactory.getQueue())
            try listenSocket.accept(onInterface: address?.presentation, port: port.value)
            try super.start()
        }
    }

    /**
     Stop the proxy server.
     */
    override open func stop() {
        QueueFactory.executeOnQueueSynchronizedly { //同步度列关闭
            listenSocket?.setDelegate(nil, delegateQueue: nil)
            listenSocket?.disconnect()
            listenSocket = nil
            super.stop()
        }
    }

    /**
     处理新接受的GCDTCPSocket的委托方法。
     在使用GCDAsyncSocket侦听某些端口的代理服务器的任何具体实现中，仅应覆盖此方法。
     - parameter socket: The accepted socket.
     */
    open func handleNewGCDSocket(_ socket: GCDTCPSocket) {

    }

    /**
     GCDAsyncSocket delegate callback.
     
     - parameter sock:      The listening GCDAsyncSocket.
     - parameter newSocket: The accepted new GCDAsyncSocket.
     
     - warning: Do not call this method. This should be marked private but have to be marked public since the `GCDAsyncSocketDelegate` is public.
     */
    open func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        let gcdTCPSocket = GCDTCPSocket(socket: newSocket) // 先创建GCDTCPSocket
        handleNewGCDSocket(gcdTCPSocket)
    }

    public func newSocketQueueForConnection(fromAddress address: Data, on sock: GCDAsyncSocket) -> DispatchQueue? {
        return QueueFactory.getQueue()
    }
}
