import SwiftUI

struct WeatherAndTimeSection: View {
    @ObservedObject var weatherService: WeatherService
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Weather & Astronomy")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)

            if isExpanded && weatherService.isLoading {
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("Loading weather...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            } else if isExpanded, let weather = weatherService.currentWeather {
                VStack(spacing: 12) {
                    // Sun & Moon Times
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "sun.max.fill")
                                .foregroundStyle(.orange)
                                .font(.title3)
                            Text("Sun & Twilight")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(formatDayLength(weather.dayLength))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        VStack(spacing: 6) {
                            ForEach(getSortedSunEvents(weather: weather), id: \.label) { event in
                                SunTimeRow(
                                    icon: event.icon,
                                    label: event.label,
                                    time: event.time,
                                    isSubtle: event.isSubtle
                                )
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)

                    // Current Weather
                    VStack(spacing: 12) {
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: weatherService.getWeatherSymbol(for: weather.symbolName))
                                .foregroundStyle(.blue)
                                .font(.title)
                                .frame(width: 40)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text("\(Int(weather.temperatureFahrenheit))°F")
                                        .font(.title2)
                                        .fontWeight(.bold)

                                    Text("\(Int(weather.temperatureCelsius))°C")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }

                                Text(weather.description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Text("Feels like \(Int(weather.feelsLikeFahrenheit))°F")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text(weatherService.getLocalTime())
                                    .font(.headline)

                                Text(weatherService.getTimezoneName())
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Conditions Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            WeatherInfoCell(
                                icon: "wind",
                                label: "Wind",
                                value: String(format: "%.1f mph", weather.windSpeedMph)
                            )
                            WeatherInfoCell(icon: "humidity", label: "Humidity", value: "\(weather.humidityPercentage)%")
                            WeatherInfoCell(icon: "barometer", label: "Pressure", value: "\(weather.pressureHpa) hPa")
                            WeatherInfoCell(
                                icon: "eye",
                                label: "Visibility",
                                value: String(format: "%.1f mi", weather.visibilityMiles)
                            )
                            WeatherInfoCell(icon: "cloud", label: "Cloudiness", value: "\(weather.cloudiness)%")
                            WeatherInfoCell(icon: "sun.max", label: "UV Index", value: "\(weather.uvIndex)")
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)

                    // Hourly Forecast
                    if !weatherService.hourlyForecast.isEmpty {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundStyle(.blue)
                                    .font(.title3)
                                Text("24-Hour Forecast")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Spacer()
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(weatherService.hourlyForecast) { hourly in
                                        HourlyForecastCard(hourly: hourly, timeZone: weatherService.venueTimeZone ?? TimeZone.current)
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }

                    // Apple Weather Attribution
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "cloud.sun.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("Weather by Apple")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            } else if isExpanded, let error = weatherService.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if error.contains("WeatherKit not configured") {
                        Text("To enable weather:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("1. Join Apple Developer Program ($99/year)")
                            Text("2. Enable WeatherKit at developer.apple.com")
                            Text("3. Update provisioning profile in Xcode")
                        }
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = weatherService.venueTimeZone ?? TimeZone.current
        return formatter.string(from: date)
    }

    private func formatDayLength(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return "\(hours)h \(minutes)m daylight"
    }

    private func getSortedSunEvents(weather: WeatherData) -> [SunEvent] {
        let events = [
            SunEvent(
                date: weather.astronomicalDawn,
                icon: "moon.stars",
                label: "Astronomical Dawn",
                time: formatTime(weather.astronomicalDawn),
                isSubtle: true
            ),
            SunEvent(
                date: weather.civilDawn,
                icon: "sun.horizon",
                label: "Civil Dawn",
                time: formatTime(weather.civilDawn),
                isSubtle: true
            ),
            SunEvent(
                date: weather.sunrise,
                icon: "sunrise",
                label: "Sunrise",
                time: formatTime(weather.sunrise),
                isSubtle: false
            ),
            SunEvent(
                date: weather.sunset,
                icon: "sunset",
                label: "Sunset",
                time: formatTime(weather.sunset),
                isSubtle: false
            ),
            SunEvent(
                date: weather.civilDusk,
                icon: "sun.horizon.fill",
                label: "Civil Dusk",
                time: formatTime(weather.civilDusk),
                isSubtle: true
            ),
            SunEvent(
                date: weather.astronomicalDusk,
                icon: "moon.stars.fill",
                label: "Astronomical Dusk",
                time: formatTime(weather.astronomicalDusk),
                isSubtle: true
            )
        ]

        return events.sorted { $0.date < $1.date }
    }
}

struct SunEvent {
    let date: Date
    let icon: String
    let label: String
    let time: String
    let isSubtle: Bool
}

struct HourlyForecastCard: View {
    let hourly: HourlyWeatherData
    let timeZone: TimeZone

    var body: some View {
        VStack(spacing: 6) {
            Text(formatHour(hourly.date))
                .font(.caption)
                .foregroundStyle(.secondary)

            Image(systemName: hourly.symbolName)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(height: 24)

            Text("\(Int(hourly.temperatureFahrenheit))°")
                .font(.subheadline)
                .fontWeight(.semibold)

            if hourly.precipitationChance > 0.1 {
                HStack(spacing: 2) {
                    Image(systemName: "drop.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                    Text("\(hourly.precipitationChancePercentage)%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.thinMaterial)
        .cornerRadius(10)
    }

    private func formatHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        formatter.timeZone = timeZone
        return formatter.string(from: date).lowercased()
    }
}
