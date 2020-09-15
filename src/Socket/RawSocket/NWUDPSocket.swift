import Foundation
import NetworkExtension
import CocoaLumberjackSwift

/// The delegate protocol of `NWUDPSocket`.
public protocol NWUDPSocketDelegate: class {
    /**
     套接字确实从远程接收数据。
     -参数数据：数据。
     -参数自：从中读取数据的套接字。
     */
    func didReceive(data: Data, from: NWUDPSocket)
    
    func didCancel(socket: NWUDPSocket)
}

/// NWUDPSession的包装器。
///
/// - note: This class is thread-safe.
public class NWUDPSocket: NSObject {
    private let session: NWUDPSession
    private var pendingWriteData: [Data] = []
    private var writing = false
    private let queue: DispatchQueue = QueueFactory.getQueue()
    private let timer: DispatchSourceTimer
    private let timeout: Int
    
    /// The delegate instance.
    public weak var delegate: NWUDPSocketDelegate?
    
    ///上一次活动发生的时间。
    ///由于UDP不具有“关闭”语义，因此这可以指示超时。
    public var lastActive: Date = Date()
    
    /**
     创建一个新的UDP套接字连接到远程。
     - parameter host: The host.
     - parameter port: The port.
     */
    public init?(host: String, port: Int, timeout: Int = Opt.UDPSocketActiveTimeout) {
        guard let udpsession = RawSocketFactory.TunnelProvider?.createUDPSession(to: NWHostEndpoint(hostname: host, port: "\(port)"), from: nil) else {
            return nil
        }
        
        session = udpsession
        self.timeout = timeout
        
        timer = DispatchSource.makeTimerSource(queue: queue)
        
        super.init()
        
        timer.schedule(deadline: DispatchTime.now(), repeating: DispatchTimeInterval.seconds(Opt.UDPSocketActiveCheckInterval), leeway: DispatchTimeInterval.seconds(Opt.UDPSocketActiveCheckInterval))
        timer.setEventHandler { [weak self] in
            self?.queueCall {
                self?.checkStatus()
            }
        }
        timer.resume()
        
        session.addObserver(self, forKeyPath: #keyPath(NWUDPSession.state), options: [.new], context: nil)
        session.setReadHandler({ [ weak self ] dataArray, error in
            self?.queueCall {
                guard let sSelf = self else {
                    return
                }
                
                sSelf.updateActivityTimer()
                
                guard error == nil, let dataArray = dataArray else {
                    DDLogError("Error when reading from remote server. \(error?.localizedDescription ?? "Connection reset")")
                    return
                }
                
                for data in dataArray {
                    sSelf.delegate?.didReceive(data: data, from: sSelf)
                }
            }
            }, maxDatagrams: 32)
    }
    
    /**
     Send data to remote.
     
     - parameter data: The data to send.
     */
    public func write(data: Data) {
        pendingWriteData.append(data)
        checkWrite()
    }
    
    public func disconnect() {
        session.cancel()
        timer.cancel()
    }
    
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == "state" else {
            return
        }
        
        switch session.state {
        case .cancelled:
            queueCall {
                self.delegate?.didCancel(socket: self)
            }
        case .ready:
            checkWrite()
        default:
            break
        }
    }
    
    private func checkWrite() {
        updateActivityTimer()
        
        guard session.state == .ready else {
            return
        }
        
        guard !writing else {
            return
        }
        
        guard pendingWriteData.count > 0 else {
            return
        }
        
        writing = true
        session.writeMultipleDatagrams(self.pendingWriteData) {_ in
            self.queueCall {
                self.writing = false
                self.checkWrite()
            }
        }
        self.pendingWriteData.removeAll(keepingCapacity: true)
    }
    
    private func updateActivityTimer() {
        lastActive = Date()
    }
    
    private func checkStatus() {
        if timeout > 0 && Date().timeIntervalSince(lastActive) > TimeInterval(timeout) {
            disconnect()
        }
    }
    
    private func queueCall(block: @escaping () -> Void) {
        queue.async {
            block()
        }
    }
    
    deinit {
        session.removeObserver(self, forKeyPath: #keyPath(NWUDPSession.state))
    }
}
