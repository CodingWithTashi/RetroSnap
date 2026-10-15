import AVFoundation
import Foundation
import ImageIO

/// The metadata written into a baked picture.
nonisolated enum PhotoMetadata {
    /// The original's own metadata, corrected for a picture that is now upright and may have been re-encoded,
    /// with the capture date filled in when the original carries none, and the place when the shot has one.
    static func properties(original: [String: Any], capturedAt: Date, location: PhotoLocation?) -> [String: Any] {
        var properties = original
        properties[kCGImagePropertyOrientation as String] = CGImagePropertyOrientation.up.rawValue
        properties[kCGImagePropertyPixelWidth as String] = nil
        properties[kCGImagePropertyPixelHeight as String] = nil

        var tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        tiff[kCGImagePropertyTIFFOrientation as String] = CGImagePropertyOrientation.up.rawValue
        properties[kCGImagePropertyTIFFDictionary as String] = tiff

        var exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        exif[kCGImagePropertyExifPixelXDimension as String] = nil
        exif[kCGImagePropertyExifPixelYDimension as String] = nil
        if exif[kCGImagePropertyExifDateTimeOriginal as String] == nil {
            exif[kCGImagePropertyExifDateTimeOriginal as String] = exifDate.string(from: capturedAt)
            exif[kCGImagePropertyExifOffsetTimeOriginal as String] = exifOffset.string(from: capturedAt)
        }
        properties[kCGImagePropertyExifDictionary as String] = exif

        if let location {
            properties[kCGImagePropertyGPSDictionary as String] = gps(location)
        }
        return properties
    }

    /// EXIF stores a place as positive degrees with a hemisphere beside each.
    private static func gps(_ location: PhotoLocation) -> [String: Any] {
        var gps: [String: Any] = [
            kCGImagePropertyGPSLatitude as String: abs(location.latitude),
            kCGImagePropertyGPSLatitudeRef as String: location.latitude >= 0 ? "N" : "S",
            kCGImagePropertyGPSLongitude as String: abs(location.longitude),
            kCGImagePropertyGPSLongitudeRef as String: location.longitude >= 0 ? "E" : "W",
        ]
        if let altitude = location.altitude {
            gps[kCGImagePropertyGPSAltitude as String] = abs(altitude)
            gps[kCGImagePropertyGPSAltitudeRef as String] = altitude >= 0 ? 0 : 1
        }
        return gps
    }

    /// The same two facts for a movie: when it was taken, and where if the clip has a place.
    static func items(capturedAt: Date, location: PhotoLocation?) -> [AVMetadataItem] {
        func item(_ identifier: AVMetadataIdentifier, _ value: String) -> AVMetadataItem {
            let item = AVMutableMetadataItem()
            item.identifier = identifier
            item.value = value as NSString
            return item
        }
        var items = [item(.quickTimeMetadataCreationDate, ISO8601DateFormatter().string(from: capturedAt))]
        if let location {
            items.append(item(.quickTimeMetadataLocationISO6709, iso6709(location)))
        }
        return items
    }

    /// "+27.7172+085.3240+1400.000/": signed latitude, longitude and, when known, altitude in metres.
    private static func iso6709(_ location: PhotoLocation) -> String {
        let place = String(format: "%+08.4f%+09.4f", location.latitude, location.longitude)
        let height = location.altitude.map { String(format: "%+.3f", $0) } ?? ""
        return place + height + "/"
    }

    /// A formatter that writes the same digits whatever the phone's region and calendar are.
    static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }

    /// EXIF's date and time, local to where the picture was taken.
    static let exifDateFormat = "yyyy:MM:dd HH:mm:ss"

    /// EXIF writes local time and its offset from UTC separately.
    private static let exifDate = formatter(exifDateFormat)
    private static let exifOffset = formatter("xxx")

    /// When the picture was taken, as its EXIF says ("2026:10:08 12:32:41", with the zone when it is there).
    static func takenAt(of properties: [CFString: Any]) -> Date? {
        guard let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let text = exif[kCGImagePropertyExifDateTimeOriginal] as? String
        else { return nil }
        let reader = formatter(exifDateFormat)
        if let offset = exif[kCGImagePropertyExifOffsetTimeOriginal] as? String,
           let zone = TimeZone(iso8601: offset) {
            reader.timeZone = zone
        } else {
            reader.timeZone = .current
        }
        return reader.date(from: text)
    }
}

extension TimeZone {
    /// A zone from an EXIF offset such as "+02:00" or "-07:00".
    nonisolated init?(iso8601 offset: String) {
        let trimmed = offset.trimmingCharacters(in: .whitespaces)
        guard trimmed.count == 6, let sign = trimmed.first, sign == "+" || sign == "-",
              let hours = Int(trimmed.dropFirst().prefix(2)), let minutes = Int(trimmed.suffix(2))
        else { return nil }
        let seconds = (hours * 3600 + minutes * 60) * (sign == "-" ? -1 : 1)
        self.init(secondsFromGMT: seconds)
    }
}
