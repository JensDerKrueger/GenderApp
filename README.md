# Gender App (iOS & watchOS)

A SwiftUI-based iOS and watchOS app that predicts **gender**, **age**, and **nationality** from a given name.  
It integrates the [Genderize](https://genderize.io), [Agify](https://agify.io), and [Nationalize](https://nationalize.io) APIs, with support for multiple languages, shared settings, and synchronization between iPhone and Apple Watch via **App Groups** and **WatchConnectivity**.

---

## ✨ Features

- **Gender prediction** with probability visualization (traffic-light bar).
- **Age estimation** for the given name.
- **Nationality prediction** (top 3 countries, with probabilities).
- **Settings** to enable/disable age and nationality prediction.
- **Localization** (so far we have German, English but you are welcome to contribute).
- **Info view** with project details and source links.
- **Apple Watch app** with shared settings and live sync via WatchConnectivity.
- **App Group support** for shared UserDefaults across iOS and watchOS targets.

---

## 🛠 Architecture

- **SwiftUI** for all UI components.
- **@AppStorage** with a shared `UserDefaults(suiteName:)` for cross-target storage.
- **WatchConnectivity** to synchronize settings between iOS and watchOS devices.
- **Modular networking** with `async/await` and structured error handling (`APIError`).

---

## 🔧 Setup

1. Clone this repository:
   ```bash
   git clone https://github.com/JensDerKrueger/genderApp.git
   cd genderApp
