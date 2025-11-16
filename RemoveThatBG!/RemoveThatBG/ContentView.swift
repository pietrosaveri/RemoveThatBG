//
//  ContentView.swift
//  RemoveThatBG!
//
//  Created by Pietro Saveri on 13/11/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var draggedImage: NSImage? = nil
    @State private var processedImage: NSImage? = nil
    @State private var isProcessing = false
    @State private var isTargeted = false
    @FocusState private var isDragAreaFocused: Bool
    @State private var isHovering = false
    @State private var isRightAreaHovering = false  // ← NEW: For right area hover
    @State private var canPaste = false  // ← NEW: Check if clipboard has image
    @State private var progress: Double = 0.0 // NEW: Progress state
    @StateObject private var settings = SettingsManager.shared
    
    var body: some View {
        VStack(spacing: -10) {
            
            // Preferences shortcut hint
            HStack {
                Spacer()
                Text("Preferences: ⌘,")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 12)
                    .padding(.top, 8)
            }
            
            // Main content area
            HStack(spacing: 10) {
                // Left side - Drag and Drop area
                VStack {
                    ZStack {
                        if let image = draggedImage {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(8)
                        } else {
                            Text("Drag and Drop here!\n⌘+v")
                                .multilineTextAlignment(.center)
                                .font(.title3)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        
                        // Paste button - only shows on hover and if clipboard has image
                        if isHovering && canPaste {
                            Button(action: {
                                pasteFromClipboard()
                            }) {
                                HStack {
                                    Image(systemName: "doc.on.clipboard")
                                    Text("Paste")
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background((isHovering || isTargeted) ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .focusable()
                    .focusEffectDisabled()
                    .focused($isDragAreaFocused)
                    .onDrop(of: ["public.file-url", "public.image"], isTargeted: $isTargeted) { providers in
                        handleDrop(providers: providers)
                        return true
                    }
                    .onTapGesture {
                        isDragAreaFocused = true
                    }
                    .onPasteCommand(of: [.fileURL, .image]) { providers in
                        handlePaste(providers: providers)
                    }
                    .onHover { hovering in
                        isHovering = hovering
                        if hovering {
                            checkClipboard()
                        }
                    }
                }
                
                // Arrow
                Image(systemName: "arrow.right")
                    .font(.largeTitle)
                
                // Right side - Processing area
                VStack {
                    ZStack {
                        if let processed = processedImage {
                            Image(nsImage: processed)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(8)
                                .onDrag {
                                    let provider = NSItemProvider()
                                    provider.suggestedName = "processed_image"
                                    
                                    if let tiffData = processed.tiffRepresentation,
                                       let bitmapImage = NSBitmapImageRep(data: tiffData),
                                       let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                                        provider.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier, visibility: .all) { completion in
                                            completion(pngData, nil)
                                            return nil
                                        }
                                    }
                                    return provider
                                }
                        } else if isProcessing {
                            VStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.bottom, 4)
                                Text("Processing...")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            Text("Processing\nArea")
                                .multilineTextAlignment(.center)
                                .font(.title3)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        
                        // Copy button - only shows on hover when processed image exists
                        if isRightAreaHovering && processedImage != nil {
                            Button(action: {
                                copyToClipboard()
                            }) {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy")
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.green.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .onHover { hovering in
                        isRightAreaHovering = hovering
                    }
                }
            }
            .padding()
            .padding(.top, 0)
            
            // Close and Quit buttons
            HStack(spacing: 5) {
                Button("Close") {
                    NotificationCenter.default.post(name: .closePopover, object: nil)
                }
                .font(.caption)
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(4)
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.caption)
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(4)
            }
            .padding(.bottom, 8)
            
            // Loading bar - NEW
            if isProcessing {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
        }
        .frame(width: 500, height: 270)
        .background(.ultraThinMaterial)
        .onAppear {
            isDragAreaFocused = true
            checkClipboard()
        }
    }
    
    func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            // Try to load as file URL first (from Finder, WhatsApp, etc.)
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (item, error) in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil),
                       let image = NSImage(contentsOf: url) {
                        DispatchQueue.main.async {
                            self.draggedImage = image
                            self.removeBackground(from: image)
                        }
                    }
                }
            }
            // Try to load as direct image data (from Safari, Chrome, etc.)
            else if provider.hasItemConformingToTypeIdentifier("public.image") {
                provider.loadItem(forTypeIdentifier: "public.image", options: nil) { (item, error) in
                    var image: NSImage?
                    
                    if let data = item as? Data {
                        image = NSImage(data: data)
                    } else if let url = item as? URL {
                        image = NSImage(contentsOf: url)
                    } else if let img = item as? NSImage {
                        image = img
                    }
                    
                    if let image = image {
                        DispatchQueue.main.async {
                            self.draggedImage = image
                            self.removeBackground(from: image)
                        }
                    }
                }
            }
        }
    }
    
    func handlePaste(providers: [NSItemProvider]) {
        for provider in providers {
            // Try to load as file URL first
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil),
                       let image = NSImage(contentsOf: url) {
                        DispatchQueue.main.async {
                            self.draggedImage = image
                            self.removeBackground(from: image)
                        }
                    }
                }
            }
            // Try to load as direct image data
            else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { (item, error) in
                    var image: NSImage?
                    
                    if let data = item as? Data {
                        image = NSImage(data: data)
                    } else if let url = item as? URL {
                        image = NSImage(contentsOf: url)
                    } else if let img = item as? NSImage {
                        image = img
                    }
                    
                    if let image = image {
                        DispatchQueue.main.async {
                            self.draggedImage = image
                            self.removeBackground(from: image)
                        }
                    }
                }
            }
        }
    }
    
    // ← NEW: Check if clipboard contains an image file or image data
    func checkClipboard() {
        let pasteboard = NSPasteboard.general
        canPaste = (pasteboard.types?.contains(.fileURL) ?? false) || 
                   (pasteboard.types?.contains(.tiff) ?? false) ||
                   (pasteboard.types?.contains(.png) ?? false)
    }
    
    // ← NEW: Paste image from clipboard
    func pasteFromClipboard() {
        let pasteboard = NSPasteboard.general
        
        // Try file URL first (from Finder)
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first,
           let image = NSImage(contentsOf: url) {
            self.draggedImage = image
            removeBackground(from: image)
            return
        }
        
        // Try direct image data (from Safari, screenshots, etc.)
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first {
            self.draggedImage = image
            removeBackground(from: image)
            return
        }
    }
    
    // Copy processed image to clipboard
    func copyToClipboard() {
        guard let nsImage = processedImage else {
            print("No image to copy")
            return
        }

        // Make sure the image has a bitmap representation
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            print("Failed to get PNG data")
            return
        }

        // Create a temporary file for Finder paste
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("clipboard_image.png")

        do {
            try pngData.write(to: tempURL)
            print("Temporary image saved at: \(tempURL.path)")
        } catch {
            print("Failed to write temporary file:", error)
            return
        }

        // Prepare the pasteboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Write both the image and the file URL
        let objectsToWrite: [NSPasteboardWriting] = [nsImage, tempURL as NSURL]
        let success = pasteboard.writeObjects(objectsToWrite)

        print("Copied to clipboard: \(success)")
    }

    // Remove background using Python script
    func removeBackground(from image: NSImage) {
        isProcessing = true
        processedImage = nil
        progress = 0.0

        DispatchQueue.global(qos: .userInitiated).async {
            let tempInput = FileManager.default.temporaryDirectory.appendingPathComponent("input_\(UUID().uuidString).png")
            let tempOutput = FileManager.default.temporaryDirectory.appendingPathComponent("output_\(UUID().uuidString).png")

            // Save input image
            guard let tiffData = image.tiffRepresentation,
                  let bitmapImage = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
                return
            }

            do {
                try pngData.write(to: tempInput)
                DispatchQueue.main.async {
                    self.progress = 0.05
                }

                guard let scriptPath = Bundle.main.url(forResource: "remove_bg", withExtension: nil) else {
                    print("ERROR: Python script not found in bundle")
                    DispatchQueue.main.async {
                        self.isProcessing = false
                    }
                    return
                }

                let process = Process()
                process.executableURL = scriptPath
                process.arguments = [tempInput.path, tempOutput.path, self.settings.selectedModel]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                try process.run()

                // Smooth progress animation while processing
                DispatchQueue.global(qos: .background).async {
                    while process.isRunning {
                        DispatchQueue.main.async {
                            // Smooth increment but never reach 100% until done
                            if self.progress < 0.95 {
                                self.progress += 0.01
                            }
                        }
                        Thread.sleep(forTimeInterval: 0.2)
                    }
                }

                process.waitUntilExit()

                // Read output for debugging
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    print("Python output: \(output)")
                }
                print("Exit code: \(process.terminationStatus)")

                // Load result
                if FileManager.default.fileExists(atPath: tempOutput.path),
                   let resultImage = NSImage(contentsOf: tempOutput) {
                    DispatchQueue.main.async {
                        self.processedImage = resultImage
                        
                        // Speed to 100% if not there yet
                        if self.progress < 1.0 {
                            withAnimation(.easeOut(duration: 0.3)) {
                                self.progress = 1.0
                            }
                        }
                        
                        // Small delay before hiding the progress bar
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.isProcessing = false
                        }
                    }
                } else {
                    print("Output file not found at: \(tempOutput.path)")
                    DispatchQueue.main.async {
                        self.isProcessing = false
                    }
                }

                // Cleanup temp files
                try? FileManager.default.removeItem(at: tempInput)
                try? FileManager.default.removeItem(at: tempOutput)

            } catch {
                print("Error: \(error)")
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
