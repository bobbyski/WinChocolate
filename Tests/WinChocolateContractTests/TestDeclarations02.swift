import WinChocolate

@MainActor
func testAspectRatioCrossAxisConstraints() {
    // A `height == width` constraint couples the axes; the solver's outer
    // alternating loop folds the cross-axis dimension as a constant and settles.
    let container = NSView(frame: NSMakeRect(0, 0, 200, 200))
    let box = NSView(frame: .zero)
    box.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(box)
    NSLayoutConstraint.activate([
        box.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        box.topAnchor.constraint(equalTo: container.topAnchor),
        box.widthAnchor.constraint(equalToConstant: 120),
        box.heightAnchor.constraint(equalTo: box.widthAnchor),
    ])
    container.layoutSubtreeIfNeeded()
    expect(winClose(box.frame.size.width, 120) && winClose(box.frame.size.height, 120),
        "1:1 aspect: height should follow width to 120: got \(box.frame.size).")

    // A 2:1 aspect ratio the other way — width follows height.
    let box2 = NSView(frame: .zero)
    box2.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(box2)
    NSLayoutConstraint.activate([
        box2.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        box2.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        box2.heightAnchor.constraint(equalToConstant: 40),
        box2.widthAnchor.constraint(equalTo: box2.heightAnchor, multiplier: 2),
    ])
    container.layoutSubtreeIfNeeded()
    expect(winClose(box2.frame.size.width, 80) && winClose(box2.frame.size.height, 40),
        "2:1 aspect: width should follow height to 80: got \(box2.frame.size).")
}

@MainActor
func testLayoutMarginsGuideInsetsChild() {
    // A child pinned to the margins guide sits inset by directionalLayoutMargins.
    let view = NSView(frame: NSMakeRect(0, 0, 200, 100))
    view.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
    let child = NSView(frame: .zero)
    child.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(child)
    let guide = view.layoutMarginsGuide
    NSLayoutConstraint.activate([
        child.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
        child.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
        child.topAnchor.constraint(equalTo: guide.topAnchor),
        child.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
    ])
    view.layoutSubtreeIfNeeded()
    expect(winClose(child.frame.origin.x, 20) && winClose(child.frame.origin.y, 10)
        && winClose(child.frame.size.width, 160) && winClose(child.frame.size.height, 80),
        "Margins guide should inset child to (20,10,160,80): got \(child.frame).")
}

@MainActor
func testControlIntrinsicContentSizes() {
    let button = NSButton(title: "OK", frame: .zero)
    button.isBordered = true
    expect(button.intrinsicContentSize.width > 0 && button.intrinsicContentSize.height >= 22,
        "Bordered button should report a positive width and >=22 height: got \(button.intrinsicContentSize).")
    let stepper = NSStepper(frame: .zero)
    expect(winClose(stepper.intrinsicContentSize.width, 19) && winClose(stepper.intrinsicContentSize.height, 27),
        "Stepper intrinsic should be 19x27: got \(stepper.intrinsicContentSize).")
    let slider = NSSlider(frame: .zero)
    slider.isVertical = false
    expect(winClose(slider.intrinsicContentSize.height, 21)
        && slider.intrinsicContentSize.width == NSView.noIntrinsicMetric,
        "Horizontal slider should be 21 thick with flexible length: got \(slider.intrinsicContentSize).")
}

