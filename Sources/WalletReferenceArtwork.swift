import SwiftUI

/// Displays a bounded decorative-art viewport of an unchanged public reference.
/// Source rectangles and original-byte provenance are recorded in
/// References/Wallets/viewport-artwork-sources.json.
struct WalletReferenceArtwork: View {
    let source: String
    let viewport: CGRect
    var sourceSize = CGSize(width: 1242, height: 2208)
    var body: some View {
        GeometryReader { proxy in
            let scale = max(proxy.size.width / viewport.width, proxy.size.height / viewport.height)
            Image(source)
                .resizable()
                .frame(width: sourceSize.width * scale, height: sourceSize.height * scale)
                .offset(x: -viewport.minX * scale, y: -viewport.minY * scale)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                .clipped()
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct WalletReferencePhantomAvatar: View {
    var body: some View {
        WalletReferenceArtwork(source: "WalletReference-PhantomHome", viewport: CGRect(x: 208, y: 603, width: 97, height: 97)).clipShape(Circle())
    }
}
struct WalletReferenceTrustRewards: View {
    var body: some View {
        WalletReferenceArtwork(source: "WalletReference-TrustHome", viewport: CGRect(x: 196, y: 1725, width: 146, height: 157))
    }
}
struct WalletReferenceTrustNFT: View {
    let lagoon: Bool
    var body: some View {
        WalletReferenceArtwork(source: "WalletReference-TrustHome", viewport: CGRect(x: lagoon ? 638 : 150, y: 2082, width: 453, height: 126))
    }
}
struct WalletReferencePancakeSwap: View {
    var body: some View {
        WalletReferenceArtwork(source: "WalletReference-TrustConnection", viewport: CGRect(x: 571, y: 1441, width: 101, height: 102)).clipShape(Circle())
    }
}
struct WalletReferenceTrustRisk: View {
    var body: some View {
        WalletReferenceArtwork(source: "WalletReference-TrustRisk", viewport: CGRect(x: 455, y: 1358, width: 332, height: 332))
    }
}

struct WalletReferenceMetaMaskCard: View {
    var body: some View {
        WalletReferenceArtwork(source: "WalletReference-MetaMaskCard", viewport: CGRect(x: 258, y: 984, width: 724, height: 459), sourceSize: CGSize(width: 1240, height: 2688))
            .aspectRatio(724.0 / 459.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct WalletReferenceBinanceP2P: View {
    var body: some View {
        WalletReferenceArtwork(source: "WalletReference-TrustBuy", viewport: CGRect(x: 188, y: 1698, width: 61, height: 61)).clipShape(Circle())
    }
}
