//
//  OverheadCanvasView.swift
//  WindowTest
//
//  Created by Rebecca Clarke on 9/26/25.
//

import SwiftUI
import CoreData

// MARK: - Window Type Enum
enum WindowType: String, CaseIterable, Identifiable {
    case awning = "Awning"
    case casement = "Casement"
    case centerPivot = "Center Pivot"
    case doubleHung = "Double Hung"
    case fixed = "Fixed"
    case hopper = "Hopper"
    case jalousie = "Jalousie"
    case singleHung = "Single Hung"
    case sliding = "Sliding"
    
    var id: String { rawValue }
    
    var imageName: String {
        switch self {
        case .awning:
            return "window-awning"
        case .casement:
            return "window-casement"
        case .centerPivot:
            return "window-center-pivot"
        case .doubleHung:
            return "window-doublehung"
        case .fixed:
            return "window-fixed"
        case .hopper:
            return "window-hopper"
        case .jalousie:
            return "window-jalousie"
        case .singleHung:
            return "window-singlehung"
        case .sliding:
            return "window-sliding"
        }
    }
    
    var imagePath: String {
        return "window-types/\(imageName)"
    }
    
    var image: Image {
        // Try to load from the window-types subdirectory first
        if let uiImage = UIImage(named: imagePath) {
            return Image(uiImage: uiImage)
        }
        // Fallback to just the image name (in case images are in root bundle)
        else if let uiImage = UIImage(named: imageName) {
            return Image(uiImage: uiImage)
        }
        // Final fallback to system image
        else {
            return Image(systemName: "square.grid.3x3")
        }
    }
    
    var displayName: String {
        return rawValue
    }
}

