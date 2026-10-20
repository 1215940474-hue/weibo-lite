import SwiftUI

extension Notification.Name {
    /// 再次点击「首页」标签时发出，用来刷新信息流
    static let homeRefreshRequested = Notification.Name("weibolite.homeRefresh")
}

struct MainTabView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case home = "首页"
        case hot = "热搜"
        case search = "搜索"
        case me = "我"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .hot: return "flame.fill"
            case .search: return "magnifyingglass"
            case .me: return "person.crop.circle.fill"
            }
        }
    }

    @State private var selection: Tab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selection {
                case .home:
                    FeedView()
                case .hot:
                    HotTabView()
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

    /// 悬浮玻璃导航栏：内容从下面滚过，玻璃才有折射感
    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(Tab.allCases) { tab in
                Button {
                    if selection == tab {
                        if tab == .home {
                            NotificationCenter.default.post(name: .homeRefreshRequested, object: nil)
                        }
                    } else {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 17, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(selection == tab ? Color.accentColor : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .glassSurface(Capsule(style: .continuous))
        .padding(.horizontal, 26)
        .padding(.bottom, 4)
    }
}
