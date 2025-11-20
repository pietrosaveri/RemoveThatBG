//
//  SettingsView.swift
//  RemoveThatBG!
//
//  Created by Pietro Saveri on 13/11/25.
//

import SwiftUI

struct ModelOption: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let size: String // e.g. "176 MB"
    let sizeBytes: Int // for sorting/comparison
    
    init(_ name: String, _ description: String, _ size: String, _ sizeBytes: Int) {
        self.id = name
        self.name = name
        self.description = description
        self.size = size
        self.sizeBytes = sizeBytes
    }
}

class SettingsManager: ObservableObject {
    @Published var selectedModel: String {
        didSet {
            UserDefaults.standard.set(selectedModel, forKey: "selectedModel")
        }
    }
    
    @Published var animatePopover: Bool {
        didSet {
            UserDefaults.standard.set(animatePopover, forKey: "animatePopover")
            NotificationCenter.default.post(name: .popoverAnimationChanged, object: nil)
        }
    }
    
    init() {
        self.selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "u2netp"
        self.animatePopover = UserDefaults.standard.bool(forKey: "animatePopover")
    }
    
    static let shared = SettingsManager()
}

enum SettingsTab: String, CaseIterable {
    case authors = "Authors"
    case model = "Model"
    case design = "Design"
    
    var icon: String {
        switch self {
        case .authors: return "person.circle"
        case .model: return "cube.box"
        case .design: return "paintpalette"
        }
    }
}

