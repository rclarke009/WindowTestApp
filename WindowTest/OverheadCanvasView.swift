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
                                .background(
                                    GeometryReader { imageGeometry in
                                        Color.clear
                                            .onAppear {
                                                // Use the same logic as markLocation - calculate based on frame size
                                                let frameSize = imageGeometry.size
                                                let imageAspectRatio = image.size.width / image.size.height
                                                let frameAspectRatio = frameSize.width / frameSize.height
                                                
                                                if imageAspectRatio > frameAspectRatio {
                                                    // Image is wider - letterboxed (empty space top/bottom)
                                                    let displayedHeight = frameSize.width / imageAspectRatio
                                                    imageSize = CGSize(width: frameSize.width, height: displayedHeight)
                                                } else {
                                                    // Image is taller - pillarboxed (empty space left/right)
                                                    let displayedWidth = frameSize.height * imageAspectRatio
                                                    imageSize = CGSize(width: displayedWidth, height: frameSize.height)
                                                }
                                            }
                                            .onTapGesture { location in
                                                handleImageTap(at: location, in: imageGeometry.size)
                                            }
                                    }
                                )
                            
                            // Window dots overlay - only render after imageSize is set
                            if imageSize.width > 0 && imageSize.height > 0 {
                            ForEach(windows, id: \.objectID) { window in
                                WindowDotView(
                                    window: window,
                                    imageSize: imageSize,
                                    scale: scale,
                                        offset: offset,
                                        onTap: {
                                    selectedWindow = window
                                    showingWindowEditor = true
                                        },
                                        originalImageSize: image.size
                                    )
                                }
                            }
                            
                            // Visual feedback overlay when in adding mode
                            if isAddingWindow {
                                VStack {
                                    Spacer()
                                    Text("Tap anywhere on the image to place a new window")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.black.opacity(0.7))
                                        .cornerRadius(10)
                                        .padding(.bottom, 50)
                                }
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
                Button(isAddingWindow ? "Cancel" : "Add Window") {
                    isAddingWindow.toggle()
                }
                .disabled(image == nil)
                .foregroundColor(isAddingWindow ? .red : .blue)
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
            // Convert tap location to actual image coordinates using the same logic as main view
            let imageAspectRatio = (image?.size.width ?? 1.0) / (image?.size.height ?? 1.0)
            let frameAspectRatio = size.width / size.height
            
            var imageLocation: CGPoint
            
            if imageAspectRatio > frameAspectRatio {
                // Image is wider than frame - letterboxed (black bars on top/bottom)
                let imageWidth = size.width
                let imageHeight = size.width / imageAspectRatio
                let yOffset = (size.height - imageHeight) / 2
                
                imageLocation = CGPoint(
                    x: location.x * (image?.size.width ?? 1.0) / imageWidth,
                    y: (location.y - yOffset) * (image?.size.height ?? 1.0) / imageHeight
                )
            } else {
                // Image is taller than frame - pillarboxed (black bars on left/right)
                let imageHeight = size.height
                let imageWidth = size.height * imageAspectRatio
                let xOffset = (size.width - imageWidth) / 2
                
                imageLocation = CGPoint(
                    x: (location.x - xOffset) * (image?.size.width ?? 1.0) / imageWidth,
                    y: location.y * (image?.size.height ?? 1.0) / imageHeight
                )
            }
            
            // Immediately create a new window at the tapped location
        let newWindow = Window(context: viewContext)
        newWindow.windowId = UUID().uuidString
        newWindow.windowNumber = "W\(windows.count + 1)"
            newWindow.xPosition = Double(imageLocation.x)
            newWindow.yPosition = Double(imageLocation.y)
        newWindow.isAccessible = true
        newWindow.createdAt = Date()
        newWindow.updatedAt = Date()
        newWindow.job = job
            
            print("🔍 Created window \(newWindow.windowNumber ?? "Unknown") for job: \(job.jobId ?? "Unknown")")
            print("🔍 Job overhead image path: \(job.overheadImagePath ?? "None")")
        
        do {
            try viewContext.save()
                print("✅ Window saved successfully")
                
                // Set the new window as selected and open the editor
                selectedWindow = newWindow
                showingWindowEditor = true
                isAddingWindow = false
        } catch {
            // Handle error
                print("❌ Error creating window: \(error)")
            }
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
    let originalImageSize: CGSize
    
    var body: some View {
        GeometryReader { geometry in
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
                    x: convertImageToViewX(Double(window.xPosition), imageSize: imageSize, viewSize: geometry.size, originalImageSize: originalImageSize),
                    y: convertImageToViewY(Double(window.yPosition), imageSize: imageSize, viewSize: geometry.size, originalImageSize: originalImageSize)
            )
            .onTapGesture {
                onTap()
                }
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
    @State private var showingLocationMarker = false
    
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
                    
                    Button("Mark Location on Overhead") {
                        showingLocationMarker = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.blue)
                }
                
                Section("Photos") {
                    PhotoRow(
                        icon: "house",
                        title: "Exterior Photos",
                        window: window,
                        photoType: .exterior
                    )
                    
                    PhotoRow(
                        icon: "door.left.hand.open",
                        title: "Interior Photos",
                        window: window,
                        photoType: .interior
                    )
                    
                    if testResult == "Fail" {
                        PhotoRow(
                            icon: "drop",
                            title: "Leak Photos",
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
            .sheet(isPresented: $showingLocationMarker) {
                LocationMarkerView(window: window)
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
    let window: Window
    let photoType: PhotoType
    @State private var showingPhotoGallery = false
    
    private var photoCount: Int {
        switch photoType {
        case .exterior:
            return window.exteriorPhotos?.count ?? 0
        case .interior:
            return window.interiorPhotos?.count ?? 0
        case .leak:
            return window.leakPhotos?.count ?? 0
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(photoType.color)
            Text(title)
            Spacer()
            if photoCount > 0 {
                HStack(spacing: 4) {
                    Text("\(photoCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Image(systemName: "photo.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.gray)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingPhotoGallery = true
        }
        .sheet(isPresented: $showingPhotoGallery) {
            PhotoGalleryView(window: window, photoType: photoType)
        }
    }
}

// MARK: - Location Marker View
struct LocationMarkerView: View {
    let window: Window
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var imageSize: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var markedLocation: CGPoint?
    @State private var imageLoadTrigger = UUID()
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()
                    
                    if let image = image {
                        imageView(geometry: geometry, image: image)
                    } else {
                        noImageView
                    }
                }
            }
            .navigationTitle("Mark Location")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .safeAreaInset(edge: .bottom) {
                bottomButtons
            }
        }
        .onAppear {
            loadImage()
            loadExistingLocation()
        }
    }
    
    private func imageView(geometry: GeometryProxy, image: UIImage) -> some View {
        ScrollView([.horizontal, .vertical]) {
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .id(imageLoadTrigger)
                    .scaleEffect(scale)
                    .offset(offset)
                    .background(
                        GeometryReader { imageGeometry in
                            Color.clear
                                .onAppear {
                                    print("📐 IMAGE SIZE DEBUG - Geometry size: \(imageGeometry.size)")
                                    print("📐 IMAGE SIZE DEBUG - Original image size: \(image.size)")
                                    
                                    // Calculate the actual displayed image size based on aspect ratio
                                    let originalSize = image.size
                                    let imageAspectRatio = originalSize.width / originalSize.height
                                    let frameAspectRatio = imageGeometry.size.width / imageGeometry.size.height
                                    
                                    let calculatedImageSize: CGSize
                                    if imageAspectRatio > frameAspectRatio {
                                        // Image is wider - letterboxed
                                        let displayedHeight = imageGeometry.size.width / imageAspectRatio
                                        calculatedImageSize = CGSize(width: imageGeometry.size.width, height: displayedHeight)
                                    } else {
                                        // Image is taller - pillarboxed
                                        let displayedWidth = imageGeometry.size.height * imageAspectRatio
                                        calculatedImageSize = CGSize(width: displayedWidth, height: imageGeometry.size.height)
                                    }
                                    
                                    print("📐 IMAGE SIZE DEBUG - Calculated displayed size: \(calculatedImageSize)")
                                    imageSize = calculatedImageSize
                                }
                        }
                    )
                    .overlay(tapOverlay)
                
                if let location = markedLocation {
                    markedLocationDot(location: location, geometry: geometry, image: image)
                }
            }
            .frame(
                width: max(geometry.size.width, imageSize.width * scale),
                height: max(geometry.size.height, imageSize.height * scale)
            )
        }
        .clipped()
    }
    
    private var tapOverlay: some View {
        GeometryReader { tapGeometry in
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { location in
                    handleTap(at: location)
                }
        }
    }
    
    private func handleTap(at location: CGPoint) {
        // Use the same coordinate conversion logic as the main view
        let originalImageSize = image?.size ?? CGSize.zero
        let imageAspectRatio = originalImageSize.width / originalImageSize.height
        let frameAspectRatio = imageSize.width / imageSize.height
        
        print("🔍 TAP DEBUG - Original image size: \(originalImageSize)")
        print("🔍 TAP DEBUG - Displayed image size: \(imageSize)")
        print("🔍 TAP DEBUG - Image aspect ratio: \(imageAspectRatio)")
        print("🔍 TAP DEBUG - Frame aspect ratio: \(frameAspectRatio)")
        print("🔍 TAP DEBUG - Tap location: \(location)")
        
        var imageLocation: CGPoint
        
        if imageAspectRatio > frameAspectRatio {
            // Image is wider than frame - letterboxed (black bars on top/bottom)
            let imageWidth = imageSize.width
            let imageHeight = imageSize.width / imageAspectRatio
            let yOffset = (imageSize.height - imageHeight) / 2
            
            print("🔍 TAP DEBUG - Letterboxed mode")
            print("🔍 TAP DEBUG - Calculated image width: \(imageWidth)")
            print("🔍 TAP DEBUG - Calculated image height: \(imageHeight)")
            print("🔍 TAP DEBUG - Y offset: \(yOffset)")
            
            imageLocation = CGPoint(
                x: location.x * originalImageSize.width / imageWidth,
                y: (location.y - yOffset) * originalImageSize.height / imageHeight
            )
        } else {
            // Image is taller than frame - pillarboxed (black bars on left/right)
            let imageHeight = imageSize.height
            let imageWidth = imageSize.height * imageAspectRatio
            let xOffset = (imageSize.width - imageWidth) / 2
            
            print("🔍 TAP DEBUG - Pillarboxed mode")
            print("🔍 TAP DEBUG - Calculated image width: \(imageWidth)")
            print("🔍 TAP DEBUG - Calculated image height: \(imageHeight)")
            print("🔍 TAP DEBUG - X offset: \(xOffset)")
            
            imageLocation = CGPoint(
                x: (location.x - xOffset) * originalImageSize.width / imageWidth,
                y: location.y * originalImageSize.height / imageHeight
            )
        }
        
        print("🔍 TAP DEBUG - Final image location: \(imageLocation)")
        markLocation(at: imageLocation, in: imageSize)
    }
    
    private func markedLocationDot(location: CGPoint, geometry: GeometryProxy, image: UIImage) -> some View {
        // Convert image coordinates to view coordinates using the same logic as tap detection
        let originalImageSize = image.size
        let imageAspectRatio = originalImageSize.width / originalImageSize.height
        let frameAspectRatio = geometry.size.width / geometry.size.height
        
        print("🔵 DOT DEBUG - Original image size: \(originalImageSize)")
        print("🔵 DOT DEBUG - Displayed image size: \(imageSize)")
        print("🔵 DOT DEBUG - Geometry size: \(geometry.size)")
        print("🔵 DOT DEBUG - Image aspect ratio: \(imageAspectRatio)")
        print("🔵 DOT DEBUG - Frame aspect ratio: \(frameAspectRatio)")
        print("🔵 DOT DEBUG - Image location: \(location)")
        
        let dotPosition: CGPoint
        
        if imageAspectRatio > frameAspectRatio {
            // Image is wider than frame - letterboxed (black bars on top/bottom)
            let imageWidth = geometry.size.width
            let imageHeight = geometry.size.width / imageAspectRatio
            let yOffset = (geometry.size.height - imageHeight) / 2
            
            print("🔵 DOT DEBUG - Letterboxed mode")
            print("🔵 DOT DEBUG - Calculated image width: \(imageWidth)")
            print("🔵 DOT DEBUG - Calculated image height: \(imageHeight)")
            print("🔵 DOT DEBUG - Y offset: \(yOffset)")
            
            dotPosition = CGPoint(
                x: location.x * imageWidth / originalImageSize.width,
                y: location.y * imageHeight / originalImageSize.height + yOffset
            )
        } else {
            // Image is taller than frame - pillarboxed (black bars on left/right)
            let imageHeight = geometry.size.height
            let imageWidth = geometry.size.height * imageAspectRatio
            let xOffset = (geometry.size.width - imageWidth) / 2
            
            print("🔵 DOT DEBUG - Pillarboxed mode")
            print("🔵 DOT DEBUG - Calculated image width: \(imageWidth)")
            print("🔵 DOT DEBUG - Calculated image height: \(imageHeight)")
            print("🔵 DOT DEBUG - X offset: \(xOffset)")
            
            dotPosition = CGPoint(
                x: location.x * imageWidth / originalImageSize.width + xOffset,
                y: location.y * imageHeight / originalImageSize.height
            )
        }
        
        print("🔵 DOT DEBUG - Final dot position: \(dotPosition)")
        
        return Circle()
            .fill(Color.blue)
            .frame(width: 20, height: 20)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
            .position(x: dotPosition.x, y: dotPosition.y)
            .onAppear {
                print("🔵 Rendering dot - markedLocation: \(location)")
                print("🔵 Original image size: \(image.size)")
                print("🔵 Displayed image size: \(imageSize)")
                print("🔵 ViewSize: \(geometry.size)")
                print("🔵 Converted position: (\(dotPosition.x), \(dotPosition.y))")
            }
    }
    
    private var noImageView: some View {
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
    
    private var bottomButtons: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
            
            Spacer()
            
            Button("Save") {
                saveLocation()
                dismiss()
            }
            .disabled(markedLocation == nil)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
        .padding()
    }
    
    private func loadImage() {
        // Try to get the job from the window relationship first
        let job: Job? = window.job
        
        // If that fails, try to find the job by looking up the window's job relationship
        if job == nil {
            print("⚠️ Window has no associated job, trying to find job by context")
            // This shouldn't happen if the relationship is set correctly, but let's be safe
            return
        }
        
        guard let imagePath = job?.overheadImagePath else {
            print("⚠️ Job has no overhead image path")
            return
        }
        
        print("🔍 Loading overhead image from path: \(imagePath)")
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let imageURL = documentsDirectory.appendingPathComponent("overhead_images").appendingPathComponent(imagePath)
        
        print("🔍 Full image URL: \(imageURL.path)")
        print("🔍 File exists: \(FileManager.default.fileExists(atPath: imageURL.path))")
        
        if let loadedImage = UIImage(contentsOfFile: imageURL.path) {
            DispatchQueue.main.async {
                self.image = loadedImage
                self.imageLoadTrigger = UUID()
                print("✅ Successfully loaded overhead image")
            }
        } else {
            print("❌ Failed to load overhead image")
        }
    }
    
    private func loadExistingLocation() {
        if window.xPosition > 0 && window.yPosition > 0 {
            markedLocation = CGPoint(x: window.xPosition, y: window.yPosition)
        }
    }
    
    private func markLocation(at location: CGPoint, in size: CGSize) {
        print("🎯 Tap detected at location: \(location)")
        print("🎯 Image size: \(size)")
        print("🎯 Current scale: \(scale)")
        print("🎯 Current offset: \(offset)")
        print("🎯 Original image size: \(image?.size ?? CGSize.zero)")
        
        // The location is already in image coordinates from the tap gesture
        // No additional conversion needed
        print("🎯 Setting marked location to: \(location)")
        markedLocation = location
        print("🎯 Marked location is now: \(markedLocation ?? CGPoint.zero)")
        
        // Force UI update
        imageLoadTrigger = UUID()
    }
    
    private func saveLocation() {
        guard let location = markedLocation else { return }
        
        window.xPosition = Double(location.x)
        window.yPosition = Double(location.y)
        window.updatedAt = Date()
        
        do {
            try viewContext.save()
        } catch {
            print("Error saving location: \(error)")
        }
    }
}