@MainActor
func testLayoutControlIntrinsicSizes() {
    // Controls that a layout system creates without a frame must measure > 0 so
    // they don't collapse to 0×0 (the ActiveUI demo-walk blocker, R11).
    let segmented = NSSegmentedControl(labels: ["One", "Two", "Three"], frame: .zero)
    expect(segmented.intrinsicContentSize.width > 60 && winClose(segmented.intrinsicContentSize.height, 24),
        "Segmented control should measure its labels: got \(segmented.intrinsicContentSize).")

    let spinner = NSProgressIndicator(frame: .zero)
    spinner.style = .spinning
    expect(winClose(spinner.intrinsicContentSize.width, 32) && winClose(spinner.intrinsicContentSize.height, 32),
        "Spinning progress indicator should be 32×32: got \(spinner.intrinsicContentSize).")

    let well = NSColorWell(frame: .zero)
    expect(winClose(well.intrinsicContentSize.width, 44) && winClose(well.intrinsicContentSize.height, 23),
        "Color well should report standard 44×23: got \(well.intrinsicContentSize).")
    // The base NSControl.sizeThatFits now derives from intrinsicContentSize, so
    // consumers that call sizeThatFits (rather than reading the anchor) also work.
    let fitted = well.sizeThatFits(.zero)
    expect(winClose(fitted.width, 44) && winClose(fitted.height, 23),
        "sizeThatFits should follow intrinsicContentSize: got \(fitted).")

    let level = NSLevelIndicator(frame: .zero)
    expect(winClose(level.intrinsicContentSize.height, 18),
        "Level indicator should report standard height 18: got \(level.intrinsicContentSize).")

    let popup = NSPopUpButton(frame: .zero, pullsDown: false)
    popup.addItem(withTitle: "A reasonably long item title")
    expect(popup.intrinsicContentSize.width > 60 && winClose(popup.intrinsicContentSize.height, 26),
        "Pop-up button should measure its widest item + chevron: got \(popup.intrinsicContentSize).")
}

@MainActor
func testWinCoreGraphicsPNGDecode() {
    // Build a minimal 2×2 truecolor PNG by hand: signature, IHDR, one IDAT
    // holding a stored-block zlib stream of two filtered scanlines (row 0
    // None-filtered, row 1 Up-filtered), IEND. This exercises the full path —
    // chunk parsing, inflate (stored block), and unfiltering (None + Up).
    func chunk(_ type: String, _ data: [UInt8]) -> [UInt8] {
        let length = data.count
        var out: [UInt8] = [
            UInt8((length >> 24) & 0xFF), UInt8((length >> 16) & 0xFF),
            UInt8((length >> 8) & 0xFF), UInt8(length & 0xFF),
        ]
        out.append(contentsOf: Array(type.utf8))
        out.append(contentsOf: data)
        out.append(contentsOf: [0, 0, 0, 0]) // CRC (not validated)
        return out
    }
    let ihdr: [UInt8] = [0, 0, 0, 2,  0, 0, 0, 2,  8, 2, 0, 0, 0] // 2×2, 8-bit, RGB
    // Filtered scanlines: row0 None → red, green; row1 Up → blue, yellow.
    let raw: [UInt8] = [0, 255, 0, 0,  0, 255, 0,
                        2,   1, 0, 255, 255,  0, 0]
    var idat: [UInt8] = [0x78, 0x01,       // zlib header
                         0x01,             // BFINAL=1, BTYPE=00 (stored)
                         0x0E, 0x00,        // LEN = 14
                         0xF1, 0xFF]        // NLEN = ~14
    idat.append(contentsOf: raw)
    idat.append(contentsOf: [0, 0, 0, 0])  // Adler-32 (ignored)
    var png: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
    png.append(contentsOf: chunk("IHDR", ihdr))
    png.append(contentsOf: chunk("IDAT", idat))
    png.append(contentsOf: chunk("IEND", []))

    guard let image = CGImage.decodePNG(png) else {
        expect(false, "The hand-built PNG should decode.")
        return
    }
    expect(image.width == 2 && image.height == 2,
        "PNG dimensions should be 2×2: got \(image.width)×\(image.height).")
    // Top row (None filter): red, green.
    expect(image.pixel(atX: 0, y: 0).map { [$0.r, $0.g, $0.b, $0.a] } == [255, 0, 0, 255],
        "PNG (0,0) should be red: got \(String(describing: image.pixel(atX: 0, y: 0))).")
    expect(image.pixel(atX: 1, y: 0).map { [$0.r, $0.g, $0.b, $0.a] } == [0, 255, 0, 255],
        "PNG (1,0) should be green.")
    // Bottom row (Up filter reconstructs against the top row): blue, yellow.
    expect(image.pixel(atX: 0, y: 1).map { [$0.r, $0.g, $0.b, $0.a] } == [0, 0, 255, 255],
        "PNG (0,1) should be blue (Up-filter reconstruction): got \(String(describing: image.pixel(atX: 0, y: 1))).")
    expect(image.pixel(atX: 1, y: 1).map { [$0.r, $0.g, $0.b, $0.a] } == [255, 255, 0, 255],
        "PNG (1,1) should be yellow.")

    // The format-sniffing entry point routes PNG signatures to the PNG path.
    expect(CGImage.decode(png)?.width == 2, "decode() should sniff and route a PNG.")
    // And it still round-trips BMP through the same door.
    expect(CGImage.decode(image.encodeBMP())?.pixel(atX: 1, y: 1)?.g == 255,
        "decode() should also handle BMP bytes.")
}

