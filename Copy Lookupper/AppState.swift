//
//  AppState.swift
//  Copy Lookupper
//
//  Created by skylar on 03/03/2026.
//
import SwiftUI
import KeyboardShortcuts
import AppKit
import Combine
import ScreenCaptureKit
import Vision

extension KeyboardShortcuts.Name {
    // captureShortcut
    static let captureShortcut = Self("captureShortcut", default: .init(.e, modifiers: [.command, .shift]))
    // translateShortcut
    static let translateShortcut = Self("translateShortcut", default: .init(.t, modifiers: [.command, .shift]))
}

@MainActor
final class AppState: ObservableObject {
    
    // recognizedText
    @Published var recognizedText: String? = nil
    // resultLocation
    @Published var resultLocation: NSPoint? = nil
    
    init() {
            KeyboardShortcuts.onKeyUp(for: .captureShortcut) { [weak self] in
                Task {
                    await self?.performOCRAtMouseLocation()
                }
            }
            KeyboardShortcuts.onKeyUp(for: .translateShortcut) { [weak self] in
                Task {
                    await self?.performFullTextTranslation()
                }
            }
        }

    private func performFullTextTranslation() async {
            // pasteboard
            let pasteboard = NSPasteboard.general
            // oldChangeCount
            let oldChangeCount = pasteboard.changeCount
            
            // source
            let source = CGEventSource(stateID: .hidSystemState)
            // cmdC
            let cmdC = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
            cmdC?.flags = .maskCommand
            cmdC?.post(tap: .cghidEventTap)
            
            // cmdCUp
            let cmdCUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
            cmdCUp?.flags = .maskCommand
            cmdCUp?.post(tap: .cghidEventTap)
            
            try? await Task.sleep(nanoseconds: 150_000_000)
            
            if pasteboard.changeCount != oldChangeCount, let selectedText = pasteboard.string(forType: .string) {
                // mouseLocation
                let mouseLocation = NSEvent.mouseLocation
                WindowManager.shared.showTranslation(text: selectedText, location: mouseLocation)
            }
        }

    private func performOCRAtMouseLocation() async {
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            return
        }
        
        // mouseLocation
        let mouseLocation = NSEvent.mouseLocation
        // screens
        let screens = NSScreen.screens
        
        // targetScreen
        guard let targetScreen = screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) else { return }
        
        // screenFrame
        let screenFrame = targetScreen.frame
        // relativeX
        let relativeX = mouseLocation.x - screenFrame.origin.x
        // relativeY
        let relativeY = screenFrame.height - (mouseLocation.y - screenFrame.origin.y)
        
        // captureWidth
        let captureWidth: CGFloat = 300
        // captureHeight
        let captureHeight: CGFloat = 100
        
        // captureX
        var captureX = relativeX - (captureWidth / 2)
        // captureY
        var captureY = relativeY - (captureHeight / 2)
        
        captureX = max(0, min(captureX, screenFrame.width - captureWidth))
        captureY = max(0, min(captureY, screenFrame.height - captureHeight))
        
        // captureRect
        let captureRect = CGRect(x: captureX, y: captureY, width: captureWidth, height: captureHeight)
    
        do {
            // shareableContent
            let shareableContent = try await SCShareableContent.current
            
            // screenNumber
            guard let screenNumber = targetScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return }

            // display
            guard let display = shareableContent.displays.first(where: { $0.displayID == screenNumber }) else { return }

            // filter
            let filter = SCContentFilter(display: display, excludingWindows: [])
            // configuration
            let configuration = SCStreamConfiguration()
            configuration.sourceRect = captureRect
            configuration.width = Int(captureRect.width)
            configuration.height = Int(captureRect.height)
            configuration.showsCursor = false

            // cgImage
            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            
            // result
            let result = await Task.detached(priority: .userInitiated) { () -> (String, NSPoint, NSRect)? in
                // requestHandler
                let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                // request
                let request = VNRecognizeTextRequest()
                request.recognitionLanguages = ["zh-Hans", "en-US"]
                request.recognitionLevel = .accurate
                
                try? requestHandler.perform([request])
                
                // observations
                guard let observations = request.results else { return nil }
                
                // actualCenterX
                let actualCenterX = (relativeX - captureX) / captureWidth
                // actualCenterY
                let actualCenterY = 1.0 - ((relativeY - captureY) / captureHeight)
                // centerPoint
                let centerPoint = CGPoint(x: actualCenterX, y: actualCenterY)
                
                // bestWord
                var bestWord: String? = nil
                // bestBox
                var bestBox: CGRect? = nil
                // minPixelDistance
                var minPixelDistance: CGFloat = .infinity

                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }
                    
                    // text
                    let text = topCandidate.string
                    text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byWords) { substring, range, _, _ in
                        if let word = substring,
                           let wordBox = try? topCandidate.boundingBox(for: range) {
                            
                            // box
                            let box = wordBox.boundingBox
                            
                            if box.contains(centerPoint) {
                                if 0 < minPixelDistance {
                                    minPixelDistance = 0
                                    bestWord = word
                                    bestBox = box
                                }
                            } else {
                                // wordCenter
                                let wordCenter = CGPoint(x: box.midX, y: box.midY)
                                // pixelDistance
                                let pixelDistance = hypot(
                                    (wordCenter.x - centerPoint.x) * captureWidth,
                                    (wordCenter.y - centerPoint.y) * captureHeight
                                )
                                
                                if pixelDistance < minPixelDistance && pixelDistance < 40 {
                                    minPixelDistance = pixelDistance
                                    bestWord = word
                                    bestBox = box
                                }
                            }
                        }
                    }
                }
                
                if let word = bestWord, let box = bestBox {
                    // appKitX
                    let appKitX = screenFrame.origin.x + captureX + (box.minX * captureWidth)
                    // appKitY
                    let appKitY = screenFrame.origin.y + screenFrame.height - captureY - captureHeight + (box.minY * captureHeight)
                    // wordRect
                    let wordRect = NSRect(x: appKitX, y: appKitY, width: box.width * captureWidth, height: box.height * captureHeight)
                    
                    return (word, NSPoint(x: mouseLocation.x, y: mouseLocation.y + 20), wordRect)
                }
                return nil
            }.value
            
            if let (word, location, wordRect) = result {
                self.recognizedText = word
                self.resultLocation = location
                WindowManager.shared.showDictionary(text: word, location: location, highlightRect: wordRect)
            }
            
        } catch {}
    }
}
