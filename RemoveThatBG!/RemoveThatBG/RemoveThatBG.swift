//
//  RemoveThatBG.swift
//  RemoveThatBG!
//
//  Created by Pietro Saveri on 13/11/25.
//

import SwiftUI

@main
struct MyMenuBarAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Start Python server ONCE in App init, NOT in AppDelegate
        PythonServerManager.shared.startServer()
        print("🚀 Python server started from App.init()")
    }
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Preferences…") {
                    appDelegate.showSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var settingsWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Python server is started in App.init(), NOT here!
        
        // Create the status item (menu bar icon)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
    
        if let button = statusItem?.button {
            //button.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: "My App")
            if let image = NSImage(named: "MenuIcon") {
                    image.size = NSSize(width: 42, height: 42) // adjust to fit menu bar
                    button.image = image
                    button.image?.isTemplate = true
                }
            
            //button.image = NSImage(named: "MenuIcon")
            //button.image?.isTemplate = true
            button.toolTip = "Super Incredible Bg Remover"
            
            button.action = #selector(togglePopover)
        }
        
        // Create the popover (the window that appears)
        popover = NSPopover()
        // Match ContentView's intrinsic frame to avoid clipping/click issues
        popover?.contentSize = NSSize(width: 500, height: 250)
        popover?.behavior = .semitransient
        popover?.contentViewController = NSHostingController(rootView: ContentView())
        popover?.setValue(true, forKeyPath: "shouldHideAnchor")
        
        // Set initial animation state from settings
        updatePopoverAnimation()
        
        NotificationCenter.default.addObserver(self,
                                                       selector: #selector(handleClosePopoverNotification(_:)),
                                                       name: .closePopover,
                                                       object: nil)
        
        NotificationCenter.default.addObserver(self,
                                                       selector: #selector(handlePopoverAnimationChanged(_:)),
                                                       name: .popoverAnimationChanged,
                                                       object: nil)
        //fine codice per il parametro della animazione

    }
    
    @objc func handleClosePopoverNotification(_ note: Notification) {
            closePopover()
        }
    
    @objc func handlePopoverAnimationChanged(_ note: Notification) {
        updatePopoverAnimation()
    }
    
    func updatePopoverAnimation() {
        let shouldAnimate = SettingsManager.shared.animatePopover
        popover?.setValue(shouldAnimate, forKey: "animates")
    }
    
    @objc func closePopover() {
            if popover?.isShown == true {
                popover?.performClose(nil)
            }
        }
    
    @objc func togglePopover() {
        if let button = statusItem?.button {
            if popover?.isShown == true {
                popover?.performClose(nil)
            } else {

                var bounds = button.bounds
                bounds.origin.y -= 8

                popover?.show(relativeTo: bounds, of: button, preferredEdge: .minY)
                
            }
        }
    }
    
    func showSettings() {
        // Always run UI work on main thread and close popover first
        DispatchQueue.main.async {
            print("[RemoveThatBG!] showSettings invoked")
            self.popover?.performClose(nil)
            
            if self.settingsWindow == nil {
                let hostingController = NSHostingController(rootView: SettingsView())
                let window = NSWindow(contentViewController: hostingController)
                
                // Classic macOS Preferences window sizing and style
                window.title = "Preferences"
                window.setContentSize(NSSize(width: 480, height: 360))
                window.styleMask = [.titled, .closable]
                window.titlebarAppearsTransparent = false
                window.isReleasedWhenClosed = false
                window.center()
                
                // Track close to allow re-creation later
                NotificationCenter.default.addObserver(self,
                                                       selector: #selector(self.settingsWindowClosed(_:)),
                                                       name: NSWindow.willCloseNotification,
                                                       object: window)
                
                self.settingsWindow = window
            }
            // Activate app first, then bring the window forward regardless
            NSApp.activate(ignoringOtherApps: true)
            if let win = self.settingsWindow {
                win.makeKeyAndOrderFront(nil)
                win.orderFrontRegardless()
                print("[RemoveThatBG!] Preferences window presented")
            } else {
                print("[RemoveThatBG!] ERROR: settingsWindow is nil after setup")
            }
        }
    }

    @objc private func settingsWindowClosed(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == settingsWindow {
            settingsWindow = nil
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Stop the Python server when the app quits
        PythonServerManager.shared.stopServer()
    }
}

extension Notification.Name {
    static let closePopover = Notification.Name("ClosePopoverNotification")
    static let popoverAnimationChanged = Notification.Name("PopoverAnimationChangedNotification")
}

