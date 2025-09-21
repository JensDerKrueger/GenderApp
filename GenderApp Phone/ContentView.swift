import SwiftUI

// MARK: - Views
struct ContentView: View {
  @AppStorage("guessAgeEnabled", store: Defaults.store) private var guessAgeEnabled: Bool = false
  @AppStorage("guessNationalityEnabled", store: Defaults.store) private var guessNationalityEnabled: Bool = false

  @State private var name: String = ""
  @State private var genderResult: GenderizeResponse?
  @State private var ageResult: AgeResponse?
  @State private var nationalityResult: NationalizeResponse?
  @State private var isLoading = false
  @State private var errorMessage: String?

  @FocusState private var isNameFieldFocused: Bool
  @State private var showSettings = false
  @State private var showInfo = false

  var body: some View {
    NavigationStack {
      Form {
        // INPUT
        Section {
          HStack(spacing: 8) {
            TextField(
              NSLocalizedString("input.placeholder", comment: "Text field placeholder"),
              text: $name
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .submitLabel(.search)
            .onSubmit { fetchGender() }
            .focused($isNameFieldFocused)
            
            Button(NSLocalizedString("button.send", comment: "Send button")) {
              fetchGender()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)
            .accessibilityLabel(Text(NSLocalizedString("a11y.send", comment: "Send request")))
          }
        }
        
        // LOADING
        if isLoading {
          Section {
            HStack {
              ProgressView()
              Text(NSLocalizedString("state.loading", comment: "Loading…"))
            }
          }
        }
        
        // ERROR
        if let error = errorMessage {
          Section {
            Text(error)
              .foregroundColor(.red)
          }
        }
        
        // RESULT
        if let res = genderResult {
          Section(NSLocalizedString("section.result", comment: "Result section title")) {
            let genderText = (res.gender?.capitalized).map {
              NSLocalizedString("gender.\($0.lowercased())", comment: "Gender value")
            } ?? NSLocalizedString("gender.unknown", comment: "Unknown gender")

            HStack {
              Text(NSLocalizedString("label.gender", comment: "Gender label"))
              Spacer()
              Text(genderText)
                .font(.headline)
                .foregroundStyle(GenderColors.forGender(res.gender))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                  RoundedRectangle(cornerRadius: 6)
                    .fill(GenderColors.forGender(res.gender).opacity(0.12))
                )
                .overlay(
                  RoundedRectangle(cornerRadius: 6)
                    .stroke(GenderColors.forGender(res.gender).opacity(0.25), lineWidth: 0.5)
                )
            }

            if let p = res.probability {
              ProbabilityBar(probability: p)
            } else {
              Text(NSLocalizedString("probability.unavailable", comment: "No probability available"))
                .font(.caption)
                .foregroundColor(.secondary)
            }

            if let count = res.count, let n = res.name {
              let line = String(
                format: NSLocalizedString("result.samples-line", comment: "Based on X samples for name"),
                count, n
              )
              Text(line)
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }

          // Age (if enabled)
          if guessAgeEnabled, let ar = ageResult {
            HStack {
              Text(NSLocalizedString("label.age", comment: "Age label"))
              Spacer()
              Text(ar.age.map { String($0) } ?? NSLocalizedString("age.unknown", comment: "Unknown age"))
                .font(.headline)
            }
            if let ac = ar.count, let an = ar.name {
              let ageLine = String(
                format: NSLocalizedString("result.samples-line", comment: "Based on X samples for name"),
                ac, an
              )
              Text(ageLine)
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }

          // Nationality (if enabled)
          if guessNationalityEnabled, let nr = nationalityResult, let countries = nr.country, !countries.isEmpty {
            Text(NSLocalizedString("label.nationality", comment: "Nationality label"))
              .font(.headline)

            // Top 3 Länder anzeigen
            ForEach(Array(countries.prefix(3).enumerated()), id: \.offset) { _, c in
              let code = c.country_id ?? "?"
              let name = LocaleHelper.countryName(for: code)
              let prob = max(0, min(c.probability ?? 0, 1))
              HStack {
                Text("\(name) (\(code))")
                Spacer()
                Text("\(Int(prob * 100))%")
                  .monospacedDigit()
              }
            }

            if let nc = nr.count, let nn = nr.name {
              let natLine = String(
                format: NSLocalizedString("result.samples-line", comment: "Based on X samples for name"),
                nc, nn
              )
              Text(natLine)
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }
      }
      .navigationTitle(NSLocalizedString("title.app", comment: "Navigation title"))
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            // Info Sheet anzeigen
            showInfo = true
          } label: {
            Image(systemName: "info.circle")
          }
          .accessibilityLabel(Text(NSLocalizedString("info.open", comment: "Open info")))
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            showSettings = true
          } label: {
            Image(systemName: "gear")
          }
          .accessibilityLabel(Text(NSLocalizedString("settings.open", comment: "Open settings")))
        }
      }
      .sheet(isPresented: $showSettings, onDismiss: {
        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          fetchGender()
        }
      }) {
        AppSettingsView()
      }
      .sheet(isPresented: $showInfo) {
        InfoView()
      }
      .task {
        await Task.yield()
        isNameFieldFocused = true
      }
    }
  }

  // MARK: - Networking
  private func fetchGender() {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      errorMessage = NSLocalizedString("error.empty-name", comment: "Please enter a name")
      genderResult = nil
      return
    }

    var components = URLComponents(string: "https://api.genderize.io/")!
    components.queryItems = [URLQueryItem(name: "name", value: trimmed)]
    guard let genderURL = components.url else {
      errorMessage = NSLocalizedString("error.invalid-name", comment: "Invalid name")
      genderResult = nil
      return
    }

    var ageURL: URL? = nil
    if guessAgeEnabled {
      var ageComponents = URLComponents(string: "https://api.agify.io")!
      ageComponents.queryItems = [URLQueryItem(name: "name", value: trimmed)]
      ageURL = ageComponents.url
    }

    var nationalityURL: URL? = nil
    if guessNationalityEnabled {
      var natComponents = URLComponents(string: "https://api.nationalize.io/")!
      natComponents.queryItems = [URLQueryItem(name: "name", value: trimmed)]
      nationalityURL = natComponents.url
    }

    isLoading = true
    errorMessage = nil

    Task {
      defer { isLoading = false }
      do {
        // Required: gender — wirft bei Fehler APIError
        let gender: GenderizeResponse = try await makeRequest(genderURL, as: GenderizeResponse.self)
        self.genderResult = gender

        // Optional: age — Fehler werden weich „geschluckt“
        if let aURL = ageURL {
          self.ageResult = try? await makeRequest(aURL, as: AgeResponse.self)
        } else {
          self.ageResult = nil
        }

        // Optional: nationality — Fehler werden weich „geschluckt“
        if let nURL = nationalityURL {
          self.nationalityResult = try? await makeRequest(nURL, as: NationalizeResponse.self)
        } else {
          self.nationalityResult = nil
        }

      } catch let api as APIError {
        errorMessage = api.errorDescription
        genderResult = nil
        ageResult = nil
        nationalityResult = nil
      } catch {
        errorMessage = NSLocalizedString("error.fetch", comment: "Generic fetch error")
        genderResult = nil
        ageResult = nil
        nationalityResult = nil
      }
      isLoading = false
    }
  }
}

