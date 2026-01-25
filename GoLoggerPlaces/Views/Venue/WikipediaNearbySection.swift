import SwiftUI

struct WikipediaNearbySection: View {
    @ObservedObject var wikipediaService: WikipediaService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nearby Places (Wikipedia)")
                .font(.headline)

            if wikipediaService.isLoading {
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("Loading nearby places...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            } else if !wikipediaService.nearbyPlaces.isEmpty {
                VStack(spacing: 8) {
                    ForEach(wikipediaService.nearbyPlaces) { place in
                        Button(
                            action: {
                                UIApplication.shared.open(place.pageURL)
                            },
                            label: {
                                WikipediaPlaceRow(place: place)
                            }
                        )
                        .buttonStyle(.plain)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }
                }
            } else if let error = wikipediaService.errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            } else {
                Text("No nearby places found")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            }
        }
    }
}
