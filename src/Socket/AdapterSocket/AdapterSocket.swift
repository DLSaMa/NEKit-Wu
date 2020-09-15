import Foundation

open class AdapterSocket: NSObject {
    
    open var session: ConnectSession!
    open var observer: Observer<AdapterSocketEvent>?

    open override var description: String {
        return "<\(typeName) host:\(session.host) port:\(session.port))>"
    }

    internal var _cancelled = false
    public var isCancelled: Bool {
        return _cancelled
    }

    /**
     根据`ConnectSession`连接到远程。
     - parameter session: The connect session.
     */
    open func openSocketWith(session: ConnectSession) {
        guard !isCancelled else { return }

        self.session = session
        observer?.signal(.socketOpened(self, withSession: session))
        socket?.delegate = self
        _status = .connecting
    }

    deinit {
        socket?.delegate = nil
    }
    
   

    public init(observe: Bool = true) {
        super.init()
        if observe {
            observer = ObserverFactory.currentFactory?.getObserverForAdapterSocket(self)
        }
    }

  

   
}

// MARK: SocketProtocol  Implementation
extension AdapterSocket: SocketProtocol{
   
    // MARK: SocketProtocol Implementation
       /// The underlying TCP socket transmitting data.
       open var socket: RawTCPSocketProtocol!
       /// The delegate instance.
       weak open var delegate: SocketDelegate?

       var _status: SocketStatus = .invalid
       /// The current connection status of the socket.
       public var status: SocketStatus {
           return _status
       }

       open var statusDescription: String {
           return "\(status)"
       }
    
    /**
   从套接字读取数据。
       -警告：仅应在最后一次读取完成后调用，即调用`delegate？.didReadData（）`。
       */
      open func readData() {
          guard !isCancelled else {
              return
          }
          socket?.readData()
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
          socket?.write(data: data)
      }

      /**
       优雅地断开插座。
       */
      open func disconnect(becauseOf error: Error? = nil) {
          _status = .disconnecting
          _cancelled = true
          session.disconnected(becauseOf: error, by: .adapter)
          observer?.signal(.disconnectCalled(self))
          socket?.disconnect()
      }

      /**
       Disconnect the socket immediately.
       */
      open func forceDisconnect(becauseOf error: Error? = nil) {
          _status = .disconnecting
          _cancelled = true
          session.disconnected(becauseOf: error, by: .adapter)
          observer?.signal(.forceDisconnectCalled(self))
          socket?.forceDisconnect()
      }
}

// MARK: RawTCPSocketDelegate Protocol Implementation
extension AdapterSocket:RawTCPSocketDelegate{
   
       /**
        The socket did disconnect.

        - parameter socket: The socket which did disconnect.
        */
       open func didDisconnectWith(socket: RawTCPSocketProtocol) {
           _status = .closed
           observer?.signal(.disconnected(self))
           delegate?.didDisconnectWith(socket: self)
       }

       /**
        The socket did read some data.

        - parameter data:    The data read from the socket.
        - parameter from:    The socket where the data is read from.
        */
       open func didRead(data: Data, from: RawTCPSocketProtocol) {
           observer?.signal(.readData(data, on: self))
       }

       /**
        The socket did send some data.

        - parameter data:    The data which have been sent to remote (acknowledged). Note this may not be available since the data may be released to save memory.
        - parameter by:    The socket where the data is sent out.
        */
       open func didWrite(data: Data?, by: RawTCPSocketProtocol) {
           observer?.signal(.wroteData(data, on: self))
       }

       /**
        The socket did connect to remote.

        - parameter socket: The connected socket.
        */
       open func didConnectWith(socket: RawTCPSocketProtocol) {
           _status = .established
           observer?.signal(.connected(self))
           delegate?.didConnectWith(adapterSocket: self)
       }
}
