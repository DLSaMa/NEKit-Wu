import Foundation
import NetworkExtension
import CocoaLumberjackSwift

/// The TCP socket build upon `NWTCPConnection`.
///
/// - warning: This class is not thread-safe.
public class NWTCPSocket: NSObject, RawTCPSocketProtocol {
    private var connection: NWTCPConnection?

    private var writePending = false
    private var closeAfterWriting = false
    private var cancelled = false

    private var scanner: StreamScanner!
    private var scanning: Bool = false
    private var readDataPrefix: Data?

    // MARK: RawTCPSocketProtocol 实现

    /// The `RawTCPSocketDelegate` instance.
    weak open var delegate: RawTCPSocketDelegate?

    /// If the socket is connected.
    public var isConnected: Bool {
        return connection != nil && connection!.state == .connected
    }

    /// The source address.
    ///
    /// - note: Always returns `nil`.
    public var sourceIPAddress: IPAddress? {
        return nil
    }

    /// The source port.
    ///
    /// - note: Always returns `nil`.
    public var sourcePort: Port? {
        return nil
    }

    /// The destination address.
    ///
    /// - note: Always returns `nil`.
    public var destinationIPAddress: IPAddress? {
        return nil
    }

    /// The destination port.
    ///
    /// - note: Always returns `nil`.
    public var destinationPort: Port? {
        return nil
    }

    /**
     Connect to remote host.
     
     - parameter host:        Remote host.
     - parameter port:        Remote port.
     - parameter enableTLS:   Should TLS be enabled.
     - parameter tlsSettings: The settings of TLS.
     
     - throws: Never throws.
     */
    public func connectTo(host: String, port: Int, enableTLS: Bool, tlsSettings: [AnyHashable: Any]?) throws {
        let endpoint = NWHostEndpoint(hostname: host, port: "\(port)")
        let tlsParameters = NWTLSParameters()
        if let tlsSettings = tlsSettings as? [String: AnyObject] {
            tlsParameters.setValuesForKeys(tlsSettings)
        }

        guard let connection = RawSocketFactory.TunnelProvider?.createTCPConnection(to: endpoint, enableTLS: enableTLS, tlsParameters: tlsParameters, delegate: nil) else {
            // 仅当扩展已经停止并且RawSocketFactory.TunnelProvider设置为nil时，才应该发生这种情况。
            return
        }

        self.connection = connection
        connection.addObserver(self, forKeyPath: "state", options: [.initial, .new], context: nil)
    }

    /**
     Disconnect the socket.
     
     The socket will disconnect elegantly after any queued writing data are successfully sent.
     */
    public func disconnect() {
        cancelled = true

        if connection == nil  || connection!.state == .cancelled {
            delegate?.didDisconnectWith(socket: self)
        } else {
            closeAfterWriting = true
            checkStatus()
        }
    }

    /**
     Disconnect the socket immediately.
     */
    public func forceDisconnect() {
        cancelled = true

        if connection == nil  || connection!.state == .cancelled {
            delegate?.didDisconnectWith(socket: self)
        } else {
            cancel()
        }
    }

    /**
     Send data to remote.
     
     - parameter data: Data to send.
     - warning: This should only be called after the last write is finished, i.e., `delegate?.didWriteData()` is called.
     */
    public func write(data: Data) {
        guard !cancelled else {
            return
        }

        guard data.count > 0 else {
            QueueFactory.getQueue().async {
                self.delegate?.didWrite(data: data, by: self)
            }
            return
        }

        send(data: data)
    }

