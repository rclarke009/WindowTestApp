import SwiftUI
import CoreData

struct CreateJobView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // Job fields
    @State private var jobId: String = ""
    @State private var clientName: String = ""
    @State private var addressLine1: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var zip: String = ""
    @State private var notes: String = ""
    @State private var inspectorName: String = ""
    @State private var inspectionDate: Date = Date()
    
    // Overhead image fields
    @State private var overheadImageSourceName: String = ""
    @State private var overheadImageSourceUrl: String = ""
    @State private var scalePixelsPerFoot: String = "10.0"
    
    // UI state
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
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
                
                Section("Preview") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Job ID: \(jobId.isEmpty ? "Not specified" : jobId)")
                        Text("Client: \(clientName.isEmpty ? "Not specified" : clientName)")
                        Text("Address: \(addressLine1.isEmpty ? "Not specified" : addressLine1), \(city.isEmpty ? "City" : city), \(state.isEmpty ? "ST" : state) \(zip.isEmpty ? "00000" : zip)")
                        Text("Inspector: \(inspectorName.isEmpty ? "Not specified" : inspectorName)")
                        Text("Date: \(inspectionDate, formatter: dateFormatter)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Create New Job")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createJob()
                    }
                    .disabled(!isFormValid)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                PhotoLibraryPicker(selectedImage: $selectedImage)
            }
            .alert("Job Created", isPresented: $showingAlert) {
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
    
    private func createJob() {
        let newJob = Job(context: viewContext)
        newJob.jobId = jobId
        newJob.clientName = clientName
        newJob.addressLine1 = addressLine1
        newJob.city = city
        newJob.state = state
        newJob.zip = zip
        newJob.notes = notes.isEmpty ? nil : notes
        newJob.inspectorName = inspectorName.isEmpty ? nil : inspectorName
        newJob.inspectionDate = inspectionDate
        newJob.status = "Ready"
        newJob.createdAt = Date()
        newJob.updatedAt = Date()
        
        // Overhead image information
        newJob.overheadImageSourceName = overheadImageSourceName.isEmpty ? nil : overheadImageSourceName
        newJob.overheadImageSourceUrl = overheadImageSourceUrl.isEmpty ? nil : overheadImageSourceUrl
        newJob.scalePixelsPerFoot = Double(scalePixelsPerFoot) ?? 10.0
        
        // Save overhead image if selected
        if let image = selectedImage {
            saveOverheadImage(image, for: newJob)
        }
        
        do {
            try viewContext.save()
            
            // Post notification for new job creation
            NotificationCenter.default.post(name: .newJobCreated, object: newJob)
            
            alertMessage = "Job '\(jobId)' created successfully!"
            showingAlert = true
        } catch {
            alertMessage = "Failed to create job: \(error.localizedDescription)"
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
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotoLibraryPicker

        init(_ parent: PhotoLibraryPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    CreateJobView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