// MARK: - Window Type Picker View
struct WindowTypePickerView: View {
    @Binding var selectedWindowType: String
    @State private var showingPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                showingPicker = true
            }) {
                HStack {
                    if let windowType = WindowType.allCases.first(where: { $0.rawValue == selectedWindowType }) {
                        windowType.image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30, height: 30)
                        
                        Text(windowType.displayName)
                            .foregroundColor(.primary)
                    } else {
                        Image(systemName: "square.grid.3x3")
                            .foregroundColor(.secondary)
                        
                        Text(selectedWindowType.isEmpty ? "Select Window Type" : selectedWindowType)
                            .foregroundColor(selectedWindowType.isEmpty ? .secondary : .primary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .sheet(isPresented: $showingPicker) {
            WindowTypeSelectionView(selectedWindowType: $selectedWindowType)
        }
    }
}

// MARK: - Window Type Selection View
struct WindowTypeSelectionView: View {
    @Binding var selectedWindowType: String
    @Environment(\.dismiss) private var dismiss
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(WindowType.allCases) { windowType in
                        Button(action: {
                            selectedWindowType = windowType.rawValue
                            dismiss()
                        }) {
                            VStack(spacing: 8) {
                                windowType.image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 60, height: 60)
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedWindowType == windowType.rawValue ? Color.blue.opacity(0.2) : Color(.systemGray6))
                                    )
                                
                                Text(windowType.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.primary)
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedWindowType == windowType.rawValue ? Color.blue.opacity(0.1) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedWindowType == windowType.rawValue ? Color.blue : Color.clear, lineWidth: 2)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle("Select Window Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct OverheadCanvasView: View {
    let job: Job
    @Environment(\.managedObjectContext) private var viewContext
    @State private var image: UIImage?
    @State private var imageSize: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showingWindowEditor = false
    @State private var selectedWindow: Window?
    @State private var isAddingWindow = false
    @State private var newWindowPosition: CGPoint = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if let image = image {
                    ScrollView([.horizontal, .vertical]) {
                        ZStack {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .scaleEffect(scale)
                                .offset(offset)
                                .onTapGesture { location in
                                    handleImageTap(at: location, in: geometry.size)
                                }
                                .background(
                                    GeometryReader { imageGeometry in
                                        Color.clear
                                            .onAppear {
                                                imageSize = imageGeometry.size
                                            }
                                    }
                                )
                            
                            // Window dots overlay
                            ForEach(windows, id: \.objectID) { window in
                                WindowDotView(
                                    window: window,
                                    imageSize: imageSize,
                                    scale: scale,
                                    offset: offset
                                ) {
                                    selectedWindow = window
                                    showingWindowEditor = true
                                }
                            }
                            
                            // New window dot being placed
                            if isAddingWindow {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                                    .position(
                                        x: newWindowPosition.x * scale + offset.width,
                                        y: newWindowPosition.y * scale + offset.height
                                    )
                            }
                        }
                        .frame(
                            width: max(geometry.size.width, imageSize.width * scale),
                            height: max(geometry.size.height, imageSize.height * scale)
                        )
                    }
                    .clipped()
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No Overhead Image")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text("This job doesn't have an overhead image yet")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .navigationTitle("Overhead View")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Reset View") {
                    resetView()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add Window") {
                    isAddingWindow = true
                }
                .disabled(image == nil)
            }
        }
        .onAppear {
            loadImage()
        }
        .sheet(isPresented: $showingWindowEditor) {
            if let window = selectedWindow {
                WindowEditorView(window: window)
            }
        }
        .alert("Add Window", isPresented: $isAddingWindow) {
            Button("Cancel") {
                isAddingWindow = false
            }
            Button("Add") {
                addWindow(at: newWindowPosition)
                isAddingWindow = false
            }
        } message: {
            Text("Tap on the image to place a new window")
        }
    }
    
    private var windows: [Window] {
        guard let windowsSet = job.windows else { return [] }
        return (windowsSet.allObjects as? [Window]) ?? []
    }
    
    private func loadImage() {
        guard let imagePath = job.overheadImagePath else { return }
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let imageURL = documentsDirectory.appendingPathComponent("overhead_images").appendingPathComponent(imagePath)
        
        if let loadedImage = UIImage(contentsOfFile: imageURL.path) {
            image = loadedImage
        }
    }
    
    private func handleImageTap(at location: CGPoint, in size: CGSize) {
        if isAddingWindow {
            // Convert tap location to image coordinates
            let imageLocation = CGPoint(
                x: (location.x - offset.width) / scale,
                y: (location.y - offset.height) / scale
            )
            newWindowPosition = imageLocation
        }
    }
    
    private func addWindow(at position: CGPoint) {
        let newWindow = Window(context: viewContext)
        newWindow.windowId = UUID().uuidString
        newWindow.windowNumber = "W\(windows.count + 1)"
        newWindow.xPosition = Double(position.x)
        newWindow.yPosition = Double(position.y)
        newWindow.isAccessible = true
        newWindow.createdAt = Date()
        newWindow.updatedAt = Date()
        newWindow.job = job
        
        do {
            try viewContext.save()
        } catch {
            // Handle error
        }
    }
    
    private func resetView() {
        scale = 1.0
        offset = .zero
        lastOffset = .zero
    }
}

struct WindowDotView: View {
    let window: Window
    let imageSize: CGSize
    let scale: CGFloat
    let offset: CGSize
    let onTap: () -> Void
    
    var body: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 20, height: 20)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
            .overlay(
                Text(window.windowNumber ?? "")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            )
            .position(
                x: CGFloat(window.xPosition) * scale + offset.width,
                y: CGFloat(window.yPosition) * scale + offset.height
            )
            .onTapGesture {
                onTap()
            }
    }
    
    private var dotColor: Color {
        switch window.testResult {
        case "Pass":
            return .green
        case "Fail":
            return .red
        default:
            return .blue
        }
    }
}

