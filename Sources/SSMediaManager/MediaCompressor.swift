//
//  MediaCompressor.swift
//  SSMediaManager
//
//  Created by Apple on 23/06/23.
//

import Foundation
import AVFoundation
import UIKit

var documentsUrl: URL? {
    return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
}

class MediaCompressor {
    private static var documentsUrl: URL? {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    class func compressVideo(inputURL: URL, outputURL: URL, completion: @escaping (URL?, Error?) -> Void) {
        let asset = AVURLAsset(url: inputURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
            completion(nil, NSError(domain: "VideoCompressor", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create AVAssetExportSession"]))
            return
        }
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                completion(outputURL, nil)
            case .failed:
                completion(nil, exportSession.error)
            case .cancelled:
                completion(nil, NSError(domain: "VideoCompressor", code: 0, userInfo: [NSLocalizedDescriptionKey: "Video compression was cancelled"]))
            default:
                break
            }
        }
    }
    
    class func compressImage(fileName: String, completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let modeValue = UserDefaults.standard.value(forKey: "CompressionModeFloat") as? CGFloat ?? 0.5
            let compressionMode = CompressionMode(rawValue: modeValue) ?? .medium

            guard compressionMode != .noCompression,
                  let image = load(fileName: fileName),
                  let fileUrl = documentsUrl?.appendingPathComponent(fileName) else {
                DispatchQueue.main.async { completion() }
                return
            }

            let originalMetadata = EXIFMetadataHelper.extractEXIF(from: fileUrl)
            let shouldCompress = isToCompressFile(fromPath: fileUrl.path, compressionMode: compressionMode)
            let imageToSave: UIImage = (shouldCompress ? image.resizedForCompression(to: compressionMode) : nil) ?? image

            do {
                try EXIFMetadataHelper.saveImageWithEXIF(image: imageToSave, to: fileUrl, metadata: originalMetadata)
            } catch {
                image.jpegData(compressionQuality: 1.0).flatMap { try? $0.write(to: fileUrl, options: .atomic) }
            }

            DispatchQueue.main.async { completion() }
        }
    }
    
    // MARK: - Get file size from file manager
    private class func isToCompressFile(fromPath path: String, compressionMode: CompressionMode = .noCompression) -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let fileSize = attrs[.size] as? UInt64,
              fileSize >= 1024 else {
            return false
        }

        // Float conversion before division to avoid integer truncation
        let sizeInMB = Float(fileSize) / (1024 * 1024)

        guard sizeInMB >= 1.0 else { return false }

        switch compressionMode {
        case .high:   return sizeInMB > 1
        case .medium: return sizeInMB > 3
        case .low:    return sizeInMB > 5
        default:      return false
        }
    }
    
    class func load(fileName: String) -> UIImage? {
        guard let fileURL = documentsUrl?.appendingPathComponent(fileName) else { return nil }
        do {
            let imageData = try Data(contentsOf: fileURL)
            return UIImage(data: imageData)
        } catch {
            return nil
        }
    }
}


// MARK: - Compress UIImage
extension UIImage {
    
    private func jpeg(_ jpegQuality: CompressionMode) -> Data? {
        return jpegData(compressionQuality: jpegQuality.rawValue)
    }
    
    private func resized(to compressionMode: CompressionMode) -> UIImage? {
        if compressionMode == .noCompression{
            return self
        }
        let newTargetSize = compressionMode.imageResolution
        let widthRatio = newTargetSize.width / size.width
        let heightRatio = newTargetSize.height / size.height
        let scaleFactor = min(widthRatio, heightRatio)
        
        let newSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        
        let resizedImage = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return resizedImage
    }
    
    private func compressed(quality: CGFloat) -> Data? {
        return self.jpegData(compressionQuality: quality)
    }
    
    private func convertDataToImage(imageData: Data?) -> UIImage? {
        guard let imageData, let image = UIImage(data: imageData) else { return nil }
        return image
    }
    
    func compressImage(compressionMode:CompressionMode, initialQuality: CGFloat = 0.9, decrement: CGFloat = 0.1) -> Data? {
        guard let resizedImage = self.resized(to: compressionMode) else { return nil }
        var targetSizeInMB: Double = 2
        
        var quality = initialQuality
        var imageData = resizedImage.jpeg(compressionMode)
        if let sizeInMB = imageData?.getSizeInMB(){
            targetSizeInMB = sizeInMB * compressionMode.rawValue
        }
        
        while let data = imageData, Double(data.count) / (1024 * 1024) > targetSizeInMB, quality > decrement {
            quality -= decrement
            imageData = resizedImage.jpeg(compressionMode)
        }
        return imageData
    }
    
    func resizedForCompression(to compressionMode: CompressionMode) -> UIImage? {
        return self.resized(to: compressionMode)
    }
    
}

extension Data {
    func getSizeInMB() -> Double {
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useMB]
        bcf.countStyle = .file
        let string = bcf.string(fromByteCount: Int64(self.count)).replacingOccurrences(of: ",", with: ".")
        if let double = Double(string.replacingOccurrences(of: " MB", with: "")) {
            return double
        }
        return 0.0
    }
}

extension MediaCompressor {
    static func localize(_ key: String) -> String {
        let lang = UserDefaults.standard.value(forKey: "selected-language") as? String ?? "en"
        guard let path = Bundle.main.path(forResource: lang, ofType: "lproj") else {
            return NSLocalizedString(key, comment: "")
        }
        guard let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, comment: "")
        }
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
}
