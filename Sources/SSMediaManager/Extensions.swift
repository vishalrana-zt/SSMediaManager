//
//  Extensions.swift
//  SSMediaManager
//
//  Created by Apple on 12/06/22.
//

import Foundation

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