struct WindowEditorView: View {
    let window: Window
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var windowNumber: String
    @State private var windowType: String
    @State private var condition: String
    @State private var testResult: String
    @State private var leakPoints: Int16
    @State private var isAccessible: Bool
    @State private var notes: String
    @State private var showingMeasurement = false
    @State private var showingPhotoCapture = false
    @State private var selectedPhotoType: PhotoType = .exterior
    
    init(window: Window) {
        self.window = window
        _windowNumber = State(initialValue: window.windowNumber ?? "")
        _windowType = State(initialValue: window.windowType ?? "")
        _condition = State(initialValue: window.condition ?? "")
        _testResult = State(initialValue: window.testResult ?? "")
        _leakPoints = State(initialValue: window.leakPoints)
        _isAccessible = State(initialValue: window.isAccessible)
        _notes = State(initialValue: window.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Window Details") {
                    TextField("Window Number", text: $windowNumber)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Window Type")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        WindowTypePickerView(selectedWindowType: $windowType)
                    }
                    
                    TextField("Condition", text: $condition)
                }
                
                Section("Test Results") {
                    Picker("Test Result", selection: $testResult) {
                        Text("Pending").tag("")
                        Text("Pass").tag("Pass")
                        Text("Fail").tag("Fail")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Stepper("Leak Points: \(leakPoints)", value: $leakPoints, in: 0...10)
                    
                    Toggle("Accessible", isOn: $isAccessible)
                }
                
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Measurements") {
                    HStack {
                        Image(systemName: "ruler")
                        Text("Dimensions")
                        Spacer()
                        if window.width > 0 && window.height > 0 {
                            Text("\(String(format: "%.1f", window.width))\" × \(String(format: "%.1f", window.height))\"")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Not measured")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button("Measure with AR") {
                        showingMeasurement = true
                    }
                    .buttonStyle(.bordered)
                }
                
                Section("Photos") {
                    PhotoRow(
                        icon: "house",
                        title: "Exterior Photo",
                        isComplete: window.exteriorPhotoPath != nil,
                        window: window,
                        photoType: .exterior
                    )
                    
                    PhotoRow(
                        icon: "door.left.hand.open",
                        title: "Interior Photo",
                        isComplete: window.interiorPhotoPath != nil,
                        window: window,
                        photoType: .interior
                    )
                    
                    if testResult == "Fail" {
                        PhotoRow(
                            icon: "drop",
                            title: "Leak Photo",
                            isComplete: window.leakPhotoPath != nil,
                            window: window,
                            photoType: .leak
                        )
                    }
                }
            }
            .navigationTitle("Window \(windowNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveWindow()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingMeasurement) {
                MeasurementView(window: window)
            }
            .sheet(isPresented: $showingPhotoCapture) {
                PhotoCaptureView(window: window, photoType: selectedPhotoType)
            }
        }
    }
    
    private func saveWindow() {
        window.windowNumber = windowNumber
        window.windowType = windowType.isEmpty ? nil : windowType
        window.condition = condition.isEmpty ? nil : condition
        window.testResult = testResult.isEmpty ? nil : testResult
        window.leakPoints = leakPoints
        window.isAccessible = isAccessible
        window.notes = notes.isEmpty ? nil : notes
        window.updatedAt = Date()
        
        do {
            try viewContext.save()
        } catch {
            // Handle error
        }
    }
}

struct PhotoRow: View {
    let icon: String
    let title: String
    let isComplete: Bool
    let window: Window
    let photoType: PhotoType
    @State private var showingPhotoCapture = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(photoType.color)
            Text(title)
            Spacer()
            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.gray)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingPhotoCapture = true
        }
        .sheet(isPresented: $showingPhotoCapture) {
            PhotoCaptureView(window: window, photoType: photoType)
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let job = Job(context: context)
    job.jobId = "E2025-05091"
    job.clientName = "Smith"
    job.overheadImagePath = "sample_overhead.jpg"
    
    return OverheadCanvasView(job: job)
        .environment(\.managedObjectContext, context)
}
