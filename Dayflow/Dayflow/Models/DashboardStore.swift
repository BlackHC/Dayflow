//
//  DashboardStore.swift
//  Dayflow
//
//  Dashboard tile configuration management
//

import Foundation
import SwiftUI

@MainActor
final class DashboardStore: ObservableObject {
    enum StoreKeys {
        static let tiles = "dashboardTiles"
    }
    
    @Published private(set) var tiles: [DashboardTile] = []
    
    init() {
        load()
    }
    
    // MARK: - Public API
    
    func addTile(type: DashboardTileType, customQuery: String? = nil) {
        let nextPosition = (tiles.map { $0.position }.max() ?? -1) + 1
        let now = Date()
        
        let tile = DashboardTile(
            type: type,
            position: nextPosition,
            customQuery: customQuery,
            createdAt: now,
            updatedAt: now
        )
        
        guard tile.validate() else {
            print("[DashboardStore] ❌ Attempted to add invalid tile: \(tile)")
            return
        }
        
        tiles.append(tile)
        save()
        print("[DashboardStore] ✅ Added tile: \(type.displayName) at position \(nextPosition)")
    }
    
    func updateTile(id: UUID, mutate: (inout DashboardTile) -> Void) {
        guard let idx = tiles.firstIndex(where: { $0.id == id }) else {
            print("[DashboardStore] ⚠️ Tile not found: \(id)")
            return
        }
        
        var tile = tiles[idx]
        mutate(&tile)
        tile.updatedAt = Date()
        
        guard tile.validate() else {
            print("[DashboardStore] ❌ Tile validation failed after update: \(tile)")
            return
        }
        
        tiles[idx] = tile
        save()
        print("[DashboardStore] ✅ Updated tile: \(tile.type.displayName)")
    }
    
    func updateCustomQuery(_ query: String, for id: UUID) {
        updateTile(id: id) { tile in
            tile.customQuery = query
        }
    }
    
    func removeTile(id: UUID) {
        guard let tile = tiles.first(where: { $0.id == id }) else {
            print("[DashboardStore] ⚠️ Tile not found for removal: \(id)")
            return
        }
        
        tiles.removeAll { $0.id == id }
        // Reindex positions
        reindexPositions()
        save()
        print("[DashboardStore] ✅ Removed tile: \(tile.type.displayName)")
    }
    
    func reorderTiles(_ idsInOrder: [UUID]) {
        var newTiles: [DashboardTile] = []
        var position = 0
        
        for id in idsInOrder {
            guard let idx = tiles.firstIndex(where: { $0.id == id }) else {
                continue
            }
            var tile = tiles[idx]
            tile.position = position
            tile.updatedAt = Date()
            newTiles.append(tile)
            position += 1
        }
        
        // Add any tiles not in the reorder list at the end
        let untouched = tiles.filter { !idsInOrder.contains($0.id) }
        for var tile in untouched {
            tile.position = position
            tile.updatedAt = Date()
            newTiles.append(tile)
            position += 1
        }
        
        tiles = newTiles.sorted { $0.position < $1.position }
        save()
        print("[DashboardStore] ✅ Reordered \(idsInOrder.count) tiles")
    }
    
    func resetToDefaults() {
        tiles = DashboardTile.defaultTiles
        save()
        print("[DashboardStore] ✅ Reset to default tiles")
    }
    
    func persist() {
        save()
    }
    
    // MARK: - Private Methods
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: StoreKeys.tiles) else {
            // First launch - use defaults
            tiles = DashboardTile.defaultTiles
            save() // Persist defaults
            print("[DashboardStore] 📦 Initialized with \(tiles.count) default tiles")
            return
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let decoded = try? decoder.decode([DashboardTile].self, from: data) {
            tiles = decoded.sorted { $0.position < $1.position }
            print("[DashboardStore] 📦 Loaded \(tiles.count) tiles from storage")
        } else {
            // Decoding failed - use defaults
            tiles = DashboardTile.defaultTiles
            save()
            print("[DashboardStore] ⚠️ Failed to decode tiles, using defaults")
        }
    }
    
    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(tiles) {
            UserDefaults.standard.set(data, forKey: StoreKeys.tiles)
            print("[DashboardStore] 💾 Saved \(tiles.count) tiles to storage")
        } else {
            print("[DashboardStore] ❌ Failed to encode tiles for saving")
        }
    }
    
    private func reindexPositions() {
        tiles = tiles
            .sorted { $0.position < $1.position }
            .enumerated()
            .map { index, tile in
                var updated = tile
                updated.position = index
                updated.updatedAt = Date()
                return updated
            }
    }
}

// MARK: - Preview Support

#if DEBUG
extension DashboardStore {
    static var preview: DashboardStore {
        let store = DashboardStore()
        return store
    }
}
#endif

