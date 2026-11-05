import AppKit

/// How a picture is placed on the target screen before a converter reduces its colours.
///
/// Every converter scales the source to its screen size in one place. `ImageFraming` replaces
/// that plain stretch with a choice of fit, and can take the machine's non-square pixels into
/// account. The default (Stretch) draws exactly as before, so existing output doesn't change.
nonisolated struct ImageFraming: Equatable {
    enum Fit: String, CaseIterable {
        case stretch = "Stretch"   // fill the screen, ignoring the picture's shape
        case contain = "Contain"   // show the whole picture, black bars where it doesn't fill
        case cover = "Cover"       // fill the screen, cropping what sticks out
        case none = "None"         // no scaling: one source pixel per screen line, centered
    }

    var fit: Fit = .stretch
    /// Treat the target's pixels as they look on a real screen (true) or as square (false).
    var correctAspect = true
    /// Which part of the picture shows when it doesn't fit exactly, per axis from -1 to 1:
    /// x -1 shows the left edge, 1 the right edge; y -1 shows the top, 1 the bottom; 0 centers.
    var offset: CGPoint = .zero

    static let stretch = ImageFraming()

    /// Every machine's picture is assumed to fill a 4:3 screen, so a 320×200 pixel is taller
    /// than wide and a 640×200 one even more so.
    static let screenAspect: CGFloat = 4.0 / 3.0

    static let fitKey = "fit"
    static let aspectKey = "aspect"
    /// Set per picture by dragging the preview; not shown as a control.
    static let offsetKey = "fit_offset"

    /// The Fit and Aspect controls every converter shows.
    static var options: [ConversionOption] {
        [
            ConversionOption(label: "Fit", key: fitKey, values: Fit.allCases.map(\.rawValue),
                             selectedValue: Fit.stretch.rawValue),
            ConversionOption(label: "Aspect", key: aspectKey, values: ["Correct", "Ignore"],
                             selectedValue: "Correct"),
        ]
    }

    init(fit: Fit = .stretch, correctAspect: Bool = true, offset: CGPoint = .zero) {
        self.fit = fit
        self.correctAspect = correctAspect
        self.offset = offset
    }

    /// Reads Fit and Aspect from a converter's settings. Settings without them (for example
    /// settings locked before these options existed) stretch, as before.
    init(_ settings: [ConversionOption]) {
        fit = settings.first { $0.key == Self.fitKey }.flatMap { Fit(rawValue: $0.selectedValue) } ?? .stretch
        correctAspect = settings.first { $0.key == Self.aspectKey }?.selectedValue != "Ignore"
        if let value = settings.first(where: { $0.key == Self.offsetKey })?.selectedValue {
            let parts = value.split(separator: ",").compactMap { Double($0) }
            if parts.count == 2 { offset = CGPoint(x: Self.clamp(parts[0]), y: Self.clamp(parts[1])) }
        }
    }

    /// `settings` with a picture's position added, replacing any earlier one.
    static func settings(_ settings: [ConversionOption], offset: CGPoint) -> [ConversionOption] {
        var result = settings.filter { $0.key != offsetKey }
        if offset != .zero {
            let value = "\(offset.x),\(offset.y)"
            result.append(ConversionOption(label: "Position", key: offsetKey, values: [value], selectedValue: value))
        }
        return result
    }

    /// The position after dragging the preview by `fraction` of its displayed size (positive is
    /// right and down). `scale` is the picture's drawn size relative to the screen, as reported by
    /// the conversion; the picture then follows the mouse. Axes where the picture fits exactly
    /// can't move.
    static func offset(_ current: CGPoint, afterDrag fraction: CGSize, scale: CGSize) -> CGPoint {
        func move(_ value: CGFloat, _ drag: CGFloat, _ k: CGFloat) -> CGFloat {
            abs(1 - k) < 0.001 ? value : clamp(value + 2 * drag / (1 - k))
        }
        return CGPoint(x: move(current.x, fraction.width, scale.width), y: move(current.y, fraction.height, scale.height))
    }

    static func clamp(_ value: CGFloat) -> CGFloat { min(1, max(-1, value)) }

    /// Where a `sourceWidth`×`sourceHeight` picture goes in a `width`×`height` target.
    /// The rect may extend past the target (Cover, None); drawing clips it.
    func destination(sourceWidth: Int, sourceHeight: Int, width: Int, height: Int) -> CGRect {
        let w = CGFloat(width), h = CGFloat(height)
        let full = CGRect(x: 0, y: 0, width: w, height: h)
        guard fit != .stretch, sourceWidth > 0, sourceHeight > 0, width > 0, height > 0 else { return full }

        // Shape of one target pixel on screen (width / height)
        let pixelAspect = correctAspect ? Self.screenAspect * h / w : 1
        let screenShape = w * pixelAspect / h
        let sourceShape = CGFloat(sourceWidth) / CGFloat(sourceHeight)

        let size: CGSize
        switch fit {
        case .stretch:
            return full
        case .contain:
            size = sourceShape > screenShape
                ? CGSize(width: w, height: h * screenShape / sourceShape)
                : CGSize(width: w * sourceShape / screenShape, height: h)
        case .cover:
            size = sourceShape > screenShape
                ? CGSize(width: w * sourceShape / screenShape, height: h)
                : CGSize(width: w, height: h * screenShape / sourceShape)
        case .none:
            size = CGSize(width: CGFloat(sourceWidth) / pixelAspect, height: CGFloat(sourceHeight))
        }
        FramingReport.current?.record(CGSize(width: size.width / w, height: size.height / h))
        // Drawing origin is bottom-left, so y -1 (top) puts the picture's top at the screen's top
        return CGRect(x: (w - size.width) / 2 * (1 + offset.x), y: (h - size.height) / 2 * (1 - offset.y),
                      width: size.width, height: size.height)
    }

    /// Draws `image` into a `width`×`height` context. Stretch is the plain draw converters
    /// always did; the other fits paint the uncovered area black first.
    func draw(_ image: CGImage, in context: CGContext, width: Int, height: Int) {
        let full = CGRect(x: 0, y: 0, width: width, height: height)
        guard fit != .stretch else {
            context.draw(image, in: full)
            return
        }
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(full)
        context.draw(image, in: destination(sourceWidth: image.width, sourceHeight: image.height,
                                            width: width, height: height))
    }
}

/// Collects how large a conversion drew its picture relative to the screen, so dragging the
/// preview can move the picture exactly with the mouse. Set for a conversion with `$current`.
nonisolated final class FramingReport: @unchecked Sendable {
    @TaskLocal static var current: FramingReport?

    private let lock = NSLock()
    private var recorded: CGSize?

    func record(_ scale: CGSize) {
        lock.lock(); defer { lock.unlock() }
        recorded = scale
    }

    var scale: CGSize? {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }
}