@MainActor
func testWinCoreGraphicsTransformsAndBMPCodec() {
    // The geometry types come from the re-exported WinCoreGraphics module.
    // Affine transforms: composition, application, and inversion.
    let move = CGAffineTransform(translationX: 10, y: 20)
    expect(CGPoint(x: 1, y: 2).applying(move) == CGPoint(x: 11, y: 22),
        "Translation should offset the point.")
    let quarterTurn = CGAffineTransform(rotationAngle: .pi / 2)
    let rotated = CGPoint(x: 1, y: 0).applying(quarterTurn)
    expect(winClose(rotated.x, 0) && winClose(rotated.y, 1),
        "A quarter turn should map (1,0) to (0,1): got \(rotated).")
    let scaledThenMoved = CGAffineTransform(scaleX: 2, y: 3).concatenating(move)
    expect(CGPoint(x: 1, y: 1).applying(scaledThenMoved) == CGPoint(x: 12, y: 23),
        "Concatenation should apply scale then translation.")
    let roundTrip = CGPoint(x: 7, y: -3).applying(move).applying(move.inverted())
    expect(winClose(roundTrip.x, 7) && winClose(roundTrip.y, -3),
        "Inverting a transform should round-trip a point.")

    // CGImage: RGBA pixels round-trip through the BMP codec.
    let pixels: [UInt8] = [
        255, 0, 0, 255,   0, 255, 0, 255,   // red, green
        0, 0, 255, 255,   255, 255, 0, 128, // blue, translucent yellow
    ]
    guard let image = CGImage(width: 2, height: 2, rgbaPixels: pixels) else {
        expect(false, "CGImage should accept a matching RGBA buffer.")
        return
    }
    let encoded = image.encodeBMP()
    expect(encoded.count == 54 + 16 && encoded[0] == 0x42 && encoded[1] == 0x4D,
        "The encoded BMP should have the header + 16 pixel bytes: got \(encoded.count).")
    guard let decoded = CGImage.decodeBMP(encoded) else {
        expect(false, "The encoded BMP should decode.")
        return
    }
    expect(decoded.width == 2 && decoded.height == 2 && decoded.pixels == pixels,
        "The BMP round-trip should preserve every pixel (alpha included).")
    let corner = decoded.pixel(atX: 1, y: 1)
    expect(corner?.r == 255 && corner?.g == 255 && corner?.b == 0 && corner?.a == 128,
        "pixel(atX:y:) should read the translucent yellow corner.")
    expect(decoded.pixel(atX: 2, y: 0) == nil,
        "Out-of-bounds pixel reads should return nil.")
}

