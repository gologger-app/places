import SwiftUI

/// Row view for displaying a Wikipedia nearby place
struct WikipediaPlaceRow: View {
    let place: WikipediaPlace

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Thumbnail
            AsyncImage(url: place.thumbnailURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 60, height: 60)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                case .failure:
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .frame(width: 60, height: 60)
                        .background(Color.gray.opacity(0.1))
                @unknown default:
                    EmptyView()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(place.title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(place.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                    Text(distanceFormatted)
                        .font(.caption2)
                }
                .foregroundColor(.blue)
            }

            Spacer()

            // External link indicator
            Image(systemName: "arrow.up.right.square")
                .font(.body)
                .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
    }

    private var distanceFormatted: String {
        return "\(MeasurementFormatter.formatDistance(place.distance)) away"
    }
}

#Preview {
    List {
        WikipediaPlaceRow(
            place: WikipediaPlace(
                id: 1,
                title: "Sample Location",
                summary: "This is a sample summary of a Wikipedia article about a nearby place.",
                thumbnailURL: nil,
                pageURL: URL(string: "https://wikipedia.org")!,
                distance: 250,
                latitude: 37.7749,
                longitude: -122.4194
            )
        )
    }
}
