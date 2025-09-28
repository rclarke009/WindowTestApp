//
//  ExportService.swift
//  WindowTest
//
//  Created by Rebecca Clarke on 9/26/25.
//

import Foundation
import CoreData
import UIKit

struct FieldResultsPackage {
    let job: Job
    let exportDirectory: URL
    
    func generate() async throws -> URL {
        print("🚀 Starting export for job: \(job.jobId ?? "Unknown") in \(job.city ?? "Unknown")")
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let exportDirectory = documentsDirectory.appendingPathComponent("exports")
        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        
        let jobId = job.jobId ?? "Unknown"
        let city = job.city ?? "Unknown"
        let dateString = DateFormatter.exportDate.string(from: Date())
        let packageName = "\(jobId)_\(city)_\(dateString)"
        
        print("📦 Creating package: \(packageName)")
        
        let packageDirectory = exportDirectory.appendingPathComponent(packageName)
        try FileManager.default.createDirectory(at: packageDirectory, withIntermediateDirectories: true)
        
        // Generate job.json
        try await generateJobJSON(in: packageDirectory)
        
        // Generate windows.csv
        try await generateWindowsCSV(in: packageDirectory)
        
        // Generate overhead image with dots (optional)
        do {
            try await generateOverheadWithDots(in: packageDirectory)
        } catch {
            print("⚠️ Could not generate overhead image with dots: \(error.localizedDescription)")
            // Continue with export even if overhead image fails
        }
        
        // Copy photos (optional)
        do {
            try await copyPhotos(to: packageDirectory)
        } catch {
            print("⚠️ Could not copy photos: \(error.localizedDescription)")
            // Continue with export even if photo copying fails
        }
        
        // Generate report
        try await generateReport(in: packageDirectory)
        
        // Create ZIP file
        print("📦 Creating archive...")
        let zipURL = try await createZIP(from: packageDirectory, name: packageName)
        print("✅ Archive created at: \(zipURL.path)")
        
        // Clean up temporary directory
        try FileManager.default.removeItem(at: packageDirectory)
        print("🧹 Cleaned up temporary directory")
        
        return zipURL
    }
    
    private func getPhotoCount(for window: Window, type: String) -> Int {
        switch type {
        case "Exterior":
            return window.exteriorPhotos?.count ?? 0
        case "Interior":
            return window.interiorPhotos?.count ?? 0
        case "Leak":
            return window.leakPhotos?.count ?? 0
        default:
            return 0
        }
    }
    
