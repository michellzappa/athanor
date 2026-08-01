import CoreGraphics
import Foundation

enum FigureCollection: String, CaseIterable {
    case core
    case solids
    case tilings
    case curves

    var title: String {
        switch self {
        case .core: return "Core Figures"
        case .solids: return "Solids & Projections"
        case .tilings: return "Tilings & Lattices"
        case .curves: return "Curve Machines"
        }
    }
}

/// One entry in the catalog. Adding a figure means writing a builder and putting
/// its `kind` in `FigureCatalog.all` — every platform's options UI is generated
/// from this list, so nothing else needs touching.
struct FigureKind {
    let id: String
    let title: String
    let collection: FigureCollection
    let build: (inout SeededRandom) -> Drawing
}

enum FigureCatalog {
    static let all: [FigureKind] = [
        FlowerOfLife.kind,
        MetatronsCube.kind,
        VesicaConstruction.kind,
        StarPolygon.kind,
        Yantra.kind,
        TreeOfLife.kind,
        GoldenRectangle.kind,
        Phyllotaxis.kind,
    ]

    static var allIDs: Set<String> { Set(all.map(\.id)) }

    static func kind(id: String) -> FigureKind? { all.first { $0.id == id } }

    static var byCollection: [(collection: FigureCollection, kinds: [FigureKind])] {
        FigureCollection.allCases.compactMap { collection in
            let kinds = all.filter { $0.collection == collection }
            return kinds.isEmpty ? nil : (collection, kinds)
        }
    }

    /// Never returns an empty list: an empty selection means "all of them".
    static func enabled(ids: Set<String>) -> [FigureKind] {
        let picked = all.filter { ids.contains($0.id) }
        return picked.isEmpty ? all : picked
    }
}
