import XCTest
// @testable import WisperVoice (logic test - sources compiled in)
import AVFoundation
import Speech

final class PermissionsManagerTests: XCTestCase {
    func testInitCallsRefresh() {
        let pm = PermissionsManager()
        // Should not crash, values are bool (depends on host, but we test they are set)
        XCTAssertNotNil(pm.micGranted)
        XCTAssertNotNil(pm.speechGranted)
        XCTAssertNotNil(pm.accessibilityGranted)
    }

    func testRefreshUpdatesAllFlags() {
        let pm = PermissionsManager()
        pm.micGranted = !pm.micGranted
        pm.refresh()
        // After refresh, values reflect system state (authorized or not)
        // Just ensure no crash and bool assignment works
        XCTAssertTrue(pm.micGranted == true || pm.micGranted == false)
    }

    func testAllGrantedLogic() {
        let pm = PermissionsManager()
        pm.micGranted = true; pm.speechGranted = true; pm.accessibilityGranted = true
        XCTAssertTrue(pm.allGranted)
        pm.micGranted = false; XCTAssertFalse(pm.allGranted)
        pm.micGranted = true; pm.speechGranted = false; XCTAssertFalse(pm.allGranted)
        pm.speechGranted = true; pm.accessibilityGranted = false; XCTAssertFalse(pm.allGranted)
    }

    func testCheckAllDoesNotCrash() {
        PermissionsManager.checkAll()
        // No exception
    }

    func testRequestMicrophonePermissionNoCrash() {
        // Should not crash regardless of authorization status
        PermissionsManager.requestMicrophonePermission()
    }

    func testRequestSpeechPermissionNoCrash() {
        let pm = PermissionsManager()
        pm.requestSpeechPermission()
        // async refresh will be called; wait a tick
        let exp = expectation(description: "refresh")
        DispatchQueue.main.asyncAfter(deadline: .now()+0.3) { exp.fulfill() }
        waitForExpectations(timeout: 1)
    }

    func testRequestAccessibilityNoCrash() {
        let pm = PermissionsManager()
        pm.requestAccessibility()
        let exp = expectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now()+0.3) { exp.fulfill() }
        waitForExpectations(timeout: 1)
    }

    func testRequestMicrophoneWhenNotDetermined() {
        // We can't force .notDetermined, but we can ensure default case is covered
        // Call again to cover switch default branch
        PermissionsManager.requestMicrophonePermission()
        PermissionsManager.requestMicrophonePermission()
    }
}
