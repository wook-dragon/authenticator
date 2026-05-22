import XCTest
@testable import AuthenticatorCore

final class MigrationParserTests: XCTestCase {
    // Google Authenticator export 예시. data 파라미터는 base64로 인코딩된 protobuf.
    // 디코딩하면: secret=Hello!\xDE\xAD\xBE\xEF, name="test@example.com.au", issuer="Example Co",
    // algorithm=SHA1, digits=six, type=TOTP
    func testParseMigrationSingleAccount() throws {
        let url = "otpauth-migration://offline?data=CjEKCkhlbGxvId6tvu8SE3Rlc3RAZXhhbXBsZS5jb20uYXUaCkV4YW1wbGUgQ28gASgBMAIQARgBIAA%3D"
        let accounts = try OTPURLParser.parseMigration(url)
        XCTAssertEqual(accounts.count, 1)
        let a = accounts[0]
        XCTAssertEqual(a.issuer, "Example Co")
        XCTAssertEqual(a.name, "test@example.com.au")
        XCTAssertEqual(a.algorithm, .sha1)
        XCTAssertEqual(a.digits, 6)
        XCTAssertEqual(a.type, .totp)
        XCTAssertEqual(a.secret, Data([0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x21, 0xde, 0xad, 0xbe, 0xef]))
    }

    func testParseStandardOtpAuthURL() throws {
        let url = "otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&algorithm=SHA1&digits=6&period=30"
        let account = try OTPURLParser.parseSingle(url)
        XCTAssertEqual(account.issuer, "Example")
        XCTAssertEqual(account.name, "alice@google.com")
        XCTAssertEqual(account.digits, 6)
        XCTAssertEqual(account.period, 30)
        XCTAssertEqual(account.algorithm, .sha1)
        XCTAssertEqual(account.type, .totp)
        XCTAssertEqual(account.secret, try Base32.decode("JBSWY3DPEHPK3PXP"))
    }

    func testParseAnyDispatchesByScheme() throws {
        let migrationURL = "otpauth-migration://offline?data=CjEKCkhlbGxvId6tvu8SE3Rlc3RAZXhhbXBsZS5jb20uYXUaCkV4YW1wbGUgQ28gASgBMAIQARgBIAA%3D"
        let singleURL = "otpauth://totp/x?secret=JBSWY3DPEHPK3PXP"
        XCTAssertEqual(try OTPURLParser.parseAny(migrationURL).count, 1)
        XCTAssertEqual(try OTPURLParser.parseAny(singleURL).count, 1)
    }

    func testRejectsUnknownScheme() {
        XCTAssertThrowsError(try OTPURLParser.parseAny("https://example.com/foo")) { error in
            guard case OTPURLParser.Error.unsupportedScheme = error else {
                XCTFail("기대한 unsupportedScheme 에러가 아님: \(error)")
                return
            }
        }
    }
}
