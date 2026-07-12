/// A pure-Swift DEFLATE / zlib decompressor (RFC 1950 / 1951), dependency-free
/// so WinCoreGraphics can decode PNG image data without a platform library.
///
/// It supports all three block types — stored, fixed Huffman, and dynamic
/// Huffman — decoding canonically-constructed Huffman codes bit by bit. This is
/// clarity-first, not speed-first: adequate for decoding the modest bitmaps a
/// UI framework loads, not a streaming production inflater.
enum Inflate {
    /// Errors surfaced while inflating.
    enum Error: Swift.Error {
        case truncated
        case badBlockType
        case badStoredLength
        case badHuffmanCode
        case badDistance
    }

    /// A little-endian, LSB-first bit reader over a byte buffer (DEFLATE's bit
    /// order).
    private struct BitReader {
        let bytes: [UInt8]
        var byteIndex: Int
        var bitBuffer: UInt32 = 0
        var bitCount: Int = 0

        init(_ bytes: [UInt8], at start: Int) {
            self.bytes = bytes
            self.byteIndex = start
        }

        /// Reads `count` bits (0...24) as an integer, LSB first.
        mutating func bits(_ count: Int) throws -> Int {
            while bitCount < count {
                guard byteIndex < bytes.count else {
                    throw Error.truncated
                }
                bitBuffer |= UInt32(bytes[byteIndex]) << bitCount
                byteIndex += 1
                bitCount += 8
            }
            let value = Int(bitBuffer & ((1 << count) - 1))
            bitBuffer >>= count
            bitCount -= count
            return value
        }

        /// Discards buffered bits back to the next byte boundary (for stored
        /// blocks).
        mutating func alignToByte() {
            bitBuffer = 0
            bitCount = 0
        }
    }

    /// A canonical Huffman decoder built from per-symbol code lengths.
    private struct HuffmanTable {
        // For each code length, the first canonical code and the symbol-index
        // offset into `symbols`, so decoding walks bit lengths in order.
        var counts: [Int]         // number of codes of each length (0...maxBits)
        var symbols: [Int]        // symbols ordered by (length, symbol)
        let maxBits: Int

        init(codeLengths: [Int]) {
            let maxBits = codeLengths.max() ?? 0
            var counts = [Int](repeating: 0, count: maxBits + 1)
            for length in codeLengths where length > 0 {
                counts[length] += 1
            }
            // Offsets of each length's first symbol within `symbols`.
            var offsets = [Int](repeating: 0, count: maxBits + 2)
            for length in 1...max(maxBits, 1) where length <= maxBits {
                offsets[length + 1] = offsets[length] + counts[length]
            }
            var symbols = [Int](repeating: 0, count: codeLengths.count)
            var nextOffset = offsets
            for (symbol, length) in codeLengths.enumerated() where length > 0 {
                symbols[nextOffset[length]] = symbol
                nextOffset[length] += 1
            }
            self.counts = counts
            self.symbols = symbols
            self.maxBits = maxBits
        }

        /// Decodes one symbol, reading bits until a canonical code matches.
        func decode(_ reader: inout BitReader) throws -> Int {
            var code = 0
            var first = 0
            var index = 0
            var length = 1
            while length <= maxBits {
                code |= try reader.bits(1)
                let count = counts[length]
                if code - first < count {
                    return symbols[index + (code - first)]
                }
                index += count
                first = (first + count) << 1
                code <<= 1
                length += 1
            }
            throw Error.badHuffmanCode
        }
    }

