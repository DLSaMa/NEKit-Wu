import Foundation

///该适配器直接连接到远程
public class DirectAdapter: AdapterSocket {
    /// 如果将其设置为“ false”，则系统将解析IP地址。
    var resolveHost = false
    /** 根据`ConnectSession`连接到远程。
     - parameter session: The connect session.
     */
    override public func openSocketWith(session: ConnectSession) {
        super.openSocketWith(session: session)
        guard !isCancelled else { return}
        do {
            try socket.connectTo(host: session.host, port: Int(session.port), enableTLS: false, tlsSettings: nil)
        } catch let error {
            observer?.signal(.errorOccured(error, on: self))
            disconnect()
        }
    }


}

extension DirectAdapter:RawTCPSocketDelegate{
    /**
     The socket did connect to remote.

     - parameter socket: The connected socket.
     */
    override public func didConnectWith(socket: RawTCPSocketProtocol) {
        super.didConnectWith(socket: socket)
        observer?.signal(.readyForForward(self))
        delegate?.didBecomeReadyToForwardWith(socket: self)
    }

    override public func didRead(data: Data, from rawSocket: RawTCPSocketProtocol) {
        super.didRead(data: data, from: rawSocket)
        delegate?.didRead(data: data, from: self)
    }

    override public func didWrite(data: Data?, by rawSocket: RawTCPSocketProtocol) {
        super.didWrite(data: data, by: rawSocket)
        delegate?.didWrite(data: data, by: self)
    }
}
