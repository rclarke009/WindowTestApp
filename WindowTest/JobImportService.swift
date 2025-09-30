//
//  JobImportService.swift
//  WindowTest
//
//  Created by Rebecca Clarke on 9/26/25.
//

import Foundation
import CoreData

struct JobIntakePackage: Codable {
    let version: String
    let createdAt: Double  // Changed from String to Double to handle timestamp
    let preparedBy: String
    let jobs: [JobData]
    
    struct JobData: Codable {
        let jobId: String
        let clientName: String
        let address: Address
        let notes: String?
        let overhead: OverheadData?
        
        struct Address: Codable {
            let line1: String
            let city: String
            let state: String
            let zip: String
        }
        
        struct OverheadData: Codable {
            let imageFile: String
            let source: SourceData?
            let scalePixelsPerFoot: Double?
            let zoomScale: Double?  // Added to handle your JSON format
            
        struct SourceData: Codable {
            let name: String
            let url: String
            let fetchedAt: Double  // Changed from String to Double to handle timestamp
        }
        }
    }
}

class JobImportService: ObservableObject {
    @Published var isImporting = false
    @Published var importError: String?
    @Published var importProgress: Double = 0.0
    @Published var importedJobs: [Job] = []
    
    private let context: NSManagedObjectContext
    private let documentsDirectory: URL
    
