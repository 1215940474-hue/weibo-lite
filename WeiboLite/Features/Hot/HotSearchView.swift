import Combine
import Foundation
import SwiftUI

@MainActor
final class HotSearchStore: ObservableObject {
    @Published private(set) var items: [HotSearchItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    func load() async {
        if ScreenshotMode.isEnabled {
            items = ScreenshotFixtures.hotItems
            errorMessage = nil
            return
        }
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard let url = WeiboEndpoint.container(id: WeiboEndpoint.hotSearchContainer) else {
                throw WeiboAPIError.badURL
            }
            let response: ContainerResponse = try await WeiboAPI.shared.get(url)
            guard response.ok == 1, let data = response.data else {
                throw WeiboAPIError.empty
            }
            let items = data.hotItems
            guard !items.isEmpty else { throw WeiboAPIError.empty }
            self.items = items
        } catch {
            if let apiError = error as? WeiboAPIError {
                errorMessage = apiError.errorDescription
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct HotSearchView: View {
    @StateObject private var store = HotSearchStore()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if store.isLoading, store.items.isEmpty {
                    ProgressView().padding(.top, 30)
                }

                if let message = store.errorMessage, store.items.isEmpty {
                    ErrorStateView(message: message) {
                        Task { await store.load() }
                    }
                }

                ForEach(store.items) { item in
                    NavigationLink(value: SearchRoute(keyword: item.title)) {
                        HotRow(item: item)
                    }
                    .buttonStyle(.plain)
                }

                if let message = store.errorMessage, !store.items.isEmpty {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }

                if !store.items.isEmpty {
                    Text("数据来源：微博热搜榜　·　点击可查看相关微博")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("热搜")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.load() }
        .task {
            if store.items.isEmpty { await store.load() }
        }
    }

}

private struct HotRow: View {
    let item: HotSearchItem

    var body: some View {
        HStack(spacing: 12) {
            Text("\(item.rank)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(rankColor)
                .frame(width: 26, alignment: .center)

            Text(item.title)
                .font(.system(size: 15))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !item.heat.isEmpty {
                Text(heatText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassSurface(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var rankColor: Color {
        switch item.rank {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        default: return .secondary
        }
    }

    /// 热度：接口给的是字符串数字，转成「12.3万」这种更好读
    private var heatText: String {
        guard let value = Double(item.heat), value > 0 else { return item.heat }
        if value >= 10_000 {
            return String(format: "%.1f万", value / 10_000)
        }
        return String(Int(value))
    }
}
