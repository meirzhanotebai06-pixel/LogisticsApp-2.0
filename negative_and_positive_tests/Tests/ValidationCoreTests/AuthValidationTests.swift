import XCTest
@testable import ValidationCore

final class AuthValidationTests: XCTestCase {

    func testP01_minimalEmail() { XCTAssertNil(AuthValidation.validateEmailDetailed("a@b.kz")) }
    func testP02_dottedLocalPart() { XCTAssertNil(AuthValidation.validateEmailDetailed("user.name@example.com")) }
    func testP03_plusAlias() { XCTAssertNil(AuthValidation.validateEmailDetailed("user+tag@example.com")) }
    func testP04_longTLD() { XCTAssertNil(AuthValidation.validateEmailDetailed("x@domain.travel")) }

    // S3: accepted passwords; six characters is the registration form boundary.
    func testP05_sixCharacterPassword() { XCTAssertTrue(AuthValidation.isValidPassword("abc123")) }
    func testP06_mixedCasePassword() { XCTAssertTrue(AuthValidation.isValidPassword("ABCxyz012")) }

    // S4: phone numbers; punctuation is allowed as a formatting separator.
    func testP07_elevenDigits() { XCTAssertTrue(AuthValidation.isValidPhone("77001234567")) }
    func testP08_formattedPhone() { XCTAssertTrue(AuthValidation.isValidPhone("+7 (700) 123-45-67")) }

    // S5: names.
    func testP09_singleWordName() { XCTAssertTrue(AuthValidation.isValidName("Алия")) }
    func testP10_twoWordName() { XCTAssertTrue(AuthValidation.isValidName("Иван Петров")) }

    // S2: malformed addresses.
    func testN01_emptyEmail() { XCTAssertNotNil(AuthValidation.validateEmailDetailed("")) }
    func testN02_missingAtSign() { XCTAssertNotNil(AuthValidation.validateEmailDetailed("plainaddress")) }
    func testN03_missingDomainDot() { XCTAssertNotNil(AuthValidation.validateEmailDetailed("a@domain")) }
    func testN04_leadingDot() { XCTAssertNotNil(AuthValidation.validateEmailDetailed(".a@b.kz")) }
    func testN05_consecutiveDomainDots() { XCTAssertNotNil(AuthValidation.validateEmailDetailed("a@b..kz")) }

    // S3: invalid passwords.
    func testN06_symbolInPassword() { XCTAssertFalse(AuthValidation.isValidPassword("abc!")) }
    func testN07_emptyPassword() { XCTAssertFalse(AuthValidation.isValidPassword("")) }

    // S4: invalid phone numbers.
    func testN08_tenDigitPhone() { XCTAssertFalse(AuthValidation.isValidPhone("7700123456")) }
    func testN09_lettersInPhone() { XCTAssertFalse(AuthValidation.isValidPhone("abc77001234567")) }

    // S5: name lower boundary.
    func testN10_oneCharacterName() { XCTAssertFalse(AuthValidation.isValidName("А")) }
}
