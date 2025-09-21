import SwiftUI

@main
struct GenderAppWatch: App {

  init() {
    SettingsSync.shared.registerDefaults()
    SettingsSync.shared.activate()

    // Nach kurzer Verzögerung die Settings beim iPhone anfragen
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
      SettingsSync.shared.requestFromPeer()
    }
  }

  var body: some Scene {
    WindowGroup {
      WatchContentView()
    }
  }
}
