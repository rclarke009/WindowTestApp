//
//  SettingsView.swift
//  WindowTest
//
//  Created by Rebecca Clarke on 9/26/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("inspectorName") private var inspectorName: String = ""
    @AppStorage("defaultWindowType") private var defaultWindowType: String = "Single Hung"
    @AppStorage("autoSavePhotos") private var autoSavePhotos: Bool = true
    @AppStorage("measurementUnits") private var measurementUnits: String = "inches"
    @AppStorage("enableARKit") private var enableARKit: Bool = true
    
    var body: some View {
        NavigationView {
            Form {
                Section("Inspector Information") {
                    TextField("Inspector Name", text: $inspectorName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Section("Default Settings") {
                    Picker("Default Window Type", selection: $defaultWindowType) {
                        Text("Single Hung").tag("Single Hung")
                        Text("Double Hung").tag("Double Hung")
                        Text("Casement").tag("Casement")
                        Text("Awning").tag("Awning")
                        Text("Sliding").tag("Sliding")
                        Text("Fixed").tag("Fixed")
                    }
                    
                    Picker("Measurement Units", selection: $measurementUnits) {
                        Text("Inches").tag("inches")
                        Text("Centimeters").tag("centimeters")
                        Text("Feet").tag("feet")
                    }
                }
                
                Section("Features") {
                    Toggle("Auto-save Photos", isOn: $autoSavePhotos)
                    Toggle("Enable ARKit Measurements", isOn: $enableARKit)
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Support") {
                    Button("User Guide") {
                        // TODO: Open user guide
                    }
                    
                    Button("Contact Support") {
                        // TODO: Open support contact
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SettingsView()
}
