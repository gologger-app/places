import Foundation
import CoreLocation
import WeatherKit

/// Current weather data model
struct WeatherData {
    let temperature: Double  // In Celsius
    let feelsLike: Double    // In Celsius
    let description: String
    let symbolName: String
    let humidity: Double     // 0-1 range
    let windSpeed: Double    // meters per second
    let sunrise: Date
    let sunset: Date
    let pressure: Double     // In millibars (hPa)
    let visibility: Double   // In meters
    let cloudCover: Double   // 0-1 range
    let uvIndex: Int
    let latitude: Double
    let longitude: Double

    var temperatureCelsius: Double {
        temperature
    }

    var temperatureFahrenheit: Double {
        temperature * 9/5 + 32
    }

    var feelsLikeFahrenheit: Double {
        feelsLike * 9/5 + 32
    }

    // Calculate day length
    var dayLength: TimeInterval {
        sunset.timeIntervalSince(sunrise)
    }

    // Calculate astronomical twilight times
    var astronomicalDawn: Date {
        calculateTwilight(for: sunrise, angle: -18, isMorning: true)
    }

    var astronomicalDusk: Date {
        calculateTwilight(for: sunset, angle: -18, isMorning: false)
    }

    var civilDawn: Date {
        calculateTwilight(for: sunrise, angle: -6, isMorning: true)
    }

    var civilDusk: Date {
        calculateTwilight(for: sunset, angle: -6, isMorning: false)
    }

    private func calculateTwilight(for reference: Date, angle: Double, isMorning: Bool) -> Date {
        let latitudeRadians = latitude * .pi / 180
        let latitudeFactor = 1.0 / cos(latitudeRadians).magnitude

        let baseDuration = 20.0 * (abs(angle) / 6.0)
        let adjustedDuration = baseDuration * min(latitudeFactor, 3.0)

        let offset = adjustedDuration * 60
        return reference.addingTimeInterval(isMorning ? -offset : offset)
    }

    // Visibility in miles
    var visibilityMiles: Double {
        visibility * 0.000621371
    }

    // Wind speed in mph
    var windSpeedMph: Double {
        windSpeed * 2.23694
    }

    // Humidity as percentage
    var humidityPercentage: Int {
        Int(humidity * 100)
    }

    // Cloud cover as percentage
    var cloudiness: Int {
        Int(cloudCover * 100)
    }

    // Pressure in hPa (same as millibars)
    var pressureHpa: Int {
        Int(pressure)
    }
}

/// Hourly weather forecast data
struct HourlyWeatherData: Identifiable {
    let id = UUID()
    let date: Date
    let temperature: Double        // In Celsius
    let symbolName: String
    let precipitationChance: Double  // 0-1 range
    let precipitationAmount: Double  // In millimeters
    let humidity: Double             // 0-1 range
    let windSpeed: Double            // meters per second
    let uvIndex: Int
    let cloudCover: Double           // 0-1 range

    var temperatureCelsius: Double {
        temperature
    }

    var temperatureFahrenheit: Double {
        temperature * 9/5 + 32
    }

    var precipitationChancePercentage: Int {
        Int(precipitationChance * 100)
    }

    var windSpeedMph: Double {
        windSpeed * 2.23694
    }

    var humidityPercentage: Int {
        Int(humidity * 100)
    }
}

/// Service responsible for fetching weather data using Apple WeatherKit
@MainActor
class WeatherService: ObservableObject {

    // MARK: - Published Properties

    @Published var currentWeather: WeatherData?
    @Published var hourlyForecast: [HourlyWeatherData] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var venueTimeZone: TimeZone?

    // MARK: - Private Properties

    private let weatherKitService = WeatherKit.WeatherService.shared
    private var weatherCache: [String: (weather: WeatherData, hourly: [HourlyWeatherData], timestamp: Date)] = [:]
    private let cacheExpirationInterval: TimeInterval = 600  // 10 minutes

    // MARK: - Public Methods

