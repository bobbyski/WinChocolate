extension NSStackView {
    struct StackGeometry {
        let horizontal: Bool
        let mainStart: CGFloat
        let availableMain: CGFloat
        let crossStart: CGFloat
        let availableCross: CGFloat
    }

    struct StackMainLayout {
        let sizes: [CGFloat]
        let gaps: [CGFloat]
        let positions: [CGFloat]?
    }

    struct StackCrossLayout {
        let alignment: CrossAlignment
        let baseline: CGFloat
    }

    func winArrangeSubviews() {
        let views = layoutArrangedViews
        guard !views.isEmpty else { return }
        let geometry = stackGeometry()
        let mainLayout = stackMainLayout(for: views, geometry: geometry)
        let alignment = crossAlignment()
        let crossLayout = StackCrossLayout(
            alignment: alignment,
            baseline: alignment == .baseline
                ? commonBaseline(for: views, availableCross: geometry.availableCross)
                : 0
        )
        placeStackViews(views, geometry: geometry, mainLayout: mainLayout, crossLayout: crossLayout)
    }

    func stackGeometry() -> StackGeometry {
        let horizontal = orientation == .horizontal
        let mainStart = horizontal ? edgeInsets.left : edgeInsets.top
        let mainInset = horizontal
            ? edgeInsets.left + edgeInsets.right
            : edgeInsets.top + edgeInsets.bottom
        let crossStart = horizontal ? edgeInsets.top : edgeInsets.left
        let crossInset = horizontal
            ? edgeInsets.top + edgeInsets.bottom
            : edgeInsets.left + edgeInsets.right
        return StackGeometry(
            horizontal: horizontal,
            mainStart: mainStart,
            availableMain: max((horizontal ? bounds.size.width : bounds.size.height) - mainInset, 0),
            crossStart: crossStart,
            availableCross: max((horizontal ? bounds.size.height : bounds.size.width) - crossInset, 0)
        )
    }

    func stackMainLayout(for views: [NSView], geometry: StackGeometry) -> StackMainLayout {
        let intrinsicSizes = views.map {
            geometry.horizontal ? arrangedSize($0).width : arrangedSize($0).height
        }
        var gaps = views.indices.map { gapAfter(views, $0) }
        var sizes = distributedStackSizes(
            intrinsicSizes,
            gaps: &gaps,
            availableMain: geometry.availableMain
        )
        if distribution == .gravityAreas, !gravities.isEmpty {
            sizes = intrinsicSizes
        }
        let positions = explicitStackPositions(
            views: views,
            sizes: sizes,
            geometry: geometry
        )
        return StackMainLayout(sizes: sizes, gaps: gaps, positions: positions)
    }

    func distributedStackSizes(
        _ intrinsicSizes: [CGFloat],
        gaps: inout [CGFloat],
        availableMain: CGFloat
    ) -> [CGFloat] {
        let count = intrinsicSizes.count
        let totalSpacing = gaps.reduce(0, +)
        switch distribution {
        case .fillEqually:
            let each = max((availableMain - totalSpacing) / CGFloat(count), 0)
            return Array(repeating: each, count: count)
        case .fillProportionally:
            return proportionalStackSizes(intrinsicSizes, totalSpacing: totalSpacing, availableMain: availableMain)
        case .fill, .gravityAreas:
            let leftover = availableMain - totalSpacing - intrinsicSizes.reduce(0, +)
            let share = leftover / CGFloat(count)
            return intrinsicSizes.map { max($0 + share, 0) }
        case .equalSpacing:
            let freeSpace = availableMain - intrinsicSizes.reduce(0, +)
            if count > 1 {
                let uniform = max(spacing, freeSpace / CGFloat(count - 1))
                gaps = (0..<count).map { $0 < count - 1 ? uniform : 0 }
            }
            return intrinsicSizes
        case .equalCentering:
            return intrinsicSizes
        }
    }

    func proportionalStackSizes(
        _ intrinsicSizes: [CGFloat], totalSpacing: CGFloat, availableMain: CGFloat
    ) -> [CGFloat] {
        let sum = intrinsicSizes.reduce(0, +)
        guard sum > 0 else {
            let each = max((availableMain - totalSpacing) / CGFloat(intrinsicSizes.count), 0)
            return Array(repeating: each, count: intrinsicSizes.count)
        }
        let scale = max(availableMain - totalSpacing, 0) / sum
        return intrinsicSizes.map { $0 * scale }
    }

    func explicitStackPositions(
        views: [NSView], sizes: [CGFloat], geometry: StackGeometry
    ) -> [CGFloat]? {
        if distribution == .equalCentering {
            let slot = geometry.availableMain / CGFloat(views.count)
            return views.indices.map {
                geometry.mainStart + slot * (CGFloat($0) + 0.5) - sizes[$0] / 2
            }
        }
        guard distribution == .gravityAreas, !gravities.isEmpty else { return nil }
        return gravityStackPositions(views: views, sizes: sizes, geometry: geometry)
    }

    func gravityStackPositions(
        views: [NSView], sizes: [CGFloat], geometry: StackGeometry
    ) -> [CGFloat] {
        var positions = [CGFloat](repeating: geometry.mainStart, count: views.count)
        let leading = views.indices.filter { gravity(for: views[$0]) == .leading }
        let center = views.indices.filter { gravity(for: views[$0]) == .center }
        let trailing = views.indices.filter { gravity(for: views[$0]) == .trailing }
        packStackGroup(leading, from: geometry.mainStart, sizes: sizes, positions: &positions)
        let trailingTotal = stackGroupLength(trailing, sizes: sizes)
        packStackGroup(
            trailing,
            from: geometry.mainStart + geometry.availableMain - trailingTotal,
            sizes: sizes,
            positions: &positions
        )
        let centerTotal = stackGroupLength(center, sizes: sizes)
        packStackGroup(
            center,
            from: geometry.mainStart + (geometry.availableMain - centerTotal) / 2,
            sizes: sizes,
            positions: &positions
        )
        return positions
    }

    func packStackGroup(
        _ indexes: [Int], from start: CGFloat, sizes: [CGFloat], positions: inout [CGFloat]
    ) {
        var cursor = start
        for index in indexes {
            positions[index] = cursor
            cursor += sizes[index] + spacing
        }
    }

    func stackGroupLength(_ indexes: [Int], sizes: [CGFloat]) -> CGFloat {
        indexes.reduce(0) { $0 + sizes[$1] } + spacing * CGFloat(max(indexes.count - 1, 0))
    }

    func placeStackViews(
        _ views: [NSView],
        geometry: StackGeometry,
        mainLayout: StackMainLayout,
        crossLayout: StackCrossLayout
    ) {
        var cursor = geometry.mainStart
        for (index, view) in views.enumerated() {
            let cross = stackCrossPlacement(for: view, geometry: geometry, layout: crossLayout)
            let mainPosition = mainLayout.positions?[index] ?? cursor
            view.frame = geometry.horizontal
                ? NSRect(x: mainPosition, y: cross.position, width: mainLayout.sizes[index], height: cross.length)
                : NSRect(x: cross.position, y: mainPosition, width: cross.length, height: mainLayout.sizes[index])
            cursor += mainLayout.sizes[index] + mainLayout.gaps[index]
        }
    }

    func stackCrossPlacement(
        for view: NSView, geometry: StackGeometry, layout: StackCrossLayout
    ) -> (length: CGFloat, position: CGFloat) {
        guard hasIntrinsicCross(view) else {
            return (geometry.availableCross, geometry.crossStart)
        }
        let intrinsicLength = geometry.horizontal ? arrangedSize(view).height : arrangedSize(view).width
        let length = min(intrinsicLength, geometry.availableCross)
        let position: CGFloat
        switch layout.alignment {
        case .leading:
            position = geometry.crossStart
        case .center:
            position = geometry.crossStart + (geometry.availableCross - length) / 2
        case .trailing:
            position = geometry.crossStart + geometry.availableCross - length
        case .baseline:
            position = geometry.crossStart + layout.baseline - (length - view.baselineOffsetFromBottom)
        }
        return (length, position)
    }
}
