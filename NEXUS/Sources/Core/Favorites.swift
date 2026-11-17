import Foundation
import SwiftUI

struct FavoriteEntry: Codable, Identifiable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable { case repo, cve }
    let id: String
    let kind: Kind
    var title: String
    var subtitle: String
    var url: String
    var lastSeen: Date?
}

@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var items: [FavoriteEntry] = []
    private let key = "favorites.v1"

    init() {
        if let d = UserDefaults.standard.data(forKey: key),
           let v = try? JSONDecoder.cacheDecoder.decode([FavoriteEntry].self, from: d) { items = v }
    }
    private func save() {
        if let d = try? JSONEncoder.cacheEncoder.encode(items) { UserDefaults.standard.set(d, forKey: key) }
    }
    func contains(_ id: String) -> Bool { items.contains { $0.id == id } }
    func toggle(_ e: FavoriteEntry) {
        if let i = items.firstIndex(where: { $0.id == e.id }) { items.remove(at: i) } else { items.insert(e, at: 0) }
        save()
    }
    func markSeen(_ id: String, date: Date?) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].lastSeen = date; save()
    }
    func replaceAll(_ new: [FavoriteEntry]) { items = new; save() }
    var repoIDs: [String] { items.filter { $0.kind == .repo }.map(\.id) }
}

struct FavoriteButton: View {
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var settings: AppSettings
    let entry: FavoriteEntry
    var body: some View {
        Button {
            favorites.toggle(entry); settings.tap()
        } label: {
            Image(systemName: favorites.contains(entry.id) ? "star.fill" : "star")
                .foregroundStyle(favorites.contains(entry.id) ? .yellow : .secondary)
        }
        .buttonStyle(.plain)
    }
}
