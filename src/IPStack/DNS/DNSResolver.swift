import Foundation


public protocol DNSResolverDelegate: class {
    func didReceive(rawResponse: Data)
}

public protocol DNSResolverProtocol: class {
    var delegate: DNSResolverDelegate? { get set }
    func resolve(session: DNSSession)
    func stop()
}

open class UDPDNSResolver: DNSResolverProtocol {
    let socket: NWUDPSocket
    public weak var delegate: DNSResolverDelegate?
// 配置dns的地址 114.114.114.114 端口 53
    public init(address: IPAddress, port: Port) {
        socket = NWUDPSocket(host: address.presentation, port: Int(port.value))!
        socket.delegate = self
    }

    public func resolve(session: DNSSession) {
        socket.write(data: session.requestMessage.payload)
    }

    public func stop() {
        socket.disconnect()
    }

}

extension UDPDNSResolver:NWUDPSocketDelegate{
    public func didReceive(data: Data, from: NWUDPSocket) {
        delegate?.didReceive(rawResponse: data)
    }
    
    public func didCancel(socket: NWUDPSocket) {
        
    }
}
