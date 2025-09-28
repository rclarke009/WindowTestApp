//
//  ContentView.swift
//  WindowTest
//
//  Created by Rebecca Clarke on 9/26/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingImportSheet = false
    @State private var showingCreateJobSheet = false
    @State private var showingSettings = false
    @State private var selectedJob: Job?

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Job.createdAt, ascending: false)],
        animation: .default)
    private var jobs: FetchedResults<Job>

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Window Test Suite")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Field Inspector App")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                
                // Jobs List
                        if jobs.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "tray.and.arrow.down")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary)
                                Text("No Jobs Available")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                Text("Create a new job or import a Job Intake Package to get started")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                HStack(spacing: 16) {
                                    Button("Create Job") {
                                        showingCreateJobSheet = true
                                    }
                                    .buttonStyle(.borderedProminent)
                                    
                                    Button("Import Jobs") {
                                        showingImportSheet = true
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(jobs) { job in
                            Button(action: {
                                print("Tapped job: \(job.jobId ?? "Unknown")")
                                selectedJob = job
                            }) {
                                JobRowView(job: job)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .onDelete(perform: deleteJobs)
                    }
                }
            }
            .navigationTitle("Jobs")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Settings") {
                        showingSettings = true
                    }
                }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            HStack {
                                Button("Weather") {
                                    // For now, just show an alert about weather functionality
                                    let alert = UIAlertController(title: "Weather Integration", message: "Weather fetching is now integrated! Go to any job's Environmental Data section and tap 'Fetch Weather for Job Location' to automatically populate current conditions.", preferredStyle: .alert)
                                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                                    
                                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                       let window = windowScene.windows.first {
                                        window.rootViewController?.present(alert, animated: true)
                                    }
                                }
                                Button("Create") {
                                    showingCreateJobSheet = true
                                }
                                Button("Import") {
                                    showingImportSheet = true
                                }
                            }
                        }
            }
        } detail: {
            if let selectedJob = selectedJob {
                JobDetailView(job: selectedJob)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("Select a Job")
                        .font(.title2)
                        .fontWeight(.medium)
                    Text("Choose a job from the list to view details and begin inspection")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportJobsView()
        }
        .sheet(isPresented: $showingCreateJobSheet) {
            CreateJobView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onAppear {
            // Automatically select the most recently added job
            if selectedJob == nil && !jobs.isEmpty {
                selectedJob = jobs.first
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newJobCreated)) { notification in
            // Auto-select newly created job
            if let newJob = notification.object as? Job {
                selectedJob = newJob
            }
        }
    }

    private func deleteJobs(offsets: IndexSet) {
        withAnimation {
            offsets.map { jobs[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct JobRowView: View {
    let job: Job
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.jobId ?? "Unknown Job")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(job.clientName ?? "Unknown Client")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                StatusBadge(status: job.status ?? "Unknown")
            }
            
            HStack {
                Image(systemName: "location")
                    .foregroundColor(.secondary)
                Text("\(job.addressLine1 ?? ""), \(job.city ?? ""), \(job.state ?? "") \(job.zip ?? "")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            if let windows = job.windows?.allObjects as? [Window] {
                HStack {
                    Image(systemName: "square.grid.3x3")
                        .foregroundColor(.secondary)
                    Text("\(windows.count) windows")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if let updatedAt = job.updatedAt {
                        Text(updatedAt, formatter: dateFormatter)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    let status: String
    
    var body: some View {
        Text(status)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .clipShape(Capsule())
    }
    
    private var statusColor: Color {
        switch status {
        case "Ready":
            return .blue
        case "In Progress":
            return .orange
        case "Completed":
            return .green
        case "Failed":
            return .red
        default:
            return .gray
        }
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
