import SwiftUI

// MARK: - Color Utilities
struct GenderColors {
  static func forGender(_ gender: String?) -> Color {
    switch gender?.lowercased() {
      case "male":   return .blue
      case "female": return .pink
      default:       return .secondary
    }
  }
}

struct ProbabilityColors {
  static func forProbability(_ p: Double) -> Color {
    let clamped = max(0, min(p, 1))
    if clamped >= 0.95 { return .green }
    if clamped >= 0.80 { return .yellow }
    if clamped >= 0.60 { return .orange }
    return .red
  }
}
