// Copyright (c) 2021 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

struct TarHeader {

    enum HeaderEntryType {
        case normal(ContainerEntryType)
        case special(SpecialEntryType)
    }

    enum SpecialEntryType: UInt8 {
        case longName = 76
        case longLinkName = 75
        case globalExtendedHeader = 103
        case localExtendedHeader = 120
        // Sun were the first to use extended headers. Their headers are mostly compatible with PAX ones, but differ in
        // the typeflag used ("X" instead of "x").
        case sunExtendedHeader = 88
    }

    let name: String
    private(set) var prefix: String?
    let size: Int
    let type: HeaderEntryType
    private(set) var atime: Date?
    private(set) var ctime: Date?
    private(set) var mtime: Date?
    let permissions: Permissions?
    let ownerID: Int?
    let groupID: Int?
    private(set) var ownerUserName: String?
    private(set) var ownerGroupName: String?
    private(set) var deviceMajorNumber: Int?
    private(set) var deviceMinorNumber: Int?
    let linkName: String

    let format: TarContainer.Format

    let blockStartIndex: Int

    init(_ reader: LittleEndianByteReader) throws {
        self.blockStartIndex = reader.offset
        self.name = reader.tarCString(maxLength: 100)

        if let posixAttributes = reader.tarInt(maxLength: 8) {
            // Sometimes file mode field also contains unix type, so we need to filter it out.
            self.permissions = Permissions(rawValue: UInt32(truncatingIfNeeded: posixAttributes) & 0xFFF)
        } else {
            self.permissions = nil
        }

        self.ownerID = reader.tarInt(maxLength: 8)
        self.groupID = reader.tarInt(maxLength: 8)

        guard let size = reader.tarInt(maxLength: 12)
            else { throw TarError.wrongField }
        self.size = size

        if let mtime = reader.tarInt(maxLength: 12) {
            self.mtime = Date(timeIntervalSince1970: TimeInterval(mtime))
        }

        // Checksum
        guard let checksum = reader.tarInt(maxLength: 8)
            else { throw TarError.wrongHeaderChecksum }

        let currentIndex = reader.offset
        reader.offset = blockStartIndex
        var headerBytesForChecksum = reader.bytes(count: 512)
        headerBytesForChecksum.replaceSubrange(148..<156, with: Array(repeating: 0x20, count: 8))
        reader.offset = currentIndex

        // Some implementations treat bytes as signed integers, but some don't.
        // So we check both cases, equality in one of them will pass the checksum test.
        let unsignedOurChecksum = headerBytesForChecksum.reduce(0 as UInt) { $0 + UInt(truncatingIfNeeded: $1) }
        let signedOurChecksum = headerBytesForChecksum.reduce(0 as Int) { $0 + $1.toInt() }
        guard unsignedOurChecksum == UInt(truncatingIfNeeded: checksum) || signedOurChecksum == checksum
            else { throw TarError.wrongHeaderChecksum }

        let fileTypeIndicator = reader.byte()
        if let specialEntryType = SpecialEntryType(rawValue: fileTypeIndicator) {
            self.type = .special(specialEntryType)
        } else {
            self.type = .normal(ContainerEntryType(fileTypeIndicator))
        }

        self.linkName = reader.tarCString(maxLength: 100)

        // There are two different formats utilizing this section of TAR header: GNU format and POSIX (aka "ustar";
        // PAX containers can also be considered as POSIX). They differ in the value of magic field as well as what
        // comes after deviceMinorNumber field. While "ustar" format may contain prefix for file name, GNU format
        // uses this place for storing atime/ctime and fields related to sparse-files. In practice, these fields are
        // rarely used by GNU tar and only present if "incremental backups" options were used. Thus, GNU format TAR
        // container can often be incorrectly considered as having prefix field containing only NULLs.
        let magic = reader.uint64()

        if magic == 0x0020207261747375 || magic == 0x3030007261747375 || magic == 0x3030207261747375 {
            self.ownerUserName = reader.tarCString(maxLength: 32)
            self.ownerGroupName = reader.tarCString(maxLength: 32)
            self.deviceMajorNumber = reader.tarInt(maxLength: 8)
            self.deviceMinorNumber = reader.tarInt(maxLength: 8)

            if magic == 0x00_20_20_72_61_74_73_75 { // GNU format.
                // GNU format mostly is identical to POSIX format and in the common situations can be considered as
                // having prefix containing only NULLs. However, in the case of incremental backups produced by GNU tar
                // this part of the TAR header is used for storing a lot of different properties. For now, we are only
                // reading atime and ctime.

                if let atime = reader.tarInt(maxLength: 12) {
                    self.atime = Date(timeIntervalSince1970: TimeInterval(atime))
                }

                if let ctime = reader.tarInt(maxLength: 12) {
                    self.ctime = Date(timeIntervalSince1970: TimeInterval(ctime))
                }
            } else {
                self.prefix = reader.tarCString(maxLength: 155)
            }
        }

        if magic == 0x0020207261747375 {
            self.format = .gnu
        } else if magic == 0x3030007261747375 || magic == 0x3030207261747375 {
            self.format = .ustar
        } else {
            self.format = .prePosix
        }
    }

}
