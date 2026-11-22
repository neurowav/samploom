import Foundation

/// Builds minimal PCM WAV data so AVFoundation has something real to read.
enum WAVFixture {
    static func silence(seconds: Double, sampleRate: Int = 44_100) -> Data {
        let frames: Int = Int(Double(sampleRate) * seconds)
        let dataSize: Int = frames * 2
        var data: Data = .init()
        data.append(contentsOf: Array("RIFF".utf8))
        data.append(littleEndian: UInt32(36 + dataSize))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        data.append(littleEndian: UInt32(16))
        data.append(littleEndian: UInt16(1))
        data.append(littleEndian: UInt16(1))
        data.append(littleEndian: UInt32(sampleRate))
        data.append(littleEndian: UInt32(sampleRate * 2))
        data.append(littleEndian: UInt16(2))
        data.append(littleEndian: UInt16(16))
        data.append(contentsOf: Array("data".utf8))
        data.append(littleEndian: UInt32(dataSize))
        data.append(Data(count: dataSize))
        return data
    }

    static func writeSilence(seconds: Double, named name: String, sampleRate: Int = 44_100) throws -> URL {
        let directory: URL = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url: URL = directory.appending(path: name)
        try silence(seconds: seconds, sampleRate: sampleRate).write(to: url)
        return url
    }
}

private extension Data {
    mutating func append(littleEndian value: UInt32) {
        var littleEndianValue: UInt32 = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndianValue) { bytes in
            append(contentsOf: bytes)
        }
    }

    mutating func append(littleEndian value: UInt16) {
        var littleEndianValue: UInt16 = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndianValue) { bytes in
            append(contentsOf: bytes)
        }
    }
}
