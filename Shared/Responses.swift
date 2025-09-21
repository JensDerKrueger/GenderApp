// MARK: - Model
struct GenderizeResponse: Decodable {
  let count: Int?
  let name: String?
  let gender: String?
  let probability: Double?
}

struct AgeResponse: Decodable {
  let count: Int?
  let name: String?
  let age: Int?
}

struct NationalizeCountry: Decodable {
  let country_id: String?
  let probability: Double?
}

struct NationalizeResponse: Decodable {
  let count: Int?
  let name: String?
  let country: [NationalizeCountry]?
}