// MARK: - ProbabilityBar
struct ProbabilityBar: View {
  let probability: Double

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(NSLocalizedString("label.probability", comment: "Probability"))

      GeometryReader { geo in
        let clamped = max(0, min(probability, 1))
        let barColor = ProbabilityColors.forProbability(clamped)

        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 8)
            .fill(Color(.systemGray5))

          RoundedRectangle(cornerRadius: 8)
            .frame(width: geo.size.width * clamped)
            .foregroundStyle(barColor)
            .animation(.easeOut(duration: 0.25), value: clamped)
        }
        .accessibilityLabel(Text(NSLocalizedString("a11y.probability", comment: "Probability")))
        .accessibilityValue(Text("\(Int(clamped * 100))%"))
      }
      .frame(height: 14)

      let percent = Int(probability * 100)
      Text(String(
        format: NSLocalizedString("probability.percent", comment: "Percent format"),
        percent
      ))
      .font(.caption)
      .monospacedDigit()
      .foregroundStyle(ProbabilityColors.forProbability(max(0, min(probability, 1))))
    }
  }
}

// MARK: - In-App Settings View
struct AppSettingsView: View {
  @AppStorage("guessAgeEnabled", store: Defaults.store) private var guessAgeEnabled: Bool = false
  @AppStorage("guessNationalityEnabled", store: Defaults.store) private var guessNationalityEnabled: Bool = false
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section(NSLocalizedString("settings.general", comment: "")) {
          Toggle(NSLocalizedString("settings.age", comment: ""), isOn: $guessAgeEnabled)
          Toggle(NSLocalizedString("settings.nationality", comment: ""), isOn: $guessNationalityEnabled)
        }
      }
      .navigationTitle(NSLocalizedString("settings.title", comment: ""))
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(NSLocalizedString("button.done", comment: "Done")) {
            dismiss()
          }
        }
      }
    }
  }
}

// MARK: - Info View
struct InfoView: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          let introFormat = NSLocalizedString("info.intro", comment: "Intro with placeholders for group and university")
          let uniText = NSLocalizedString("university", comment: "University name")
          let uniLink = NSLocalizedString("university.link", comment: "University URL")
          let groupText = NSLocalizedString("group", comment: "Chair name")
          let groupLink = NSLocalizedString("group.link", comment: "Chair URL")

          let attributed: AttributedString = {
            var a = AttributedString(String(format: introFormat, groupText, uniText))
            if let rGroup = a.range(of: groupText), let urlGroup = URL(string: groupLink) {
              a[rGroup].link = urlGroup
            }
            if let rUni = a.range(of: uniText), let urlUni = URL(string: uniLink) {
              a[rUni].link = urlUni
            }
            return a
          }()

          Text(attributed)
            .fixedSize(horizontal: false, vertical: true)


          Text(NSLocalizedString("info.datasources", comment: "Intro about data sources"))

          VStack(alignment: .leading, spacing: 8) {
            Link("Genderize", destination: URL(string: "https://genderize.io")!)
            Link("Agify", destination: URL(string: "https://agify.io")!)
            Link("Nationalize", destination: URL(string: "https://nationalize.io")!)
          }

          Text(NSLocalizedString("info.disclaimer", comment: "Disclaimer about data sources"))
          .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
      }
      .navigationTitle("Info")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(NSLocalizedString("button.done", comment: "Done")) {
            dismiss()
          }
        }
      }
    }
  }
}

