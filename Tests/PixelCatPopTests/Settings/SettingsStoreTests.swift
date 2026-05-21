import XCTest
@testable import PixelCatPop

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testNewToolboxSettingsUseLightweightDefaults() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let settings = SettingsStore(defaults: defaults)

        XCTAssertEqual(settings.screenshotAnnotationColor, .red)
        XCTAssertTrue(settings.recordsSystemAudio)
        XCTAssertTrue(settings.recordsMicrophoneAudio)
        XCTAssertTrue(settings.playsMouseClickSound)
        XCTAssertTrue(settings.playsKeyboardInputSound)
        XCTAssertTrue(settings.showsClickRipple)
        XCTAssertTrue(settings.showsTypingZoom)
        XCTAssertTrue(settings.appCleanerSelectsPreferences)
        XCTAssertTrue(settings.appCleanerSelectsCaches)
        XCTAssertTrue(settings.appCleanerSelectsSupportFiles)
        XCTAssertTrue(settings.appCleanerSelectsContainers)
        XCTAssertTrue(settings.appCleanerSelectsLogs)
        XCTAssertTrue(settings.appCleanerSelectsSavedState)
        XCTAssertEqual(settings.systemMonitorRefreshInterval, .realtime)
        XCTAssertFalse(settings.showsCPUInMenu)
        XCTAssertFalse(settings.showsMemoryInMenu)
        XCTAssertFalse(settings.showsDiskInMenu)
        XCTAssertFalse(settings.showsNetworkInMenu)
    }

    func testPersistsToolboxSettings() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        var settings = SettingsStore(defaults: defaults)

        settings.screenshotAnnotationColor = .blue
        settings.recordsSystemAudio = false
        settings.recordsMicrophoneAudio = false
        settings.playsMouseClickSound = false
        settings.playsKeyboardInputSound = false
        settings.showsClickRipple = false
        settings.showsTypingZoom = false
        settings.appCleanerSelectsPreferences = false
        settings.appCleanerSelectsCaches = false
        settings.appCleanerSelectsSupportFiles = false
        settings.appCleanerSelectsContainers = false
        settings.appCleanerSelectsLogs = false
        settings.appCleanerSelectsSavedState = false
        settings.systemMonitorRefreshInterval = .thirtySeconds
        settings.showsCPUInMenu = false
        settings.showsMemoryInMenu = false
        settings.showsDiskInMenu = false
        settings.showsNetworkInMenu = false

        settings = SettingsStore(defaults: defaults)
        XCTAssertEqual(settings.screenshotAnnotationColor, .blue)
        XCTAssertFalse(settings.recordsSystemAudio)
        XCTAssertFalse(settings.recordsMicrophoneAudio)
        XCTAssertFalse(settings.playsMouseClickSound)
        XCTAssertFalse(settings.playsKeyboardInputSound)
        XCTAssertFalse(settings.showsClickRipple)
        XCTAssertFalse(settings.showsTypingZoom)
        XCTAssertFalse(settings.appCleanerSelectsPreferences)
        XCTAssertFalse(settings.appCleanerSelectsCaches)
        XCTAssertFalse(settings.appCleanerSelectsSupportFiles)
        XCTAssertFalse(settings.appCleanerSelectsContainers)
        XCTAssertFalse(settings.appCleanerSelectsLogs)
        XCTAssertFalse(settings.appCleanerSelectsSavedState)
        XCTAssertEqual(settings.systemMonitorRefreshInterval, .thirtySeconds)
        XCTAssertFalse(settings.showsCPUInMenu)
        XCTAssertFalse(settings.showsMemoryInMenu)
        XCTAssertFalse(settings.showsDiskInMenu)
        XCTAssertFalse(settings.showsNetworkInMenu)
    }
}
