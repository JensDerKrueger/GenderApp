//
//  GenderizeApp.swift
//  Genderize
//
//  Created by Jens Krüger on 19.09.25.
//

import SwiftUI

@main
struct GenderAppPhone: App {

  init() {
    SettingsSync.shared.registerDefaults()
    SettingsSync.shared.activate()

    // Wenn Settings in der App geändert werden: an Watch schicken
    NotificationCenter.default.addObserver(
      forName: UserDefaults.didChangeNotification,
      object: Defaults.store,
      queue: .main
    ) { _ in
      SettingsSync.shared.sendNow()
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
