import SwiftUI

struct WatchContentView: View {
  @AppStorage("guessAgeEnabled", store: Defaults.store) private var guessAgeEnabled: Bool = false
  @AppStorage("guessNationalityEnabled", store: Defaults.store) private var guessNationalityEnabled: Bool = false

  @State private var name: String = ""
  @State private var genderResult: GenderizeResponse?
  @State private var ageResult: AgeResponse?
  @State private var nationalityResult: NationalizeResponse?

  @State private var isLoading = false
  @State private var errorMessage: String?

  var body: some View {
    List {
      Section {
        TextField(NSLocalizedString("input.placeholder", comment: ""), text: $name)
          .textInputAutocapitalization(.never)
          .submitLabel(.search)
          .onSubmit(fetch)

        Button {
          fetch()
        } label: {
          if isLoading { ProgressView() } else { Text(NSLocalizedString("button.send", comment: "")) }
        }
        .disabled(isLoading || name.trimmed.isEmpty)
        .buttonStyle(.borderedProminent)
      }

      if let error = errorMessage {
        Section { Text(error).foregroundStyle(.red) }
      }

      if let res = genderResult {
        Section(NSLocalizedString("section.result", comment: "")) {
          let genderText = (res.gender?.capitalized).map {
            NSLocalizedString("gender.\($0.lowercased())", comment: "")
          } ?? NSLocalizedString("gender.unknown", comment: "")

          LabeledContent(NSLocalizedString("label.gender", comment: "")) {
            Text(genderText)
              .font(.headline)
              .foregroundStyle(GenderColors.forGender(res.gender))
          }

          if let p = res.probability {
            MiniBar(value: p, label: "\(Int(p * 100))%")
          } else {
            Text(NSLocalizedString("probability.unavailable", comment: ""))
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          if let count = res.count, let n = res.name {
            Text(String(format: NSLocalizedString("result.samples-line", comment: ""), count, n))
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          // Alter (optional)
          if guessAgeEnabled, let ar = ageResult {
            LabeledContent(NSLocalizedString("label.age", comment: "")) {
              Text(ar.age.map(String.init) ?? NSLocalizedString("age.unknown", comment: ""))
                .font(.headline)
            }
            if let ac = ar.count, let an = ar.name {
              Text(String(format: NSLocalizedString("result.samples-line", comment: ""), ac, an))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }

          // Nationalität (optional, Top 3)
          if guessNationalityEnabled,
             let nr = nationalityResult,
             let countries = nr.country, !countries.isEmpty {
            Text(NSLocalizedString("label.nationality", comment: ""))
              .font(.headline)
            ForEach(Array(countries.prefix(3).enumerated()), id: \.offset) { _, c in
              let code = c.country_id ?? "?"
              let cname = LocaleHelper.countryName(for: code)
              let prob = max(0, min(c.probability ?? 0, 1))
              HStack {
                Text("\(cname) (\(code))")
                Spacer(minLength: 8)
                MiniBar(value: prob, label: "\(Int(prob * 100))%")
              }
            }
            if let nc = nr.count, let nn = nr.name {
              Text(String(format: NSLocalizedString("result.samples-line", comment: ""), nc, nn))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
    }
    .navigationTitle(Text(NSLocalizedString("title.app", comment: "")))
  }

  private func fetch() {
    let trimmed = name.trimmed
    guard !trimmed.isEmpty else {
      errorMessage = NSLocalizedString("error.empty-name", comment: "")
      genderResult = nil; ageResult = nil; nationalityResult = nil
      return
    }

    // URLs
    var g = URLComponents(string: "https://api.genderize.io/")!
    g.queryItems = [URLQueryItem(name: "name", value: trimmed)]
    let genderURL = g.url!

    var ageURL: URL? = nil
    if guessAgeEnabled {
      var a = URLComponents(string: "https://api.agify.io")!
      a.queryItems = [URLQueryItem(name: "name", value: trimmed)]
      ageURL = a.url
    }

    var natURL: URL? = nil
    if guessNationalityEnabled {
      var n = URLComponents(string: "https://api.nationalize.io/")!
      n.queryItems = [URLQueryItem(name: "name", value: trimmed)]
      natURL = n.url
    }

    isLoading = true
    errorMessage = nil

    Task {
      defer { isLoading = false }
      do {
        // Falls du `makeRequest`/`APIError` teilst, nutze das:
        let gender: GenderizeResponse = try await makeRequest(genderURL, as: GenderizeResponse.self)
        self.genderResult = gender

        if let aURL = ageURL {
          self.ageResult = try? await makeRequest(aURL, as: AgeResponse.self)
        } else { self.ageResult = nil }

        if let nURL = natURL {
          self.nationalityResult = try? await makeRequest(nURL, as: NationalizeResponse.self)
        } else { self.nationalityResult = nil }

      } catch let api as APIError {
        self.errorMessage = api.errorDescription
        self.genderResult = nil; self.ageResult = nil; self.nationalityResult = nil
      } catch {
        self.errorMessage = NSLocalizedString("error.fetch", comment: "")
        self.genderResult = nil; self.ageResult = nil; self.nationalityResult = nil
      }
    }
  }
}

// Kompakter Balken für die Watch
private struct MiniBar: View {
  let value: Double   // 0...1
  let label: String

  var body: some View {
    GeometryReader { geo in
      let w = max(0, min(value, 1)) * geo.size.width
      ZStack(alignment: .leading) {
        Capsule().fill(Color(.gray))
        Capsule().frame(width: w).foregroundStyle(ProbabilityColors.forProbability(value))
      }
    }
    .frame(height: 10)
    .overlay(alignment: .trailing) {
      Text(label).font(.caption2).monospacedDigit()
    }
  }
}

private extension String {
  var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
