import XCTest

/// Read-only physical-device review. Never signs out, purchases, edits an
/// account, saves a verse or completes a lesson on the owner's account.
final class DeviceReviewTests: XCTestCase {
  let app = XCUIApplication(bundleIdentifier: "com.holyhim.app")
  func capture(_ name: String) {
    let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    image.name = name
    image.lifetime = .keepAlways
    add(image)
  }
  func button(_ label: String) -> XCUIElement {
    app.buttons.matching(identifier: label).firstMatch
  }
  func tapTab(_ label: String) -> Bool {
    let native = app.tabBars.buttons[label].firstMatch
    let target = native.exists ? native : button(label)
    guard target.waitForExistence(timeout: 3), target.isHittable else { return false }
    target.tap()
    return true
  }
  func testReadOnlyDeviceScreens() {
    continueAfterFailure = false
    app.launch()
    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
    capture("01-launch")
    guard tapTab("Walk") else {
      // Keep authentication/onboarding intact if that is the current state.
      capture("02-current-auth-or-setup")
      return
    }
    capture("02-walk")
    for label in ["Saved", "Growth", "Profile"] {
      XCTAssertTrue(tapTab(label))
      capture(label.lowercased())
    }
    let theme = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Theme")).firstMatch
    if theme.exists && theme.isHittable {
      theme.tap()
      capture("themes-current-selection")
      let back = button("Back")
      if back.exists && back.isHittable { back.tap() }
    }
    XCTAssertTrue(tapTab("Walk"))
    let begin = button("Begin your moment")
    if begin.exists && begin.isHittable {
      begin.tap()
      capture("lesson-scripture")
      for name in ["meaning", "reflection", "prayer"] {
        let next = button("Next card")
        XCTAssertTrue(next.waitForExistence(timeout: 3))
        next.tap()
        capture("lesson-" + name)
      }
      let amen = button("Hold to say Amen")
      XCTAssertTrue(amen.waitForExistence(timeout: 3))
      amen.press(forDuration: 0.3)
      XCTAssertFalse(app.staticTexts["Your moment is complete."].exists)
      capture("amen-cancelled")
      let close = button("Close lesson")
      if close.exists { close.tap() }
    }
    // Exercise retained tab paging without changing user data.
    app.swipeLeft(velocity: .slow)
    capture("after-home-swipe")
    _ = tapTab("Walk")
  }
}
