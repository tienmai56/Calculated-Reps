import Foundation

/// ZIP32, STORE method. Streams file bodies; no shell, external dependency, or
/// access outside the explicitly staged export directory. Reader CRCs are standard.
enum ArchiveZIP {
    private struct Entry { let name: Data; let crc: UInt32; let size: UInt32; let offset: UInt32 }
    private static func crc(_ data: Data, previous: UInt32 = 0) -> UInt32 {
        var c = previous ^ 0xffffffff
        for byte in data { c ^= UInt32(byte); for _ in 0..<8 { c = (c >> 1) ^ (c & 1 == 1 ? 0xedb88320 : 0) } }
        return c ^ 0xffffffff
    }
    /// Reads entries from a ZIP written by `write` (STORE method only), keeping
    /// those whose names pass `include`. Anything re-compressed or damaged is refused.
    static func readStored(_ data: Data, include: (String) -> Bool) throws -> [String: Data] {
        let bytes = [UInt8](data)
        let bad = ArchiveFailure.invalid("That file isn't a readable notebook export.")
        func u16(_ i: Int) throws -> Int {
            guard i >= 0, i + 2 <= bytes.count else { throw bad }
            return Int(bytes[i]) | Int(bytes[i + 1]) << 8
        }
        func u32(_ i: Int) throws -> Int {
            guard i >= 0, i + 4 <= bytes.count else { throw bad }
            return Int(bytes[i]) | Int(bytes[i + 1]) << 8 | Int(bytes[i + 2]) << 16 | Int(bytes[i + 3]) << 24
        }
        // End of central directory: the last signature within the comment window.
        guard bytes.count >= 22 else { throw bad }
        var eocd = -1
        var i = bytes.count - 22
        let floor = max(0, bytes.count - 22 - 65535)
        while i >= floor {
            if try u32(i) == 0x06054b50 { eocd = i; break }
            i -= 1
        }
        guard eocd >= 0 else { throw bad }
        let count = try u16(eocd + 10)
        var p = try u32(eocd + 16)
        var out: [String: Data] = [:]
        for _ in 0..<count {
            guard try u32(p) == 0x02014b50 else { throw bad }
            let method = try u16(p + 10)
            let checksum = UInt32(try u32(p + 16))
            let compressed = try u32(p + 20)
            let size = try u32(p + 24)
            let nameLength = try u16(p + 28)
            let extraLength = try u16(p + 30)
            let commentLength = try u16(p + 32)
            let local = try u32(p + 42)
            guard p + 46 + nameLength <= bytes.count else { throw bad }
            let name = String(decoding: bytes[(p + 46)..<(p + 46 + nameLength)], as: UTF8.self)
            p += 46 + nameLength + extraLength + commentLength
            guard include(name) else { continue }
            guard method == 0, compressed == size else {
                throw ArchiveFailure.invalid("This export was re-compressed. Export it again from Settings and pick the new file.")
            }
            guard try u32(local) == 0x04034b50 else { throw bad }
            let start = try local + 30 + u16(local + 26) + u16(local + 28)
            guard start >= 0, start + size <= bytes.count else { throw bad }
            let body = Data(bytes[start..<(start + size)])
            guard crc(body) == checksum else { throw bad }
            out[name] = body
        }
        return out
    }

    static func write(directory: URL, destination: URL) throws {
        let fm = FileManager.default
        let root = directory.resolvingSymlinksInPath().standardizedFileURL
        guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]) else { throw ArchiveFailure.invalid("Cannot enumerate export files.") }
        var files: [URL] = []
        for case let url as URL in walker {
            let v = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard v.isSymbolicLink != true else { throw ArchiveFailure.invalid("Symbolic links are not exportable.") }
            if v.isRegularFile == true { files.append(url) }
        }
        guard files.count < 65535 else { throw ArchiveFailure.invalid("Too many files for this export.") }
        fm.createFile(atPath: destination.path, contents: nil)
        let output = try FileHandle(forWritingTo: destination); defer { try? output.close() }
        func u16(_ value: UInt16) throws { var n = value.littleEndian; try output.write(contentsOf: withUnsafeBytes(of: &n) { Data($0) }) }
        func u32(_ value: UInt32) throws { var n = value.littleEndian; try output.write(contentsOf: withUnsafeBytes(of: &n) { Data($0) }) }
        var entries: [Entry] = []
        for file in files.sorted(by: { $0.path < $1.path }) {
            let filePath = file.standardizedFileURL.path
            guard filePath.hasPrefix(root.path + "/") else { throw ArchiveFailure.invalid("Export file escaped its staging directory.") }
            let name = Data(filePath.dropFirst(root.path.count + 1).utf8)
            let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            let offset = try output.offset()
            guard size < Int(UInt32.max), offset < UInt64(UInt32.max), name.count < 65535 else { throw ArchiveFailure.invalid("Export exceeds ZIP32 limits.") }
            let input = try FileHandle(forReadingFrom: file); defer { try? input.close() }
            var checksum: UInt32 = 0
            while let chunk = try input.read(upToCount: 1024 * 1024), !chunk.isEmpty { checksum = crc(chunk, previous: checksum) }
            try input.seek(toOffset: 0)
            try u32(0x04034b50); try u16(20); try u16(0x0800); try u16(0); try u16(0); try u16(33)
            try u32(checksum); try u32(UInt32(size)); try u32(UInt32(size)); try u16(UInt16(name.count)); try u16(0)
            try output.write(contentsOf: name)
            while let chunk = try input.read(upToCount: 1024 * 1024), !chunk.isEmpty { try output.write(contentsOf: chunk) }
            entries.append(Entry(name: name, crc: checksum, size: UInt32(size), offset: UInt32(offset)))
        }
        let centralStart = try output.offset()
        for e in entries {
            try u32(0x02014b50); try u16(20); try u16(20); try u16(0x0800); try u16(0); try u16(0); try u16(33)
            try u32(e.crc); try u32(e.size); try u32(e.size); try u16(UInt16(e.name.count)); try u16(0); try u16(0); try u16(0); try u16(0); try u32(0); try u32(e.offset)
            try output.write(contentsOf: e.name)
        }
        let centralEnd = try output.offset()
        guard centralEnd < UInt64(UInt32.max) else { throw ArchiveFailure.invalid("Export exceeds ZIP32 limits.") }
        try u32(0x06054b50); try u16(0); try u16(0); try u16(UInt16(entries.count)); try u16(UInt16(entries.count)); try u32(UInt32(centralEnd - centralStart)); try u32(UInt32(centralStart)); try u16(0)
        try output.synchronize()
    }
}
