import SwiftUI

struct SearchView: View {
    @State private var keyword = ""
    @State private var currentStore: FeedStore?

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                searchBar

                if let store = currentStore {
                    FeedList(store: store)
                } else {
                    GlassCard {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("输入关键词搜索微博")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal, Theme.pagePadding)
                    Spacer()
                }
            }
            .background(AppBackground())
            .navigationTitle("搜索")
            .navigationDestination(for: String.self) { mid in
                StatusDetailView(mid: mid)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("搜索微博内容 / 用户", text: $keyword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit(performSearch)

            if !keyword.isEmpty {
                Button {
                    keyword = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassCapsule()
        .padding(.horizontal, Theme.pagePadding)
    }

    private func performSearch() {
        let query = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        let store = FeedStore(source: .search(keyword: query))
        currentStore = store
        Task { await store.reload() }
    }
}

/// 搜索结果页（热搜点击 / 搜索跳转用）
struct SearchResultView: View {
    let keyword: String

    @StateObject private var store: FeedStore

    init(keyword: String) {
        self.keyword = keyword
        _store = StateObject(wrappedValue: FeedStore(source: .search(keyword: keyword)))
    }

    var body: some View {
        FeedList(store: store)
            .navigationTitle(keyword)
            .navigationBarTitleDisplayMode(.inline)
    }
}
