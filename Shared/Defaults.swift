import SwiftUI

import Foundation
import WatchConnectivity

// Welche Keys sollen gespiegelt werden?
let mirroredKeys = ["guessAgeEnabled", "guessNationalityEnabled"]

enum Defaults {
  static let groupID = "group.de.uni-due.genderapp"
  static let store: UserDefaults = {
    guard let u = UserDefaults(suiteName: groupID) else {
      assertionFailure("App Group \(groupID) fehlt in Entitlements")
      return .standard
    }
    return u
  }()
}

/// Zentraler Sync-Helper für iOS & watchOS
final class SettingsSync: NSObject, WCSessionDelegate {
  static let shared = SettingsSync()
  private var session: WCSession? { WCSession.isSupported() ? .default : nil }

  // MARK: Public API
  func activate() {
    session?.delegate = self
    session?.activate()
  }

  /// Lokale Defaults registrieren (damit es definierte Anfangswerte gibt)
  func registerDefaults() {
    Defaults.store.register(defaults: [
      "guessAgeEnabled": false,
      "guessNationalityEnabled": false
    ])
  }

  /// Settings-Payload aus dem (lokalen) App-Group-Store bauen
  var currentSettings: [String: Any] {
    mirroredKeys.reduce(into: [String: Any]()) { dict, key in
      dict[key] = Defaults.store.object(forKey: key)
    }
  }

  /// Aktiv die aktuellen Settings senden (wenn Gegenstelle erreichbar)
  func sendNow() {
    guard let s = session else { return }
    let payload: [String: Any] = ["settings": currentSettings]
    if s.isReachable {
      s.sendMessage(payload, replyHandler: nil, errorHandler: nil)
    } else {
      // Fallback: zuverlässige, aber asynchrone Zustellung
      s.transferUserInfo(payload)
    }
  }

  /// Gegenstelle bitten, Settings zu schicken (z. B. beim Start)
  func requestFromPeer() {
    session?.sendMessage(["request": "settings"], replyHandler: nil, errorHandler: nil)
  }

  // MARK: - Intern
  private func apply(_ incoming: [String: Any]) {
    var changed = false
    for (k, v) in incoming where mirroredKeys.contains(k) {
      Defaults.store.set(v, forKey: k)
      changed = true
    }
    if changed {
      Defaults.store.synchronize()
      // Optional: benachrichtige UI
      NotificationCenter.default.post(name: .settingsDidSync, object: nil)
    }
  }

  // MARK: - WCSessionDelegate
  func session(_ session: WCSession,
               activationDidCompleteWith activationState: WCSessionActivationState,
               error: Error?) {}

#if os(iOS)
  func sessionDidBecomeInactive(_ session: WCSession) {}
  func sessionDidDeactivate(_ session: WCSession) { session.activate() }
#endif

  func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
    if message["request"] as? String == "settings" {
      sendNow()
    } else if let dict = message["settings"] as? [String: Any] {
      apply(dict)
    }
  }

  func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
    if let dict = userInfo["settings"] as? [String: Any] {
      apply(dict)
    }
  }
}

extension Notification.Name {
  static let settingsDidSync = Notification.Name("SettingsDidSync")
}
