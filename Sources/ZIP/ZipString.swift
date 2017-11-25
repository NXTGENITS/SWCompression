// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

#if os(Linux)
    import CoreFoundation
#endif

class ZipString {

    #if os(Linux)
        static let cp437Encoding: CFStringEncoding = UInt32(truncatingIfNeeded: UInt(kCFStringEncodingDOSLatinUS))
        static let cp437Available: Bool = CFStringIsEncodingAvailable(cp437Encoding)
    #else
        static let cp437Encoding = CFStringEncoding(CFStringEncodings.dosLatinUS.rawValue)
        static let cp437Available = CFStringIsEncodingAvailable(cp437Encoding)
    #endif

    static func needsUtf8(_ data: Data) -> Bool {
        // UTF-8 can have BOM.
        if data.count >= 3 {
            if data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF {
                return true
            }
        }
        var codeLength = 0
        var index = 0
        var ch: UInt32 = 0
        while index < data.count {
            let byte = data[index]
            if byte <= 0x7F { // This simple byte can exist both in CP437 and UTF-8.
                index += 1
                continue
            }

            // Otherwise, it has to be correct code sequence in case of UTF-8.
            // If code sequence is incorrect, then it is CP437.
            if byte >= 0xC2 && byte <= 0xDF {
                codeLength = 2
            } else if byte >= 0xE0 && byte <= 0xEF {
                codeLength = 3
            } else if byte >= 0xF0 && byte <= 0xF4 {
                codeLength = 4
            } else {
                return false
            }
            if index + codeLength - 1 >= data.count {
                return false
            }

            for i in 1..<codeLength {
                if data[index + i] & 0xC0 != 0x80 {
                    return false
                }
            }

            if codeLength == 2 {
                ch = ((UInt32(data[index]) & 0x1F) << 6) + (UInt32(data[index + 1]) & 0x3F)
            } else if codeLength == 3 {
                ch = ((UInt32(data[index]) & 0x0F) << 12) + ((UInt32(data[index + 1]) & 0x3F) << 6) +
                    (UInt32(data[index + 2]) & 0x3F)
                if ch < 0x0800 {
                    return false
                }
                if ch >> 11 == 0x1B {
                    return false
                }
            } else if codeLength == 4 {
                ch = ((UInt32(data[index]) & 0x07) << 18) + ((UInt32(data[index + 1]) & 0x3F) << 12) +
                    ((UInt32(data[index + 2]) & 0x3F) << 6) + (UInt32(data[index + 3]) & 0x3F)
                if ch < 0x10000 || ch > 0x10FFFF {
                    return false
                }
            }
            index += codeLength
            return true
        }
        // All bytes were in range 0...0x7F, which can be both in CP437 and UTF-8.
        // We solve this ambiguity in favor of CP437.
        return false
    }

}
