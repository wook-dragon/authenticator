import Foundation

public enum Base32 {
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")

    public enum DecodeError: Error, Equatable {
        case invalidCharacter(Character)
    }

    public static func encode(_ data: Data) -> String {
        if data.isEmpty { return "" }
        var result = ""
        result.reserveCapacity(((data.count + 4) / 5) * 8)
        var buffer: UInt64 = 0
        var bitsLeft = 0
        for byte in data {
            buffer = (buffer << 8) | UInt64(byte)
            bitsLeft += 8
            while bitsLeft >= 5 {
                bitsLeft -= 5
                let index = Int((buffer >> bitsLeft) & 0x1F)
                result.append(alphabet[index])
            }
        }
        if bitsLeft > 0 {
            let index = Int((buffer << (5 - bitsLeft)) & 0x1F)
            result.append(alphabet[index])
        }
        while result.count % 8 != 0 {
            result.append("=")
        }
        return result
    }

    public static func decode(_ string: String) throws -> Data {
        var normalized = ""
        normalized.reserveCapacity(string.count)
        for ch in string.uppercased() where ch != " " && ch != "-" && ch != "=" {
            normalized.append(ch)
        }
        if normalized.isEmpty { return Data() }

        var buffer: UInt64 = 0
        var bitsLeft = 0
        var output = Data()
        output.reserveCapacity((normalized.count * 5) / 8)
        for ch in normalized {
            guard let value = alphabet.firstIndex(of: ch) else {
                throw DecodeError.invalidCharacter(ch)
            }
            buffer = (buffer << 5) | UInt64(value)
            bitsLeft += 5
            if bitsLeft >= 8 {
                bitsLeft -= 8
                let byte = UInt8((buffer >> bitsLeft) & 0xFF)
                output.append(byte)
            }
        }
        return output
    }
}
