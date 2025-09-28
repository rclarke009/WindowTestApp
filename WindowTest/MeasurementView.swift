//
//  MeasurementView.swift
//  WindowTest
//
//  Created by Rebecca Clarke on 9/26/25.
//

import SwiftUI
import ARKit
import RealityKit

struct MeasurementView: View {
    let window: Window
    @Environment(\.dismiss) private var dismiss
    @StateObject private var arManager = ARMeasurementManager()
    @State private var measuredWidth: Double = 0
    @State private var measuredHeight: Double = 0
    @State private var isMeasuring = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        ZStack {
            if arManager.isARSupported {
                ARViewContainer(arManager: arManager)
                    .ignoresSafeArea()
                
                VStack {
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        
                        Spacer()
                        
                        Button("Reset") {
                            arManager.resetMeasurement()
                        }
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }
                    .padding()
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        if isMeasuring {
                            VStack(spacing: 8) {
                                Text("Tap to place measurement points")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                Text("Point 1: Tap on one corner of the window")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            VStack(spacing: 12) {
                                Text("Window Measurements")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 20) {
                                    VStack {
                                        Text("Width")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                        Text("\(String(format: "%.1f", measuredWidth))\"")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                    
                                    VStack {
                                        Text("Height")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                        Text("\(String(format: "%.1f", measuredHeight))\"")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                }
                                
                                Button("Save Measurements") {
                                    saveMeasurements()
                                }
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                            }
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 30) {
                    Image(systemName: "arkit")
                        .font(.system(size: 80))
                        .foregroundColor(.secondary)
                    
                    Text("AR Not Available")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("ARKit is not supported on this device. You can manually enter measurements instead.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Enter Manually") {
                        // TODO: Show manual entry view
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .navigationTitle("Measure Window")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            arManager.startSession()
        }
        .onDisappear {
            arManager.stopSession()
        }
        .onReceive(arManager.$measurementComplete) { isComplete in
            if isComplete {
                measuredWidth = arManager.measuredWidth
                measuredHeight = arManager.measuredHeight
                isMeasuring = false
            }
        }
        .alert("Measurements Saved", isPresented: $showingAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func saveMeasurements() {
        window.width = measuredWidth
        window.height = measuredHeight
        window.updatedAt = Date()
        
        do {
            try window.managedObjectContext?.save()
            alertMessage = "Window measurements saved successfully"
            showingAlert = true
        } catch {
            alertMessage = "Failed to save measurements: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    let arManager: ARMeasurementManager
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arManager.setupARView(arView)
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

class ARMeasurementManager: NSObject, ObservableObject {
    @Published var isARSupported = false
    @Published var measurementComplete = false
    @Published var measuredWidth: Double = 0
    @Published var measuredHeight: Double = 0
    
    private var arView: ARView?
    private var measurementPoints: [SIMD3<Float>] = []
    private var measurementEntities: [ModelEntity] = []
    
    override init() {
        super.init()
        isARSupported = ARWorldTrackingConfiguration.isSupported
    }
    
    func setupARView(_ arView: ARView) {
        self.arView = arView
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        arView.session.run(configuration)
        
        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
    }
    
    func startSession() {
        guard let arView = arView else { return }
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        arView.session.run(configuration)
    }
    
    func stopSession() {
        arView?.session.pause()
    }
    
    func resetMeasurement() {
        measurementPoints.removeAll()
        measurementEntities.forEach { $0.removeFromParent() }
        measurementEntities.removeAll()
        measurementComplete = false
        measuredWidth = 0
        measuredHeight = 0
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let arView = arView else { return }
        
        let tapLocation = gesture.location(in: arView)
        let results = arView.raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .any)
        
        guard let result = results.first else { return }
        
        let worldPosition = result.worldTransform.columns.3
        let position = SIMD3<Float>(worldPosition.x, worldPosition.y, worldPosition.z)
        
        measurementPoints.append(position)
        
        // Add visual indicator
        addMeasurementPoint(at: position)
        
        if measurementPoints.count == 2 {
            calculateMeasurements()
        }
    }
    
    private func addMeasurementPoint(at position: SIMD3<Float>) {
        guard let arView = arView else { return }
        
        let sphere = MeshResource.generateSphere(radius: 0.01)
        let material = SimpleMaterial(color: .blue, isMetallic: false)
        let entity = ModelEntity(mesh: sphere, materials: [material])
        
        entity.position = position
        let anchorEntity = AnchorEntity()
        anchorEntity.addChild(entity)
        arView.scene.addAnchor(anchorEntity)
        measurementEntities.append(entity)
    }
    
    private func calculateMeasurements() {
        guard measurementPoints.count == 2 else { return }
        
        let point1 = measurementPoints[0]
        let point2 = measurementPoints[1]
        
        // Calculate distance in meters
        let distance = simd_distance(point1, point2)
        
        // Convert to inches (assuming 1 meter = 39.37 inches)
        let distanceInches = Double(distance) * 39.37
        
        // For simplicity, assume this is the width
        // In a real implementation, you'd need more sophisticated logic
        // to determine which dimension is width vs height
        measuredWidth = distanceInches
        measuredHeight = distanceInches * 0.75 // Placeholder ratio
        
        measurementComplete = true
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let window = Window(context: context)
    window.windowId = "W01"
    window.windowNumber = "W01"
    
    return MeasurementView(window: window)
        .environment(\.managedObjectContext, context)
}
