//
//  Extensions.swift
//  SSMediaManager
//
//  Created by Apple on 12/06/22.
//

import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

public enum CompressionMode: CGFloat {
    case low     = 0.75
    case medium  = 0.5
    case high    = 0.25
    case noCompression = 1.0
    
    var imageResolution: CGSize {
        switch self {
        case .low:
            return CGSize(width: 1920, height: 1080)
        case .medium:
            return CGSize(width: 1280, height: 720)
        case .high:
            return CGSize(width: 640, height: 480)
        case .noCompression:
            return CGSize(width: 1920, height: 1080)
        }
    }
}

extension TimeZone {
    func timeZoneOffsetInMinutes() -> Int {
        let seconds = secondsFromGMT()
        let minutes = seconds / 60
        return -(minutes)
    }
    func offsetFromGMT() -> String
    {
        let localTimeZoneFormatter = DateFormatter()
        localTimeZoneFormatter.timeZone = self
        localTimeZoneFormatter.dateFormat = "Z"
        return localTimeZoneFormatter.string(from: Date())
    }
}
// MARK: - EXIF Metadata Utilities
class EXIFMetadataHelper {
    
    /// Extract EXIF metadata from image file URL
    static func extractEXIF(from fileURL: URL) -> [String: Any]? {
        guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let metadata = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return nil
        }
        return metadata
    }
    
    /// Extract EXIF metadata from image data
    static func extractEXIF(from imageData: Data) -> [String: Any]? {
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
              let metadata = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return nil
        }
        return metadata
    }
    
    /// Convert EXIF metadata to S3 metadata headers format
    static func convertToS3Headers(exifMetadata: [String: Any]?) -> [String: String] {
        guard let metadata = exifMetadata else { return [:] }
        
        var headers: [String: String] = [:]
        
        // Extract key EXIF fields and format them for S3 metadata
        if let exif = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            if let dateTime = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                headers["x-amz-meta-exif-datetime-original"] = dateTime
            }
            if let make = exif[kCGImagePropertyExifCameraOwnerName as String] as? String {
                headers["x-amz-meta-exif-camera-owner"] = make
            }
        }
        
        if let tiff = metadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            if let make = tiff[kCGImagePropertyTIFFMake as String] as? String {
                headers["x-amz-meta-exif-make"] = make
            }
            if let model = tiff[kCGImagePropertyTIFFModel as String] as? String {
                headers["x-amz-meta-exif-model"] = model
            }
            if let software = tiff[kCGImagePropertyTIFFSoftware as String] as? String {
                headers["x-amz-meta-exif-software"] = software
            }
        }
        
        if let gps = metadata[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            if let latitude = gps[kCGImagePropertyGPSLatitude as String] as? Double,
               let latitudeRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String {
                headers["x-amz-meta-exif-gps-latitude"] = "\(latitude)\(latitudeRef)"
            }
            if let longitude = gps[kCGImagePropertyGPSLongitude as String] as? Double,
               let longitudeRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String {
                headers["x-amz-meta-exif-gps-longitude"] = "\(longitude)\(longitudeRef)"
            }
        }
        
        // Basic image properties
        if let width = metadata[kCGImagePropertyPixelWidth as String] as? Int {
            headers["x-amz-meta-image-width"] = "\(width)"
        }
        if let height = metadata[kCGImagePropertyPixelHeight as String] as? Int {
            headers["x-amz-meta-image-height"] = "\(height)"
        }
        if let orientation = metadata[kCGImagePropertyOrientation as String] as? Int {
            headers["x-amz-meta-image-orientation"] = "\(orientation)"
        }
        
        return headers
    }
    
    /// Save image with EXIF metadata preserved
    static func saveImageWithEXIF(image: UIImage, to fileURL: URL, metadata: [String: Any]?) throws {
        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            throw NSError(domain: "EXIFMetadataHelper", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG data"])
        }
        
        guard let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw NSError(domain: "EXIFMetadataHelper", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create image destination"])
        }
        
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw NSError(domain: "EXIFMetadataHelper", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create CGImage"])
        }
        
        if let metadata = metadata {
            CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)
        } else {
            CGImageDestinationAddImage(destination, cgImage, nil)
        }
        
        if !CGImageDestinationFinalize(destination) {
            throw NSError(domain: "EXIFMetadataHelper", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize image destination"])
        }
    }
}

