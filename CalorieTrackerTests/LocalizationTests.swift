import XCTest
@testable import CalorieTracker

/// Every string the app shows must follow the in-app language, including error messages that
/// originate on the server (some hard-coded in Chinese) or in iOS networking (phone's language).
@MainActor
final class LocalizationTests: XCTestCase {
    private var store: LocalizationStore!
    private var savedLanguage: AppLanguage!

    override func setUp() async throws {
        store = LocalizationStore()
        savedLanguage = store.language
    }

    override func tearDown() async throws {
        store.language = savedLanguage // don't leak the test's choice into the simulator's app state
    }

    func testEveryStringHasBothLanguages() {
        for (key, translations) in Strings.table {
            XCTAssertFalse((translations[.en] ?? "").isEmpty, "\(key) missing English")
            XCTAssertFalse((translations[.zh] ?? "").isEmpty, "\(key) missing Chinese")
        }
    }

    func testServerErrorsAreTranslatedNotShownRaw() {
        store.language = .en
        let serverChinese = APIError.server(status: 500, message: "AI 教練暫時無法回應，請稍後再試")
        XCTAssertEqual(store.message(for: serverChinese), Strings.table["error.server"]?[.en])

        store.language = .zh
        let serverEnglish = APIError.server(status: 409, message: "Email already registered")
        XCTAssertEqual(store.message(for: serverEnglish), Strings.table["error.emailTaken"]?[.zh])
    }

    func testNetworkAndLoginErrors() {
        store.language = .en
        XCTAssertEqual(store.message(for: APIError.transport(URLError(.notConnectedToInternet))), Strings.table["error.network"]?[.en])
        XCTAssertEqual(store.message(for: APIError.transport(URLError(.timedOut))), Strings.table["error.timeout"]?[.en])
        XCTAssertEqual(store.message(for: APIError.unauthorized, unauthorizedKey: "error.wrongCredentials"),
                       Strings.table["error.wrongCredentials"]?[.en])
    }

    func testLocaleAndAPILanguageFollowSetting() {
        store.language = .en
        XCTAssertEqual(store.apiLanguageCode, "en")
        XCTAssertEqual(store.locale.language.languageCode, .english)
        store.language = .zh
        XCTAssertEqual(store.apiLanguageCode, "zh")
    }
}
