//
//  BackgroundRemovalService.swift
//  RemoveThatBG!
//
//  Native background removal using Apple Vision framework
//

import Foundation
import AppKit
import Vision
import CoreImage

class BackgroundRemovalService: ObservableObject {
    static let shared = BackgroundRemovalService()
    
    @Published var isReady = true  // Always ready - no server needed
    @Published var lastError: String?
    
    private init() {
        print("✅ BackgroundRemovalService initialized - using native Vision framework")
    }
    
    /// Remove background from image using Vision framework
    /// - Parameters:
    ///   - image: The source NSImage
    ///   - completion: Callback with Result containing processed NSImage or Error
    func removeBackground(from image: NSImage, completion: @escaping (Result<NSImage, Error>) -> Void) {
        // Convert NSImage to CGImage
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(.failure(NSError(domain: "BackgroundRemoval", code: -1, 
                userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to CGImage"])))
            return
        }
        
        // Perform background removal on background queue
        DispatchQueue.global(qos: .userInitiated).async {
            self.processImage(cgImage: cgImage, originalSize: image.size, completion: completion)
        }
    }
    
    private func processImage(cgImage: CGImage, originalSize: NSSize, completion: @escaping (Result<NSImage, Error>) -> Void) {
        // Create Vision request for subject lifting (requires macOS 13.0+)
        if #available(macOS 13.0, *) {
            let request = VNGenerateForegroundInstanceMaskRequest()
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
                
                guard let result = request.results?.first else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "BackgroundRemoval", code: -2,
                            userInfo: [NSLocalizedDescriptionKey: "No foreground detected"])))
                    }
                    return
                }
                
                // Get the pixel buffer mask
                let mask = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
                
                // Apply mask to original image
                if let processedImage = self.applyMask(mask: mask, to: cgImage) {
                    let nsImage = NSImage(cgImage: processedImage, size: originalSize)
                    nsImage.cacheMode = .never
                    
                    DispatchQueue.main.async {
                        completion(.success(nsImage))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "BackgroundRemoval", code: -3,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to apply mask"])))
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        } else {
            // Fallback for older macOS versions
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "BackgroundRemoval", code: -4,
                    userInfo: [NSLocalizedDescriptionKey: "Background removal requires macOS 13.0 or later"])))
            }
        }
    }
    
    private func applyMask(mask: CVPixelBuffer, to image: CGImage) -> CGImage? {
        let ciImage = CIImage(cgImage: image)
        let maskImage = CIImage(cvPixelBuffer: mask)
        
        // Scale mask to match image size if needed
        let scaleX = ciImage.extent.width / maskImage.extent.width
        let scaleY = ciImage.extent.height / maskImage.extent.height
        let scaledMask = maskImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        // Apply blend filter to remove background
        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else { return nil }
        blendFilter.setValue(ciImage, forKey: kCIInputImageKey)
        blendFilter.setValue(scaledMask, forKey: kCIInputMaskImageKey)
        
        // Use transparent background
        let transparent = CIImage(color: .clear).cropped(to: ciImage.extent)
        blendFilter.setValue(transparent, forKey: kCIInputBackgroundImageKey)
        
        guard let outputImage = blendFilter.outputImage else { return nil }
        
        let context = CIContext()
        return context.createCGImage(outputImage, from: outputImage.extent)
    }
}
