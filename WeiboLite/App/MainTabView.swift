import SwiftUI

extension Notification.Name {
    /// 再次点击「首页」标签时发出，用来刷新信息流
    static let homeRefreshRequested = Notification.Name("weibolite.homeRefresh")
}

struct MainTabView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case home = "首页"
        case search = "搜索"
        case me = "我"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .search: return "magnifyingglass"
            case .me: return "person.crop.circle.fill"
            }
        }
    }

    @State private var selection: Tab = .home

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selection {
                case .home:
                    FeedView()
                case .search:
                    SearchView()
                case .me:
                    MeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            tabBar
        }
        .background(AppBackground())
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                Button {
                    if selection == tab {
                        // 重复点击首页 = 刷新信息流
                        if tab == .home {
                            NotificationCenter.default.post(name: .homeRefreshRequested, object: nil)
                        }
                    } else {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.caption2)
                    }
                    .foregroundStyle(selection == tab ? Color.accentColor : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .glassSurface(Capsule(style: .continuous))
        .padding(.horizontal, 44)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }
}
