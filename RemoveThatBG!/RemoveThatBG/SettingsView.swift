//
//  SettingsView.swift
//  RemoveThatBG!
//
//  Created by Pietro Saveri on 13/11/25.
//

import SwiftUI

class SettingsManager: ObservableObject {
    @Published var animatePopover: Bool {
        didSet {
            UserDefaults.standard.set(animatePopover, forKey: "animatePopover")
            NotificationCenter.default.post(name: .popoverAnimationChanged, object: nil)
        }
    }
    
    init() {
        self.animatePopover = UserDefaults.standard.bool(forKey: "animatePopover")
    }
    
    static let shared = SettingsManager()
}

enum SettingsTab: String, CaseIterable {
    case authors = "Authors"
    case design = "Design"
    
    var icon: String {
        switch self {
        case .authors: return "person.circle"
        case .design: return "paintpalette"
        }
    }
}

struct SettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var selectedTab: SettingsTab = .authors
    
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
            
            VStack(spacing: 5) {
                Text("Yes! It's Open Source.")
                    .font(.headline)
                
                HStack(spacing: 4) {
                    Text("If you want to drop me a star:")
                    Link(destination: URL(string: "https://github.com/pietrosaveri/RemoveThatBG")!) {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("GitHub")
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            
            Spacer()
            Spacer()
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Background Removal Technology")
                    .font(.headline)
                
                Text("Powered by Apple's native Vision framework")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text("Uses VNGenerateForegroundInstanceMaskRequest for fast, on-device subject extraction")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
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