// MARK: - Coordinate Conversion Functions

func convertImageToViewX(_ imageX: Double, imageSize: CGSize, viewSize: CGSize, originalImageSize: CGSize) -> Double {
    // Guard against invalid image size
    guard imageSize.width > 0 && imageSize.height > 0 else {
        print("⚠️ convertImageToViewX - Invalid image size: \(imageSize), returning 0")
        return 0
    }
    
    // Use the same logic as markLocation - calculate aspect ratios using the frame size (imageSize)
    let imageAspectRatio = originalImageSize.width / originalImageSize.height
    let frameAspectRatio = imageSize.width / imageSize.height
    let aspectRatioDifference = abs(imageAspectRatio - frameAspectRatio)
    let tolerance = 0.2
    
    print("🔧 convertImageToViewX - imageX: \(imageX), imageSize: \(imageSize), viewSize: \(viewSize)")
    print("🔧 convertImageToViewX - imageAspectRatio: \(imageAspectRatio), frameAspectRatio: \(frameAspectRatio)")
    print("🔧 convertImageToViewX - aspectRatioDifference: \(aspectRatioDifference)")
    
    if aspectRatioDifference < tolerance {
        // Image fits perfectly - no letterboxing or pillarboxing
        let result = imageX * imageSize.width / originalImageSize.width
        print("🔧 convertImageToViewX - perfect fit result: \(result)")
        return result
    } else if imageAspectRatio > frameAspectRatio {
        // Image is wider than frame - letterboxed (empty space top/bottom)
        let imageWidth = imageSize.width
        let result = imageX * imageWidth / originalImageSize.width
        print("🔧 convertImageToViewX - letterboxed result: \(result)")
        return result
    } else {
        // Image is taller than frame - pillarboxed (empty space left/right)
        let imageWidth = imageSize.width
        let xOffset = (viewSize.width - imageWidth) / 2
        let result = imageX * imageWidth / originalImageSize.width + xOffset
        print("🔧 convertImageToViewX - pillarboxed result: \(result) (offset: \(xOffset))")
        return result
    }
}

