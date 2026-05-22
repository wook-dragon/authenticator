import Foundation

struct ProtobufReader {
    enum Error: Swift.Error, Equatable {
        case truncated
        case invalidVarint
        case unsupportedWireType(Int)
    }

    private let bytes: [UInt8]
    private var index: Int

    init(_ data: Data) {
        self.bytes = Array(data)
        self.index = 0
    }

    var isAtEnd: Bool { index >= bytes.count }

    mutating func readVarint() throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while true {
            guard index < bytes.count else { throw Error.truncated }
            let byte = bytes[index]
            index += 1
            result |= UInt64(byte & 0x7F) << shift
            if (byte & 0x80) == 0 { return result }
            shift += 7
            if shift >= 64 { throw Error.invalidVarint }
        }
    }

    mutating func readLengthDelimited() throws -> Data {
        let length = Int(try readVarint())
        guard length >= 0, index + length <= bytes.count else { throw Error.truncated }
        let slice = bytes[index..<(index + length)]
        index += length
        return Data(slice)
    }

    mutating func skipField(wireType: Int) throws {
        switch wireType {
        case 0:
            _ = try readVarint()
        case 1:
            guard index + 8 <= bytes.count else { throw Error.truncated }
            index += 8
        case 2:
            _ = try readLengthDelimited()
        case 5:
            guard index + 4 <= bytes.count else { throw Error.truncated }
            index += 4
        default:
            throw Error.unsupportedWireType(wireType)
        }
    }
}
