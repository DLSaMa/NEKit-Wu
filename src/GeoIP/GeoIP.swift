import Foundation
import MMDB //一个地理位置的

open class GeoIP {
    //过去，MMDB附带了捆绑的GeoLite2数据库。但是，情况已经改变
    //由于数据库的许可证更改。现在，开发人员必须自己对其进行初始化。
    //为了在尽快暴露问题的同时保持API兼容性，我们设置了类型
    //到`MMDB！`，因此如果有人忘记初始化它，它将在开发期间崩溃。
    //请先对其进行初始化！
    public static var database: MMDB!
    public static func LookUp(_ ipAddress: String) -> MMDBCountry? {
        return GeoIP.database.lookup(ipAddress)
    }
}
