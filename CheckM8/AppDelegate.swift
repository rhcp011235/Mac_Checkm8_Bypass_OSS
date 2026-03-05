import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindow: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let vc = MainViewController()
        mainWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        mainWindow.title = "CheckM8 [v1.0.0]"
        mainWindow.contentViewController = vc
        mainWindow.backgroundColor = NSColor(red: 0.16, green: 0.16, blue: 0.16, alpha: 1)
        mainWindow.center()
        mainWindow.makeKeyAndOrderFront(nil)
        mainWindow.isReleasedWhenClosed = false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        ActivationEngine.shared.cleanup()
    }
}
