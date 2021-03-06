import Foundation
import CocoaLumberjackSwift

public enum IPVersion: UInt8 {
    case iPv4 = 4, iPv6 = 6
}

public enum TransportProtocol: UInt8 {
    case icmp = 1, tcp = 6, udp = 17
}

///处理和构建IP数据包的类。
///-注意：到目前为止，仅支持IPv4。
open class IPPacket {
    /**
   在不解析整个数据包的情况下获取IP数据包的版本。
     -参数数据：包含整个IP数据包的数据。
     -返回：数据包的版本。如果解析数据包失败，则返回“ nil”。
     */
    public static func peekIPVersion(_ data: Data) -> IPVersion? {
        guard data.count >= 20 else {
            return nil
        }

        let version = (data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count).pointee >> 4
        return IPVersion(rawValue: version)
    }

    /**
     在不解析整个数据包的情况下获取IP数据包的协议。
     -参数数据：包含整个IP数据包的数据。
     -返回：数据包的协议。如果解析数据包失败，则返回“ nil”。
     */
    public static func peekProtocol(_ data: Data) -> TransportProtocol? {
        guard data.count >= 20 else {
            return nil
        }

        return TransportProtocol(rawValue: (data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count).advanced(by: 9).pointee)
    }

    /**
     在不解析整个数据包的情况下获取IP数据包的源IP地址。
     -参数数据：包含整个IP数据包的数据。
     -返回：数据包的源IP地址。如果解析数据包失败，则返回“ nil”。
     */
    public static func peekSourceAddress(_ data: Data) -> IPAddress? {
        guard data.count >= 20 else {
            return nil
        }

        return IPAddress(fromBytesInNetworkOrder: (data as NSData).bytes.advanced(by: 12))
    }

    /**
     在不解析整个数据包的情况下获取IP数据包的目标IP地址。
     -参数数据：包含整个IP数据包的数据。
     -返回：数据包的目标IP地址。如果解析数据包失败，则返回“ nil”。
     */
    public static func peekDestinationAddress(_ data: Data) -> IPAddress? {
        guard data.count >= 20 else {
            return nil
        }

        return IPAddress(fromBytesInNetworkOrder: (data as NSData).bytes.advanced(by: 16))
    }

    /**
     获取IP数据包的源端口，而不解析整个数据包。
     -参数数据：包含整个IP数据包的数据。
     -返回：数据包的源IP地址。如果解析数据包失败，则返回“ nil”。
     -注意：仅TCP和UDP数据包具有端口字段。
     */
    public static func peekSourcePort(_ data: Data) -> Port? {
        guard let proto = peekProtocol(data) else {
            return nil
        }

        guard proto == .tcp || proto == .udp else {
            return nil
        }

        let headerLength = Int((data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count).pointee & 0x0F * 4)

        // Make sure there are bytes for source and destination bytes.
        guard data.count > headerLength + 4 else {
            return nil
        }

        return Port(bytesInNetworkOrder: (data as NSData).bytes.advanced(by: headerLength))
    }

    /**
     在不解析整个数据包的情况下获取IP数据包的目标端口。
     -参数数据：包含整个IP数据包的数据。
     -返回：数据包的目标IP地址。如果解析数据包失败，则返回“ nil”。
     -注意：仅TCP和UDP数据包具有端口字段。
     */
    public static func peekDestinationPort(_ data: Data) -> Port? {
        guard let proto = peekProtocol(data) else {
            return nil
        }

        guard proto == .tcp || proto == .udp else {
            return nil
        }

        let headerLength = Int((data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count).pointee & 0x0F * 4)

        // Make sure there are bytes for source and destination bytes.
        guard data.count > headerLength + 4 else {
            return nil
        }

        return Port(bytesInNetworkOrder: (data as NSData).bytes.advanced(by: headerLength + 2))
    }

    /// The version of the current IP packet.
    open var version: IPVersion = .iPv4

    /// The length of the IP packet header.
    open var headerLength: UInt8 = 20

    ///包含IP数据包的DSCP和ECN。
    ///-注意：由于我们无法使用NetworkExtension发送自定义IP数据包，因此这是无用的，只是被忽略了。
    open var tos: UInt8 = 0

    ///这应该是数据报的长度。
    ///由于NEPacketTunnelFlow已经为我们处理了此值，因此不会从标头中读取该值。
    open var totalLength: UInt16 {
        return UInt16(packetData.count)
    }

    ///当前数据包的标识。
    ///
    ///-注意：由于我们不支持片段，因此将忽略该片段，并且始终为零。
    ///-注意：从理论上讲，这应该是一个递增的数字。它可能会实现。
    var identification: UInt16 = 0

    ///当前数据包的偏移量。
        ///
        ///-注意：由于我们不支持片段，因此将忽略该片段，并且始终为零。
    var offset: UInt16 = 0

    /// TTL of the packet.
    var TTL: UInt8 = 64  //TTL通常表示包在被丢弃前最多能经过的路由器个数。当记数到0时，路由器决定丢弃该包，并发送一个ICMP报文给最初的发送者。

    /// 源ip.
    var sourceAddress: IPAddress!

    /// 目标ip
    var destinationAddress: IPAddress!

    /// 数据包的传输协议。
    var transportProtocol: TransportProtocol!

