import Foundation
/**
 socket的当前连接状态。

 -无效：仅创建了socket，但从未连接。
 -正在连接：插座正在连接。
 -已建立：连接已建立。
 -断开连接：插座正在断开连接。
 -闭合：插座已闭合。
 */

public enum SocketStatus {

    /// socket刚刚创建，但从不连接。
    case invalid,
    connecting,//连接
    established,//连接已建立
    disconnecting,//断开连接
    closed //socket 关闭

}

///具有各种功能的socket协议。
///任何具体的实现都不需要是线程安全的。
public protocol SocketProtocol: class {

    var socket: RawTCPSocketProtocol! { get }//底层的TCP socket 传输数据。

    var delegate: SocketDelegate? { get set }//代理对象.

    var status: SocketStatus { get }//socket 当前状态

    //当前状态的描述，都是只读类型

    /// 如果socket 断开
    var isDisconnected: Bool { get }

    /// socket
    var typeName: String { get }

    //读写的状态描述
    var readStatusDescription: String { get }
    var writeStatusDescription: String { get }


    /**
     从socket读取数据。
     -警告：仅应在最后一次读取完成后调用，即调用`delegate？.didReadData（）`。
     */

    func readData()

    /**
    将数据发送到远程。

     -警告：仅在最后一次写入完成后才调用此函数，即调用`delegate？.didWriteData（）`。
     */
    func write(data: Data)
    func disconnect(becauseOf error: Error?)// 断开socket
    func forceDisconnect(becauseOf error: Error?) // 强制断开socket

}

//实现默认属性
extension SocketProtocol {
    /// 如果socket已断开.
    ///默认实现protocol的方法
    public var isDisconnected: Bool {
        return status == .closed || status == .invalid
    }

    //添加默认属性

    public var typeName: String {
        return String(describing: type(of: self))
    }
    public var readStatusDescription: String {
        return "\(status)"
    }
    public var writeStatusDescription: String {
        return "\(status)"
    }
}

/// 委托协议，用于处理socket中的事件。
public protocol SocketDelegate : class {

    /**
     socket确实连接到了远程。
     */
    func didConnectWith(adapterSocket: AdapterSocket)

    /**
    socket没有断开。
    在socket的整个生命周期中，只能调用一次。调用此方法后，委托将不会从该socket接收任何其他事件，并且应该释放该socket。
     -参数socket：断开连接的 遵循SocketProtocol的 socket。

     */
    func didDisconnectWith(socket: SocketProtocol)
    /**
     socket确实读取了一些数据。

     -parameter：从socket读取的数据。
     -parameter：从中读取数据的socket。

     */
    func didRead(data: Data, from: SocketProtocol)
    /**

    socket确实发送了一些数据。

     -参数数据：已发送到远程（已确认）的数据。请注意，这可能不可用，因为可能会释放数据以节省内存。
     -参数依据：发送数据的socket。
     */
    func didWrite(data: Data?, by: SocketProtocol)

    /**
     socket已准备好来回转发数据。

     -参数socket：已准备好转发数据的socket。

     */
    func didBecomeReadyToForwardWith(socket: SocketProtocol)

    /**

     确实从本地收到了“ ConnectSession”，现在该连接远程了。

     -参数会话：接收的`ConnectSession`。
     -参数来自：接收`ConnectSession`的socket。
     */
    func didReceive(session: ConnectSession, from: ProxySocket)

    /**
     适配器socket决定用一个新的“ AdapterSocket”代替自身以连接到远程服务器。
     -参数newAdapter：新的`AdapterSocket`代替旧的。
     */
    func updateAdapterWith(newAdapter: AdapterSocket)
}
