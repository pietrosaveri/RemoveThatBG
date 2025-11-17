//
//  PythonServerManager.swift
//  RemoveThatBG!
//
//  Created by GitHub Copilot on 16/11/25.
//

import Foundation
import AppKit

class PythonServerManager: ObservableObject {
    static let shared = PythonServerManager()
    
    @Published var isServerRunning = false
    private var serverProcess: Process?
    private let serverPort = 55000
    
    private init() {}
    
    var serverURL: URL {
        return URL(string: "http://127.0.0.1:\(serverPort)")!
    }
    
    func startServer() {
        print("🔥 startServer() was called from:", Thread.callStackSymbols)
        
        
        guard !isServerRunning else {
            print("⚠️ Server is already running")
            return
        }

        guard serverProcess == nil || !(serverProcess?.isRunning ?? false) else {
            print("⚠️ Server process already exists and is running")
            return
        }

        // Find the Python server executable in the bundle
        guard let serverPath = Bundle.main.path(forResource: "remove_bg", ofType: nil) else {
            print("ERROR: Python server executable not found in bundle")
            print("Expected path: Resources/remove_bg/remove_bg")
            return
        }

        print("Found Python server at: \(serverPath)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: serverPath)
        process.arguments = []

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard self?.serverProcess != nil else { return }
            if let output = String(data: handle.availableData, encoding: .utf8), !output.isEmpty {
                print("Python server: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard self?.serverProcess != nil else { return }
            if let output = String(data: handle.availableData, encoding: .utf8), !output.isEmpty {
                print("Python server stdout: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }

        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.isServerRunning = false
                print("Python server terminated with code: \(process.terminationStatus)")

                errorPipe.fileHandleForReading.readabilityHandler = nil
                outputPipe.fileHandleForReading.readabilityHandler = nil

                if process.terminationStatus != 0 {
                    print("⚠️ Server crashed. Please restart the app.")
                }
            }
        }

        do {
            try process.run()
            self.serverProcess = process

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.checkServerHealth()
            }

            print("Python server process started on port \(serverPort)")
        } catch {
            print("Failed to start Python server: \(error)")
            isServerRunning = false
        }
    }

    
    func stopServer() {
        print("Stopping Python server and cleaning up all background processes...")
        
        // Terminate the server process if it exists
        if let process = serverProcess, process.isRunning {
            process.terminate()
            
            // Wait briefly for graceful shutdown
            usleep(500_000) // 0.5 seconds
            
            // Force kill if still running
            if process.isRunning {
                print("Force killing Python server...")
                process.interrupt()
            }
        }
        
        // Kill any orphaned Python processes that might be running on our port
        let killTask = Process()
        killTask.executableURL = URL(fileURLWithPath: "/usr/bin/lsof")
        killTask.arguments = ["-ti", ":\(serverPort)"]
        
        let pipe = Pipe()
        killTask.standardOutput = pipe
        
        do {
            try killTask.run()
            killTask.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                let pids = output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\n")
                for pid in pids {
                    let killProcess = Process()
                    killProcess.executableURL = URL(fileURLWithPath: "/bin/kill")
                    killProcess.arguments = ["-9", String(pid)]
                    try? killProcess.run()
                    print("Killed orphaned process with PID: \(pid)")
                }
            }
        } catch {
            print("Error cleaning up processes: \(error)")
        }
        
        serverProcess = nil
        isServerRunning = false
        print("Python server and all background processes stopped")
    }
    
    deinit {
        // Ensure server is stopped when manager is deallocated
        stopServer()
    }
    
    private func checkServerHealth() {
        let healthURL = serverURL.appendingPathComponent("health")
        
        var request = URLRequest(url: healthURL)
        request.timeoutInterval = 300
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if error == nil,
                   let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    self?.isServerRunning = true
                    print("Python server is running and healthy")
                } else {
                    print("Python server health check failed: \(error?.localizedDescription ?? "Unknown error")")
                    self?.isServerRunning = false
                }
            }
        }.resume()
    }
    
    func removeBackground(from image: NSImage, model: String, completion: @escaping (Result<NSImage, Error>) -> Void) {
        guard isServerRunning else {
            completion(.failure(NSError(domain: "PythonServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Server is not running"])))
            return
        }
        
        // Convert NSImage to PNG data
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            completion(.failure(NSError(domain: "ImageConversion", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to PNG"])))
            return
        }
        
        // Create multipart form data request
        print("[Client] Sending remove-background with model=\(model)")
        let boundary = UUID().uuidString
        let url = serverURL.appendingPathComponent("remove-background")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300
        
        var body = Data()
        
        // Add model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)
        
        // Add image file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.png\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(pngData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Send request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let resultImage = NSImage(data: data) else {
                completion(.failure(NSError(domain: "ImageConversion", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode processed image"])))
                return
            }
            
            completion(.success(resultImage))
        }.resume()
    }

    // Preload/download a model proactively
    func preloadModel(_ model: String, completion: ((Bool) -> Void)? = nil) {
        guard isServerRunning else {
            print("[Client] Skipping preload — server not running")
            completion?(false)
            return
        }

        let boundary = UUID().uuidString
        let url = serverURL.appendingPathComponent("preload-model")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        print("[Client] Preloading model=\(model)")
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[Client] Preload failed: \(error.localizedDescription)")
                completion?(false)
                return
            }
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                print("[Client] Preload failed: bad status")
                completion?(false)
                return
            }
            print("[Client] Preload succeeded for model=\(model)")
            completion?(true)
        }.resume()
    }
    
    // Download a model explicitly (UI-friendly wrapper around preload)
    func downloadModel(_ modelName: String, completion: @escaping (Bool) -> Void) {
        let url = serverURL.appendingPathComponent("preload-model")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        
        // Use simple URL-encoded form data (like curl -d does)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let bodyString = "model=\(modelName)"
        request.httpBody = bodyString.data(using: .utf8)
        
        print("[Client] Downloading model=\(modelName)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[Client] Download failed: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[Client] Download failed: no HTTP response")
                completion(false)
                return
            }
            
            print("[Client] Download response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                print("[Client] Download succeeded for model=\(modelName)")
                completion(true)
            } else {
                if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                    print("[Client] Download failed with body: \(responseBody)")
                }
                completion(false)
            }
        }.resume()
    }

}
