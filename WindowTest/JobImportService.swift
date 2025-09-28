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
    let createdAt: String
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
            
            struct SourceData: Codable {
                let name: String
                let url: String
                let fetchedAt: String
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
            
            // Create temporary directory for extraction
            let tempDirectory = documentsDirectory.appendingPathComponent("temp_import_\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
            defer {
                try? FileManager.default.removeItem(at: tempDirectory)
            }
            
            await MainActor.run { importProgress = 0.1 }
            
            // Extract ZIP file
            try await extractZIP(from: url, to: tempDirectory)
            
            await MainActor.run { importProgress = 0.3 }
            
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
        // For now, we'll simulate ZIP extraction by creating a sample jobs.json
        // In a real implementation, you would use a ZIP library like ZIPFoundation
        let sampleJobsJSON = """
        {
            "version": "1.0",
            "createdAt": "2025-09-26T14:12:00Z",
            "preparedBy": "DesktopScraper 1.0.0",
            "jobs": [
                {
                    "jobId": "E2025-05091",
                    "clientName": "Smith",
                    "address": {
                        "line1": "408 2nd Ave NW",
                        "city": "Largo",
                        "state": "FL",
                        "zip": "33770"
                    },
                    "notes": "Rush job",
                    "overhead": {
                        "imageFile": "overhead/E2025-05091_overhead.jpg",
                        "source": {
                            "name": "Pinellas County Property Appraiser",
                            "url": "https://example.com/parcel/123",
                            "fetchedAt": "2025-09-26T14:00:10Z"
                        },
                        "scalePixelsPerFoot": 10.0
                    }
                }
            ]
        }
        """
        
        let jobsJSONURL = destinationURL.appendingPathComponent("jobs.json")
        try sampleJobsJSON.write(to: jobsJSONURL, atomically: true, encoding: .utf8)
    }
    
    private func parseJobsJSON(from directory: URL) async throws -> JobIntakePackage {
        let jobsJSONURL = directory.appendingPathComponent("jobs.json")
        
        guard FileManager.default.fileExists(atPath: jobsJSONURL.path) else {
            throw ImportError.missingJobsJSON
        }
        
        let data = try Data(contentsOf: jobsJSONURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(JobIntakePackage.self, from: data)
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
        
        // Create images directory in documents
        let imagesDirectory = documentsDirectory.appendingPathComponent("images")
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        
        // Copy image to documents directory
        let destinationImageURL = imagesDirectory.appendingPathComponent("\(job.jobId ?? UUID().uuidString)_overhead.jpg")
        try FileManager.default.copyItem(at: sourceImageURL, to: destinationImageURL)
        
        // Update job with image path
        job.overheadImagePath = destinationImageURL.lastPathComponent
        
        // Set source information
        if let source = overheadData.source {
            job.overheadImageSourceName = source.name
            job.overheadImageSourceUrl = source.url
            
            let formatter = ISO8601DateFormatter()
            job.overheadImageFetchedAt = formatter.date(from: source.fetchedAt)
        }
        
        // Set scale if available
        if let scale = overheadData.scalePixelsPerFoot {
            job.scalePixelsPerFoot = scale
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
