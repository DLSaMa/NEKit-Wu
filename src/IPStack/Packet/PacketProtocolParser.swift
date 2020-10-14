import Foundation

protocol TransportProtocolParserProtocol {
    var packetData: Data! { get set }

    var offset: Int { get set }

    var bytesLength: Int { get }

    var payload: Data! { get set }

    func buildSegment(_ pseudoHeaderChecksum: UInt32)
}

/// 解析器处理UDP数据包并构建数据包。
class UDPProtocolParser: TransportProtocolParserProtocol {
    /// The source port.
    var sourcePort: Port!

    /// The destination port.
    var destinationPort: Port!

    /// 包含UDP段的数据。
    var packetData: Data!

    /// UDP数据段在“ packetData”中的偏移量。
    var offset: Int = 0

    /// 要封装的有效负载。
    var payload: Data!

    /// UDP段的长度。
    var bytesLength: Int {
        return payload.count + 8
    }

    init() {}

    init?(packetData: Data, offset: Int) {
        guard packetData.count >= offset + 8 else {
            return nil
        }

        self.packetData = packetData
        self.offset = offset

        sourcePort = Port(bytesInNetworkOrder: (packetData as NSData).bytes.advanced(by: offset))
        destinationPort = Port(bytesInNetworkOrder: (packetData as NSData).bytes.advanced(by: offset + 2))

        payload = packetData.subdata(in: offset+8..<packetData.count)
    }

    func buildSegment(_ pseudoHeaderChecksum: UInt32) {
        sourcePort.withUnsafeBufferPointer {
            self.packetData.replaceSubrange(offset..<offset+2, with: $0)
        }
        destinationPort.withUnsafeBufferPointer {
            self.packetData.replaceSubrange(offset+2..<offset+4, with: $0)
        }
        var length = NSSwapHostShortToBig(UInt16(bytesLength))
        withUnsafeBytes(of: &length) {
            packetData.replaceSubrange(offset+4..<offset+6, with: $0)
        }
        packetData.replaceSubrange(offset+8..<offset+8+payload.count, with: payload)

        packetData.resetBytes(in: offset+6..<offset+8)
        var checksum = Checksum.computeChecksum(packetData, from: offset, to: nil, withPseudoHeaderChecksum: pseudoHeaderChecksum)
        withUnsafeBytes(of: &checksum) {
            packetData.replaceSubrange(offset+6..<offset+8, with: $0)
        }
    }
}
