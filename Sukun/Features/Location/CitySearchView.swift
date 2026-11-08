import SukunKit
import SwiftUI

/// Manual location entry. Uses Apple Maps search; nothing is sent anywhere else.
struct CitySearchView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [PlaceSearchResult] = []
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            List {
                if !model.isLocationDenied {
                    Section {
                        Button {
                            model.useDeviceLocation()
                            dismiss()
                        } label: {
                            Label("Use current location", systemImage: "location.fill")
                                .foregroundStyle(Palette.text)
                        }
                    }
                }
                Section {
                    ForEach(results) { result in
                        Button {
                            model.useManualLocation(result.location)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .font(.sukunBody)
                                    .foregroundStyle(Palette.text)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.footnote)
                                        .foregroundStyle(Palette.secondaryText)
                                }
                            }
                        }
                        .accessibilityLabel(Text("\(result.title), \(result.subtitle)"))
                    }
                } footer: {
                    if results.isEmpty && query.count >= 2 && !isSearching {
                        Text("No places found.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("City"))
            .task(id: query) {
                // Debounce typing.
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                isSearching = true
                results = await PlaceSearch.search(query)
                isSearching = false
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
