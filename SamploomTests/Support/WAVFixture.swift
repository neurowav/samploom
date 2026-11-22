import Foundation

/// Builds minimal PCM WAV data so AVFoundation has something real to read.
enum WAVFixture {
    static func silence(seconds: Double, sampleRate: Int = 44_100) -> Data {
        wav(samples: Array(repeating: 0, count: frameCount(seconds: seconds, sampleRate: sampleRate)), sampleRate: sampleRate)
    }

    static func tone(
        seconds: Double,
        frequency: Double = 440,
        amplitude: Double = 0.5,
        sampleRate: Int = 44_100
    ) -> Data {
        let frames: Int = frameCount(seconds: seconds, sampleRate: sampleRate)
        var samples: [Int16] = []
        samples.reserveCapacity(frames)
        for frame in 0..<frames {
            let value: Double = sin(2 * .pi * frequency * Double(frame) / Double(sampleRate)) * amplitude
            samples.append(Int16(max(-1, min(1, value)) * Double(Int16.max)))
        }
        return wav(samples: samples, sampleRate: sampleRate)
    }

    static func write(_ data: Data, named name: String) throws -> URL {
        let directory: URL = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url: URL = directory.appending(path: name)
        try data.write(to: url)
        return url
    }

    static func writeSilence(seconds: Double, named name: String, sampleRate: Int = 44_100) throws -> URL {
        try write(silence(seconds: seconds, sampleRate: sampleRate), named: name)
    }

    private static func frameCount(seconds: Double, sampleRate: Int) -> Int {
        Int(Double(sampleRate) * seconds)
    }

    private static func wav(samples: [Int16], sampleRate: Int) -> Data {
        let dataSize: Int = samples.count * 2
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
        for sample in samples {
            data.append(littleEndian: UInt16(bitPattern: sample))
        }
        return data
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