@MainActor
func testBaselineAnchorsAlignAcrossViews() {
    // Baselines resolve through baselineOffsetFromBottom (0 for plain views, so
    // baseline == bottom); a text field reports a positive descent offset.
    expect(NSTextField(labelWithString: "Hi").baselineOffsetFromBottom > 0,
        "A text field should report a positive baseline offset.")

    let container = NSView(frame: NSMakeRect(0, 0, 200, 100))
    let a = IntrinsicSizeView(NSSize(width: 40, height: 20))
    let b = IntrinsicSizeView(NSSize(width: 40, height: 30))
    a.translatesAutoresizingMaskIntoConstraints = false
    b.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(a)
    container.addSubview(b)
    NSLayoutConstraint.activate([
        a.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        a.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
        b.leadingAnchor.constraint(equalTo: a.trailingAnchor, constant: 10),
        b.lastBaselineAnchor.constraint(equalTo: a.lastBaselineAnchor),
    ])
    container.layoutSubtreeIfNeeded()
    // a spans y 10..30 (baseline 30); b (30 tall, offset 0) hangs from the same
    // baseline, so its top is 0.
    expect(winClose(a.frame.origin.y, 10) && winClose(b.frame.origin.y, 0),
        "Baseline-aligned views should share a baseline: a=\(a.frame) b=\(b.frame).")
}

@MainActor
func testCrossHierarchyConstraintUsesNestedFixedInput() {
    // A constraint may reference a view *inside* a nested container: the nested
    // view is a fixed input converted into the outer container's coordinates.
    let container = NSView(frame: NSMakeRect(0, 0, 200, 100))
    let nest = NSView(frame: NSMakeRect(20, 10, 80, 50))
    let inner = NSView(frame: NSMakeRect(5, 5, 30, 20))
    nest.addSubview(inner)
    container.addSubview(nest)

    let solved = NSView(frame: .zero)
    solved.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(solved)
    NSLayoutConstraint.activate([
        solved.leadingAnchor.constraint(equalTo: inner.trailingAnchor), // 25 + 30 = 55
        solved.topAnchor.constraint(equalTo: inner.bottomAnchor),       // 15 + 20 = 35
        solved.widthAnchor.constraint(equalToConstant: 40),
        solved.heightAnchor.constraint(equalToConstant: 10),
    ])
    container.layoutSubtreeIfNeeded()
    expect(winClose(solved.frame.origin.x, 55) && winClose(solved.frame.origin.y, 35),
        "Cross-hierarchy fixed input should convert to container coordinates: got \(solved.frame).")
}

@MainActor
func testStackViewGravityAreasAndEqualCentering() {
    func iv(_ w: CGFloat, _ h: CGFloat) -> IntrinsicSizeView { IntrinsicSizeView(NSSize(width: w, height: h)) }

    // Gravity areas: leading packs at the start, center centers as a block,
    // trailing packs at the end; views keep their intrinsic sizes.
    let stack = NSStackView(frame: NSMakeRect(0, 0, 300, 40))
    stack.orientation = .horizontal
    stack.distribution = .gravityAreas
    stack.spacing = 10
    let lead = iv(40, 20), mid = iv(60, 20), tail = iv(50, 20)
    stack.addView(lead, in: .leading)
    stack.addView(mid, in: .center)
    stack.addView(tail, in: .trailing)
    stack.layoutSubtreeIfNeeded()
    expect(winClose(lead.frame.origin.x, 0), "Leading gravity should pack at 0: got \(lead.frame.origin.x).")
    expect(winClose(mid.frame.origin.x, 120), "Center gravity should center at 120: got \(mid.frame.origin.x).")
    expect(winClose(tail.frame.origin.x, 250), "Trailing gravity should end at the edge: got \(tail.frame.origin.x).")
    expect(stack.views(in: .center).count == 1 && stack.views(in: .center)[0] === mid,
        "views(in:) should report the center-area view.")

    // equalCentering: centers equally spaced across the axis (slots of 100 →
    // centers 50/150/250 → origins 30/130/230 for 40-wide views).
    let centering = NSStackView(frame: NSMakeRect(0, 0, 300, 40))
    centering.orientation = .horizontal
    centering.distribution = .equalCentering
    let e1 = iv(40, 20), e2 = iv(40, 20), e3 = iv(40, 20)
    centering.addArrangedSubview(e1)
    centering.addArrangedSubview(e2)
    centering.addArrangedSubview(e3)
    centering.layoutSubtreeIfNeeded()
    expect(winClose(e1.frame.origin.x, 30) && winClose(e2.frame.origin.x, 130) && winClose(e3.frame.origin.x, 230),
        "equalCentering should space centers equally: got \(e1.frame.origin.x)/\(e2.frame.origin.x)/\(e3.frame.origin.x).")
}