    private func generateJobJSON(in directory: URL) async throws {
        let jobData = JobExportData(
            intake: IntakeData(
                sourceName: job.overheadImageSourceName,
                sourceUrl: job.overheadImageSourceUrl,
                fetchedAt: job.overheadImageFetchedAt
            ),
            field: FieldData(
                inspector: job.inspectorName ?? "Unknown",
                date: job.inspectionDate ?? Date(),
                overheadFile: "overhead_with_dots.png",
                windows: windows.map { window in
                    WindowExportData(
                        windowId: window.windowId ?? "",
                        windowNumber: window.windowNumber ?? "",
                        xPosition: window.xPosition,
                        yPosition: window.yPosition,
                        width: window.width,
                        height: window.height,
                        windowType: window.windowType,
                        condition: window.condition,
                        testResult: window.testResult,
                        leakPoints: Int(window.leakPoints),
                        isAccessible: window.isAccessible,
                        notes: window.notes,
                        exteriorPhotoCount: getPhotoCount(for: window, type: "Exterior"),
                        interiorPhotoCount: getPhotoCount(for: window, type: "Interior"),
                        leakPhotoCount: getPhotoCount(for: window, type: "Leak")
                    )
                }
            )
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(jobData)
        let jsonURL = directory.appendingPathComponent("job.json")
        try data.write(to: jsonURL)
    }
    
    private func generateWindowsCSV(in directory: URL) async throws {
        var csvContent = "Window ID,Window Number,X Position,Y Position,Width,Height,Type,Condition,Test Result,Leak Points,Accessible,Notes,Exterior Photo Count,Interior Photo Count,Leak Photo Count\n"
        
        for window in windows {
            let windowId = window.windowId ?? ""
            let windowNumber = window.windowNumber ?? ""
            let xPosition = String(window.xPosition)
            let yPosition = String(window.yPosition)
            let width = String(window.width)
            let height = String(window.height)
            let windowType = window.windowType ?? ""
            let condition = window.condition ?? ""
            let testResult = window.testResult ?? ""
            let leakPoints = String(window.leakPoints)
            let accessible = window.isAccessible ? "Yes" : "No"
            let notes = window.notes ?? ""
            let exteriorPhotoCount = getPhotoCount(for: window, type: "Exterior")
            let interiorPhotoCount = getPhotoCount(for: window, type: "Interior")
            let leakPhotoCount = getPhotoCount(for: window, type: "Leak")
            
            let row = "\(windowId),\(windowNumber),\(xPosition),\(yPosition),\(width),\(height),\(windowType),\(condition),\(testResult),\(leakPoints),\(accessible),\(notes),\(exteriorPhotoCount),\(interiorPhotoCount),\(leakPhotoCount)"
            
            csvContent += row + "\n"
        }
        
        let csvURL = directory.appendingPathComponent("windows.csv")
        try csvContent.write(to: csvURL, atomically: true, encoding: .utf8)
    }
    
    private func generateOverheadWithDots(in directory: URL) async throws {
        guard let imagePath = job.overheadImagePath else { 
            print("⚠️ No overhead image path found for job")
            return 
        }
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let imageURL = documentsDirectory.appendingPathComponent("overhead_images").appendingPathComponent(imagePath)
        
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            print("⚠️ Overhead image file not found at: \(imageURL.path)")
            return
        }
        
        guard let image = UIImage(contentsOfFile: imageURL.path) else { 
            print("⚠️ Could not load overhead image from: \(imageURL.path)")
            return 
        }
        
        // Create image with window dots
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let imageWithDots = renderer.image { context in
            image.draw(at: .zero)
            
            // Draw window dots
            for window in windows {
                let point = CGPoint(x: window.xPosition, y: window.yPosition)
                let dotColor = dotColor(for: window)
                
                context.cgContext.setFillColor(dotColor.cgColor)
                context.cgContext.fillEllipse(in: CGRect(x: point.x - 10, y: point.y - 10, width: 20, height: 20))
                
                // Draw window number
                let windowNumber = window.windowNumber ?? ""
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
                let textSize = windowNumber.size(withAttributes: attributes)
                let textRect = CGRect(
                    x: point.x - textSize.width / 2,
                    y: point.y - textSize.height / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                windowNumber.draw(in: textRect, withAttributes: attributes)
            }
        }
        
        let pngData = imageWithDots.pngData()
        let outputURL = directory.appendingPathComponent("overhead_with_dots.png")
        try pngData?.write(to: outputURL)
    }
    
    private func copyPhotos(to directory: URL) async throws {
        let photosDirectory = directory.appendingPathComponent("photos")
        try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        
        // Generate photo manifest since photos are now in camera roll
        var photoManifest = "Photo Manifest\n"
        photoManifest += "==============\n\n"
        
        for window in windows {
            let exteriorPhotos = (window.exteriorPhotos?.allObjects as? [Photo]) ?? []
            let interiorPhotos = (window.interiorPhotos?.allObjects as? [Photo]) ?? []
            let leakPhotos = (window.leakPhotos?.allObjects as? [Photo]) ?? []
            
            photoManifest += "Window \(window.windowNumber ?? "Unknown"):\n"
            photoManifest += "  Exterior Photos: \(exteriorPhotos.count)\n"
            photoManifest += "  Interior Photos: \(interiorPhotos.count)\n"
            photoManifest += "  Leak Photos: \(leakPhotos.count)\n\n"
        }
        
        let manifestURL = photosDirectory.appendingPathComponent("photo_manifest.txt")
        try photoManifest.write(to: manifestURL, atomically: true, encoding: .utf8)
    }
    
    private func generateReport(in directory: URL) async throws {
        // Generate a simple text report
        var reportContent = "Window Test Report\n"
        reportContent += "================\n\n"
        reportContent += "Job ID: \(job.jobId ?? "Unknown")\n"
        reportContent += "Client: \(job.clientName ?? "Unknown")\n"
        reportContent += "Address: \(job.addressLine1 ?? ""), \(job.city ?? ""), \(job.state ?? "") \(job.zip ?? "")\n"
        reportContent += "Inspector: \(job.inspectorName ?? "Unknown")\n"
        reportContent += "Date: \(DateFormatter.shortDate.string(from: job.inspectionDate ?? Date()))\n\n"
        
        reportContent += "Window Test Results:\n"
        reportContent += "===================\n\n"
        
        for window in windows {
            reportContent += "Window \(window.windowNumber ?? ""):\n"
            reportContent += "  Type: \(window.windowType ?? "Unknown")\n"
            reportContent += "  Condition: \(window.condition ?? "Unknown")\n"
            reportContent += "  Test Result: \(window.testResult ?? "Pending")\n"
            if window.leakPoints > 0 {
                reportContent += "  Leak Points: \(window.leakPoints)\n"
            }
            reportContent += "  Accessible: \(window.isAccessible ? "Yes" : "No")\n"
            if let notes = window.notes, !notes.isEmpty {
                reportContent += "  Notes: \(notes)\n"
            }
            reportContent += "\n"
        }
        
        let reportURL = directory.appendingPathComponent("WindowTests.txt")
        try reportContent.write(to: reportURL, atomically: true, encoding: .utf8)
    }
    
    private func createZIP(from directory: URL, name: String) async throws -> URL {
        print("📁 Creating archive from: \(directory.path)")
        
        // Create a simple archive by copying all files from the directory
        // Since we can't easily create a ZIP without external libraries, we'll create a folder
        let archiveDirectory = directory.deletingLastPathComponent().appendingPathComponent(name)
        
        print("📁 Archive will be created at: \(archiveDirectory.path)")
        
        // Remove existing archive directory if it exists
        if FileManager.default.fileExists(atPath: archiveDirectory.path) {
            print("🗑️ Removing existing archive directory")
            try FileManager.default.removeItem(at: archiveDirectory)
        }
        
        // Verify source directory exists
        guard FileManager.default.fileExists(atPath: directory.path) else {
            throw NSError(domain: "ExportError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Source directory does not exist: \(directory.path)"])
        }
        
        // Copy the entire package directory to the archive directory
        print("📋 Copying files to archive...")
        try FileManager.default.copyItem(at: directory, to: archiveDirectory)
        
        // Verify archive was created
        guard FileManager.default.fileExists(atPath: archiveDirectory.path) else {
            throw NSError(domain: "ExportError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create archive directory"])
        }
        
