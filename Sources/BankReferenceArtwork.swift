import SwiftUI

/// Only decorative photo fragments are shown from these unchanged listing files.
/// References/Banks/viewport-artwork-sources.json records exact source rectangles,
/// original-byte hashes, dimensions, URLs and the reference limits.
struct BankReferenceArtwork: View {
    let source: String
    let viewport: CGRect
    var sourceSize = CGSize(width: 392, height: 696)
    var body: some View {
        GeometryReader { proxy in
            let scale = max(proxy.size.width / viewport.width, proxy.size.height / viewport.height)
            Image(source)
                .resizable()
                .frame(width: sourceSize.width * scale, height: sourceSize.height * scale)
                .offset(x: -viewport.minX * scale, y: -viewport.minY * scale)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                .clipped()
        }.clipped().allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct BankReferenceGroceries: View {
    var body: some View { BankReferenceArtwork(source: "BankReference-StarlingSpaces", viewport: CGRect(x: 31, y: 470, width: 114, height: 112)) }
}
struct BankReferenceCottage: View {
    var hero = false
    var body: some View {
        if hero { BankReferenceArtwork(source: "BankReference-StarlingSpaceHero", viewport: CGRect(x: 86, y: 234, width: 266, height: 99)) }
        else { BankReferenceArtwork(source: "BankReference-StarlingSpaces", viewport: CGRect(x: 54, y: 593, width: 98, height: 98)) }
    }
}
struct BankReferenceHoliday: View {
    var body: some View { BankReferenceArtwork(source: "BankReference-MonzoSavings", viewport: CGRect(x: 154, y: 215, width: 84, height: 66)) }
}
enum BankReferenceRevolutPhoto: String, CaseIterable {
    case savings, joint, salary
    var title: String { switch self { case .savings: return "House deposit"; case .joint: return "Joint · GBP"; case .salary: return "Salary" } }
    var asset: String { switch self { case .savings: return "BankReference-RevolutSavings"; case .joint: return "BankReference-RevolutJoint"; case .salary: return "BankReference-RevolutSalary" } }
    var viewport: CGRect { CGRect(x: 30, y: 113, width: 162, height: self == .salary ? 72 : self == .joint ? 60 : 60) }
}
struct BankReferenceRevolutArtwork: View {
    let photo: BankReferenceRevolutPhoto
    var body: some View { BankReferenceArtwork(source: photo.asset, viewport: photo.viewport, sourceSize: CGSize(width: 222, height: 480)) }
}