@MainActor
func testStackViewBaselineAlignment() {
    // .lastBaseline in a horizontal stack hangs every view from the deepest
    // common baseline (offsets 0 → bottoms align at the tallest view's bottom).
    let stack = NSStackView(frame: NSMakeRect(0, 0, 200, 40))
    stack.orientation = .horizontal
    stack.alignment = .lastBaseline
    let short = IntrinsicSizeView(NSSize(width: 40, height: 20))
    let tall = IntrinsicSizeView(NSSize(width: 40, height: 30))
    stack.addArrangedSubview(short)
    stack.addArrangedSubview(tall)
    stack.layoutSubtreeIfNeeded()
    expect(winClose(short.frame.origin.y, 10) && winClose(tall.frame.origin.y, 0),
        "Baseline alignment should align bottoms at the common baseline: short=\(short.frame) tall=\(tall.frame).")
}

@MainActor
func testGridViewStretchesAndBaselineAlignsRows() {
    func iv(_ w: CGFloat, _ h: CGFloat) -> IntrinsicSizeView { IntrinsicSizeView(NSSize(width: w, height: h)) }

    // An over-sized grid distributes extra space to content-sized tracks.
    // Fitting size: cols 60+50+10 = 120, rows 20+24+8 = 52. Frame 160×72 →
    // +40 width (20 per column), +20 height (10 per row).
    let c00 = iv(30, 20), c01 = iv(50, 20)
    let c10 = iv(60, 24), c11 = iv(40, 16)
    let grid = NSGridView(views: [[c00, c01], [c10, c11]])
    grid.columnSpacing = 10
    grid.rowSpacing = 8
    grid.frame = NSMakeRect(0, 0, 160, 72)
    grid.layoutSubtreeIfNeeded()
    expect(winClose(c01.frame.origin.x, 90),
        "Stretched col0 (60+20) should push col1 to x=90: got \(c01.frame.origin.x).")
    expect(winClose(c00.frame.origin.y, 5),
        "Row stretched to 30 should center 20-tall content at y=5: got \(c00.frame.origin.y).")

    // Baseline row alignment: contents hang from the row's common baseline.
    let b0 = iv(40, 20), b1 = iv(40, 30)
    let baselineGrid = NSGridView(views: [[b0, b1]])
    baselineGrid.rowAlignment = .lastBaseline
    baselineGrid.layoutSubtreeIfNeeded()
    expect(winClose(b0.frame.origin.y, 10) && winClose(b1.frame.origin.y, 0),
        "Baseline row alignment should align bottoms (offsets 0): b0=\(b0.frame) b1=\(b1.frame).")
}

@MainActor
func testAutoresizingMaskMixesWithConstraintsThroughResize() {
    // 9.3 both directions: a mask-driven (translates == true) view resizes with
    // its container via autoresizing, and a constraint-driven sibling re-solves
    // against the new fixed frame.
    let container = NSView(frame: NSMakeRect(0, 0, 200, 100))
    let masked = NSView(frame: NSMakeRect(0, 0, 100, 20))
    masked.autoresizingMask = [.width]
    container.addSubview(masked)

    let solved = NSView(frame: .zero)
    solved.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(solved)
    NSLayoutConstraint.activate([
        solved.leadingAnchor.constraint(equalTo: masked.trailingAnchor),
        solved.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        solved.topAnchor.constraint(equalTo: container.topAnchor),
        solved.heightAnchor.constraint(equalToConstant: 20),
    ])
    container.layoutSubtreeIfNeeded()
    expect(winClose(solved.frame.origin.x, 100) && winClose(solved.frame.size.width, 100),
        "Solved view should fill from the masked view's edge: got \(solved.frame).")

    // Widen the container: the mask grows the fixed view, the solver re-fits
    // the constrained one against it.
    container.frame = NSMakeRect(0, 0, 300, 100)
    container.layoutSubtreeIfNeeded()
    expect(winClose(masked.frame.size.width, 200),
        "Autoresizing width should track the container (+100): got \(masked.frame.size.width).")
    expect(winClose(solved.frame.origin.x, 200) && winClose(solved.frame.size.width, 100),
        "Solved view should re-fit after the masked view grew: got \(solved.frame).")
}

