import Foundation

/// 封装逻辑的socket，用于处理与代理的连接。
open class ProxySocket: NSObject, SocketProtocol, RawTCPSocketDelegate {
    /// Received `ConnectSession`.
    public var session: ConnectSession?

    public var observer: Observer<ProxySocketEvent>?

    private var _cancelled = false
    var isCancelled: Bool {
        return _cancelled
    }

    open override var description: String {
        if let session = session {
            return "<\(typeName) host:\(session.host) port: \(session.port))>"
        } else {
            return "<\(typeName)>"
        }
    }

    /**
     Init a `ProxySocket` with a raw TCP socket.

     - parameter socket: The raw TCP socket.
     */
    public init(socket: RawTCPSocketProtocol, observe: Bool = true) {
        self.socket = socket //来自协议的属性 ，socket
        super.init()
        self.socket.delegate = self
        if observe {
            observer = ObserverFactory.currentFactory?.getObserverForProxySocket(self)
        }
    }

    /**
     Begin reading and processing data from the socket.
     */
    open func openSocket() {
        guard !isCancelled else {
            return
        }

        observer?.signal(.socketOpened(self))
    }

    /**
    对已成功连接到远程服务器的“隧道”另一侧的“ AdapterSocket”的响应。
     参数适配器：AdapterSocket。
     */
    open func respondTo(adapter: AdapterSocket) {
        guard !isCancelled else {
            return
        }

        observer?.signal(.askedToResponseTo(adapter, on: self))
    }

    /**
     Read data from the socket.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    open func readData() {
        guard !isCancelled else {
            return
        }

        socket.readData()
    }

    /**
     Send data to remote.

     - parameter data: Data to send.
     - warning: This should only be called after the last write is finished, i.e., `delegate?.didWriteData()` is called.
     */
    open func write(data: Data) {
        guard !isCancelled else {
            return
        }

        socket.write(data: data)
    }

    /**
     Disconnect the socket elegantly.
     */
    open func disconnect(becauseOf error: Error? = nil) {
        guard !isCancelled else {
            return
        }

        _status = .disconnecting
        _cancelled = true
        session?.disconnected(becauseOf: error, by: .proxy)
        socket.disconnect()
        observer?.signal(.disconnectCalled(self))
    }

    /**
     Disconnect the socket immediately.
     */
    open func forceDisconnect(becauseOf error: Error? = nil) {
        guard !isCancelled else {
            return
        }

        _status = .disconnecting
        _cancelled = true
        session?.disconnected(becauseOf: error, by: .proxy)
        socket.forceDisconnect()
        observer?.signal(.forceDisconnectCalled(self))
    }

    // MARK: SocketProtocol 实现

    public var socket: RawTCPSocketProtocol!///底层的TCPsocket传输数据。
    weak public var delegate: SocketDelegate?///委托实例。
    var _status: SocketStatus = .established
    public var status: SocketStatus {///socket的当前连接状态。
        return _status
    }

    // MARK: RawTCPSocketDelegate 实现  

    open func didDisconnectWith(socket: RawTCPSocketProtocol) {
        _status = .closed
        observer?.signal(.disconnected(self))
        delegate?.didDisconnectWith(socket: self)  //其delegate  (SocketDelegate) 是Tunnel
    }

    open func didRead(data: Data, from: RawTCPSocketProtocol) {
        observer?.signal(.readData(data, on: self))
    }

    open func didWrite(data: Data?, by: RawTCPSocketProtocol) {
        observer?.signal(.wroteData(data, on: self))
    }

    open func didConnectWith(socket: RawTCPSocketProtocol) {

    }

}
