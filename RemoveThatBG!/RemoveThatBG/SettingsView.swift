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
    
    init(_ name: String, _ description: String) {
        self.id = name
        self.name = name
        self.description = description
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
        ModelOption("u2net", "A pre-trained model for general use cases."),
        ModelOption("u2netp", "A lightweight version of u2net model."),
        ModelOption("u2net_human_seg", "A pre-trained model for human segmentation."),
        ModelOption("silueta", "Same as u2net but the size is reduced to 43Mb."),
        ModelOption("isnet-general-use", "A new pre-trained model for general use cases. (recommended)"),
        ModelOption("isnet-anime", "A high-accuracy segmentation for anime character."),
        
        ModelOption("sam", "General use cases"),
        ModelOption("birefnet-general", "A pre-trained model for general use cases."),
        ModelOption("birefnet-general-lite", "A light pre-trained model for general use cases."),
        ModelOption("birefnet-portrait", "A pre-trained model for human portraits."),
        ModelOption("birefnet-dis", "A pre-trained model for dichotomous image segmentation (DIS)"),
        ModelOption("birefnet-hrsod", "A pre-trained model for high-resolution salient object detection (HRSOD)"),
        ModelOption("birefnet-cod", "A pre-trained model for concealed object detection (COD)."),
        ModelOption("birefnet-massive", "Massive dataset training")
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
                }
                
                // Model status check
                VStack(alignment: .leading, spacing: 8) {
                    Text("Status:")
                        .font(.headline)
                    
                    ModelStatusView(modelName: selectedModelInfo.name)
                }
                .padding(.top, 8)
            }
            
            Text("Note: First use of a new model will download it to ~/.u2net/")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
            
            Spacer()
        }
        .padding(24)
    }
}

struct ModelStatusView: View {
    let modelName: String
    
    var isModelDownloaded: Bool {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let modelPath = homeDirectory.appendingPathComponent(".u2net/\(modelName).onnx")
        return FileManager.default.fileExists(atPath: modelPath.path)
    }
    
    var modelPath: String {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        return homeDirectory.appendingPathComponent(".u2net/\(modelName).onnx").path
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isModelDownloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                .foregroundColor(isModelDownloaded ? .green : .secondary)
            
            if isModelDownloaded {
                Text("Already downloaded at \(modelPath)")
                    .font(.body)
                    .foregroundColor(.green)
            } else {
                Text("Not yet downloaded")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isModelDownloaded ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
        .cornerRadius(8)
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
