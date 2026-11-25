import Foundation

struct BrewTapInfo: Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let official: Bool
    let path: String?
    let formulaCount: Int
    let caskCount: Int
}
