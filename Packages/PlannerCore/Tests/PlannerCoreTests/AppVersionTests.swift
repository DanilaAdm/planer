import XCTest
@testable import PlannerCore

final class AppVersionTests: XCTestCase {

    func testParsesPlainAndTaggedVersions() {
        XCTAssertEqual(AppVersion("1.2.3")?.numbers, [1, 2, 3])
        XCTAssertEqual(AppVersion("v1.2.3")?.numbers, [1, 2, 3])
        XCTAssertEqual(AppVersion("  v10.0  ")?.numbers, [10, 0])
        XCTAssertNil(AppVersion("1.2.3")?.prerelease)
    }

    /// Ручной запуск релизного workflow даёт версию вида `0.0.0-1a2b3c4`.
    func testParsesManualBuildVersion() {
        let version = AppVersion("0.0.0-1a2b3c4")
        XCTAssertEqual(version?.numbers, [0, 0, 0])
        XCTAssertEqual(version?.prerelease, "1a2b3c4")
    }

    func testRejectsVersionsWithoutNumbers() {
        XCTAssertNil(AppVersion(""))
        XCTAssertNil(AppVersion("latest"))
        XCTAssertNil(AppVersion("v"))
        XCTAssertNil(AppVersion("1.2.x"))
        XCTAssertNil(AppVersion("1..2"))
    }

    /// Главная причина не сравнивать версии строками.
    func testComparesNumericallyNotAlphabetically() {
        XCTAssertTrue(AppVersion("1.9.0")! < AppVersion("1.10.0")!)
        XCTAssertTrue(AppVersion("1.2.9")! < AppVersion("1.3.0")!)
        XCTAssertTrue(AppVersion("2.0.0")! > AppVersion("1.99.99")!)
    }

    func testMissingComponentsCountAsZero() {
        XCTAssertEqual(AppVersion("1.2"), AppVersion("1.2.0"))
        XCTAssertTrue(AppVersion("1.2")! < AppVersion("1.2.1")!)
        XCTAssertEqual(AppVersion("1.2")?.hashValue, AppVersion("1.2.0")?.hashValue)
    }

    func testPrereleaseIsOlderThanRelease() {
        XCTAssertTrue(AppVersion("1.1.0-beta")! < AppVersion("1.1.0")!)
        XCTAssertTrue(AppVersion("1.1.0-alpha")! < AppVersion("1.1.0-beta")!)
        XCTAssertTrue(AppVersion("1.1.0")! < AppVersion("1.2.0-beta")!)
    }

    func testBuildMetadataIsIgnored() {
        XCTAssertEqual(AppVersion("1.2.3+42"), AppVersion("1.2.3"))
    }

    func testDescriptionRestoresOriginalForm() {
        XCTAssertEqual(AppVersion("v1.2.3")?.description, "1.2.3")
        XCTAssertEqual(AppVersion("0.0.0-abc")?.description, "0.0.0-abc")
    }

    func testUpdateIsOfferedOnlyForNewerRelease() {
        XCTAssertTrue(AppVersion.isUpdateAvailable(installed: "1.0.0", latest: "v1.1.0"))
        XCTAssertFalse(AppVersion.isUpdateAvailable(installed: "1.1.0", latest: "v1.1.0"))
        // Сборка из свежего кода новее опубликованного релиза — обновлять нечего.
        XCTAssertFalse(AppVersion.isUpdateAvailable(installed: "1.2.0", latest: "v1.1.0"))
    }

    func testUnparsableVersionsNeverOfferUpdate() {
        XCTAssertFalse(AppVersion.isUpdateAvailable(installed: "", latest: "v1.1.0"))
        XCTAssertFalse(AppVersion.isUpdateAvailable(installed: "1.0.0", latest: "latest"))
    }
}
