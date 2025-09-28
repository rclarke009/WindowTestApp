import SwiftUI
import CoreData

// MARK: - Notification Names
extension Notification.Name {
    static let jobDataUpdated = Notification.Name("jobDataUpdated")
    static let newJobCreated = Notification.Name("newJobCreated")
}

struct EnvironmentalDataView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    let job: Job
    
    @State private var temperature: Double = 72.0
    @State private var weatherCondition: String = "Clear"
    @State private var humidity: Double = 50.0
    @State private var windSpeed: Double = 5.0
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @StateObject private var weatherService = WeatherService()
    
    private let weatherConditions = ["Clear", "Partly Cloudy", "Cloudy", "Overcast", "Rain", "Snow", "Fog", "Windy"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Temperature") {
                    HStack {
                        Text("Temperature")
                        Spacer()
                        Text("\(Int(temperature))°F")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $temperature, in: 0...120, step: 1)
                        .accentColor(temperatureColor)
                    
                    HStack {
                        Text("0°F")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("120°F")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Weather Conditions") {
                    Picker("Weather", selection: $weatherCondition) {
                        ForEach(weatherConditions, id: \.self) { condition in
                            Text(condition).tag(condition)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Humidity") {
                    HStack {
                        Text("Humidity")
                        Spacer()
                        Text("\(Int(humidity))%")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $humidity, in: 0...100, step: 1)
                        .accentColor(.blue)
                    
                    HStack {
                        Text("0%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("100%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Wind Speed") {
                    HStack {
                        Text("Wind Speed")
                        Spacer()
                        Text("\(Int(windSpeed)) mph")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $windSpeed, in: 0...50, step: 1)
                        .accentColor(.green)
                    
                    HStack {
                        Text("0 mph")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("50 mph")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Quick Actions") {
                    Button(action: fetchWeatherForJob) {
                        HStack {
                            if weatherService.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "cloud.sun")
                            }
                            Text("Fetch Weather for Job Location")
                        }
                    }
                    .disabled(weatherService.isLoading || job.addressLine1?.isEmpty != false)
                    
                    Button("Reset to Defaults") {
                        temperature = 72.0
                        weatherCondition = "Clear"
                        humidity = 50.0
                        windSpeed = 5.0
                    }
                }
            }
            .navigationTitle("Environmental Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveEnvironmentalData()
                    }
                }
            }
            .onAppear {
                loadExistingData()
            }
            .alert("Environmental Data", isPresented: $showingAlert) {
                Button("OK") {
                    if alertMessage.contains("saved") {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private var temperatureColor: Color {
        switch temperature {
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
    
    private func loadExistingData() {
        temperature = job.temperature > 0 ? job.temperature : 72.0
        weatherCondition = job.weatherCondition ?? "Clear"
        humidity = job.humidity > 0 ? job.humidity : 50.0
        windSpeed = job.windSpeed > 0 ? job.windSpeed : 5.0
    }
    
    private func saveEnvironmentalData() {
        job.temperature = temperature
        job.weatherCondition = weatherCondition
        job.humidity = humidity
        job.windSpeed = windSpeed
        job.updatedAt = Date()
        
        do {
            try viewContext.save()
            
            // Post notification to refresh UI
            NotificationCenter.default.post(name: .jobDataUpdated, object: job)
            
            alertMessage = "Environmental data saved successfully!"
            showingAlert = true
        } catch {
            alertMessage = "Failed to save environmental data: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func fetchWeatherForJob() {
        guard let addressLine1 = job.addressLine1,
              let city = job.city,
              let state = job.state,
              let zip = job.zip else {
            alertMessage = "Job address is incomplete. Please add a complete address first."
            showingAlert = true
            return
        }
        
        let fullAddress = "\(addressLine1), \(city), \(state) \(zip)"
        
        weatherService.fetchWeather(for: fullAddress) { result in
            switch result {
            case .success(let weatherData):
                temperature = weatherData.temperature
                humidity = weatherData.humidity
                windSpeed = weatherData.windSpeed
                weatherCondition = weatherData.condition.toWeatherCondition()
                
                alertMessage = "Weather data fetched successfully!"
                showingAlert = true
                
            case .failure(let error):
                alertMessage = "Failed to fetch weather: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let job = Job(context: context)
    job.jobId = "E2025-05091"
    job.clientName = "Smith"
    job.temperature = 75.0
    job.weatherCondition = "Partly Cloudy"
    job.humidity = 60.0
    job.windSpeed = 8.0
    
    return EnvironmentalDataView(job: job)
        .environment(\.managedObjectContext, context)
}