    ///解析器解析IP数据包中的有效负载。
    var protocolParser: TransportProtocolParserProtocol!

    ///代表数据包的数据。
    var packetData: Data!

    /**
     Initailize a new instance to build IP packet.
     */
    init() {}

    /**
     Initailize an `IPPacket` with data.
     
     - parameter packetData: 包含整个数据包的数据。
     */
    init?(packetData: Data) {
        // no need to validate the packet.无需验证数据包。

        self.packetData = packetData

        let scanner = BinaryDataScanner(data: packetData, littleEndian: false)//二进制扫描

        let vhl = scanner.readByte()!
        guard let v = IPVersion(rawValue: vhl >> 4) else {
            DDLogError("Got unknown ip packet version \(vhl >> 4)")//得到了未知的IP数据包版本
            return nil
        }
        version = v
        headerLength = vhl & 0x0F * 4

        guard packetData.count >= Int(headerLength) else {
            return nil
        }

        tos = scanner.readByte()!

        guard totalLength == scanner.read16()! else {
            DDLogError("Packet length mismatches from header.")
            return nil
        }

        identification = scanner.read16()!
        offset = scanner.read16()!
        TTL = scanner.readByte()!

        guard let proto = TransportProtocol(rawValue: scanner.readByte()!) else {
            DDLogWarn("Get unsupported packet protocol.")
            return nil
        }
        transportProtocol = proto

        // ignore checksum
        _ = scanner.read16()!

        switch version {
        case .iPv4:
            sourceAddress = IPAddress(ipv4InNetworkOrder: CFSwapInt32(scanner.read32()!))
            destinationAddress = IPAddress(ipv4InNetworkOrder: CFSwapInt32(scanner.read32()!))
        default:
            // IPv6 is not supported yet.
            DDLogWarn("IPv6 is not supported yet.")
            return nil
        }

        switch transportProtocol! {
        case .udp:
            guard let parser = UDPProtocolParser(packetData: packetData, offset: Int(headerLength)) else {
                return nil
            }
            self.protocolParser = parser
        default:
            DDLogError("Can not parse packet header of type \(String(describing: transportProtocol)) yet")
            return nil
        }
    }

    func computePseudoHeaderChecksum() -> UInt32 {
        var result: UInt32 = 0
        if let address = sourceAddress {
            result += address.UInt32InNetworkOrder! >> 16 + address.UInt32InNetworkOrder! & 0xFFFF
        }
        if let address = destinationAddress {
            result += address.UInt32InNetworkOrder! >> 16 + address.UInt32InNetworkOrder! & 0xFFFF
        }
        result += UInt32(transportProtocol.rawValue) << 8
        result += CFSwapInt32(UInt32(protocolParser.bytesLength))
        return result
    }

    func buildPacket() {
        packetData = NSMutableData(length: Int(headerLength) + protocolParser.bytesLength) as Data?

        // set header
        setPayloadWithUInt8(headerLength / 4 + version.rawValue << 4, at: 0)
        setPayloadWithUInt8(tos, at: 1)
        setPayloadWithUInt16(totalLength, at: 2)
        setPayloadWithUInt16(identification, at: 4)
        setPayloadWithUInt16(offset, at: 6)
        setPayloadWithUInt8(TTL, at: 8)
        setPayloadWithUInt8(transportProtocol.rawValue, at: 9)
        // clear checksum bytes
        resetPayloadAt(10, length: 2)
        setPayloadWithUInt32(sourceAddress.UInt32InNetworkOrder!, at: 12, swap: false)
        setPayloadWithUInt32(destinationAddress.UInt32InNetworkOrder!, at: 16, swap: false)

        // let TCP or UDP packet build
        protocolParser.packetData = packetData
        protocolParser.offset = Int(headerLength)
        protocolParser.buildSegment(computePseudoHeaderChecksum())
        packetData = protocolParser.packetData

        setPayloadWithUInt16(Checksum.computeChecksum(packetData, from: 0, to: Int(headerLength)), at: 10, swap: false)
    }

    func setPayloadWithUInt8(_ value: UInt8, at: Int) {
        var v = value
        withUnsafeBytes(of: &v) {
            packetData.replaceSubrange(at..<at+1, with: $0)
        }
    }

    func setPayloadWithUInt16(_ value: UInt16, at: Int, swap: Bool = true) {
        var v: UInt16
        if swap {
            v = CFSwapInt16HostToBig(value)
        } else {
            v = value
        }
        withUnsafeBytes(of: &v) {
            packetData.replaceSubrange(at..<at+2, with: $0)
        }
    }

    func setPayloadWithUInt32(_ value: UInt32, at: Int, swap: Bool = true) {
        var v: UInt32
        if swap {
            v = CFSwapInt32HostToBig(value)
        } else {
            v = value
        }
        withUnsafeBytes(of: &v) {
            packetData.replaceSubrange(at..<at+4, with: $0)
        }
    }

    func setPayloadWithData(_ data: Data, at: Int, length: Int? = nil, from: Int = 0) {
        var length = length
        if length == nil {
            length = data.count - from
        }
        packetData.replaceSubrange(at..<at+length!, with: data)
    }

    func resetPayloadAt(_ at: Int, length: Int) {
        packetData.resetBytes(in: at..<at+length)
    }

}