struct SettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var selectedTab: SettingsTab = .authors
    
    let models: [ModelOption] = [
        ModelOption("u2net", "A pre-trained model for general use cases.", "176 MB", 176),
        ModelOption("u2netp", "A lightweight version of u2net model.", "4.6 MB", 5),
        ModelOption("u2net_human_seg", "A pre-trained model for human segmentation.", "176 MB", 176),
        ModelOption("isnet-general-use", "A new pre-trained model for general use cases. (recommended)", "178.6 MB", 179),
        ModelOption("isnet-anime", "A high-accuracy segmentation for anime character.", "176.1 MB", 176),
        ModelOption("birefnet-general", "A pre-trained model for general use cases.", "972.7 MB", 973),
        ModelOption("birefnet-general-lite", "A light pre-trained model for general use cases.", "224 MB", 224),
        ModelOption("birefnet-portrait", "A pre-trained model for human portraits.", "972.7 MB", 973),
        ModelOption("birefnet-dis", "A pre-trained model for dichotomous image segmentation (DIS)", "972.7 MB", 973),
        ModelOption("birefnet-hrsod", "A pre-trained model for high-resolution salient object detection (HRSOD)", "972.7 MB", 973),
        ModelOption("birefnet-cod", "A pre-trained model for concealed object detection (COD).", "972.7 MB", 973),
        ModelOption("birefnet-massive", "Massive dataset training", "972.7 MB", 973)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar with tab buttons
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    ToolbarTabButton(
                        title: tab.rawValue,
                        icon: tab.icon,
                        isSelected: selectedTab == tab
                    ) {
                        selectedTab = tab
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            
            Divider()
            
            // Content area
            ScrollView {
                switch selectedTab {
                case .authors:
                    AuthorsTabContent()
                case .model:
                    ModelTabContent(settings: settings, models: models)
                case .design:
                    DesignTabContent()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        }
    }
}

struct ToolbarTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                Text(title)
                    .font(.caption)
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .frame(width: 50, height: 50)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(8)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

struct AuthorsTabContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RemoveThatBG!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
            
            Text("Created by Pietro Saveri for a real need")
                .font(.title3)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                
            Spacer()
            Spacer()
            Spacer()
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Special Thanks")
                    .font(.headline)
                
                Text("Background removal powered by rembg")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Link("github.com/danielgatis/rembg", 
                     destination: URL(string: "https://github.com/danielgatis/rembg")!)
                    .font(.body)
            }
            
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ModelTabContent: View {
    @ObservedObject var settings: SettingsManager
    let models: [ModelOption]
    @State private var downloadingModel: String?
    @State private var downloadComplete: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Select Model")
                .font(.title2)
                .fontWeight(.semibold)
            
            Picker("Model", selection: $settings.selectedModel) {
                ForEach(models) { model in
                    Text(model.name).tag(model.name)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)
            
            if let selectedModelInfo = models.first(where: { $0.name == settings.selectedModel }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description:")
                        .font(.headline)
                    
                    Text(selectedModelInfo.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    
                    // Model size indicator
                    HStack(spacing: 8) {
                        Text("Size:")
                            .font(.headline)
                        
                        // Size badge with color based on file size
                        HStack(spacing: 4) {
                            Image(systemName: sizeIcon(for: selectedModelInfo.sizeBytes))
                                .foregroundColor(sizeColor(for: selectedModelInfo.sizeBytes))
                            Text(selectedModelInfo.size)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(sizeColor(for: selectedModelInfo.sizeBytes).opacity(0.15))
                        .cornerRadius(8)
                        
                        Spacer()
                        
                        // Size indicator text
                        Text(sizeLabel(for: selectedModelInfo.sizeBytes))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Model status check with download button
                VStack(alignment: .leading, spacing: 8) {
                    Text("Status:")
                        .font(.headline)
                    
                    ModelStatusView(
                        modelName: selectedModelInfo.name,
                        downloadingModel: $downloadingModel,
                        downloadComplete: $downloadComplete
                    )
                }
                .padding(.top, 8)
            }
                
            Text("Speed: ")
                .font(.headline)
            
            Text("""
            When you download a new model, the download starts immediately. Depending on the model’s size, this may take a little while.
            
            The first image you process with a model may take longer, as the model needs to be loaded into cache. After that, processing speed increases significantly.
            
            The “u2netp” model is the lightest option and still delivers very good results, making it ideal for most users.
            
            If you have a slow or unstable internet connection, consider using a local model for faster and more reliable performance.
            
            The model server automatically starts on the first available port between 55000 and 55010 on your computer.
            
            When you close the app, the server shuts down automatically.
            If the server fails to start, a message is shown in the main window.
            """)
                .font(.body)
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            
            Text("Note: All models will download to ~/Library/Application Support/RemoveThatBG/models/")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
            
            Spacer()
        }
        .padding(24)
    }
    
    // Helper functions for size indicators
    private func sizeColor(for sizeMB: Int) -> Color {
        switch sizeMB {
        case 0..<50: return .green
        case 50..<200: return .blue
        case 200..<500: return .orange
        default: return .red
        }
    }
    
    private func sizeIcon(for sizeMB: Int) -> String {
        switch sizeMB {
        case 0..<50: return "hare.fill"
        case 50..<200: return "tortoise.fill"
        case 200..<500: return "arrow.down.circle.fill"
        default: return "exclamationmark.arrow.triangle.2.circlepath"
        }
    }
    
    private func sizeLabel(for sizeMB: Int) -> String {
        switch sizeMB {
        case 0..<50: return "Very light"
        case 50..<200: return "Light"
        case 200..<500: return "Medium"
        default: return "Heavy"
        }
    }
}

struct ModelStatusView: View {
    let modelName: String
    @Binding var downloadingModel: String?
    @Binding var downloadComplete: Bool
    
    // Simple computed property - checks file existence every time view updates
    private var isDownloaded: Bool {
        let modelsDir = PythonServerManager.shared.getModelsDirectory()
        let path = modelsDir.appendingPathComponent("\(modelName).onnx").path
        return FileManager.default.fileExists(atPath: path)
    }
    
    private var modelPath: String {
        let modelsDir = PythonServerManager.shared.getModelsDirectory()
        return modelsDir.appendingPathComponent("\(modelName).onnx").path
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if downloadingModel == modelName {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Downloading...")
                        .font(.body)
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: isDownloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                        .foregroundColor(isDownloaded ? .green : .orange)
                    
                    if isDownloaded {
                        Text("Downloaded at \(modelPath)")
                            .font(.body)
                            .foregroundColor(.green)
                    } else {
                        Text("Not downloaded yet")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Download button only if NOT downloaded and NOT downloading
                if !isDownloaded && downloadingModel != modelName {
                    Button("Download Now") {
                        startDownload()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isDownloaded ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
            .cornerRadius(8)
        }
        // Force refresh when download completes
        .id("\(modelName)-\(downloadComplete)")
    }
    
    private func startDownload() {
        downloadingModel = modelName
        
        PythonServerManager.shared.downloadModel(modelName) { success in
            DispatchQueue.main.async {
                downloadingModel = nil
                if success {
                    downloadComplete.toggle() // Trigger UI refresh
                }
            }
        }
    }
}

struct DesignTabContent: View {
    @StateObject private var settings = SettingsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Design Settings")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.leading)
                
            
            Toggle("Animate at opening", isOn: $settings.animatePopover)
                .toggleStyle(.switch)
                .multilineTextAlignment(.leading)
            
            Spacer()
            Divider()
            
            Text("More design features coming soon...")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
    }
}

#Preview {
    SettingsView()
}
