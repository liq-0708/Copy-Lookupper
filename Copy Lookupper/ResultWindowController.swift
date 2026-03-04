//
//  ResultWindowController.swift
//  Copy Lookupper
//
//  Created by skylar on 03/03/2026.
//

import AppKit
import SwiftUI
import Translation
import Combine

class BorderlessWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
}

// translationState
@available(macOS 14.4, *)
class TranslationState: ObservableObject {
    @Published var isPresented: Bool = false
    @Published var text: String = ""
}

// translationHostView
@available(macOS 14.4, *)
struct TranslationHostView: View {
    @ObservedObject var state: TranslationState
    
    var body: some View {
        Color.clear
            .frame(width: 2, height: 2)
            .translationPresentation(isPresented: $state.isPresented, text: state.text)
    }
}

@MainActor
class WindowManager {
    // shared
    static let shared = WindowManager()
    
    // dictionaryWindow
    private var dictionaryWindow: BorderlessWindow?
    // translationWindow
    private var translationWindow: BorderlessWindow?
    // highlightWindow
    private var highlightWindow: BorderlessWindow?
    
    // translationState
    @available(macOS 14.4, *)
    private lazy var translationState = TranslationState()
    
    func showDictionary(text: String, location: NSPoint, highlightRect: NSRect?) {
        if dictionaryWindow == nil {
            // window
            let window = BorderlessWindow(
                contentRect: .zero,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            
            // textView
            let textView = NSTextView(frame: .zero)
            textView.backgroundColor = .clear
            textView.isEditable = false
            textView.isSelectable = true
            window.contentView = textView
            
            self.dictionaryWindow = window
        }
        
        handleHighlight(highlightRect: highlightRect, location: location) { popLocation in
            guard let window = self.dictionaryWindow, let textView = window.contentView as? NSTextView else { return }
            
            window.setFrame(NSRect(x: popLocation.x, y: popLocation.y, width: 2, height: 2), display: true)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            
            textView.string = text
            // attrString
            let attrString = NSAttributedString(string: text)
            textView.showDefinition(for: attrString, at: NSPoint(x: 1, y: 1))
        }
    }
    
    func showTranslation(text: String, location: NSPoint) {
        guard #available(macOS 14.4, *) else { return }
        
        if translationWindow == nil {
            // window
            let window = BorderlessWindow(
                contentRect: .zero,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            
            // hostingView
            let hostingView = NSHostingView(rootView: TranslationHostView(state: translationState))
            window.contentView = hostingView
            self.translationWindow = window
        }
        
        guard let window = translationWindow else { return }
        
        window.setFrame(NSRect(x: location.x, y: location.y, width: 2, height: 2), display: true)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        
        translationState.isPresented = false
        translationState.text = text
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.translationState.isPresented = true
        }
    }
    
    private func handleHighlight(highlightRect: NSRect?, location: NSPoint, completion: (NSPoint) -> Void) {
        if highlightWindow == nil {
            // hw
            let hw = BorderlessWindow(
                contentRect: .zero,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            hw.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.4)
            hw.isOpaque = false
            hw.hasShadow = false
            hw.level = .floating
            hw.ignoresMouseEvents = true
            hw.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            
            self.highlightWindow = hw
        }
        
        // popLocation
        var popLocation = location
        
        if let rect = highlightRect {
            highlightWindow?.setFrame(rect, display: true)
            highlightWindow?.makeKeyAndOrderFront(nil)
            
            // screen
            if let screen = NSScreen.screens.first(where: { NSMouseInRect(location, $0.frame, false) }) ?? NSScreen.main {
                if rect.midY > screen.frame.midY {
                    popLocation = NSPoint(x: rect.midX, y: rect.minY)
                } else {
                    popLocation = NSPoint(x: rect.midX, y: rect.maxY)
                }
            } else {
                popLocation = NSPoint(x: rect.midX, y: rect.minY)
            }
            
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                self.highlightWindow?.orderOut(nil)
            }
        } else {
            highlightWindow?.orderOut(nil)
        }
        
        completion(popLocation)
    }
}