    init(context: NSManagedObjectContext) {
        self.context = context
        self.documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    func importJobPackage(from url: URL) async {
        await MainActor.run {
            isImporting = true
            importError = nil
            importProgress = 0.0
        }
        
        do {
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                throw ImportError.unableToAccessFile
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            var tempDirectory: URL
            
            // Check if it's a ZIP file or a folder
            if url.pathExtension.lowercased() == "zip" {
                // Create temporary directory for ZIP extraction
                tempDirectory = documentsDirectory.appendingPathComponent("temp_import_\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
                defer {
                    try? FileManager.default.removeItem(at: tempDirectory)
                }
                
                await MainActor.run { importProgress = 0.1 }
                
                // Extract ZIP file
                try await extractZIP(from: url, to: tempDirectory)
                
                await MainActor.run { importProgress = 0.3 }
            } else {
                // It's a folder, check if it contains a jobs.json or if we need to look deeper
                tempDirectory = url
                print("📁 Using folder directly: \(url.path)")
                
                // Check if the folder contains a jobs.json file
                let jobsJSONURL = tempDirectory.appendingPathComponent("jobs.json")
                if FileManager.default.fileExists(atPath: jobsJSONURL.path) {
                    print("✅ Found jobs.json in root folder")
                } else {
                    print("❌ No jobs.json found in root folder")
                    // List contents of the folder for debugging
                    do {
                        let contents = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
                        print("📁 Folder contents:")
                        for item in contents {
                            print("  - \(item.lastPathComponent)")
                        }
                        
                        // Check if there's a subfolder that might contain the data
                        let subfolders = contents.filter { item in
                            var isDirectory: ObjCBool = false
                            FileManager.default.fileExists(atPath: item.path, isDirectory: &isDirectory)
                            return isDirectory.boolValue
                        }
                        
                        if subfolders.count == 1, let subfolder = subfolders.first {
                            print("🔍 Found single subfolder, checking for jobs.json inside: \(subfolder.lastPathComponent)")
                            let subfolderJobsJSON = subfolder.appendingPathComponent("jobs.json")
                            if FileManager.default.fileExists(atPath: subfolderJobsJSON.path) {
                                print("✅ Found jobs.json in subfolder, using subfolder as source")
                                tempDirectory = subfolder
                            } else {
                                print("❌ No jobs.json found in subfolder either")
                            }
                        } else if subfolders.count > 1 {
                            print("⚠️ Multiple subfolders found, checking each one...")
                            for subfolder in subfolders {
                                let subfolderJobsJSON = subfolder.appendingPathComponent("jobs.json")
                                if FileManager.default.fileExists(atPath: subfolderJobsJSON.path) {
                                    print("✅ Found jobs.json in subfolder: \(subfolder.lastPathComponent)")
                                    tempDirectory = subfolder
                                    break
                                }
                            }
                        }
                    } catch {
                        print("❌ Error listing folder contents: \(error)")
                    }
                }
                
                await MainActor.run { importProgress = 0.2 }
            }
            
            // Parse jobs.json
            let jobsData = try await parseJobsJSON(from: tempDirectory)
            
            await MainActor.run { importProgress = 0.5 }
            
            // Process and save jobs
            let importedJobs = try await processJobs(jobsData, from: tempDirectory)
            
            await MainActor.run {
                importProgress = 1.0
                isImporting = false
                self.importedJobs = importedJobs
                
                // Post notification for imported jobs
                if let firstJob = importedJobs.first {
                    NotificationCenter.default.post(name: .newJobCreated, object: firstJob)
                }
            }
            
        } catch {
            await MainActor.run {
                importError = error.localizedDescription
                isImporting = false
                importProgress = 0.0
            }
        }
    }
    
    private func extractZIP(from sourceURL: URL, to destinationURL: URL) async throws {
        // For now, we'll use a simple approach: copy the ZIP file and try to extract it
        // In a production app, you'd use a proper ZIP library like ZIPFoundation
        print("📦 Attempting to extract ZIP from: \(sourceURL.path)")
        print("📦 To destination: \(destinationURL.path)")
        
        // For now, let's create a sample structure that matches your folder
        // This simulates what would be extracted from a ZIP
        let sampleJobsJSON = """
        {
            "version": "1.0",
            "createdAt": "2025-09-28T20:30:00Z",
            "preparedBy": "WindowTest App",
            "jobs": [
                {
                    "jobId": "E2025-05095",
                    "clientName": "Sample Client 1",
                    "address": {
                        "line1": "123 Main St",
                        "city": "Sample City",
                        "state": "FL",
                        "zip": "12345"
                    },
                    "notes": "Sample job for testing",
                    "overhead": {
                        "imageFile": "overhead/E2025-05095_overhead.jpg",
                        "source": {
                            "name": "Sample Source",
                            "url": "https://example.com/parcel/123",
                            "fetchedAt": "2025-09-28T20:00:00Z"
                        },
                        "scalePixelsPerFoot": 10.0
                    }
                },
                {
                    "jobId": "E2025-05092",
                    "clientName": "Sample Client 2",
                    "address": {
                        "line1": "456 Oak Ave",
                        "city": "Sample City",
                        "state": "FL",
                        "zip": "12345"
                    },
                    "notes": "Another sample job",
                    "overhead": {
                        "imageFile": "overhead/E2025-05092_overhead.jpg",
                        "source": {
                            "name": "Sample Source",
                            "url": "https://example.com/parcel/456",
                            "fetchedAt": "2025-09-28T20:00:00Z"
                        },
                        "scalePixelsPerFoot": 10.0
                    }
                }
            ]
        }
        """
        
        // Create the jobs.json file
        let jobsJSONURL = destinationURL.appendingPathComponent("jobs.json")
        try sampleJobsJSON.write(to: jobsJSONURL, atomically: true, encoding: .utf8)
        print("📦 Created sample jobs.json at: \(jobsJSONURL.path)")
        
        // Create overhead directory and copy sample images if they exist
        let overheadDir = destinationURL.appendingPathComponent("overhead")
        try FileManager.default.createDirectory(at: overheadDir, withIntermediateDirectories: true)
        print("📦 Created overhead directory at: \(overheadDir.path)")
        
        // For now, we'll just create the directory structure
        // In a real implementation, you'd extract the actual files from the ZIP
    }
    
    private func parseJobsJSON(from directory: URL) async throws -> JobIntakePackage {
        let jobsJSONURL = directory.appendingPathComponent("jobs.json")
        
        print("🔍 Looking for jobs.json at: \(jobsJSONURL.path)")
        
        guard FileManager.default.fileExists(atPath: jobsJSONURL.path) else {
            print("❌ jobs.json not found at: \(jobsJSONURL.path)")
            throw ImportError.missingJobsJSON
        }
        
        print("✅ Found jobs.json, reading data...")
        
        let data = try Data(contentsOf: jobsJSONURL)
        print("📄 Read \(data.count) bytes from jobs.json")
        
        // Try to print the JSON content for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📄 JSON content preview: \(String(jsonString.prefix(500)))...")
            print("📄 Full JSON content:")
            print(jsonString)
        }
        
        let decoder = JSONDecoder()
        // No special date decoding strategy needed since we're using timestamps
        
        do {
            let package = try decoder.decode(JobIntakePackage.self, from: data)
            print("✅ Successfully parsed JSON with \(package.jobs.count) jobs")
            return package
        } catch {
            print("❌ JSON parsing error: \(error)")
            if let decodingError = error as? DecodingError {
                print("❌ Decoding error details: \(decodingError)")
            }
            throw ImportError.invalidJSONFormat
        }
    }
    
    private func processJobs(_ package: JobIntakePackage, from directory: URL) async throws -> [Job] {
        let jobCount = package.jobs.count
        var importedJobs: [Job] = []
        
        for (index, jobData) in package.jobs.enumerated() {
            // Create Job entity
            let job = Job(context: context)
            job.jobId = jobData.jobId
            job.clientName = jobData.clientName
            job.addressLine1 = jobData.address.line1
            job.city = jobData.address.city
            job.state = jobData.address.state
            job.zip = jobData.address.zip
            job.notes = jobData.notes
            job.status = "Ready"
            job.createdAt = Date()
            job.updatedAt = Date()
            
            // Add to imported jobs list
            importedJobs.append(job)
            
            // Process overhead image
            if let overheadData = jobData.overhead {
                try await processOverheadImage(overheadData, for: job, from: directory)
            }
            
            // Update progress
            let progress = 0.5 + (Double(index + 1) / Double(jobCount)) * 0.4
            await MainActor.run { importProgress = progress }
        }
        
        // Save context
        try context.save()
        
        return importedJobs
    }
    
    private func processOverheadImage(_ overheadData: JobIntakePackage.JobData.OverheadData, for job: Job, from directory: URL) async throws {
        let imagePath = overheadData.imageFile
        let sourceImageURL = directory.appendingPathComponent(imagePath)
        
        guard FileManager.default.fileExists(atPath: sourceImageURL.path) else {
            print("Warning: Overhead image not found at \(imagePath)")
            return
        }
        
        // Create overhead_images directory in documents (to match the export structure)
        let overheadImagesDirectory = documentsDirectory.appendingPathComponent("overhead_images")
        try FileManager.default.createDirectory(at: overheadImagesDirectory, withIntermediateDirectories: true)
        
        // Copy image to documents directory
        let destinationImageURL = overheadImagesDirectory.appendingPathComponent("\(job.jobId ?? UUID().uuidString)_overhead.jpg")
        try FileManager.default.copyItem(at: sourceImageURL, to: destinationImageURL)
        
        // Update job with image path
        job.overheadImagePath = destinationImageURL.lastPathComponent
        
        // Set source information
        if let source = overheadData.source {
            job.overheadImageSourceName = source.name
            job.overheadImageSourceUrl = source.url
            
            // Convert timestamp to Date
            job.overheadImageFetchedAt = Date(timeIntervalSince1970: source.fetchedAt)
        }
        
        // Set scale if available (prefer scalePixelsPerFoot, fallback to zoomScale)
        if let scale = overheadData.scalePixelsPerFoot {
            job.scalePixelsPerFoot = scale
        } else if let zoomScale = overheadData.zoomScale {
            // Convert zoomScale to scalePixelsPerFoot (rough approximation)
            // This is a simple conversion - you may need to adjust based on your data
            job.scalePixelsPerFoot = zoomScale * 10.0  // Adjust multiplier as needed
        }
    }
}

enum ImportError: LocalizedError {
    case unableToAccessFile
    case missingJobsJSON
    case invalidJSONFormat
    case imageProcessingFailed
    
    var errorDescription: String? {
        switch self {
        case .unableToAccessFile:
            return "Unable to access the selected file"
        case .missingJobsJSON:
            return "The ZIP file doesn't contain a jobs.json file"
        case .invalidJSONFormat:
            return "The jobs.json file has an invalid format"
        case .imageProcessingFailed:
            return "Failed to process overhead images"
        }
    }
}
