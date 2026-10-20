import XCTest

/// 用假数据跑一遍主要界面并截图，产物上传为 CI artifact，供产品侧对照 UI。
final class ScreenshotUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["--screenshot-mode"]
        app.launch()
        sleep(2)
    }

    func testCaptureMainScreens() throws {
        shot("01-首页-推荐")

        tapSegment("关注")
        shot("02-首页-关注")

        tapSegment("特别关注")
        shot("03-首页-特别关注")

        tapSegment("推荐")

        tapTab("热搜")
        shot("04-热搜")

        tapTab("搜索")
        shot("05-搜索")

        tapTab("我")
        shot("06-我")

        tapTab("首页")
        sleep(1)

        if app.buttons["详情"].firstMatch.waitForExistence(timeout: 8) {
            app.buttons["详情"].firstMatch.tap()
            sleep(2)
            shot("07-微博详情")
        }
    }

    private func tapTab(_ label: String) {
        let button = app.tabBars.buttons[label]
        if button.waitForExistence(timeout: 5) {
            button.tap()
            sleep(1)
        }
    }

    private func tapSegment(_ label: String) {
        let button = app.buttons[label].firstMatch
        if button.waitForExistence(timeout: 5) {
            button.tap()
            sleep(1)
        }
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
