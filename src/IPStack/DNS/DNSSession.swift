import Foundation
import CocoaLumberjackSwift

open class DNSSession {
    public let requestMessage: DNSMessage
    var requestIPPacket: IPPacket?
    open var realIP: IPAddress?
    open var fakeIP: IPAddress?
    open var realResponseMessage: DNSMessage?
    var realResponseIPPacket: IPPacket?
    open var matchedRule: Rule?
    open var matchResult: DNSSessionMatchResult?
    var indexToMatch = 0
    var expireAt: Date?
    lazy var countryCode: String? = {
        [unowned self] in
        guard self.realIP != nil else {
            return nil
        }
        return Utils.GeoIPLookup.Lookup(self.realIP!.presentation)
    }()

    init?(message: DNSMessage) {
        guard message.messageType == .query else {
            DDLogError("DNSSession can only be initailized by a DNS query.")//NSSession只能通过DNS查询初始化
            return nil
        }

        guard message.queries.count == 1 else {
            DDLogError("Expecting the DNS query has exact one query entry.")//期望DNS查询具有确切的一个查询条目。
            return nil
        }

        requestMessage = message
    }

    //便利构造函数 一般在对系统的类方法 扩展的时候 使用
    // 一般的构造函数 是创建对象的，便利函数
    convenience init?(packet: IPPacket) {
        guard let message = DNSMessage(payload: packet.protocolParser.payload) else {
            return nil
        }
        self.init(message: message)
        requestIPPacket = packet
    }
}

extension DNSSession: CustomStringConvertible {
    public var description: String {
        return "<\(type(of: self)) domain: \(self.requestMessage.queries.first!.name) realIP: \(String(describing: realIP)) fakeIP: \(String(describing: fakeIP))>"
    }
}
