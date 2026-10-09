import Foundation

/// The recovered YTyper 3.8 line balancing and Kashida algorithm. Glyph width
/// comes from the platform; identical algorithms do not imply identical glyph metrics.
struct Typesetter {
    var measure: (String) -> Double
    private func metric(_ text: String) -> Double { Double(Float(measure(text))) }
    private let high = "عغ", medium = "فقصضطظ", low = "كملنهي"
    private let nonConnectors = "اأإآدذرزوؤةء", marks = "ـ،؛:؟!()...\"' "
    func normalized(_ text: String) -> String {
        // Kotlin trims Unicode space characters; its Java \\s regex then collapses
        // ASCII whitespace only. ICU's \\s on Apple also collapses NBSP, which
        // changes word boundaries in copied dialogue.
        func trims(_ unit: UInt16) -> Bool {
            (0x9...0xD).contains(unit) || (0x1C...0x20).contains(unit)
                || unit == 0xA0 || unit == 0x1680 || (0x2000...0x200A).contains(unit)
                || unit == 0x2028 || unit == 0x2029 || unit == 0x202F
                || unit == 0x205F || unit == 0x3000
        }
        let units = Array(text.utf16)
        var start = 0, end = units.count
        while start < end && trims(units[start]) { start += 1 }
        while end > start && trims(units[end - 1]) { end -= 1 }
        var result: [UInt16] = [], previousSpace = false
        for unit in units[start..<end] {
            if unit == 0x20 || (0x9...0xD).contains(unit) {
                if !previousSpace { result.append(0x20) }
                previousSpace = true
            } else { result.append(unit); previousSpace = false }
        }
        return String(decoding: result, as: UTF16.self)
    }
    private func words(_ text: String) -> [String] { text.components(separatedBy: " ") }
    private func noOrphans(_ original: [String]) -> [String] {
        guard original.count > 1 else { return original }
        var lines = original
        let last = lines.count - 1
        if !lines[last].trimmingCharacters(in: .whitespaces).contains(" ") {
            var previous = words(lines[last - 1])
            if previous.count > 1, let word = previous.popLast() {
                lines[last - 1] = previous.joined(separator: " ")
                lines[last] = word + " " + lines[last]
            }
        }
        return lines
    }
    private func balance(_ text: String, width: Double) -> [String] {
        var lines: [String] = [], current = ""
        for word in words(text) {
            let candidate = current.isEmpty ? word : current + " " + word
            if metric(candidate) <= width { current = candidate }
            else { if !current.isEmpty { lines.append(current) }; current = word }
        }
        if !current.isEmpty { lines.append(current) }
        guard lines.count > 1 else { return lines }
        for _ in 0..<3 {
            var changed = false
            for i in 0..<(lines.count - 1) {
                var previous = words(lines[i])
                guard previous.count > 1, let last = previous.popLast() else { continue }
                let shorter = previous.joined(separator: " ")
                let next = last + " " + lines[i + 1]
                if metric(next) <= width * 1.1 && (abs(metric(shorter) - width) < abs(metric(lines[i]) - width) || metric(lines[i]) > width) {
                    lines[i] = shorter; lines[i + 1] = next; changed = true
                }
            }
            if !changed { break }
        }
        return lines
    }
    private func priority(_ char: UInt16) -> Int {
        high.utf16.contains(char) ? 4 : medium.utf16.contains(char) ? 3 : low.utf16.contains(char) ? 2 : 1
    }
    private func canStretch(_ first: UInt16, _ second: UInt16) -> Bool {
        !nonConnectors.utf16.contains(first) && !marks.utf16.contains(first) && !marks.utf16.contains(second)
            && first >= 0x600 && first < 0x700 && second >= 0x600 && second < 0x700
    }
    private func justify(_ line: String, width: Double, soft: Bool) -> String {
        let measured = metric(line), parts = words(line)
        guard measured < width, parts.count > 1 else { return line }
        let extra = width - measured
        if !line.utf16.contains(where: { $0 >= 0x600 && $0 < 0x700 }) {
            let space = metric(" ")
            guard space > 0 else { return line }
            let count = Int(ceil(extra / space)), perGap = count / (parts.count - 1), remainder = count % (parts.count - 1)
            return parts.enumerated().map { index, word in
                index == parts.count - 1 ? word : word + String(repeating: " ", count: 1 + perGap + (index < remainder ? 1 : 0))
            }.joined()
        }
        let tatweelWidth = metric("ـ"), noSpaceWidth = metric(line.replacingOccurrences(of: " ", with: ""))
        guard tatweelWidth > 0, noSpaceWidth > 0 else { return line }
        let requested = Int(ceil(extra / tatweelWidth))
        let total = soft ? Int(Double(requested) * 0.5) : requested
        return parts.map { word -> String in
            // Android indexes UTF-16 code units, including Arabic combining marks.
            let chars = Array(word.utf16)
            guard chars.count > 1 else { return word }
            let positions = (0..<(chars.count - 1)).filter { canStretch(chars[$0], chars[$0 + 1]) }
                .sorted { a, b in priority(chars[a]) == priority(chars[b]) ? a < b : priority(chars[a]) > priority(chars[b]) }
            let budget = max(1, Int((metric(word) / noSpaceWidth * Double(total)).rounded()))
            var result = chars, inserted = 0
            for position in positions {
                if inserted >= budget { break }
                let index = position + 1 + inserted
                let amount = min(soft ? 1 : 3, priority(chars[position]))
                for _ in 0..<amount where inserted < 15 {
                    if index <= result.count { result.insert(0x640, at: index); inserted += 1 }
                }
            }
            return String(decoding: result, as: UTF16.self)
        }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }
    func box(_ text: String, width: Double, tatweel: Bool) -> String {
        guard width > 0, !normalized(text).isEmpty else { return "" }
        let lines = noOrphans(balance(normalized(text), width: width))
        let target = Double(Int(max(width, lines.map(metric).max() ?? 0)))
        return lines.enumerated().map { index, line in
            if !tatweel { return line }
            if index == lines.count - 1 && metric(line) <= target * 0.65 { return line }
            return justify(line, width: target, soft: index == lines.count - 1)
        }.joined(separator: "\n")
    }
    private func ratios(_ count: Int) -> [Double] {
        switch count {
        case 2: return [0.6, 0.4]
        case 3: return [0.25, 0.5, 0.25]
        case 4: return [0.17, 0.33, 0.33, 0.17]
        case 5: return [0.15, 0.23, 0.24, 0.23, 0.15]
        case 6: return [0.1, 0.18, 0.22, 0.22, 0.18, 0.1]
        case 7: return [0.08, 0.13, 0.15, 0.28, 0.15, 0.13, 0.08]
        case 8: return [0.06, 0.1, 0.12, 0.18, 0.18, 0.12, 0.1, 0.06]
        default: return count == 0 ? [] : Array(repeating: 1 / Double(count), count: count)
        }
    }
    private func center(_ line: String, width: Double) -> String {
        let remaining = width - metric(line), space = metric(" ")
        guard remaining > 0, space > 0 else { return line }
        let padding = String(repeating: " ", count: Int(remaining / 2 / space))
        return padding + line + padding
    }
    func circle(_ text: String, width: Double, fontSize: Double) -> String {
        let text = normalized(text)
        guard width > 0, !text.isEmpty else { return "" }
        let measured = metric(text)
        var count = max(0, Int(ceil(measured / (width * 0.75))))
        if count > 2 && count % 2 == 0 { count += 1 }
        let targets = ratios(count).map { max(Double(Int(measured * 1.15 * $0)), 3 * fontSize) }
        let parts = words(text); var index = 0, lines: [String] = []
        for target in targets {
            var current = ""
            while index < parts.count {
                let candidate = current.isEmpty ? parts[index] : current + " " + parts[index]
                if metric(candidate) > target * 1.1 {
                    if current.isEmpty { current = parts[index]; index += 1 }
                    break
                }
                current = candidate; index += 1
            }
            if !current.isEmpty { lines.append(current) }
        }
        while index < parts.count {
            if lines.isEmpty { lines.append("") }
            lines[lines.count - 1] += " " + parts[index]; index += 1
        }
        let target = Double(Int(lines.map(metric).max() ?? 0)), middle = lines.count / 2
        return lines.enumerated().map { index, line in
            center(index == middle && lines.count > 2 ? justify(line, width: target, soft: false) : line, width: target)
        }.joined(separator: "\n")
    }
}
