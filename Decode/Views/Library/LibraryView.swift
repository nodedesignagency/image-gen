import SwiftUI

/// Everything you've generated, grouped by day, with a favourites filter.
struct LibraryView: View {
    @Environment(Studio.self) private var studio
    @Namespace private var zoom
    @State private var favoritesOnly = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    var body: some View {
        @Bindable var studio = studio
        let sections = studio.librarySections(favoritesOnly: favoritesOnly)

        NavigationStack(path: $studio.libraryPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    LibraryStats(boards: studio.generatedBoards.count, images: studio.imageCount, favorites: studio.favorites.count)

                    SegmentToggle(favoritesOnly: $favoritesOnly)

                    if sections.isEmpty {
                        EmptyLibrary(favoritesOnly: favoritesOnly)
                    }

                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(section.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                                .padding(.horizontal, 4)

                            LazyVGrid(columns: columns, spacing: 4) {
                                ForEach(section.entries) { entry in
                                    NavigationLink(value: entry.route) {
                                        LibraryTile(entry: entry, isFavorite: studio.isFavorite(entry.route.imageName), zoom: zoom)
                                    }
                                    .buttonStyle(PressableStyle())
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .animation(.smooth(duration: 0.3), value: favoritesOnly)
            }
            .scrollIndicators(.hidden)
            .background(Theme.canvas.ignoresSafeArea())
            .edgeBar(.top) {
                TopBar("Library") {
                    Button {
                        studio.select(.create)
                    } label: {
                        CircleIcon(systemImage: "plus")
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("New generation")
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ShotRoute.self) { route in
                ShotDetailView(route: route)
                    .navigationTransition(.zoom(sourceID: route.id, in: zoom))
            }
        }
    }
}

private struct LibraryStats: View {
    let boards: Int
    let images: Int
    let favorites: Int

    var body: some View {
        HStack(spacing: 0) {
            stat("\(boards)", "generations")
            Divider().frame(height: 28)
            stat("\(images)", "images")
            Divider().frame(height: 28)
            stat("\(favorites)", "favourites")
        }
        .padding(.vertical, 14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .cardShadow()
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: value)
                .font(.system(size: 19, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SegmentToggle: View {
    @Binding var favoritesOnly: Bool
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 0) {
            segment("All", isOn: !favoritesOnly) { favoritesOnly = false }
            segment("Favourites", isOn: favoritesOnly) { favoritesOnly = true }
        }
        .padding(3)
        .background(Theme.ink.opacity(0.06), in: Capsule())
    }

    private func segment(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(duration: 0.35, bounce: 0.2)) { action() }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isOn ? Theme.ink : Theme.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background {
                    if isOn {
                        Capsule()
                            .fill(Theme.card)
                            .shadow(color: .black.opacity(0.08), radius: 4, y: 1)
                            .matchedGeometryEffect(id: "pill", in: pill)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

private struct LibraryTile: View {
    let entry: LibraryEntry
    let isFavorite: Bool
    let zoom: Namespace.ID

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                StyledImage(imageName: entry.route.imageName, style: entry.route.style)
            }
            .clipShape(shape)
            .overlay(alignment: .bottomTrailing) {
                if isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 2)
                        .padding(6)
                }
            }
            .contentShape(shape)
            .matchedTransitionSource(id: entry.id, in: zoom)
    }
}

private struct EmptyLibrary: View {
    let favoritesOnly: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: favoritesOnly ? "heart" : "photo.stack")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Theme.secondary)
            Text(favoritesOnly ? "No favourites yet" : "Nothing here yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(favoritesOnly ? "Tap the heart on any image to keep it here." : "Your generations will collect here.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}