@MainActor
func testStackViewCustomSpacingAndHiddenViews() {
    func iv(_ w: CGFloat, _ h: CGFloat) -> IntrinsicSizeView { IntrinsicSizeView(NSSize(width: w, height: h)) }
    let a = iv(40, 20), b = iv(40, 20), c = iv(40, 20)
    let stack = NSStackView(views: [a, b, c])
    stack.orientation = .horizontal
    stack.distribution = .fill
    stack.spacing = 8

    // A custom gap after `a` widens the first gap to 20; the rest stay 8.
    stack.setCustomSpacing(20, after: a)
    stack.frame = NSRect(origin: .zero, size: stack.intrinsicContentSize)
    stack.layoutSubtreeIfNeeded()
    expect(winClose(stack.intrinsicContentSize.width, 148),
        "Custom spacing should widen the intrinsic size to 148: got \(stack.intrinsicContentSize.width).")
    expect(winClose(b.frame.origin.x, 60) && winClose(c.frame.origin.x, 108),
        "Custom spacing after a should push b to 60 and c to 108: b=\(b.frame.origin.x) c=\(c.frame.origin.x).")

    // Hiding b drops it from layout (detachesHiddenViews); a→c gap is a's custom 20.
    b.isHidden = true
    stack.frame = NSRect(origin: .zero, size: stack.intrinsicContentSize)
    stack.layoutSubtreeIfNeeded()
    expect(winClose(stack.intrinsicContentSize.width, 100),
        "Hidden b should shrink the stack to 100: got \(stack.intrinsicContentSize.width).")
    expect(winClose(c.frame.origin.x, 60),
        "With b hidden, c should follow a's custom gap to x=60: got \(c.frame.origin.x).")
}

@MainActor
func testGridViewHiddenStructureAndSolver() {
    func iv(_ w: CGFloat, _ h: CGFloat) -> IntrinsicSizeView { IntrinsicSizeView(NSSize(width: w, height: h)) }

    // Hiding a column excludes it from sizing and layout.
    let a = iv(30, 20), b = iv(50, 20)
    let grid = NSGridView(views: [[a, b]])
    grid.columnSpacing = 10
    grid.column(at: 0).isHidden = true
    grid.layoutSubtreeIfNeeded()
    expect(winClose(grid.intrinsicContentSize.width, 50),
        "Hidden column should leave only col1's width (50): got \(grid.intrinsicContentSize.width).")
    expect(winClose(b.frame.origin.x, 0), "The visible column should start at x=0: got \(b.frame.origin.x).")

    // Structure mutation: adding rows/columns grows the grid.
    let empty = NSGridView(frame: .zero)
    _ = empty.addRow(with: [iv(20, 20), iv(20, 20)])
    _ = empty.addRow(with: [iv(20, 20), iv(20, 20)])
    expect(empty.numberOfRows == 2 && empty.numberOfColumns == 2,
        "addRow should build a 2×2 grid: got \(empty.numberOfRows)×\(empty.numberOfColumns).")
    _ = empty.addColumn(with: [iv(20, 20), iv(20, 20)])
    expect(empty.numberOfColumns == 3, "addColumn should widen to 3 columns: got \(empty.numberOfColumns).")

    // Composition: a grid pinned into a container is sized to its intrinsic
    // size by the solver, then arranges its cells.
    let container = NSView(frame: NSMakeRect(0, 0, 400, 300))
    let c11 = iv(40, 16)
    let composed = NSGridView(views: [[iv(30, 20), iv(50, 20)], [iv(60, 24), c11]])
    composed.columnSpacing = 10
    composed.rowSpacing = 8
    composed.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(composed)
    NSLayoutConstraint.activate([
        composed.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        composed.topAnchor.constraint(equalTo: container.topAnchor),
    ])
    container.layoutSubtreeIfNeeded()
    expect(winClose(composed.frame.size.width, 120) && winClose(composed.frame.size.height, 52),
        "Solver should size the grid to its intrinsic size: got \(composed.frame.size).")
    expect(winClose(c11.frame.origin.x, 70) && winClose(c11.frame.origin.y, 32),
        "Grid cell should be placed after the solver sizes the grid: got \(c11.frame).")
}

