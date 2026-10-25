import Foundation

/// Chooses palette colors that cover the whole picture rather than the most
/// frequent ones, so small but distinct areas (a red region on a mostly grey
/// image) still get a color.
///
/// Median cut splits the pixels into groups along their widest color range;
/// for small palettes a few k-means passes then refine the groups. Each group
/// gets its own hardware color, larger groups choosing first.
nonisolated enum CoveringPalette {

    /// Refinement passes are skipped above this size: median cut alone is a
    /// good fit for large palettes, and k-means would be slow in debug builds.
    private static let refineLimit = 64

    /// Indices of up to `count` distinct entries of `candidates` (a fixed
    /// hardware palette) that together cover `pixels` (RGB, 0-255).
    static func pick(_ count: Int, from candidates: [[UInt8]], pixels: [[Float]]) -> [Int] {
        let targets = candidates.map { SIMD3<Float>($0.map(Float.init)) }
        let n = min(count, targets.count)
        let points = clamped(pixels)
        guard n > 0, !points.isEmpty else { return [] }

        var (centers, weights) = medianCut(points, into: n)
        var chosen = snap(centers, weights: weights, to: targets)
        if n <= refineLimit {
            for _ in 0..<6 {
                if Task.isCancelled { break }  // the caller checks again and throws
                let (updated, counts) = kMeansStep(points, toward: chosen.map { targets[$0] }, fallback: centers)
                weights = counts
                if updated == centers { break }
                centers = updated
                chosen = snap(centers, weights: weights, to: targets)
            }
            chosen = snap(centers, weights: weights, to: targets)
        }
        return chosen
    }

    /// Up to `count` distinct colors for hardware that can show any color on a
    /// grid (`quantize` rounds a color to that grid).
    static func pick(_ count: Int, pixels: [[Float]], quantize: (SIMD3<Float>) -> [UInt8]) -> [[UInt8]] {
        let points = clamped(pixels)
        guard count > 0, !points.isEmpty else { return [] }
        var (centers, weights) = medianCut(points, into: count)
        if count <= refineLimit {
            for _ in 0..<6 {
                if Task.isCancelled { break }  // the caller checks again and throws
                let snapped = centers.map { SIMD3<Float>(quantize($0).map(Float.init)) }
                let (updated, counts) = kMeansStep(points, toward: snapped, fallback: centers)
                weights = counts
                if updated == centers { break }
                centers = updated
            }
        }
        // Larger groups first; drop colors that round to the same grid point
        var result: [[UInt8]] = []
        for i in centers.indices.sorted(by: { weights[$0] != weights[$1] ? weights[$0] > weights[$1] : $0 < $1 }) {
            let color = quantize(centers[i])
            if !result.contains(color) { result.append(color) }
        }
        return result
    }

    // MARK: - Steps

    private static func clamped(_ pixels: [[Float]]) -> [SIMD3<Float>] {
        pixels.map { SIMD3<Float>(max(0, min(255, $0[0])), max(0, min(255, $0[1])), max(0, min(255, $0[2]))) }
    }

    /// Splits the box with the widest color range at its median until there are
    /// `count` boxes (or no box can be split). Returns box averages and sizes.
    private static func medianCut(_ points: [SIMD3<Float>], into count: Int) -> ([SIMD3<Float>], [Int]) {
        // Widest axis and its range for a box, computed once when the box is created
        func widest(_ box: [SIMD3<Float>]) -> (axis: Int, range: Float) {
            var lo = box[0], hi = box[0]
            for p in box { lo = pointwiseMin(lo, p); hi = pointwiseMax(hi, p) }
            let size = hi - lo
            let axis = size.x >= size.y && size.x >= size.z ? 0 : (size.y >= size.z ? 1 : 2)
            return (axis, size[axis])
        }
        var boxes: [[SIMD3<Float>]] = [points]
        var spans = [widest(points)]
        while boxes.count < count {
            var best: (box: Int, axis: Int, range: Float)?
            for (i, box) in boxes.enumerated() where box.count > 1 {
                if spans[i].range > (best?.range ?? 0) { best = (i, spans[i].axis, spans[i].range) }
            }
            guard let split = best else { break }  // fewer distinct colors than requested
            let sorted = boxes[split.box].sorted { $0[split.axis] < $1[split.axis] }
            boxes[split.box] = Array(sorted[..<(sorted.count / 2)])
            boxes.append(Array(sorted[(sorted.count / 2)...]))
            spans[split.box] = widest(boxes[split.box])
            spans.append(widest(boxes[boxes.count - 1]))
        }
        return (boxes.map { $0.reduce(SIMD3<Float>(), +) / Float($0.count) }, boxes.map(\.count))
    }

    /// Assigns every point to the nearest target and returns each group's
    /// average (or the fallback center when a group is empty) and size.
    private static func kMeansStep(_ points: [SIMD3<Float>], toward targets: [SIMD3<Float>],
                                   fallback: [SIMD3<Float>]) -> ([SIMD3<Float>], [Int]) {
        var sums = [SIMD3<Float>](repeating: .zero, count: targets.count)
        var counts = [Int](repeating: 0, count: targets.count)
        for (n, p) in points.enumerated() {
            if n % 4096 == 0 && Task.isCancelled { break }  // the caller checks again and throws
            var bestIdx = 0, bestDist = Float.greatestFiniteMagnitude
            for (i, t) in targets.enumerated() {
                let d = p - t, dist = (d * d).sum()
                if dist < bestDist { bestDist = dist; bestIdx = i }
            }
            sums[bestIdx] += p
            counts[bestIdx] += 1
        }
        let centers = targets.indices.map { counts[$0] > 0 ? sums[$0] / Float(counts[$0]) : fallback[$0] }
        return (centers, counts)
    }

    /// Nearest candidate index for each center, never using an index twice.
    /// Centers with more pixels choose first.
    private static func snap(_ centers: [SIMD3<Float>], weights: [Int], to targets: [SIMD3<Float>]) -> [Int] {
        var result = [Int](repeating: 0, count: centers.count)
        var used = Set<Int>()
        for i in centers.indices.sorted(by: { weights[$0] != weights[$1] ? weights[$0] > weights[$1] : $0 < $1 }) {
            var bestIdx = 0, bestDist = Float.greatestFiniteMagnitude
            for (idx, t) in targets.enumerated() where !used.contains(idx) {
                let d = centers[i] - t, dist = (d * d).sum()
                if dist < bestDist { bestDist = dist; bestIdx = idx }
            }
            used.insert(bestIdx)
            result[i] = bestIdx
        }
        return result
    }
}
