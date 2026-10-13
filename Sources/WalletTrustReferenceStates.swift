import SwiftUI

/// Local connection choices use the composition visible in trustWallet-7.jpg.
struct WalletTrustConnectionsSheet: View {
    let walletName: String
    let address: String
    @Environment(\.dismiss) private var dismiss
    @State private var connections: [String] = []
    @State private var requested = false
    var body: some View {
        NavigationStack {
            List {
                if connections.isEmpty {
                    ContentUnavailableView("No connections", systemImage: "link", description: Text("Connected apps appear here."))
                }
                ForEach(connections, id: \.self) { connection in
                    HStack {
                        WalletReferencePancakeSwap().frame(width: 38, height: 38)
                        Text(connection)
                        Spacer()
                        Button("Disconnect") { connections.removeAll { $0 == connection } }
                            .font(.caption).accessibilityIdentifier("wallet-disconnect-pancakeswap")
                    }
                }
                Button { requested = true } label: {
                    Label("Connect app", systemImage: "plus").frame(minHeight: 44)
                }.accessibilityIdentifier("wallet-connect-app")
            }
            .navigationTitle("Connections").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $requested) {
                WalletTrustConnectionRequest(walletName: walletName, address: address) {
                    if !connections.contains("PancakeSwap") { connections.append("PancakeSwap") }
                    requested = false
                }
            }
        }.preferredColorScheme(.light).tint(.blue)
    }
}

private struct WalletTrustConnectionRequest: View {
    let walletName: String
    let address: String
    let onConnect: () -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer().frame(width: 44)
                Spacer()
                Text("Connect dApp").font(.system(size: 18, weight: .semibold))
                Spacer()
                Image(systemName: "info.circle.fill").font(.system(size: 20)).foregroundStyle(.gray).frame(width: 44, height: 44)
            }.padding(.horizontal, 16).padding(.top, 12)
            ScrollView {
                VStack(spacing: 18) {
                    WalletReferencePancakeSwap().frame(width: 48, height: 48).padding(.top, 35)
                    Text("Home wants to connect to your wallet")
                        .font(.system(size: 24, weight: .medium)).multilineTextAlignment(.center)
                    Text("pancakeswap.finance").font(.system(size: 15)).foregroundStyle(.gray)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("ETHEREUM").font(.system(size: 13, weight: .medium)).foregroundStyle(.gray)
                        HStack(spacing: 12) {
                            Image("WalletFidelity-Ethereum").resizable().scaledToFit().frame(width: 35, height: 35)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(walletName).font(.system(size: 17, weight: .semibold))
                                Text(String(address.prefix(7)) + "…" + String(address.suffix(6)))
                                    .font(.system(size: 14)).foregroundStyle(.gray)
                            }
                            Spacer()
                        }.padding(18).background(Color(white: 0.975), in: RoundedRectangle(cornerRadius: 13))
                        Label("View your wallet balance and activity.", systemImage: "wallet.bifold.fill")
                            .font(.system(size: 14)).foregroundStyle(.gray).padding(.top, 10)
                        Label("Request approval for transactions.", systemImage: "checkmark.shield.fill")
                            .font(.system(size: 14)).foregroundStyle(.gray)
                    }.padding(.top, 35)
                }.padding(.horizontal, 20).padding(.bottom, 25)
            }
            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .frame(maxWidth: .infinity, minHeight: 49).background(Color(white: 0.96), in: RoundedRectangle(cornerRadius: 12))
                Button("Connect", action: onConnect)
                    .foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 49).background(Color.blue, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("wallet-confirm-connection")
            }.font(.system(size: 16, weight: .semibold)).buttonStyle(.plain).padding(20)
        }.background(.white).preferredColorScheme(.light)
    }
}

/// These APR values are the saved listing's visible snapshot, not live rates.
struct WalletTrustStakingSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let rates: [(String, String, Int)] = [("EVMOS", "36.00", 0), ("STARS", "27.84", 1), ("ATOM", "18.85", 2), ("KAVA", "16.41", 3), ("DOT", "15.12", 4), ("LUNA", "15.00", 5), ("KSM", "14.73", 6)]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text("Native Staking").font(.system(size: 22, weight: .semibold))
                        Image(systemName: "questionmark.circle.fill").font(.system(size: 16)).foregroundStyle(.gray)
                    }.padding(.bottom, 12)
                    ForEach(rates, id: \.0) { token in
                        HStack(spacing: 13) {
                            WalletReferenceArtwork(source: "WalletReference-TrustStaking", viewport: CGRect(x: 149, y: CGFloat(1250 + token.2 * 137), width: 76, height: 76))
                                .frame(width: 35, height: 35).clipShape(Circle())
                            Text(token.0).font(.system(size: 17, weight: .medium))
                            Spacer()
                            Text(token.1 + "% APR").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color(red: 0.20, green: 0.73, blue: 0.56))
                        }.frame(minHeight: 55)
                    }
                }.padding(20)
            }.background(.white).navigationTitle("Earn").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { Image(systemName: "arrow.left").foregroundStyle(.gray) }.accessibilityLabel("Back") } }
        }.preferredColorScheme(.light)
    }
}

struct WalletTrustRiskSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer().frame(width: 40)
                Spacer()
                Text("Critical Risk Alert").font(.system(size: 18, weight: .semibold))
                Spacer()
                Image(systemName: "info.circle.fill").foregroundStyle(.gray).font(.system(size: 20)).frame(width: 40, height: 44)
            }.padding(.top, 12).padding(.horizontal, 15)
            ScrollView {
                VStack(spacing: 25) {
                    WalletReferenceTrustRisk().frame(width: 145, height: 145).padding(.top, 24)
                    Text("This address is unsafe as identified by Binance")
                        .font(.system(size: 23, weight: .medium)).multilineTextAlignment(.center)
                    Label("0x9817196e2078917721398922c", systemImage: "exclamationmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(red: 0.82, green: 0.28, blue: 0.39))
                        .lineLimit(1).minimumScaleFactor(0.7)
                    VStack(alignment: .leading, spacing: 13) {
                        Text("•  The address is associated with a known scammer.")
                        Text("•  The address is deemed risky after manual examination.")
                    }.font(.system(size: 15)).foregroundStyle(Color(red: 0.70, green: 0.33, blue: 0.42))
                        .padding(19).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 1, green: 0.96, blue: 0.97), in: RoundedRectangle(cornerRadius: 13))
                }.padding(20)
            }
            Button("Back to wallet") { dismiss() }.font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 49).background(Color.blue, in: RoundedRectangle(cornerRadius: 12))
                .padding(20).accessibilityIdentifier("wallet-dismiss-risk")
        }.background(.white).preferredColorScheme(.light)
    }
}
