// Copyright (c) 2021 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class LZ4CompressionTests: XCTestCase {

    func answerTest(_ testName: String) throws {
        let answerData = try Constants.data(forAnswer: testName)
        let compressedData = LZ4.compress(data: answerData)
        let redecompressedData = try LZ4.decompress(data: compressedData)
        XCTAssertEqual(redecompressedData, answerData)
        if answerData.count > 0 { // Compression ratio is always bad for empty file.
            let compressionRatio = Double(answerData.count) / Double(compressedData.count)
            print("LZ4.\(testName).compressionRatio = \(compressionRatio)")
        }
    }

    func stringTest(_ string: String) throws {
        let answerData = Data(string.utf8)
        let compressedData = LZ4.compress(data: answerData)
        let redecompressedData = try LZ4.decompress(data: compressedData)
        XCTAssertEqual(redecompressedData, answerData)
    }

    func testLZ4CompressStrings() throws {
        try stringTest("banana")
        try stringTest("abaaba")
        try stringTest("abracadabra")
        try stringTest("cabbage")
        try stringTest("baabaabac")
        try stringTest("AAAAAAABBBBCCCD")
        try stringTest("AAAAAAA")
        try stringTest("qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890")
    }

    func testLZ4CompressBytes() throws {
        var bytes = ""
        for i: UInt8 in 0...255 {
            bytes += String(format: "%c", i)
        }
        try stringTest(bytes)
    }

    func testWithAnswer1LZ4Compress() throws {
        try answerTest("test1")
    }

    func testWithAnswer2LZ4Compress() throws {
        try answerTest("test2")
    }

    func testWithAnswer3LZ4Compress() throws {
        try answerTest("test3")
    }

    func testWithAnswer4LZ4Compress() throws {
        try answerTest("test4")
    }

    func testWithAnswer5LZ4Compress() throws {
        try answerTest("test5")
    }

    func testWithAnswer6LZ4Compress() throws {
        try answerTest("test6")
    }

    func testWithAnswer7LZ4Compress() throws {
        try answerTest("test7")
    }

    func testWithAnswer8LZ4Compress() throws {
        try answerTest("test8")
    }

    func testWithAnswer9LZ4Compress() throws {
        try answerTest("test9")
    }

    func testWithRandomOptions() throws {
        for i in 1...9 {
            let independentBlocks = Bool.random()
            let blockChecksums = Bool.random()
            let contentChecksum = Bool.random()
            let contentSize = Bool.random()
            let blockSize = Int.random(in: 1024...4 * 1024 * 1024)

            let answerData = try Constants.data(forAnswer: "test\(i)")
            let compressedData = LZ4.compress(data: answerData, independentBlocks: independentBlocks,
                                              blockChecksums: blockChecksums, contentChecksum: contentChecksum,
                                              contentSize: contentSize, blockSize: blockSize, dictionary: nil,
                                              dictionaryID: nil)
            do {
                let redecompressedData = try LZ4.decompress(data: compressedData)
                XCTAssertEqual(redecompressedData, answerData, "Test #\(i) failed (result mismatch) with the following " +
                               "options: independent blocks = \(independentBlocks), block checksums = \(blockChecksums), " +
                               "content checksum = \(contentChecksum), content size = \(contentSize), " +
                               "block size = \(blockSize) bytes")
            } catch let error {
                XCTFail("Test #\(i) failed (DataError.\(error) caught) with the following options: " +
                        "independent blocks = \(independentBlocks), block checksums = \(blockChecksums), " +
                        "content checksum = \(contentChecksum), content size = \(contentSize), " +
                        "block size = \(blockSize) bytes")
            }
        }
    }

    func testDictionary() throws {
        let answerData = try Constants.data(forTest: "SWCompressionSourceCode", withType: "tar")
        let dictData = try Constants.data(forTest: "lz4_dict", withType: "")

        var compressedData = LZ4.compress(data: answerData, independentBlocks: true, blockChecksums: Bool.random(),
                                              contentChecksum: Bool.random(), contentSize: Bool.random(),
                                              blockSize: 256 * 1024, dictionary: dictData, dictionaryID: nil)
        var redecompressedData = try LZ4.decompress(data: compressedData, dictionary: dictData)
        XCTAssertEqual(redecompressedData, answerData)
        var compressionRatio = Double(answerData.count) / Double(compressedData.count)
        print("LZ4.dict.compressionRatio = \(compressionRatio)")

        compressedData = LZ4.compress(data: answerData, independentBlocks: false, blockChecksums: Bool.random(),
                                              contentChecksum: Bool.random(), contentSize: Bool.random(),
                                              blockSize: 256 * 1024, dictionary: dictData, dictionaryID: nil)
        redecompressedData = try LZ4.decompress(data: compressedData, dictionary: dictData)
        XCTAssertEqual(redecompressedData, answerData)
        compressionRatio = Double(answerData.count) / Double(compressedData.count)
        print("LZ4.dict_BD.compressionRatio = \(compressionRatio)")

        compressedData = LZ4.compress(data: answerData, independentBlocks: true, blockChecksums: Bool.random(),
                                              contentChecksum: Bool.random(), contentSize: Bool.random(),
                                              blockSize: 256 * 1024, dictionary: dictData, dictionaryID: 20000)
        redecompressedData = try LZ4.decompress(data: compressedData, dictionary: dictData, dictionaryID: 20000)
        XCTAssertEqual(redecompressedData, answerData)
        // If the wrong dictionary ID is specified the decompression should fail.
        XCTAssertThrowsError(try LZ4.decompress(data: compressedData, dictionary: dictData, dictionaryID: 12345))
    }

    func testSmallDictionary() throws {
        let answerData = try Constants.data(forTest: "SWCompressionSourceCode", withType: "tar")
        let dictData = try Constants.data(forTest: "lz4_small_dict", withType: "")

        var compressedData = LZ4.compress(data: answerData, independentBlocks: true, blockChecksums: Bool.random(),
                                              contentChecksum: Bool.random(), contentSize: Bool.random(),
                                              blockSize: 256 * 1024, dictionary: dictData, dictionaryID: nil)
        var redecompressedData = try LZ4.decompress(data: compressedData, dictionary: dictData)
        XCTAssertEqual(redecompressedData, answerData)
        var compressionRatio = Double(answerData.count) / Double(compressedData.count)
        print("LZ4.small_dict.compressionRatio = \(compressionRatio)")

        compressedData = LZ4.compress(data: answerData, independentBlocks: false, blockChecksums: Bool.random(),
                                              contentChecksum: Bool.random(), contentSize: Bool.random(),
                                              blockSize: 256 * 1024, dictionary: dictData, dictionaryID: nil)
        redecompressedData = try LZ4.decompress(data: compressedData, dictionary: dictData)
        XCTAssertEqual(redecompressedData, answerData)
        compressionRatio = Double(answerData.count) / Double(compressedData.count)
        print("LZ4.small_dict_BD.compressionRatio = \(compressionRatio)")
    }

}
