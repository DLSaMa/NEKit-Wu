import Foundation

open class Observer<T: EventType> {
    public init() {}
    open func signal(_ event: T) {}
    
//    open func signal_test<E:EventType>(_event:E){}
}