    // Length codes 257...285: base value + extra bits.
    private static let lengthBase = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
                                     35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258]
    private static let lengthExtra = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
                                      3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0]
    // Distance codes 0...29: base value + extra bits.
    private static let distanceBase = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
                                       257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145,
                                       8193, 12289, 16385, 24577]
    private static let distanceExtra = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
                                        7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13]
    // Order the dynamic block lists its code-length code lengths in.
    private static let codeLengthOrder = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]

    /// Inflates a raw DEFLATE stream (no zlib header).
    static func inflateRaw(_ bytes: [UInt8], from start: Int = 0) throws -> [UInt8] {
        var reader = BitReader(bytes, at: start)
        var output = [UInt8]()

        while true {
            let isFinal = try reader.bits(1)
            let type = try reader.bits(2)
            switch type {
            case 0:
                reader.alignToByte()
                guard reader.byteIndex + 4 <= bytes.count else { throw Error.truncated }
                let length = Int(bytes[reader.byteIndex]) | (Int(bytes[reader.byteIndex + 1]) << 8)
                reader.byteIndex += 4 // skip LEN + NLEN
                guard reader.byteIndex + length <= bytes.count else { throw Error.badStoredLength }
                output.append(contentsOf: bytes[reader.byteIndex..<reader.byteIndex + length])
                reader.byteIndex += length
            case 1:
                try inflateBlock(&reader, into: &output,
                                 literals: fixedLiteralTable, distances: fixedDistanceTable)
            case 2:
                let (literals, distances) = try readDynamicTables(&reader)
                try inflateBlock(&reader, into: &output, literals: literals, distances: distances)
            default:
                throw Error.badBlockType
            }
            if isFinal == 1 {
                break
            }
        }
        return output
    }

    /// Inflates a zlib stream (2-byte header + DEFLATE + Adler-32 trailer).
    static func inflateZlib(_ bytes: [UInt8]) throws -> [UInt8] {
        guard bytes.count >= 2 else { throw Error.truncated }
        // CMF/FLG header; a preset dictionary (FLG bit 5) is not used by PNG.
        return try inflateRaw(bytes, from: 2)
    }

    private static func inflateBlock(
        _ reader: inout BitReader,
        into output: inout [UInt8],
        literals: HuffmanTable,
        distances: HuffmanTable
    ) throws {
        while true {
            let symbol = try literals.decode(&reader)
            if symbol < 256 {
                output.append(UInt8(symbol))
            } else if symbol == 256 {
                return
            } else {
                let lengthIndex = symbol - 257
                guard lengthIndex < lengthBase.count else { throw Error.badHuffmanCode }
                let length = lengthBase[lengthIndex] + (try reader.bits(lengthExtra[lengthIndex]))
                let distanceSymbol = try distances.decode(&reader)
                guard distanceSymbol < distanceBase.count else { throw Error.badDistance }
                let distance = distanceBase[distanceSymbol] + (try reader.bits(distanceExtra[distanceSymbol]))
                guard distance <= output.count else { throw Error.badDistance }
                var source = output.count - distance
                for _ in 0..<length {
                    output.append(output[source])
                    source += 1
                }
            }
        }
    }

    private static func readDynamicTables(_ reader: inout BitReader) throws -> (HuffmanTable, HuffmanTable) {
        let literalCount = try reader.bits(5) + 257
        let distanceCount = try reader.bits(5) + 1
        let codeLengthCount = try reader.bits(4) + 4

        var codeLengthLengths = [Int](repeating: 0, count: 19)
        for index in 0..<codeLengthCount {
            codeLengthLengths[codeLengthOrder[index]] = try reader.bits(3)
        }
        let codeLengthTable = HuffmanTable(codeLengths: codeLengthLengths)

        var lengths = [Int]()
        lengths.reserveCapacity(literalCount + distanceCount)
        while lengths.count < literalCount + distanceCount {
            let symbol = try codeLengthTable.decode(&reader)
            switch symbol {
            case 0...15:
                lengths.append(symbol)
            case 16:
                guard let previous = lengths.last else { throw Error.badHuffmanCode }
                let repeatCount = try reader.bits(2) + 3
                lengths.append(contentsOf: Array(repeating: previous, count: repeatCount))
            case 17:
                let repeatCount = try reader.bits(3) + 3
                lengths.append(contentsOf: Array(repeating: 0, count: repeatCount))
            case 18:
                let repeatCount = try reader.bits(7) + 11
                lengths.append(contentsOf: Array(repeating: 0, count: repeatCount))
            default:
                throw Error.badHuffmanCode
            }
        }
        let literalLengths = Array(lengths[0..<literalCount])
        let distanceLengths = Array(lengths[literalCount..<literalCount + distanceCount])
        return (HuffmanTable(codeLengths: literalLengths), HuffmanTable(codeLengths: distanceLengths))
    }

    // Fixed Huffman tables (RFC 1951 §3.2.6), built once.
    private static let fixedLiteralTable: HuffmanTable = {
        var lengths = [Int](repeating: 0, count: 288)
        for symbol in 0...143 { lengths[symbol] = 8 }
        for symbol in 144...255 { lengths[symbol] = 9 }
        for symbol in 256...279 { lengths[symbol] = 7 }
        for symbol in 280...287 { lengths[symbol] = 8 }
        return HuffmanTable(codeLengths: lengths)
    }()

    private static let fixedDistanceTable = HuffmanTable(codeLengths: [Int](repeating: 5, count: 30))
}