    /// Fetch weather data for a specific coordinate
    func fetchWeather(for coordinate: CLLocationCoordinate2D) {
        let cacheKey = "\(coordinate.latitude),\(coordinate.longitude)"

        // Check cache first
        if let cached = weatherCache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheExpirationInterval {
            currentWeather = cached.weather
            hourlyForecast = cached.hourly
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            await fetchWeatherData(coordinate: coordinate, cacheKey: cacheKey)
        }
    }

    /// Fetch weather data using WeatherKit
    private func fetchWeatherData(coordinate: CLLocationCoordinate2D, cacheKey: String) async {
        do {
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

            // Fetch both current weather and hourly forecast
            let weather = try await weatherKitService.weather(
                for: location,
                including: .current, .hourly, .daily
            )

            let currentCondition = weather.0  // CurrentWeather
            let hourlyForecast = weather.1    // Forecast<HourForecast>
            let dailyForecast = weather.2     // Forecast<DayForecast>

            // Get today's sunrise/sunset from daily forecast
            let todaySunrise = dailyForecast.first?.sun.sunrise ?? Date()
            let todaySunset = dailyForecast.first?.sun.sunset ?? Date()

            // Create current weather data
            let currentWeatherData = WeatherData(
                temperature: currentCondition.temperature.value,
                feelsLike: currentCondition.apparentTemperature.value,
                description: currentCondition.condition.description,
                symbolName: currentCondition.symbolName,
                humidity: currentCondition.humidity,
                windSpeed: currentCondition.wind.speed.value,
                sunrise: todaySunrise,
                sunset: todaySunset,
                pressure: currentCondition.pressure.value,
                visibility: currentCondition.visibility.value,
                cloudCover: currentCondition.cloudCover,
                uvIndex: currentCondition.uvIndex.value,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )

            // Create hourly forecast data (next 24 hours)
            let hourlyData = hourlyForecast.prefix(24).map { hour in
                HourlyWeatherData(
                    date: hour.date,
                    temperature: hour.temperature.value,
                    symbolName: hour.symbolName,
                    precipitationChance: hour.precipitationChance,
                    precipitationAmount: hour.precipitationAmount.value,
                    humidity: hour.humidity,
                    windSpeed: hour.wind.speed.value,
                    uvIndex: hour.uvIndex.value,
                    cloudCover: hour.cloudCover
                )
            }

            // Update UI on main thread
            self.currentWeather = currentWeatherData
            self.hourlyForecast = Array(hourlyData)
            self.weatherCache[cacheKey] = (currentWeatherData, Array(hourlyData), Date())
            self.isLoading = false

            // Fetch venue's local timezone
            let geocoder = CLGeocoder()
            if let placemark = try? await geocoder.reverseGeocodeLocation(location).first,
               let tz = placemark.timeZone {
                self.venueTimeZone = tz
            }

        } catch {
            print("⚠️ WeatherKit error: \(error.localizedDescription)")
            print("   Error details: \(error)")

            // Handle specific error types
            let nsError = error as NSError

            // Check for WeatherKit authentication errors
            if nsError.domain == "WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors" {
                self.errorMessage = "WeatherKit not configured. Requires Apple Developer Program membership and setup in developer portal."
            } else if nsError.domain == NSURLErrorDomain {
                self.errorMessage = "Network unavailable"
            } else {
                // Generic error message
                self.errorMessage = "Weather data unavailable"
            }

            self.isLoading = false
        }
    }

    /// Get local time for the venue's timezone
    func getLocalTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = venueTimeZone ?? TimeZone.current
        return formatter.string(from: Date())
    }

    /// Get timezone name for the venue's timezone
    func getTimezoneName() -> String {
        let timezone = venueTimeZone ?? TimeZone.current
        return timezone.abbreviation() ?? "UTC"
    }

    /// Get weather icon SF Symbol name (WeatherKit already provides this)
    func getWeatherSymbol(for symbolName: String) -> String {
        return symbolName
    }
}