@MainActor
func testStackViewDistributionsAlignmentAndInsets() {
    func iv(_ w: CGFloat, _ h: CGFloat) -> IntrinsicSizeView { IntrinsicSizeView(NSSize(width: w, height: h)) }

    // A: horizontal .fill — views keep intrinsic size, leftover shared equally.
    let a = NSStackView(views: [iv(40, 20), iv(60, 20), iv(30, 20)])
    a.orientation = .horizontal
    a.distribution = .fill
    a.spacing = 10
    a.frame = NSMakeRect(0, 0, 300, 50)
    a.layoutSubtreeIfNeeded()
    // leftover = 300 - 20(spacing) - 130(intrinsic) = 150 → +50 each → [90,110,80].
    expect(winClose(a.arrangedSubviews[0].frame.origin.x, 0) && winClose(a.arrangedSubviews[0].frame.size.width, 90),
        "Fill v0 wrong: got \(a.arrangedSubviews[0].frame).")
    expect(winClose(a.arrangedSubviews[1].frame.origin.x, 100) && winClose(a.arrangedSubviews[1].frame.size.width, 110),
        "Fill v1 wrong: got \(a.arrangedSubviews[1].frame).")
    expect(winClose(a.arrangedSubviews[2].frame.origin.x, 220) && winClose(a.arrangedSubviews[2].frame.size.width, 80),
        "Fill v2 wrong: got \(a.arrangedSubviews[2].frame).")
    // Cross axis: default center — height 20 in 50 → y = 15.
    expect(winClose(a.arrangedSubviews[0].frame.origin.y, 15) && winClose(a.arrangedSubviews[0].frame.size.height, 20),
        "Fill cross-centering wrong: got \(a.arrangedSubviews[0].frame).")

    // B: horizontal .fillEqually — every view the same width.
    let b = NSStackView(views: [iv(40, 20), iv(60, 20), iv(30, 20)])
    b.distribution = .fillEqually
    b.spacing = 10
    b.frame = NSMakeRect(0, 0, 320, 40)
    b.layoutSubtreeIfNeeded()
    // each = (320 - 20) / 3 = 100.
    for (i, v) in b.arrangedSubviews.enumerated() {
        expect(winClose(v.frame.size.width, 100), "fillEqually v\(i) width should be 100: got \(v.frame.size.width).")
    }
    expect(winClose(b.arrangedSubviews[1].frame.origin.x, 110), "fillEqually v1 x should be 110: got \(b.arrangedSubviews[1].frame.origin.x).")

    // C: vertical .fill.
    let c = NSStackView(views: [iv(40, 30), iv(40, 50)])
    c.orientation = .vertical
    c.spacing = 8
    c.frame = NSMakeRect(0, 0, 60, 200)
    c.layoutSubtreeIfNeeded()
    // heights: leftover = 200 - 8 - 80 = 112 → +56 each → [86,106]; x centered = 10.
    expect(winClose(c.arrangedSubviews[0].frame.origin.y, 0) && winClose(c.arrangedSubviews[0].frame.size.height, 86)
        && winClose(c.arrangedSubviews[0].frame.origin.x, 10),
        "Vertical v0 wrong: got \(c.arrangedSubviews[0].frame).")
    expect(winClose(c.arrangedSubviews[1].frame.origin.y, 94) && winClose(c.arrangedSubviews[1].frame.size.height, 106),
        "Vertical v1 wrong: got \(c.arrangedSubviews[1].frame).")

    // D: horizontal .equalSpacing — intrinsic sizes, gaps grow to fill.
    let d = NSStackView(views: [iv(40, 20), iv(40, 20), iv(40, 20)])
    d.distribution = .equalSpacing
    d.spacing = 5
    d.frame = NSMakeRect(0, 0, 300, 40)
    d.layoutSubtreeIfNeeded()
    // free = 300 - 120 = 180; gap = 180/2 = 90 → x = 0, 130, 260.
    expect(winClose(d.arrangedSubviews[1].frame.origin.x, 130) && winClose(d.arrangedSubviews[2].frame.origin.x, 260),
        "equalSpacing positions wrong: got \(d.arrangedSubviews.map { $0.frame.origin.x }).")

    // E: cross-axis alignment leading vs trailing (horizontal → .top/.bottom).
    testStackCrossAxisAlignment()
    testStackIntrinsicContentSizeWithInsets()
}

