//
//  ImportJobsView.swift
//  WindowTest
//
//  Created by Rebecca Clarke on 9/26/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportJobsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var importService = JobImportService(context: PersistenceController.shared.container.viewContext)
    @State private var showingDocumentPicker = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Import Job Intake Package")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Select a ZIP file or folder containing job data to import into the app")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Import Options
                VStack(spacing: 16) {
                    Button(action: {
                        showingDocumentPicker = true
                    }) {
                        HStack {
                            Image(systemName: "folder")
                            Text("Choose ZIP File or Folder")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(importService.isImporting)
                    
                    Button(action: {
                        // TODO: Implement AirDrop functionality
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Receive via AirDrop")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(importService.isImporting)
                }
                .padding(.horizontal, 40)
                
                // Instructions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Supported File Types:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("ZIP files or folders containing jobs.json")
                        }
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Overhead images in JPG/PNG format")
                        }
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Source documents (optional)")
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
                .background(Color(.systemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 40)
                
                Spacer()
                
                if importService.isImporting {
                    VStack(spacing: 12) {
                        ProgressView(value: importService.importProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                        Text("Importing jobs... \(Int(importService.importProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                if let error = importService.importError {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, 40)
                }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Import Jobs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingDocumentPicker,
            allowedContentTypes: [.zip, .folder],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }
    }
    
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await importService.importJobPackage(from: url)
                if !importService.isImporting && importService.importError == nil {
                    await MainActor.run {
                        dismiss()
                    }
                }
            }
        case .failure(let error):
            importService.importError = error.localizedDescription
        }
    }
}

#Preview {
    ImportJobsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
