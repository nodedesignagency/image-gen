import SwiftUI

/// Community feed: a two-column masonry of everyone's decodes. Tiles decode
/// themselves in the first time they show up.
struct ExploreView: View {
    @Environment(Studio.self) private var studio
    @Namespace private var zoom
    @State private var filter: FeedFilter = .trending

    var body: some View {
        @Bindable var studio = studio
        let items = filter.apply(to: studio.feed)
        let left = items.enumerated().filter { $0.offset.isMultiple(of: 2) }.map(\.element)
        let right = items.enumerated().filter { !$0.offset.isMultiple(of: 2) }.map(\.element)

        NavigationStack(path: $studio.explorePath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FilterBar(selection: $filter)

                    HStack(alignment: .top, spacing: 10) {
                        column(left, offset: 0)
                        column(right, offset: 1)
                    }
                    .padding(.horizontal, 16)
                    .id(filter)
                    .transition(.opacity)
                }
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Theme.canvas.ignoresSafeArea())
            .edgeBar(.top) {
                TopBar("Explore") {
                    CircleIcon(systemImage: "magnifyingglass")
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ShotRoute.self) { route in
                ShotDetailView(route: route)
                    .navigationTransition(.zoom(sourceID: route.id, in: zoom))
            }
            .animation(.smooth(duration: 0.3), value: filter)
        }
    }

    private func column(_ items: [FeedItem], offset: Int) -> some View {
        LazyVStack(spacing: 16) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                NavigationLink(value: item.route) {
                    FeedCard(item: item, delay: min(Double(index * 2 + offset) * 0.12, 0.9), zoom: zoom)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}

private struct FilterBar: View {
    @Binding var selection: FeedFilter

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(FeedFilter.allCases) { filter in
                    let isOn = filter == selection
                    Button {
                        selection = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(isOn ? Color.white : Theme.ink)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(isOn ? Theme.ink : Theme.card, in: Capsule())
                            .overlay { Capsule().strokeBorder(isOn ? Color.clear : Theme.hairline, lineWidth: 1) }
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }
}

private struct FeedCard: View {
    let item: FeedItem
    let delay: Double
    let zoom: Namespace.ID

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        VStack(alignment: .leading, spacing: 8) {
            Color.clear
                .aspectRatio(item.ratio.value, contentMode: .fit)
                .overlay {
                    RevealImage(key: "feed-\(item.id)", imageName: item.imageName, delay: delay, seed: item.seed)
                }
                .clipShape(shape)
                .contentShape(shape)
                .matchedTransitionSource(id: item.id, in: zoom)

            HStack(spacing: 6) {
                Avatar(name: item.author, size: 18)
                Text(verbatim: item.author)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.ink.opacity(0.75))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "heart")
                    .font(.system(size: 11, weight: .semibold))
                Text(verbatim: item.likes.compact)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, 2)
        }
    }
}