@MainActor
func testStackCrossAxisAlignment() {
    let view = IntrinsicSizeView(NSSize(width: 40, height: 20))
    let stack = NSStackView(views: [view])
    stack.frame = NSMakeRect(0, 0, 100, 50)
    stack.alignment = .top
    stack.layoutSubtreeIfNeeded()
    expect(winClose(view.frame.origin.y, 0), "Top alignment should place at y=0: got \(view.frame.origin.y).")
    stack.alignment = .bottom
    stack.layoutSubtreeIfNeeded()
    expect(winClose(view.frame.origin.y, 30), "Bottom alignment should place at y=30: got \(view.frame.origin.y).")
}

@MainActor
func testStackIntrinsicContentSizeWithInsets() {
    func iv(_ width: CGFloat, _ height: CGFloat) -> IntrinsicSizeView {
        IntrinsicSizeView(NSSize(width: width, height: height))
    }

    // intrinsicContentSize from arranged content + spacing + insets.
    let f = NSStackView(views: [iv(40, 20), iv(60, 30)])
    f.spacing = 10
    f.edgeInsets = NSEdgeInsets(top: 5, left: 8, bottom: 5, right: 8)
    let size = f.intrinsicContentSize
    // width = 40+60+10 + 16 = 126; height = max(20,30) + 10 = 40.
    expect(winClose(size.width, 126) && winClose(size.height, 40),
        "Stack intrinsic size wrong: got \(size).")
}

@MainActor
func testStackViewComposesWithSolverAndResizes() {
    // A stack pinned to all edges of a container: the solver sizes the stack,
    // then the stack arranges its views — and both track a container resize.
    let container = NSView(frame: NSMakeRect(0, 0, 300, 50))
    let stack = NSStackView(views: [IntrinsicSizeView(NSSize(width: 20, height: 20)),
                                    IntrinsicSizeView(NSSize(width: 20, height: 20)),
                                    IntrinsicSizeView(NSSize(width: 20, height: 20))])
    stack.distribution = .fillEqually
    stack.spacing = 0
    stack.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(stack)
    NSLayoutConstraint.activate([
        stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        stack.topAnchor.constraint(equalTo: container.topAnchor),
        stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
    container.layoutSubtreeIfNeeded()
    expect(winClose(stack.frame.size.width, 300), "Stack should fill the container: got \(stack.frame.size.width).")
    expect(winClose(stack.arrangedSubviews[0].frame.size.width, 100),
        "fillEqually in a 300 stack should give 100 each: got \(stack.arrangedSubviews[0].frame.size.width).")

    // Resize the container — the stack refills and its views re-split.
    container.frame = NSMakeRect(0, 0, 600, 50)
    container.layoutSubtreeIfNeeded()
    expect(winClose(stack.frame.size.width, 600), "Stack should track the resized container: got \(stack.frame.size.width).")
    expect(winClose(stack.arrangedSubviews[2].frame.origin.x, 400)
        && winClose(stack.arrangedSubviews[2].frame.size.width, 200),
        "fillEqually should re-split to 200 each on resize: got \(stack.arrangedSubviews[2].frame).")
}

