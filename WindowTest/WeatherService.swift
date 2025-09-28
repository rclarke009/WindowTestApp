import Foundation
import CoreLocation

// MARK: - Weather Models
struct WeatherResponse: Codable {
    let current: CurrentWeather
}

struct CurrentWeather: Codable {
    let tempF: Double
    let humidity: Double
    let windMph: Double
    let condition: WeatherCondition
    
    enum CodingKeys: String, CodingKey {
        case tempF = "temp_f"
        case humidity
        case windMph = "wind_mph"
        case condition
    }
}

struct WeatherCondition: Codable {
    let text: String
}

// MARK: - Weather Service
class WeatherService: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?
    
    // Using OpenWeatherMap API (free tier available)
    // You'll need to sign up at https://openweathermap.org/api for an API key
    private let apiKey = "YOUR_API_KEY_HERE" // Replace with your actual API key
    private let baseURL = "https://api.weatherapi.com/v1/current.json"
    
    func fetchWeather(for address: String, completion: @escaping (Result<WeatherData, Error>) -> Void) {
        isLoading = true
        error = nil
        
        // First, geocode the address to get coordinates
        geocodeAddress(address) { [weak self] result in
            switch result {
            case .success(let coordinates):
                self?.fetchWeatherForCoordinates(coordinates, completion: completion)
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.error = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func geocodeAddress(_ address: String, completion: @escaping (Result<CLLocationCoordinate2D, Error>) -> Void) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                completion(.failure(WeatherError.locationNotFound))
                return
            }
            
            completion(.success(location.coordinate))
        }
    }
    
    private func fetchWeatherForCoordinates(_ coordinates: CLLocationCoordinate2D, completion: @escaping (Result<WeatherData, Error>) -> Void) {
        let urlString = "\(baseURL)?key=\(apiKey)&q=\(coordinates.latitude),\(coordinates.longitude)"
        
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.error = "Invalid URL"
                completion(.failure(WeatherError.invalidURL))
            }
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.error = error.localizedDescription
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    self.error = "No data received"
                    completion(.failure(WeatherError.noData))
                    return
                }
                
                do {
                    let weatherResponse = try JSONDecoder().decode(WeatherResponse.self, from: data)
                    let weatherData = WeatherData(
                        temperature: weatherResponse.current.tempF,
                        humidity: weatherResponse.current.humidity,
                        windSpeed: weatherResponse.current.windMph,
                        condition: weatherResponse.current.condition.text
                    )
                    completion(.success(weatherData))
                } catch {
                    self.error = "Failed to parse weather data: \(error.localizedDescription)"
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}

// MARK: - Weather Data Model
struct WeatherData {
    let temperature: Double
    let humidity: Double
    let windSpeed: Double
    let condition: String
}

// MARK: - Weather Errors
enum WeatherError: LocalizedError {
    case locationNotFound
    case invalidURL
    case noData
    
    var errorDescription: String? {
        switch self {
        case .locationNotFound:
            return "Could not find location for the given address"
        case .invalidURL:
            return "Invalid weather API URL"
        case .noData:
            return "No weather data received"
        }
    }
}

// MARK: - Weather Condition Mapping
extension String {
    func toWeatherCondition() -> String {
        let lowercased = self.lowercased()
        
        if lowercased.contains("clear") {
            return "Clear"
        } else if lowercased.contains("sunny") {
            return "Clear"
        } else if lowercased.contains("partly cloudy") || lowercased.contains("partially cloudy") {
            return "Partly Cloudy"
        } else if lowercased.contains("cloudy") {
            return "Cloudy"
        } else if lowercased.contains("overcast") {
            return "Overcast"
        } else if lowercased.contains("rain") || lowercased.contains("shower") {
            return "Rain"
        } else if lowercased.contains("snow") {
            return "Snow"
        } else if lowercased.contains("fog") || lowercased.contains("mist") {
            return "Fog"
        } else if lowercased.contains("wind") {
            return "Windy"
        } else {
            return "Clear" // Default fallback
        }
    }
}
