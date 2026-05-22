import XCTest
@testable import AuthenticatorCore

final class Base32Tests: XCTestCase {
    // RFC 4648 §10 표준 테스트 벡터
    private let vectors: [(String, String)] = [
        ("", ""),
        ("f", "MY======"),
        ("fo", "MZXQ===="),
        ("foo", "MZXW6==="),
        ("foob", "MZXW6YQ="),
        ("fooba", "MZXW6YTB"),
        ("foobar", "MZXW6YTBOI======"),
    ]

    func testEncodeRFC4648Vectors() {
        for (plain, encoded) in vectors {
            let data = Data(plain.utf8)
            XCTAssertEqual(Base32.encode(data), encoded, "encode(\(plain))")
        }
    }

    func testDecodeRFC4648Vectors() throws {
        for (plain, encoded) in vectors {
            let decoded = try Base32.decode(encoded)
            XCTAssertEqual(decoded, Data(plain.utf8), "decode(\(encoded))")
        }
    }

    func testDecodeIgnoresWhitespaceAndDashes() throws {
        let decoded = try Base32.decode("MZ XW-6YTB")
        XCTAssertEqual(decoded, Data("fooba".utf8))
    }

    func testDecodeIsCaseInsensitive() throws {
        let decoded = try Base32.decode("mzxw6ytboi")
        XCTAssertEqual(decoded, Data("foobar".utf8))
    }

    func testDecodeInvalidCharacterThrows() {
        XCTAssertThrowsError(try Base32.decode("MZXW8!!!")) { error in
            guard case Base32.DecodeError.invalidCharacter = error else {
                XCTFail("기대한 invalidCharacter 에러가 아님: \(error)")
                return
            }
        }
    }
}
