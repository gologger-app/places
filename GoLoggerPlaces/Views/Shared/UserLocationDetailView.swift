import SwiftUI
import CoreLocation

/// Detailed view showing user's location information including weather and nearby places
struct UserLocationDetailView: View {
    let location: CLLocation
    let address: String?

    @StateObject private var weatherService = WeatherService()
    @StateObject private var wikipediaService = WikipediaService()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Address Section
                    if let address = address {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Address", systemImage: "mappin.circle.fill")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Text(address)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }

                    // Coordinates Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Coordinates", systemImage: "location.fill")
                            .font(.headline)
                            .foregroundColor(.primary)

                        HStack {
                            Text("Latitude:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.6f°", location.coordinate.latitude))
                                .monospacedDigit()
                        }

                        HStack {
                            Text("Longitude:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.6f°", location.coordinate.longitude))
                                .monospacedDigit()
                        }

                        HStack {
                            Text("Altitude:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(MeasurementFormatter.formatAltitude(location.altitude))
                                .monospacedDigit()
                        }

                        if location.horizontalAccuracy > 0 {
                            HStack {
                                Text("Accuracy:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(MeasurementFormatter.formatDistance(location.horizontalAccuracy))
                                    .monospacedDigit()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)

                    // Weather Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Weather", systemImage: "cloud.sun.fill")
                            .font(.headline)
                            .foregroundColor(.primary)

                        if weatherService.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if let error = weatherService.errorMessage {
                            Text(error)
                                .foregroundColor(.secondary)
                                .font(.callout)
                        } else if let weather = weatherService.currentWeather {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: weather.symbolName)
                                        .font(.system(size: 40))
                                        .foregroundColor(.blue)

                                    VStack(alignment: .leading) {
                                        Text(MeasurementFormatter.formatTemperature(weather.temperature))
                                            .font(.system(size: 32, weight: .semibold))
                                        Text(weather.description)
                                            .font(.callout)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()
                                }

                                Divider()

                                // Additional weather details
                                HStack {
                                    WeatherDetailItem(
                                        icon: "thermometer",
                                        label: "Feels like",
                                        value: MeasurementFormatter.formatTemperature(weather.feelsLike)
                                    )
                                    Spacer()
                                    WeatherDetailItem(
                                        icon: "humidity.fill",
                                        label: "Humidity",
                                        value: "\(weather.humidityPercentage)%"
                                    )
                                }

                                HStack {
                                    WeatherDetailItem(
                                        icon: "wind",
                                        label: "Wind",
                                        value: MeasurementFormatter.formatSpeed(weather.windSpeed)
                                    )
                                    Spacer()
                                    WeatherDetailItem(
                                        icon: "sun.max.fill",
                                        label: "UV Index",
                                        value: "\(weather.uvIndex)"
                                    )
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)

                    // Wikipedia Nearby Places Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Nearby Places", systemImage: "mappin.and.ellipse")
                            .font(.headline)
                            .foregroundColor(.primary)

                        if wikipediaService.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if let error = wikipediaService.errorMessage {
                            Text(error)
                                .foregroundColor(.secondary)
                                .font(.callout)
                        } else if wikipediaService.nearbyPlaces.isEmpty {
                            Text("No nearby places found")
                                .foregroundColor(.secondary)
                                .font(.callout)
                        } else {
                            ForEach(Array(wikipediaService.nearbyPlaces.prefix(5).enumerated()), id: \.element.id) { index, place in
                                WikipediaPlaceCard(
                                    place: place,
                                    isLast: index == min(4, wikipediaService.nearbyPlaces.count - 1)
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Your Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Fetch weather and Wikipedia data
                weatherService.fetchWeather(for: location.coordinate)
                wikipediaService.fetchNearbyPlaces(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            }
        }
    }
}

/// Small weather detail item component
struct WeatherDetailItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.callout)
                .fontWeight(.medium)
        }
    }
}

/// Wikipedia place card component
struct WikipediaPlaceCard: View {
    let place: WikipediaPlace
    let isLast: Bool

    var body: some View {
        SwiftUI.Link(destination: place.pageURL) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(place.summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    Text(MeasurementFormatter.formatDistance(place.distance))
                        .font(.caption2)
                        .foregroundColor(.blue)
                }

                Spacer()

                Image(systemName: "arrow.up.forward.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
            }
            .padding(.vertical, 8)
        }

        if !isLast {
            Divider()
        }
    }
}

#Preview {
    UserLocationDetailView(
        location: CLLocation(latitude: 37.7749, longitude: -122.4194),
        address: "San Francisco, CA"
    )
}
