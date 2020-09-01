import Foundation
import MMDB

open class GeoIP {
   //以前，MMDB提供了一个绑定的GeoLite2数据库。然而，情况已经改变了
    //由于数据库的许可证更改。现在开发人员必须自己初始化它。
    //为了在尽快暴露问题的同时保持API兼容性，我们设置了
    //到`MMDB！`因此，如果忘记初始化它，它将在开发过程中崩溃。

    //请先初始化！
    public static var database: MMDB!

    public static func LookUp(_ ipAddress: String) -> MMDBCountry? {
        return GeoIP.database.lookup(ipAddress)
    }
}
