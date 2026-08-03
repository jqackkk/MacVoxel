//
//  BlockData.swift
//  MacVoxel
//
//  Created by Jack Davenport on 8/3/26.
//


//
//  BlockRegistry.swift
//  Macvoxel
//
//  A central directory for all block properties and behaviors.
//

import Foundation

struct BlockData {
    let breakTime: Float // How long it takes to break the block (in seconds)
}

class BlockRegistry {
    // Singleton instance so we can access it from anywhere
    static let shared = BlockRegistry()
    
    // The master dictionary of block properties
    private let blocks: [BlockType: BlockData] = [
        .grass: BlockData(breakTime: 0.6),
        .dirt: BlockData(breakTime: 0.5),
        .cobblestone: BlockData(breakTime: 1.5)
    ]
    
    func getData(for type: BlockType) -> BlockData {
        // Return the data, or a default of 0.0 seconds (instant) if not found
        return blocks[type] ?? BlockData(breakTime: 0.0)
    }
    
    func getData(for rawValue: UInt8) -> BlockData {
        guard let type = BlockType(rawValue: rawValue) else { return BlockData(breakTime: 0.0) }
        return getData(for: type)
    }
}