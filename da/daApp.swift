//
//  daApp.swift
//  da
//
//  Created by Динара Ибрагимова on 20.06.2026.
//

import SwiftUI

@main
struct daApp: App {
    init() {
        // RU-only product: pin the UI to Russian regardless of the device
        // language. Without this, an English-language phone serves the `en`
        // strings while concatenated fragments (which have no `en`) stay
        // Russian — producing a mixed RU/EN screen. Set before the first
        // localized lookup so Bundle.main resolves to ru for this launch.
        UserDefaults.standard.set(["ru"], forKey: "AppleLanguages")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, Locale(identifier: "ru"))
        }
    }
}
