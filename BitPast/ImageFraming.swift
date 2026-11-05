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

    static let stretch = ImageFraming()

    /// Every machine's picture is assumed to fill a 4:3 screen, so a 320×200 pixel is taller
    /// than wide and a 640×200 one even more so.
    static let screenAspect: CGFloat = 4.0 / 3.0

    static let fitKey = "fit"
    static let aspectKey = "aspect"

    /// The Fit and Aspect controls every converter shows.
    static var options: [ConversionOption] {
        [
            ConversionOption(label: "Fit", key: fitKey, values: Fit.allCases.map(\.rawValue),
                             selectedValue: Fit.stretch.rawValue),
            ConversionOption(label: "Aspect", key: aspectKey, values: ["Correct", "Ignore"],
                             selectedValue: "Correct"),
        ]
    }

    init(fit: Fit = .stretch, correctAspect: Bool = true) {
        self.fit = fit
        self.correctAspect = correctAspect
    }

    /// Reads Fit and Aspect from a converter's settings. Settings without them (for example
    /// settings locked before these options existed) stretch, as before.
    init(_ settings: [ConversionOption]) {
        fit = settings.first { $0.key == Self.fitKey }.flatMap { Fit(rawValue: $0.selectedValue) } ?? .stretch
        correctAspect = settings.first { $0.key == Self.aspectKey }?.selectedValue != "Ignore"
    }

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
        return CGRect(x: (w - size.width) / 2, y: (h - size.height) / 2, width: size.width, height: size.height)
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
