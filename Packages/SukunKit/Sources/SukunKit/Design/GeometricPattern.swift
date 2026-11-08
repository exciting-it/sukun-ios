#if canImport(SwiftUI)
import SwiftUI

/// A tiling of eight-pointed stars (khatam) — two overlapping squares per tile, connected by thin lines.
/// Meant to be stroked at very low opacity as a texture.
public struct GeometricPattern: Shape {
    public var tile: CGFloat

    public init(tile: CGFloat = 56) {
        self.tile = tile
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let half = tile / 2
        let r = tile * 0.32
        let columns = Int(ceil(rect.width / tile)) + 1
        let rows = Int(ceil(rect.height / tile)) + 1

        for row in 0..<rows {
            for column in 0..<columns {
                let center = CGPoint(x: rect.minX + CGFloat(column) * tile, y: rect.minY + CGFloat(row) * tile)
                addStar(to: &path, center: center, radius: r)
                // Connectors between neighbouring stars form the lattice.
                path.move(to: CGPoint(x: center.x + r, y: center.y))
                path.addLine(to: CGPoint(x: center.x + half, y: center.y))
                path.move(to: CGPoint(x: center.x, y: center.y + r))
                path.addLine(to: CGPoint(x: center.x, y: center.y + half))
            }
        }
        return path
    }

    private func addStar(to path: inout Path, center: CGPoint, radius: CGFloat) {
        for offset in [0.0, Double.pi / 4] {
            let points = (0..<4).map { i -> CGPoint in
                let angle = offset + Double(i) * .pi / 2
                return CGPoint(x: center.x + radius * CGFloat(cos(angle)), y: center.y + radius * CGFloat(sin(angle)))
            }
            path.addLines(points)
            path.closeSubpath()
        }
    }
}
#endif
