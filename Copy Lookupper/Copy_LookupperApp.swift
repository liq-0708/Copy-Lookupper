//
//  Copy_LookupperApp.swift
//  Copy Lookupper
//
//  Created by skylar on 03/03/2026.
//

import SwiftUI

@main
struct Copy_LookupperApp: App {
    // appState
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Copy Lookupper", systemImage: "doc.text.magnifyingglass") {
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
