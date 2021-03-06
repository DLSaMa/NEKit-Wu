//
//  BinaryDataScanner.swift
//  Murphy
//
//  Created by Dave Peck on 7/20/14.
//  Copyright (c) 2014 Dave Peck. All rights reserved.
//

import Foundation

/*
玩弄帮助读取二进制格式的工具。

我已经看到许多迅速产生的方法
每次读取的中间对象（通常是另一个NSData）
但是即使这些引擎盖很轻巧，
似乎过分杀伤力了。 加上这让我了解了<（）>又名<Void>

扩展到
NSFileHandle的功能也差不多。
*/

public protocol BinaryReadable {
    var littleEndian: Self { get }
    var bigEndian: Self { get }
}

extension UInt8: BinaryReadable {
    public var littleEndian: UInt8 { return self }
    public var bigEndian: UInt8 { return self }
}

extension UInt16: BinaryReadable {}

extension UInt32: BinaryReadable {}

extension UInt64: BinaryReadable {}

open class BinaryDataScanner {
    let data: Data
    let littleEndian: Bool
//    let encoding: NSStringEncoding

    var remaining: Int {
        return data.count - position
    }

    var position: Int = 0

    public init(data: Data, littleEndian: Bool) {
        self.data = data
        self.littleEndian = littleEndian
    }

    open func read<T: BinaryReadable>() -> T? {
        if remaining < MemoryLayout<T>.size {
            return nil
        }

        let v = data.withUnsafeBytes {
            $0.baseAddress!.advanced(by: position).assumingMemoryBound(to: T.self).pointee
        }
        position += MemoryLayout<T>.size
        return littleEndian ? v.littleEndian : v.bigEndian
    }

    // swiftlint:disable variable_name
    open func skip(to n: Int) {
        position = n
    }

    open func advance(by n: Int) {
        position += n
    }

    /* convenience read funcs */

    open func readByte() -> UInt8? {
        return read()
    }

    open func read16() -> UInt16? {
        return read()
    }

    open func read32() -> UInt32? {
        return read()
    }

    open func read64() -> UInt64? {
        return read()
    }
}
