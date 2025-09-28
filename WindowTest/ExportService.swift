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
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let exportDirectory = documentsDirectory.appendingPathComponent("exports")
        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        
        let packageName = "\(job.jobId ?? "Unknown")_\(job.city ?? "Unknown")_\(DateFormatter.exportDate.string(from: Date()))"
        let packageDirectory = exportDirectory.appendingPathComponent(packageName)
        try FileManager.default.createDirectory(at: packageDirectory, withIntermediateDirectories: true)
        
        // Generate job.json
        try await generateJobJSON(in: packageDirectory)
        
        // Generate windows.csv
        try await generateWindowsCSV(in: packageDirectory)
        
        // Generate overhead image with dots
        try await generateOverheadWithDots(in: packageDirectory)
        
        // Copy photos
        try await copyPhotos(to: packageDirectory)
        
        // Generate report
        try await generateReport(in: packageDirectory)
        
        // Create ZIP file
        let zipURL = try await createZIP(from: packageDirectory, name: packageName)
        
        // Clean up temporary directory
        try FileManager.default.removeItem(at: packageDirectory)
        
        return zipURL
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
                        exteriorPhotoPath: window.exteriorPhotoPath,
                        interiorPhotoPath: window.interiorPhotoPath,
                        leakPhotoPath: window.leakPhotoPath
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
        var csvContent = "Window ID,Window Number,X Position,Y Position,Width,Height,Type,Condition,Test Result,Leak Points,Accessible,Notes,Exterior Photo,Interior Photo,Leak Photo\n"
        
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
            let exteriorPhoto = window.exteriorPhotoPath ?? ""
            let interiorPhoto = window.interiorPhotoPath ?? ""
            let leakPhoto = window.leakPhotoPath ?? ""
            
            let row = "\(windowId),\(windowNumber),\(xPosition),\(yPosition),\(width),\(height),\(windowType),\(condition),\(testResult),\(leakPoints),\(accessible),\(notes),\(exteriorPhoto),\(interiorPhoto),\(leakPhoto)"
            
            csvContent += row + "\n"
        }
        
        let csvURL = directory.appendingPathComponent("windows.csv")
        try csvContent.write(to: csvURL, atomically: true, encoding: .utf8)
    }
    
    private func generateOverheadWithDots(in directory: URL) async throws {
        guard let imagePath = job.overheadImagePath else { return }
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let imageURL = documentsDirectory.appendingPathComponent("images").appendingPathComponent(imagePath)
        
        guard let image = UIImage(contentsOfFile: imageURL.path) else { return }
        
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
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let sourcePhotosDirectory = documentsDirectory.appendingPathComponent("photos")
        
        for window in windows {
            let photoTypes = [
                (window.exteriorPhotoPath, "Exterior"),
                (window.interiorPhotoPath, "Interior"),
                (window.leakPhotoPath, "Leak")
            ]
            
            for (photoPath, type) in photoTypes {
                guard let photoPath = photoPath else { continue }
                
                let sourceURL = sourcePhotosDirectory.appendingPathComponent(photoPath)
                let destinationFileName = "\(window.windowNumber ?? "W")_\(type)_1.jpg"
                let destinationURL = photosDirectory.appendingPathComponent(destinationFileName)
                
                if FileManager.default.fileExists(atPath: sourceURL.path) {
                    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                }
            }
        }
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
        let zipURL = directory.deletingLastPathComponent().appendingPathComponent("\(name).zip")
        
        // For now, we'll create a simple archive by copying the directory
        // In a real implementation, you would use a ZIP library
        try FileManager.default.copyItem(at: directory, to: zipURL)
        
        return zipURL
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
    let exteriorPhotoPath: String?
    let interiorPhotoPath: String?
    let leakPhotoPath: String?
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
