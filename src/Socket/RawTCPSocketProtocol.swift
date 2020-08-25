import Foundation
///代表TCPsocket的原始socket协议。
///任何具体的实现都不需要是线程安全的。
///-警告：预期仅在特定队列上访问实例。
public protocol RawTCPSocketProtocol : class {
    /// The `RawTCPSocketDelegate` instance.
    var delegate: RawTCPSocketDelegate? { get set }
    var isConnected: Bool { get }///If the socket is connected.
    var sourceIPAddress: IPAddress? { get } //源地址
    var sourcePort: Port? { get }//源端口
    var destinationIPAddress: IPAddress? { get }//目标地址
    var destinationPort: Port? { get }//目标端口

    /**
   
     连接到远程主机。

     -参数主机：远程主机。
     -参数端口：远程端口。
     -参数enableTLS：应启用TLS。
     -参数tlsSettings：TLS的设置。

     -抛出：连接到主机时发生错误。
     */
    func connectTo(host: String, port: Int, enableTLS: Bool, tlsSettings: [AnyHashable: Any]?) throws

    /**
    断开socket。
     成功发送任何排队的写入数据后，socket应断开优雅连接。
     -注意：通常，任何具体的实现都应等到所有未完成的写入数据完成后再调用“ forceDisconnect（）”。
     */
    func disconnect()

    /**
     立即断开socket。

     -注意：socket应尽快断开连接。
     */
    func forceDisconnect()

    /**
     将数据发送到远程。

     -参数数据：要发送的数据。
     -警告：仅在最后一次写入完成后才调用此函数，即调用`delegate？.didWriteData（）`。
     */
    func write(data: Data)

    /**
    从socket读取数据。

     -警告：仅应在最后一次读取完成后调用，即调用`delegate？.didReadData（）`。
     */
    func readData()

    /**
    从socket读取特定长度的数据。

     -参数长度：要读取的数据长度。
     -警告：仅应在最后一次读取完成后调用，即调用`delegate？.didReadData（）`。
     */
    func readDataTo(length: Int)

    /**
     读取数据直到特定的模式（包括模式）。

     -参数数据：模式。
     -警告：仅应在最后一次读取完成后调用，即调用`delegate？.didReadData（）`。
     */
    func readDataTo(data: Data)

    /**
  读取数据直到特定的模式（包括模式）。

     -参数数据：模式。
     -参数maxLength：扫描模式的最大数据长度。
     -警告：仅应在最后一次读取完成后调用，即调用`delegate？.didReadData（）`。
     */
    func readDataTo(data: Data, maxLength: Int)
}

/// The delegate protocol to handle the events from a raw TCP socket.
//MARK:- GCDAsyncSocketDelegate的一个定制版，用于Socket连接/读写/取消连接后向外界发送通知 -
public protocol RawTCPSocketDelegate: class {

    func didDisconnectWith(socket: RawTCPSocketProtocol) // socket没有断开。在socket的整个生命周期中，只能调用一次。调用此方法后，委托将不会从该socket接收任何其他事件，并且应该释放该socket。
    /**
     socket确实读取了一些数据。
     -参数数据：从socket读取的数据。
     -参数from：读取数据的socket。
     */
    func didRead(data: Data, from: RawTCPSocketProtocol)

    /**
     socket确实发送了一些数据。
     -参数数据：已发送到远程（已确认）的数据。请注意，这可能不可用，因为可能会释放数据以节省内存。
     -参数依据：发送数据的socket。
     */
    func didWrite(data: Data?, by: RawTCPSocketProtocol)

    /**
  socket确实连接到了遥控器。

     -参数socket：连接的socket。
     */
    func didConnectWith(socket: RawTCPSocketProtocol) //
}
