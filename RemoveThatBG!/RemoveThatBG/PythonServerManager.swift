//
//  PythonServerManager.swift
//  RemoveThatBG!
//
//  Rewritten for direct Python execution (no PyInstaller)
//

import Foundation
import AppKit

class PythonServerManager: ObservableObject {
    static let shared = PythonServerManager()
    
    @Published var isServerRunning = false
    @Published var serverPort: Int = 55000
    @Published var lastError: String?
    @Published var healthCheckCount: Int = 0
    @Published var isDependencyCheckComplete = false
    @Published var dependencyInstallProgress: String?
    
    private var serverProcess: Process?
    private var healthCheckTimer: Timer?
    private var restartAttempts: Int = 0
    private let maxRestartAttempts: Int = 3
    
    private init() {}
    
    var serverURL: URL {
        return URL(string: "http://127.0.0.1:\(serverPort)")!
    }
    
    /// Get the Application Support directory for models
    func getModelsDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelsDir = appSupport.appendingPathComponent("RemoveThatBG/models")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        
        return modelsDir
    }
    
    /// Check if there's sufficient disk space (500 MB minimum)
    func checkDiskSpace() -> Bool {
        let modelsDir = getModelsDirectory()
        
        do {
            let values = try modelsDir.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let capacity = values.volumeAvailableCapacityForImportantUsage {
                let requiredBytes: Int64 = 500 * 1024 * 1024 // 500 MB
                return capacity >= requiredBytes
            }
        } catch {
            print("⚠️ Could not check disk space: \(error)")
        }
        
        return true // Assume OK if check fails
    }
    
    /// Get path to Python backend directory
    private func getPythonBackendPath() -> URL? {
        guard let resourcePath = Bundle.main.resourcePath else {
            print("❌ Could not find resource path")
            return nil
        }
        
        // Backend is in Resources/PythonBackend
        let backendPath = URL(fileURLWithPath: resourcePath).appendingPathComponent("PythonBackend")
        
        if !FileManager.default.fileExists(atPath: backendPath.path) {
            print("❌ PythonBackend directory not found at: \(backendPath.path)")
            return nil
        }
        
        return backendPath
    }
    
    /// Get the virtual environment path in Application Support
    private func getVenvPath() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("RemoveThatBG/venv")
    }
    
    /// Get the Python executable from the venv
    private func getVenvPython() -> URL {
        return getVenvPath().appendingPathComponent("bin/python3")
    }
    
    /// Check if venv exists and is valid
    private func venvExists() -> Bool {
        let pythonPath = getVenvPython()
        return FileManager.default.fileExists(atPath: pythonPath.path)
    }
    
    /// Check and install dependencies if needed
    func checkAndInstallDependencies(completion: @escaping (Bool, String?) -> Void) {
        guard let backendPath = getPythonBackendPath() else {
            completion(false, "Python backend not found in app bundle")
            return
        }
        
        let setupScript = backendPath.appendingPathComponent("setup_venv.py")
        let requirementsFile = backendPath.appendingPathComponent("requirements.txt")
        
        guard FileManager.default.fileExists(atPath: setupScript.path) else {
            completion(false, "Virtual environment setup script not found")
            return
        }
        
        guard FileManager.default.fileExists(atPath: requirementsFile.path) else {
            completion(false, "requirements.txt not found")
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            process.arguments = [setupScript.path]
            process.currentDirectoryURL = backendPath
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            var output = ""
            pipe.fileHandleForReading.readabilityHandler = { handle in
                if let line = String(data: handle.availableData, encoding: .utf8), !line.isEmpty {
                    output += line
                    print("[Dependency Check] \(line.trimmingCharacters(in: .whitespacesAndNewlines))")
                    
                    DispatchQueue.main.async {
                        self?.dependencyInstallProgress = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
            
            do {
                try process.run()
                process.waitUntilExit()
                
                DispatchQueue.main.async {
                    let success = process.terminationStatus == 0
                    self?.isDependencyCheckComplete = true
                    self?.dependencyInstallProgress = nil
                    
                    if success {
                        print("✅ Virtual environment ready")
                        completion(true, nil)
                    } else {
                        let errorMsg = "Virtual environment setup failed. Please run manually:\ncd PythonBackend && python3 setup_venv.py\n\nOutput:\n\(output)"
                        print("❌ Virtual environment setup failed: \(errorMsg)")
                        completion(false, errorMsg)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.isDependencyCheckComplete = true
                    self?.dependencyInstallProgress = nil
                    completion(false, "Failed to run dependency installer: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Read port from temp file written by Python server
    private func readPortFromFile() -> Int? {
        let portFile = FileManager.default.temporaryDirectory.appendingPathComponent("removethatbg_port.json")
        
        guard FileManager.default.fileExists(atPath: portFile.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: portFile)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let port = json["port"] as? Int {
                return port
            }
        } catch {
            print("⚠️ Failed to read port file: \(error)")
        }
        
        return nil
    }
    
    /// Check if server is already running
    private func isServerProcessRunning() -> Bool {
        return serverProcess?.isRunning ?? false
    }
    
    /// Start periodic health checks
    private func startHealthCheck() {
        stopHealthCheck() // Clear any existing timer
        
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.checkServerHealth()
        }
    }
    
    /// Stop health check timer
    private func stopHealthCheck() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }
    
    func startServer() {
        print("🔥 startServer() was called")
        
        // Prevent multiple instances
        guard !isServerRunning else {
            print("⚠️ Server is already running")
            return
        }

        guard !isServerProcessRunning() else {
            print("⚠️ Server process already exists and is running")
            return
        }
        
        // Check disk space before starting
        guard checkDiskSpace() else {
            print("❌ Insufficient disk space")
            lastError = "Insufficient disk space. Please free up at least 500 MB."
            return
        }

        // Find the Python backend directory
        guard let backendPath = getPythonBackendPath() else {
            print("❌ Python backend not found")
            lastError = "Python backend not found in app bundle"
            return
        }
        
        let serverScript = backendPath.appendingPathComponent("server.py")
        
        guard FileManager.default.fileExists(atPath: serverScript.path) else {
            print("❌ server.py not found at: \(serverScript.path)")
            lastError = "server.py not found"
            return
        }

        print("✅ Found server.py at: \(serverScript.path)")
        
        // Use venv Python if available, otherwise fall back to system Python
        let venvAvailable = venvExists()
        let pythonExec = venvAvailable ? getVenvPython() : URL(fileURLWithPath: "/usr/bin/python3")
        print("🐍 Venv exists: \(venvAvailable)")
        print("🐍 Using Python: \(pythonExec.path)")
        
        // Verify Python executable exists
        if !FileManager.default.fileExists(atPath: pythonExec.path) {
            print("❌ Python executable not found at: \(pythonExec.path)")
            lastError = "Python executable not found"
            return
        }
        
        let process = Process()
        process.executableURL = pythonExec
        process.arguments = [serverScript.path]
        process.currentDirectoryURL = backendPath

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard self?.serverProcess != nil else { return }
            if let output = String(data: handle.availableData, encoding: .utf8), !output.isEmpty {
                print("[Python stderr] \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard self?.serverProcess != nil else { return }
            if let output = String(data: handle.availableData, encoding: .utf8), !output.isEmpty {
                print("[Python stdout] \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }

        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                guard let self = self else { return }
                print("⚠️ Python server terminated with status: \(process.terminationStatus)")
                self.isServerRunning = false
                self.stopHealthCheck()
                
                // Cleanup handlers
                errorPipe.fileHandleForReading.readabilityHandler = nil
                outputPipe.fileHandleForReading.readabilityHandler = nil
                
                // Auto-restart if it crashed unexpectedly and we haven't exceeded max attempts
                if process.terminationStatus != 0 && self.restartAttempts < self.maxRestartAttempts {
                    self.restartAttempts += 1
                    print("🔄 Attempting to restart server (attempt \(self.restartAttempts)/\(self.maxRestartAttempts))")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.startServer()
                    }
                } else if self.restartAttempts >= self.maxRestartAttempts {
                    self.lastError = "Server failed to start after \(self.maxRestartAttempts) attempts"
                }
            }
        }

        do {
            try process.run()
            self.serverProcess = process

            // Wait for port file to be written
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                
                // Read port from file
                if let port = self.readPortFromFile() {
                    self.serverPort = port
                    print("✅ Server running on port \(port)")
                } else {
                    print("⚠️ Could not read port file, using default port \(self.serverPort)")
                }
                
                self.checkServerHealth()
                self.startHealthCheck()
            }

            print("✅ Python server process started")
        } catch {
            print("❌ Failed to start Python server: \(error)")
            lastError = "Failed to start server: \(error.localizedDescription)"
            isServerRunning = false
        }
    }

    
    func stopServer() {
        print("🛑 Stopping Python server and cleaning up all background processes...")
        
        // Stop health checks first
        stopHealthCheck()
        
        // Get port before killing process
        let currentPort = readPortFromFile() ?? serverPort
        
        // Terminate the server process if it exists
        if let process = serverProcess, process.isRunning {
            print("📍 Terminating server process (PID: \(process.processIdentifier))")
            process.terminate()
            
            // Wait briefly for graceful shutdown
            usleep(300_000) // 0.3 seconds
            
            // Force kill if still running
            if process.isRunning {
                print("💀 Force killing server process")
                kill(process.processIdentifier, SIGKILL)
            }
        }
        
        // Kill any orphaned Python processes on our port (async to not block)
        DispatchQueue.global(qos: .background).async {
            self.killProcessOnPort(currentPort)
            self.killServerPyProcesses()
        }
        
        // Clean up port file
        let portFile = FileManager.default.temporaryDirectory.appendingPathComponent("removethatbg_port.json")
        try? FileManager.default.removeItem(at: portFile)
        
        serverProcess = nil
        isServerRunning = false
        restartAttempts = 0
        print("✅ Python server stopped")
    }
    
    /// Kill any Python processes running server.py
    private func killServerPyProcesses() {
        let psTask = Process()
        psTask.executableURL = URL(fileURLWithPath: "/bin/ps")
        psTask.arguments = ["-ax", "-o", "pid,command"]
        
        let pipe = Pipe()
        psTask.standardOutput = pipe
        
        do {
            try psTask.run()
            psTask.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.split(separator: "\n")
                for line in lines {
                    if line.contains("server.py") && line.contains("RemoveThatBG") {
                        let components = line.split(separator: " ", maxSplits: 1)
                        if let pidString = components.first, let pid = Int(pidString.trimmingCharacters(in: .whitespaces)) {
                            print("🔪 Killing orphaned server.py process (PID: \(pid))")
                            kill(pid_t(pid), SIGTERM)
                            usleep(100_000)
                            kill(pid_t(pid), SIGKILL) // Make sure it's dead
                        }
                    }
                }
            }
        } catch {
            print("⚠️ Error finding server.py processes: \(error)")
        }
    }
    
    /// Kill process running on specific port
    private func killProcessOnPort(_ port: Int) {
        let killTask = Process()
        killTask.executableURL = URL(fileURLWithPath: "/usr/bin/lsof")
        killTask.arguments = ["-ti", ":\(port)"]
        
        let pipe = Pipe()
        killTask.standardOutput = pipe
        
        do {
            try killTask.run()
            killTask.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                let pids = output.split(separator: "\n").compactMap { Int($0) }
                for pid in pids {
                    print("Killing process \(pid) on port \(port)")
                    kill(pid_t(pid), SIGTERM)
                }
            }
        } catch {
            print("Error cleaning up processes: \(error)")
        }
    }
    
    deinit {
        // Ensure server is stopped when manager is deallocated
        stopServer()
    }
    
    private func checkServerHealth() {
        let healthURL = serverURL.appendingPathComponent("health")
        
        var request = URLRequest(url: healthURL)
        request.timeoutInterval = 5.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    if !self.isServerRunning {
                        print("✅ Server health check passed")
                        self.restartAttempts = 0 // Reset on successful connection
                    }
                    self.isServerRunning = true
                    self.lastError = nil
                    self.healthCheckCount += 1
                } else {
                    if self.isServerRunning {
                        print("❌ Server health check failed: \(error?.localizedDescription ?? "Unknown error")")
                    }
                    self.isServerRunning = false
                    self.lastError = error?.localizedDescription
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
            
            guard let data = data else {
                completion(.failure(NSError(domain: "ImageConversion", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received from server"])))
                return
            }
            
            // Debug: Log response details
            if let httpResponse = response as? HTTPURLResponse {
                print("[Client] Response status: \(httpResponse.statusCode)")
                print("[Client] Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "none")")
                print("[Client] Data size: \(data.count) bytes")
            }
            
            // Create NSImage from PNG data - same as old version
            guard let resultImage = NSImage(data: data) else {
                completion(.failure(NSError(domain: "ImageConversion", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode processed image"])))
                return
            }
            
            // CRITICAL FIX: Disable caching to ensure proper rendering of alpha channel
            resultImage.cacheMode = .never
            
            print("[Client] Created NSImage: \(resultImage.size)")
            
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
                print("[Client] Preload failed: \(error)")
                completion?(false)
                return
            }
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                print("[Client] Preload returned non-200")
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
                print("[Client] Download failed: \(error)")
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[Client] Download invalid response")
                completion(false)
                return
            }
            
            completion(httpResponse.statusCode == 200)
        }.resume()
    }

}