func convertImageToViewY(_ imageY: Double, imageSize: CGSize, viewSize: CGSize, originalImageSize: CGSize) -> Double {
    // Guard against invalid image size
    guard imageSize.width > 0 && imageSize.height > 0 else {
        print("⚠️ convertImageToViewY - Invalid image size: \(imageSize), returning 0")
        return 0
    }
    
    // Use the same logic as markLocation - calculate aspect ratios using the frame size (imageSize)
    let imageAspectRatio = originalImageSize.width / originalImageSize.height
    let frameAspectRatio = imageSize.width / imageSize.height
    let aspectRatioDifference = abs(imageAspectRatio - frameAspectRatio)
    let tolerance = 0.2
    
    print("🔧 convertImageToViewY - imageY: \(imageY), imageSize: \(imageSize), viewSize: \(viewSize)")
    print("🔧 convertImageToViewY - imageAspectRatio: \(imageAspectRatio), frameAspectRatio: \(frameAspectRatio)")
    print("🔧 convertImageToViewY - aspectRatioDifference: \(aspectRatioDifference)")
    
    if aspectRatioDifference < tolerance {
        // Image fits perfectly - no letterboxing or pillarboxing
        let result = imageY * imageSize.height / originalImageSize.height
        print("🔧 convertImageToViewY - perfect fit result: \(result)")
        return result
    } else if imageAspectRatio > frameAspectRatio {
        // Image is wider than frame - letterboxed (empty space top/bottom)
        let imageHeight = imageSize.height
        let yOffset = (viewSize.height - imageHeight) / 2
        let result = imageY * imageHeight / originalImageSize.height + yOffset
        print("🔧 convertImageToViewY - letterboxed result: \(result) (offset: \(yOffset))")
        return result
    } else {
        // Image is taller than frame - pillarboxed (empty space left/right)
        let imageHeight = imageSize.height
        let result = imageY * imageHeight / originalImageSize.height
        print("🔧 convertImageToViewY - pillarboxed result: \(result)")
        return result
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
