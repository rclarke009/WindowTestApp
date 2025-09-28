//
//  PhotoCaptureView.swift
//  WindowTest
//
//  Created by Rebecca Clarke on 9/26/25.
//

import SwiftUI
import AVFoundation
import Photos

enum PhotoType: String, CaseIterable {
    case exterior = "Exterior"
    case interior = "Interior"
    case leak = "Leak"
    
    var icon: String {
        switch self {
        case .exterior:
            return "house"
        case .interior:
            return "door.left.hand.open"
        case .leak:
            return "drop"
        }
    }
    
    var color: Color {
        switch self {
        case .exterior:
            return .blue
        case .interior:
            return .green
        case .leak:
            return .red
        }
    }
}

struct PhotoCaptureView: View {
    let window: Window
    let photoType: PhotoType
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraManager = CameraManager()
    @State private var capturedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingPhotoLibrary = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if cameraManager.isAuthorized {
                    CameraPreviewView(session: cameraManager.session)
                        .aspectRatio(4/3, contentMode: .fit)
                        .clipped()
                        .overlay(
                            VStack {
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        cameraManager.switchCamera()
                                    }) {
                                        Image(systemName: "camera.rotate")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(Circle())
                                    }
                                    .padding()
                                }
                                Spacer()
                                HStack(spacing: 20) {
                                    Button(action: {
                                        showingPhotoLibrary = true
                                    }) {
                                        Image(systemName: "photo.on.rectangle")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(Circle())
                                    }
                                    
                                    Button(action: capturePhoto) {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 80, height: 80)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.black, lineWidth: 4)
                                            )
                                    }
                                    
                                    Button(action: {
                                        // Flash toggle
                                    }) {
                                        Image(systemName: "bolt.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(Circle())
                                    }
                                }
                                .padding()
                            }
                        )
                } else {
                    VStack(spacing: 30) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.secondary)
                        
                        Text("Camera Access Required")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Please allow camera access to take photos for window inspection")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Open Settings") {
                            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsURL)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("\(photoType.rawValue) Photo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .onAppear {
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            ImagePicker(selectedImage: $capturedImage)
        }
        .alert("Photo Saved", isPresented: $showingAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: capturedImage) { _, image in
            if let image = image {
                savePhoto(image)
            }
        }
    }
    
    private func capturePhoto() {
        cameraManager.capturePhoto { image in
            capturedImage = image
        }
    }
    
    private func savePhoto(_ image: UIImage) {
        // Request photo library permission
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                if status == .authorized {
                    self.savePhotoToLibrary(image)
                } else {
                    self.alertMessage = "Photo library access is required to save photos"
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func savePhotoToLibrary(_ image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .photo, imageData: image.jpegData(compressionQuality: 0.9)!, options: nil)
            
            if let assetPlaceholder = creationRequest.placeholderForCreatedAsset {
                // Create Photo entity in Core Data
                let photo = Photo(context: self.window.managedObjectContext!)
                photo.photoId = UUID().uuidString
                photo.photoType = self.photoType.rawValue
                photo.localIdentifier = assetPlaceholder.localIdentifier
                photo.createdAt = Date()
                photo.window = self.window
                
                // Add to photos relationship
                self.window.addToPhotos(photo)
                
                self.window.updatedAt = Date()
            }
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    do {
                        try self.window.managedObjectContext?.save()
                        self.alertMessage = "\(self.photoType.rawValue) photo saved to camera roll successfully"
                        self.showingAlert = true
                    } catch {
                        self.alertMessage = "Failed to save photo data: \(error.localizedDescription)"
                        self.showingAlert = true
                    }
                } else {
                    self.alertMessage = "Failed to save photo to camera roll: \(error?.localizedDescription ?? "Unknown error")"
                    self.showingAlert = true
                }
            }
        }
    }
}

class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    
    @Published var isAuthorized = false
    @Published var error: String?
    
    override init() {
        super.init()
        checkAuthorization()
    }
    
    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                }
            }
        case .denied, .restricted:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }
    
    func startSession() {
        guard isAuthorized else { return }
        
        session.beginConfiguration()
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        
        setupVideoInput()
        
        session.commitConfiguration()
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }
    
    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.stopRunning()
        }
    }
    
    private func setupVideoInput() {
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func switchCamera() {
        guard let currentInput = videoDeviceInput else { return }
        
        session.beginConfiguration()
        session.removeInput(currentInput)
        
        let newPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
        
        guard let newVideoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
            session.addInput(currentInput)
            session.commitConfiguration()
            return
        }
        
        do {
            let newVideoDeviceInput = try AVCaptureDeviceInput(device: newVideoDevice)
            
            if session.canAddInput(newVideoDeviceInput) {
                session.addInput(newVideoDeviceInput)
                self.videoDeviceInput = newVideoDeviceInput
            } else {
                session.addInput(currentInput)
            }
        } catch {
            session.addInput(currentInput)
        }
        
        session.commitConfiguration()
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        let settings = AVCapturePhotoSettings()
        let delegate = PhotoCaptureDelegate(completion: completion)
        
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }
}

class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (UIImage?) -> Void
    
    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            completion(nil)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            completion(nil)
            return
        }
        
        DispatchQueue.main.async {
            self.completion(image)
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.frame
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
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
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
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
    let context = PersistenceController.preview.container.viewContext
    let window = Window(context: context)
    window.windowId = "W01"
    window.windowNumber = "W01"
    
    return PhotoCaptureView(window: window, photoType: .exterior)
        .environment(\.managedObjectContext, context)
}