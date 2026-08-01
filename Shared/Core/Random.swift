import CoreGraphics
import Foundation

/// SplitMix64. Deterministic for a given seed, which is what makes the figures
/// "half preset": the construction is fixed, the parameters come from here.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> CGFloat {
        CGFloat(next() >> 11) / CGFloat(1 << 53)
    }

    mutating func value(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        lo + (hi - lo) * unit()
    }

    mutating func int(_ range: ClosedRange<Int>) -> Int {
        let span = range.upperBound - range.lowerBound + 1
        guard span > 0 else { return range.lowerBound }
        return range.lowerBound + Int(next() % UInt64(span))
    }

    mutating func chance(_ p: CGFloat) -> Bool { unit() < p }

    mutating func pick<T>(_ items: [T]) -> T {
        items[int(0...(items.count - 1))]
    }

    mutating func maybePick<T>(_ items: [T]) -> T? {
        items.isEmpty ? nil : pick(items)
    }

    /// A few distinct picks without replacement, used for things like choosing
    /// which star-polygon steps to layer.
    mutating func sample<T>(_ items: [T], count: Int) -> [T] {
        var pool = items
        var out: [T] = []
        while out.count < count, !pool.isEmpty {
            out.append(pool.remove(at: int(0...(pool.count - 1))))
        }
        return out
    }
}
