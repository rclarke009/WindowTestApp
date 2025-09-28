//
//  JobDetailView.swift
//  WindowTest
//
//  Created by Rebecca Clarke on 9/26/25.
//

import SwiftUI
import CoreData

struct JobDetailView: View {
    let job: Job
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab = 0
    @State private var showingOverheadCanvas = false
    @State private var showingEnvironmentalData = false
    @State private var showingEditJob = false
    @State private var refreshTrigger = UUID()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(job.jobId ?? "Unknown Job")
                            .font(.title)
                            .fontWeight(.bold)
                        Text(job.clientName ?? "Unknown Client")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    StatusBadge(status: job.status ?? "Unknown")
                }
                
                Button(action: {
                    showingEditJob = true
                }) {
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(.secondary)
                        Text("\(job.addressLine1 ?? ""), \(job.city ?? ""), \(job.state ?? "") \(job.zip ?? "")")
                            .font(.body)
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                if let notes = job.notes, !notes.isEmpty {
                    HStack {
                        Image(systemName: "note.text")
                            .foregroundColor(.secondary)
                        Text(notes)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            
            // Environmental Data Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Environmental Data")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Button("Edit") {
                        showingEnvironmentalData = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                HStack(spacing: 20) {
                    EnvironmentalDataItem(
                        icon: "thermometer",
                        label: "Temperature",
                        value: job.temperature > 0 ? "\(Int(job.temperature))°F" : "Not set",
                        color: temperatureColor
                    )
                    .id("temp-\(refreshTrigger)")
                    
                    EnvironmentalDataItem(
                        icon: "cloud",
                        label: "Weather",
                        value: job.weatherCondition ?? "Not set",
                        color: .blue
                    )
                    .id("weather-\(refreshTrigger)")
                    
                    EnvironmentalDataItem(
                        icon: "humidity",
                        label: "Humidity",
                        value: job.humidity > 0 ? "\(Int(job.humidity))%" : "Not set",
                        color: .cyan
                    )
                    .id("humidity-\(refreshTrigger)")
                    
                    EnvironmentalDataItem(
                        icon: "wind",
                        label: "Wind",
                        value: job.windSpeed > 0 ? "\(Int(job.windSpeed)) mph" : "Not set",
                        color: .green
                    )
                    .id("wind-\(refreshTrigger)")
                }
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            
            // Tab Selection
            Picker("View", selection: $selectedTab) {
                Text("Overview").tag(0)
                Text("Overhead").tag(1)
                Text("Windows").tag(2)
                Text("Export").tag(3)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Content
            TabView(selection: $selectedTab) {
                JobOverviewView(job: job)
                    .tag(0)
                
                OverheadCanvasView(job: job)
                    .tag(1)
                
                WindowsListView(job: job)
                    .tag(2)
                
                ExportView(job: job)
                    .tag(3)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .navigationTitle("Job Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEnvironmentalData) {
            EnvironmentalDataView(job: job)
        }
        .sheet(isPresented: $showingEditJob) {
            EditJobView(job: job)
        }
        .onReceive(NotificationCenter.default.publisher(for: .jobDataUpdated)) { notification in
            if let updatedJob = notification.object as? Job, updatedJob == job {
                refreshTrigger = UUID()
            }
        }
    }
    
    private var temperatureColor: Color {
        switch job.temperature {
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

struct JobOverviewView: View {
    let job: Job
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Job Information
                VStack(alignment: .leading, spacing: 12) {
                    Text("Job Information")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    InfoRow(label: "Job ID", value: job.jobId ?? "Unknown")
                    InfoRow(label: "Client", value: job.clientName ?? "Unknown")
                    InfoRow(label: "Address", value: "\(job.addressLine1 ?? ""), \(job.city ?? ""), \(job.state ?? "") \(job.zip ?? "")")
                    InfoRow(label: "Status", value: job.status ?? "Unknown")
                    
                    if let inspector = job.inspectorName {
                        InfoRow(label: "Inspector", value: inspector)
                    }
                    
                    if let inspectionDate = job.inspectionDate {
                        InfoRow(label: "Inspection Date", value: DateFormatter.shortDate.string(from: inspectionDate))
                    }
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Overhead Image
                if let imagePath = job.overheadImagePath {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Overhead Image")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if let image = loadOverheadImage(from: imagePath) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 300)
                                .cornerRadius(8)
                                .clipped()
                        } else {
                            HStack {
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                                Text("Image not found")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: 100)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        
                        if let sourceName = job.overheadImageSourceName {
                            InfoRow(label: "Source", value: sourceName)
                        }
                        
                        if let sourceUrl = job.overheadImageSourceUrl {
                            InfoRow(label: "URL", value: sourceUrl)
                        }
                        
                        if let fetchedAt = job.overheadImageFetchedAt {
                            InfoRow(label: "Fetched", value: DateFormatter.shortDate.string(from: fetchedAt))
                        }
                        
                        if job.scalePixelsPerFoot > 0 {
                            InfoRow(label: "Scale", value: "\(String(format: "%.1f", job.scalePixelsPerFoot)) pixels per foot")
                        }
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Windows Summary
                if let windows = job.windows?.allObjects as? [Window] {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Windows Summary")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        HStack {
                            Text("Total Windows:")
                            Spacer()
                            Text("\(windows.count)")
                                .fontWeight(.semibold)
                        }
                        
                        let completedWindows = windows.filter { $0.testResult != nil }
                        HStack {
                            Text("Completed:")
                            Spacer()
                            Text("\(completedWindows.count)")
                                .fontWeight(.semibold)
                        }
                        
                        let failedWindows = windows.filter { $0.testResult == "Fail" }
                        HStack {
                            Text("Failed:")
                            Spacer()
                            Text("\(failedWindows.count)")
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
    }
    
    private func loadOverheadImage(from imagePath: String) -> UIImage? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let imageURL = documentsDirectory.appendingPathComponent("overhead_images").appendingPathComponent(imagePath)
        
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            print("Overhead image not found at: \(imageURL.path)")
            return nil
        }
        
        return UIImage(contentsOfFile: imageURL.path)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// OverheadCanvasView is now in its own file

struct WindowsListView: View {
    let job: Job
    @Environment(\.managedObjectContext) private var viewContext
    @State private var refreshTrigger = UUID()
    
    private var windows: [Window] {
        guard let windowsSet = job.windows else { return [] }
        return windowsSet.allObjects as? [Window] ?? []
    }
    
    var body: some View {
        VStack {
            if !windows.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Windows (\(windows.count))")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .id("window-count-\(refreshTrigger)")
                        Spacer()
                        Button("Add Window") {
                            addWindow()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal)
                    
                    List {
                        ForEach(windows.sorted(by: { $0.windowNumber ?? "" < $1.windowNumber ?? "" }), id: \.objectID) { window in
                            WindowRowView(window: window)
                        }
                    }
                    .id(refreshTrigger)
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "square.grid.3x3")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No Windows Added")
                        .font(.title2)
                        .fontWeight(.medium)
                    Text("Add windows to this job to begin inspection")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Add Window") {
                        addWindow()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func addWindow() {
        let newWindow = Window(context: viewContext)
        newWindow.windowId = UUID().uuidString
        let windowCount = (job.windows?.count ?? 0) + 1
        newWindow.windowNumber = String(format: "W%02d", windowCount)
        newWindow.xPosition = 0
        newWindow.yPosition = 0
        newWindow.isAccessible = true
        newWindow.createdAt = Date()
        newWindow.updatedAt = Date()
        newWindow.job = job
        
        do {
            try viewContext.save()
            print("✅ Window \(newWindow.windowNumber ?? "Unknown") created successfully!")
            refreshTrigger = UUID() // Trigger UI refresh
        } catch {
            print("❌ Failed to save new window: \(error.localizedDescription)")
        }
    }
}

struct WindowRowView: View {
    let window: Window
    @State private var showingWindowEditor = false
    
    var body: some View {
        Button(action: {
            showingWindowEditor = true
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(window.windowNumber ?? "Unknown")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    if let testResult = window.testResult {
                        StatusBadge(status: testResult)
                    } else {
                        StatusBadge(status: "Pending")
                    }
                }
                
                if let windowType = window.windowType {
                    HStack {
                        Text("Type:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(windowType)
                            .font(.caption)
                    }
                }
                
                if window.width > 0 && window.height > 0 {
                    HStack {
                        Text("Size:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(String(format: "%.1f", window.width))\" × \(String(format: "%.1f", window.height))\"")
                            .font(.caption)
                    }
                }
                
                if let condition = window.condition {
                    HStack {
                        Text("Condition:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(condition)
                            .font(.caption)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingWindowEditor) {
            WindowEditorView(window: window)
        }
    }
}

struct ExportView: View {
    let job: Job
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var exportSuccess = false
    @State private var exportedFileURL: URL?
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Export Field Results")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Export this job's inspection data as a Field Results Package")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Export includes:")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Job data (JSON)")
                    }
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Windows data (CSV)")
                    }
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Overhead image with dots")
                    }
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Window photos")
                    }
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Inspection report (TXT)")
                    }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 40)
            
            if isExporting {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Generating export package...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if exportSuccess {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Export Complete!")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let fileURL = exportedFileURL {
                        Button("Share Package") {
                            shareFile(fileURL)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            } else {
                Button(action: exportJob) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Package")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 40)
            }
            
            if let error = exportError {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }
    
    private func exportJob() {
        isExporting = true
        exportError = nil
        exportSuccess = false
        
        Task {
            do {
                let package = FieldResultsPackage(job: job, exportDirectory: URL(fileURLWithPath: ""))
                let exportedURL = try await package.generate()
                
                await MainActor.run {
                    exportedFileURL = exportedURL
                    isExporting = false
                    exportSuccess = true
                }
            } catch {
                await MainActor.run {
                    exportError = error.localizedDescription
                    isExporting = false
                }
            }
        }
    }
    
    private func shareFile(_ url: URL) {
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityViewController, animated: true)
        }
    }
}

// DateFormatter extensions moved to ExportService.swift

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
    
    return JobDetailView(job: job)
        .environment(\.managedObjectContext, context)
}

struct EnvironmentalDataItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
    }
}
