import SwiftUI

struct LocaleHelper {
  static func countryName(for code: String) -> String {
    Locale.current.localizedString(forRegionCode: code) ?? code
  }
}
