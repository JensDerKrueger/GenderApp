import SwiftUI

// MARK: - Errors & Networking Helpers
enum APIError: LocalizedError {
  case unauthorized(message: String?)        // 401
  case paymentRequired(message: String?)     // 402
  case unprocessable(message: String?)       // 422 (missing/invalid name)
  case tooManyRequests(message: String?)     // 429
  case decoding
  case network(URLError)
  case unknown(message: String?)

  var errorDescription: String? {
    switch self {
      case .unauthorized:
        return NSLocalizedString("error.unauthorized", comment: "Invalid API key")
      case .paymentRequired:
        return NSLocalizedString("error.payment", comment: "Subscription is not active")
      case .unprocessable:
        return NSLocalizedString("error.unprocessable", comment: "Invalid or missing name parameter")
      case .tooManyRequests:
        return NSLocalizedString("error.too-many", comment: "Too many requests")
      case .decoding:
        return NSLocalizedString("error.decoding", comment: "Failed to decode server response")
      case .network(let e):
        return e.localizedDescription
      case .unknown(let msg):
        return msg ?? NSLocalizedString("error.fetch", comment: "Generic fetch error")
    }
  }

  static func from(_ http: HTTPURLResponse, _ data: Data?) -> APIError {
    let message = (try? JSONDecoder().decode([String:String].self, from: data ?? Data()))?["error"]
    switch http.statusCode {
      case 401: return .unauthorized(message: message)
      case 402: return .paymentRequired(message: message)
      case 422: return .unprocessable(message: message)
      case 429: return .tooManyRequests(message: message)
      default:  return .unknown(message: message)
    }
  }
}

func makeRequest<T: Decodable>(_ url: URL, as type: T.Type) async throws -> T {
  do {
    let (data, resp) = try await URLSession.shared.data(from: url)
    guard let http = resp as? HTTPURLResponse else { throw APIError.unknown(message: nil) }
    guard (200..<300).contains(http.statusCode) else { throw APIError.from(http, data) }
    do { return try JSONDecoder().decode(T.self, from: data) }
    catch { throw APIError.decoding }
  } catch let e as URLError {
    throw APIError.network(e)
  }
  }
