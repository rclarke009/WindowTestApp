//
//  PhotoGalleryView.swift
//  WindowTest
//
//  Created by Rebecca Clarke on 9/26/25.
//

import SwiftUI
import Photos
import CoreData

struct PhotoGalleryView: View {
    let window: Window
    let photoType: PhotoType
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingPhotoCapture = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var photos: [Photo] = []
    
    private var photoRelationship: String {
        switch photoType {
        case .exterior:
            return "exteriorPhotos"
        case .interior:
            return "interiorPhotos"
        case .leak:
            return "leakPhotos"
        }
    }
    
    private var photosArray: [Photo] {
        let allPhotos = (window.photos?.allObjects as? [Photo]) ?? []
        return allPhotos.filter { $0.photoType == photoType.rawValue }
    }
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if photosArray.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: photoType.icon)
                            .font(.system(size: 60))
                            .foregroundColor(photoType.color)
                        
                        Text("No \(photoType.rawValue) Photos")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("Tap the + button to add your first \(photoType.rawValue.lowercased()) photo")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(photosArray.sorted(by: { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }), id: \.photoId) { photo in
                                PhotoThumbnailView(photo: photo, photoType: photoType)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("\(photoType.rawValue) Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingPhotoCapture = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingPhotoCapture) {
            PhotoCaptureView(window: window, photoType: photoType)
        }
        .alert("Photo Deleted", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            loadPhotos()
        }
    }
    
    private func loadPhotos() {
        // Refresh the photos array
        photos = photosArray
    }
    
    private func deletePhoto(_ photo: Photo) {
        viewContext.delete(photo)
        
        do {
            try viewContext.save()
            alertMessage = "Photo deleted successfully"
            showingAlert = true
            loadPhotos()
        } catch {
            alertMessage = "Failed to delete photo: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

struct PhotoThumbnailView: View {
    let photo: Photo
    let photoType: PhotoType
    @State private var image: UIImage?
    @State private var showingFullScreen = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        Button(action: {
            showingFullScreen = true
        }) {
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
                
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            showingDeleteAlert = true
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                    }
                    Spacer()
                }
                .padding(4)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadImage()
        }
        .fullScreenCover(isPresented: $showingFullScreen) {
            FullScreenPhotoView(photo: photo, image: image)
        }
        .alert("Delete Photo", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                // Delete photo logic would go here
            }
        } message: {
            Text("Are you sure you want to delete this photo?")
        }
    }
    
    private func loadImage() {
        guard let localIdentifier = photo.localIdentifier else { return }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        
        guard let asset = fetchResult.firstObject else { return }
        
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        
        imageManager.requestImage(for: asset, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFill, options: options) { result, _ in
            DispatchQueue.main.async {
                self.image = result
            }
        }
    }
}

struct FullScreenPhotoView: View {
    let photo: Photo
    let image: UIImage?
    @Environment(\.dismiss) private var dismiss
    @State private var fullSizeImage: UIImage?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let fullSizeImage = fullSizeImage {
                    Image(uiImage: fullSizeImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .ignoresSafeArea()
                } else if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .ignoresSafeArea()
                } else {
                    VStack {
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                        Text("Loading...")
                            .foregroundColor(.white)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            loadFullSizeImage()
        }
    }
    
    private func loadFullSizeImage() {
        guard let localIdentifier = photo.localIdentifier else { return }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        
        guard let asset = fetchResult.firstObject else { return }
        
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        
        imageManager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { result, _ in
            DispatchQueue.main.async {
                self.fullSizeImage = result
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let window = Window(context: context)
    window.windowId = "W01"
    window.windowNumber = "W01"
    
    return PhotoGalleryView(window: window, photoType: .exterior)
        .environment(\.managedObjectContext, context)
}
