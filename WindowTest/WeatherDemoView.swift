import SwiftUI
import CoreLocation

struct WeatherDemoView: View {
    @StateObject private var weatherService = WeatherService()
    @State private var address = "408 2nd Ave NW, Largo, FL 33770"
    @State private var weatherData: WeatherData?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Weather Service Demo")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Test Address:")
                        .font(.headline)
                    TextField("Enter job address", text: $address)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                }
                
                Button(action: fetchWeather) {
                    HStack {
                        if weatherService.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "cloud.sun")
                        }
                        Text("Fetch Weather")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(weatherService.isLoading || address.isEmpty)
                .padding(.horizontal)
                
                if let data = weatherData {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Weather")
                            .font(.headline)
                            .padding(.top)
                        
                        WeatherDataRow(label: "Temperature", value: "\(Int(data.temperature))°F", color: temperatureColor(data.temperature))
                        WeatherDataRow(label: "Condition", value: data.condition, color: .blue)
                        WeatherDataRow(label: "Humidity", value: "\(Int(data.humidity))%", color: .cyan)
                        WeatherDataRow(label: "Wind Speed", value: "\(Int(data.windSpeed)) mph", color: .green)
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                if let error = weatherService.error {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Weather Demo")
            .alert("Weather Update", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func fetchWeather() {
        weatherService.fetchWeather(for: address) { result in
            switch result {
            case .success(let data):
                weatherData = data
                alertMessage = "Weather data fetched successfully!"
                showingAlert = true
                
            case .failure(let error):
                alertMessage = "Failed to fetch weather: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
    
    private func temperatureColor(_ temp: Double) -> Color {
        switch temp {
        case 0..<32:
            return .blue
        case 32..<50:
            return .cyan
        case 50..<70:
            return .green
        case 70..<85:
            return .orange
        case 85...:
            return .red
        default:
            return .gray
        }
    }
}

struct WeatherDataRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

#Preview {
    WeatherDemoView()
}
