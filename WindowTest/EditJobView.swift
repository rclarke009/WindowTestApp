import SwiftUI
import CoreData

struct EditJobView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    let job: Job
    
    // Job fields
    @State private var jobId: String
    @State private var clientName: String
    @State private var addressLine1: String
    @State private var city: String
    @State private var state: String
    @State private var zip: String
    @State private var notes: String
    @State private var inspectorName: String
    @State private var inspectionDate: Date
    @State private var status: String
    
    // Overhead image fields
    @State private var overheadImageSourceName: String
    @State private var overheadImageSourceUrl: String
    @State private var scalePixelsPerFoot: String
    
    // UI state
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    private let statusOptions = ["Ready", "In Progress", "Completed", "Failed"]
    
    init(job: Job) {
        self.job = job
        _jobId = State(initialValue: job.jobId ?? "")
        _clientName = State(initialValue: job.clientName ?? "")
        _addressLine1 = State(initialValue: job.addressLine1 ?? "")
        _city = State(initialValue: job.city ?? "")
        _state = State(initialValue: job.state ?? "")
        _zip = State(initialValue: job.zip ?? "")
        _notes = State(initialValue: job.notes ?? "")
        _inspectorName = State(initialValue: job.inspectorName ?? "")
        _inspectionDate = State(initialValue: job.inspectionDate ?? Date())
        _status = State(initialValue: job.status ?? "Ready")
        _overheadImageSourceName = State(initialValue: job.overheadImageSourceName ?? "")
        _overheadImageSourceUrl = State(initialValue: job.overheadImageSourceUrl ?? "")
        _scalePixelsPerFoot = State(initialValue: String(job.scalePixelsPerFoot))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Job Information") {
                    TextField("Job ID", text: $jobId)
                        .textInputAutocapitalization(.characters)
                    TextField("Client Name", text: $clientName)
                    TextField("Address Line 1", text: $addressLine1)
                    HStack {
                        TextField("City", text: $city)
                        TextField("State", text: $state)
                            .frame(width: 80)
                        TextField("ZIP", text: $zip)
                            .frame(width: 100)
                    }
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Inspector Information") {
                    TextField("Inspector Name", text: $inspectorName)
                    DatePicker("Inspection Date", selection: $inspectionDate, displayedComponents: .date)
                    Picker("Status", selection: $status) {
                        ForEach(statusOptions, id: \.self) { status in
                            Text(status).tag(status)
                        }
                    }
                }
                
                Section("Overhead Image") {
                    TextField("Source Name (e.g., County Property Appraiser)", text: $overheadImageSourceName)
                    TextField("Source URL", text: $overheadImageSourceUrl)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                    TextField("Scale (pixels per foot)", text: $scalePixelsPerFoot)
                        .keyboardType(.decimalPad)
                    
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        HStack {
                            Image(systemName: "photo")
                            if selectedImage != nil {
                                Text("Overhead Image Selected")
                                    .foregroundColor(.green)
                            } else {
                                Text("Select Overhead Image")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                    }
                }
                
                Section("Environmental Data") {
                    HStack {
                        Image(systemName: "thermometer")
                            .foregroundColor(.orange)
                        Text("Temperature: \(job.temperature > 0 ? "\(Int(job.temperature))°F" : "Not set")")
                    }
                    HStack {
                        Image(systemName: "cloud")
                            .foregroundColor(.blue)
                        Text("Weather: \(job.weatherCondition ?? "Not set")")
                    }
                    HStack {
                        Image(systemName: "humidity")
                            .foregroundColor(.cyan)
                        Text("Humidity: \(job.humidity > 0 ? "\(Int(job.humidity))%" : "Not set")")
                    }
                    HStack {
                        Image(systemName: "wind")
                            .foregroundColor(.green)
                        Text("Wind: \(job.windSpeed > 0 ? "\(Int(job.windSpeed)) mph" : "Not set")")
                    }
                }
            }
            .navigationTitle("Edit Job")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveJob()
                    }
                    .disabled(!isFormValid)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                PhotoLibraryPicker(selectedImage: $selectedImage)
            }
            .alert("Job Updated", isPresented: $showingAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private var isFormValid: Bool {
        !jobId.isEmpty && !clientName.isEmpty && !addressLine1.isEmpty && !city.isEmpty && !state.isEmpty && !zip.isEmpty
    }
    
    private func saveJob() {
        job.jobId = jobId
        job.clientName = clientName
        job.addressLine1 = addressLine1
        job.city = city
        job.state = state
        job.zip = zip
        job.notes = notes.isEmpty ? nil : notes
        job.inspectorName = inspectorName.isEmpty ? nil : inspectorName
        job.inspectionDate = inspectionDate
        job.status = status
        
        // Overhead image information
        job.overheadImageSourceName = overheadImageSourceName.isEmpty ? nil : overheadImageSourceName
        job.overheadImageSourceUrl = overheadImageSourceUrl.isEmpty ? nil : overheadImageSourceUrl
        job.scalePixelsPerFoot = Double(scalePixelsPerFoot) ?? 0.0
        
        // Save overhead image if selected
        if let image = selectedImage {
            saveOverheadImage(image, for: job)
        }
        
        job.updatedAt = Date()
        
        do {
            try viewContext.save()
            alertMessage = "Job '\(jobId)' updated successfully!"
            showingAlert = true
        } catch {
            alertMessage = "Failed to update job: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func saveOverheadImage(_ image: UIImage, for job: Job) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let imagesDirectory = documentsDirectory.appendingPathComponent("overhead_images")
        
        do {
            try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
            
            let fileName = "\(job.jobId ?? UUID().uuidString)_overhead.jpg"
            let fileURL = imagesDirectory.appendingPathComponent(fileName)
            
            try imageData.write(to: fileURL)
            job.overheadImagePath = fileName
            job.overheadImageFetchedAt = Date()
            
        } catch {
            print("Failed to save overhead image: \(error.localizedDescription)")
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let job = Job(context: context)
    job.jobId = "E2025-05091"
    job.clientName = "Smith"
    job.addressLine1 = "408 2nd Ave NW"
    job.city = "Largo"
    job.state = "FL"
    job.zip = "33770"
    job.status = "Ready"
    job.createdAt = Date()
    job.updatedAt = Date()
    
    return EditJobView(job: job)
        .environment(\.managedObjectContext, context)
}