        print("✅ Archive created successfully at: \(archiveDirectory.path)")
        
        // For now, return the directory instead of a ZIP file
        // In a production app, you would use a ZIP library like ZipArchive
        return archiveDirectory
    }
    
    private func dotColor(for window: Window) -> UIColor {
        switch window.testResult {
        case "Pass":
            return .green
        case "Fail":
            return .red
        default:
            return .blue
        }
    }
    
    private var windows: [Window] {
        guard let windowsSet = job.windows else { return [] }
        return (windowsSet.allObjects as? [Window]) ?? []
    }
}

// MARK: - Data Models

struct JobExportData: Codable {
    let intake: IntakeData
    let field: FieldData
}

struct IntakeData: Codable {
    let sourceName: String?
    let sourceUrl: String?
    let fetchedAt: Date?
}

struct FieldData: Codable {
    let inspector: String
    let date: Date
    let overheadFile: String
    let windows: [WindowExportData]
}

struct WindowExportData: Codable {
    let windowId: String
    let windowNumber: String
    let xPosition: Double
    let yPosition: Double
    let width: Double
    let height: Double
    let windowType: String?
    let condition: String?
    let testResult: String?
    let leakPoints: Int
    let isAccessible: Bool
    let notes: String?
    let exteriorPhotoCount: Int
    let interiorPhotoCount: Int
    let leakPhotoCount: Int
}

extension DateFormatter {
    static let exportDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
    
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}
