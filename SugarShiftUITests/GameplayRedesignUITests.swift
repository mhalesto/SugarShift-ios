import XCTest

final class GameplayRedesignUITests: XCTestCase {
    @MainActor
    func testRealSwapAndTargetedBoosterCancellation() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ss.dev.skipToLevel", "1", "-ss.dev.uiTesting", "YES"]
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = springboard.buttons["Don’t Allow"]
        if deny.waitForExistence(timeout: 3) { deny.tap() }
        let game = app.descendants(matching: .any).matching(identifier: "ss.game").firstMatch
        XCTAssertTrue(game.waitForExistence(timeout: 20))
        func read() -> [String: Any] {
            guard let text = game.value as? String, let data = text.data(using: .utf8),
                  let state = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
            return state
        }
        let ready = NSPredicate { _, _ in read()["swipe"] != nil }
        expectation(for: ready, evaluatedWith: game)
        waitForExpectations(timeout: 15)
        let before = read()
        let hammer = try XCTUnwrap(before["hammerPoint"] as? [Double])
        let hammerButton = app.coordinate(withNormalizedOffset: CGVector(dx: hammer[0], dy: hammer[1]))
        hammerButton.tap()
        hammerButton.tap()
        XCTAssertEqual(read()["cash"] as? Int, before["cash"] as? Int, "Selecting and cancelling must not charge")
        XCTAssertEqual(read()["hammer"] as? Int, before["hammer"] as? Int)
        let swipe = try XCTUnwrap(before["swipe"] as? [Double])
        let moves = try XCTUnwrap(before["moves"] as? Int)
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: swipe[0], dy: swipe[1]))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: swipe[2], dy: swipe[3]))
        start.press(forDuration: 0.06, thenDragTo: end)
        let resolved = NSPredicate { _, _ in
            let state = read()
            return (state["moves"] as? Int ?? moves) < moves && (state["score"] as? Int ?? 0) > 0
        }
        expectation(for: resolved, evaluatedWith: game)
        waitForExpectations(timeout: 30)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Candy Valley real move"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
