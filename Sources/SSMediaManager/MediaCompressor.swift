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
    
    class func compressImage(fileName: String, completion: @escaping() -> Void) {
        
        let selectedValue = UserDefaults.standard.value(forKey: "CompressionMode") as? String ?? ""
        let compressionMode = selectedValue.fetchCompressionModeFromUserValue()
        if compressionMode == .noCompression{
            completion()
            return
        }
        guard let image = load(fileName: fileName),
              let fileUrl = documentsUrl?.appendingPathComponent(fileName),
        // Convert the image to JPEG format
        let jpegData = image.jpegData(compressionQuality: 1.0) else {
            completion()
            return
        }
        
        // Save the JPEG data with the original file extension
        try? jpegData.write(to: fileUrl, options: .atomic)
        
        // Check if the newly converted file needs compression
        if isToCompressFile(fromPath: fileUrl.path , compressionMode: compressionMode),
           let compressedData = image.compressImage(compressionMode: compressionMode){
            try? compressedData.write(to: fileUrl, options: .atomic)
        }
        completion()
    }
    
    // MARK: - Get file size from file manager
    private class func isToCompressFile(fromPath path: String, compressionMode:CompressionMode = .noCompression) -> Bool {
        guard let size = try? FileManager.default.attributesOfItem(atPath: path)[FileAttributeKey.size],
              let fileSize = size as? UInt64 else {
            return false
        }
        if fileSize < 1023 {
             return false
        }
        var floatSize = Float(fileSize / 1024)
        if floatSize < 1023 {
            print(String(format: "%.0f KB", floatSize))
            return false
        }
        floatSize = floatSize / 1024
        if floatSize < 1023 {
            print(String(format: "%.0f MB", floatSize))
            switch compressionMode {
            case .high:
                return floatSize > 1
            case .medium:
                return floatSize > 3
            case.low:
                return floatSize > 5
            default:
                return false
            }
        }
        floatSize = floatSize / 1024
        return true
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

extension String{
    public func fetchCompressionModeFromUserValue() -> CompressionMode{
        switch self {
        case "low":
            return CompressionMode.low
        case "medium":
            return CompressionMode.medium
        case "high":
            return CompressionMode.high
        case "no":
            return CompressionMode.noCompression
        default:
            return CompressionMode.medium
        }
    }
    
    public func fetchCompressionModeFromDisplayValue() -> CompressionMode{
        switch self {
        case MediaCompressor.localize("lbl_Low"):
            return CompressionMode.low
        case MediaCompressor.localize("lbl_Medium"):
            return CompressionMode.medium
        case MediaCompressor.localize("lbl_High"):
            return CompressionMode.high
        case MediaCompressor.localize("lbl_No_Compression"):
            return CompressionMode.noCompression
        default:
            return CompressionMode.medium
        }
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