    /**
     Read data from the socket.
     
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    public func readData() {
        guard !cancelled else {
            return
        }

        connection!.readMinimumLength(1, maximumLength: Opt.MAXNWTCPSocketReadDataSize) { data, error in
            guard error == nil else {
                DDLogError("NWTCPSocket got an error when reading data: \(String(describing: error))")
                self.queueCall {
                    self.disconnect()
                }
                return
            }

            self.readCallback(data: data)
        }
    }

    /**
     Read specific length of data from the socket.
     
     - parameter length: The length of the data to read.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    public func readDataTo(length: Int) {
        guard !cancelled else {
            return
        }

        connection!.readLength(length) { data, error in
            guard error == nil else {
                DDLogError("NWTCPSocket got an error when reading data: \(String(describing: error))")
                self.queueCall {
                    self.disconnect()
                }
                return
            }

            self.readCallback(data: data)
        }
    }

    /**
     Read data until a specific pattern (including the pattern).
     
     - parameter data: The pattern.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    public func readDataTo(data: Data) {
        readDataTo(data: data, maxLength: 0)
    }

    //实际上，此方法可以使用`-（void）readToPattern：（id）arg1 maximumLength：（unsigned int）arg2completeHandler：（id / * block * /）arg3;`
    //不幸的是，由于某些未知原因，它在public标头中不可用。
    //我不想自己做，因为这种方法实施起来并不容易，而且我不喜欢重新发明轮子。
    //这只是最幼稚的版本，如果与大数据块一起使用可能不是最佳选择。
    /**
     读取数据直到特定的模式（包括模式）。
     
     -参数数据：模式。
     -参数maxLength：扫描模式的最大数据长度。
     -警告：仅应在最后一次读取完成后调用，即调用`delegate？.didReadData（）`。
     */
    public func readDataTo(data: Data, maxLength: Int) {
        guard !cancelled else {
            return
        }

        var maxLength = maxLength
        if maxLength == 0 {
            maxLength = Opt.MAXNWTCPScanLength
        }
        scanner = StreamScanner(pattern: data, maximumLength: maxLength)
        scanning = true
        readData()
    }

    private func queueCall(_ block: @escaping () -> Void) {
        QueueFactory.getQueue().async(execute: block)
    }

    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == "state" else {
            return
        }

        switch connection!.state {
        case .connected:
            queueCall {
                self.delegate?.didConnectWith(socket: self)
            }
        case .disconnected:
            cancelled = true
            cancel()
        case .cancelled:
            cancelled = true
            queueCall {
                let delegate = self.delegate
                self.delegate = nil
                delegate?.didDisconnectWith(socket: self)
            }
        default:
            break
        }
    }

    private func readCallback(data: Data?) {
        guard !cancelled else {
            return
        }

        queueCall {
            guard let data = self.consumeReadData(data) else {
                // remote read is closed, but this is okay, nothing need to be done, if this socket is read again, then error occurs.
                return
            }

            if self.scanning {
                guard let (match, rest) = self.scanner.addAndScan(data) else {
                    self.readData()
                    return
                }

                self.scanner = nil
                self.scanning = false

                guard let matchData = match else {
                    // do not find match in the given length, stop now
                    return
                }

                self.readDataPrefix = rest
                self.delegate?.didRead(data: matchData, from: self)
            } else {
                self.delegate?.didRead(data: data, from: self)
            }
        }
    }

    private func send(data: Data) {
        writePending = true
        self.connection!.write(data) { error in
            self.queueCall {
                self.writePending = false

                guard error == nil else {
                    DDLogError("NWTCPSocket got an error when writing data: \(String(describing: error))")
                    self.disconnect()
                    return
                }

                self.delegate?.didWrite(data: data, by: self)
                self.checkStatus()
            }
        }
    }

    private func consumeReadData(_ data: Data?) -> Data? {
        defer {
            readDataPrefix = nil
        }

        if readDataPrefix == nil {
            return data
        }

        if data == nil {
            return readDataPrefix
        }

        var wholeData = readDataPrefix!
        wholeData.append(data!)
        return wholeData
    }

    private func cancel() {
        connection?.cancel()
    }

    private func checkStatus() {
        if closeAfterWriting && !writePending {
            cancel()
        }
    }

    deinit {
        guard let connection = connection else {
            return
        }

        connection.removeObserver(self, forKeyPath: "state")
    }
}
