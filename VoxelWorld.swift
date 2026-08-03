//
//  VoxelWorld.swift
//  Macvoxel
//

import MetalKit
import simd

enum BlockType: UInt8 {
    case air = 0
    case grass = 1
    case dirt = 2
    case cobblestone = 3
}

class Chunk {
    static let width = 16
    static let height = 64
    static let depth = 16
    
    let chunkX: Int
    let chunkZ: Int
    var blocks: [UInt8]
    
    var vertexBuffer: MTLBuffer?
    var vertexCount: Int = 0
    
    init(chunkX: Int, chunkZ: Int) {
        self.chunkX = chunkX
        self.chunkZ = chunkZ
        self.blocks = Array(repeating: 0, count: Chunk.width * Chunk.height * Chunk.depth)
        generateTerrain()
    }
    
    private func generateTerrain() {
        for x in 0..<Chunk.width {
            for z in 0..<Chunk.depth {
                let worldX = Float(chunkX * Chunk.width + x)
                let worldZ = Float(chunkZ * Chunk.depth + z)
                let noiseHeight = Int(20 + smoothNoise(x: worldX * 0.05, z: worldZ * 0.05) * 10)
                
                for y in 0..<Chunk.height {
                    let index = getIndex(x: x, y: y, z: z)
                    if y == noiseHeight {
                        blocks[index] = BlockType.grass.rawValue
                    } else if y < noiseHeight {
                        blocks[index] = BlockType.dirt.rawValue
                    }
                }
            }
        }
    }
    
    private func getIndex(x: Int, y: Int, z: Int) -> Int {
        return x + (y * Chunk.width) + (z * Chunk.width * Chunk.height)
    }
    
    func getBlock(x: Int, y: Int, z: Int) -> UInt8 {
        if x < 0 || x >= Chunk.width || y < 0 || y >= Chunk.height || z < 0 || z >= Chunk.depth { return 0 }
        return blocks[getIndex(x: x, y: y, z: z)]
    }
    
    func setBlock(x: Int, y: Int, z: Int, type: UInt8) {
        if x < 0 || x >= Chunk.width || y < 0 || y >= Chunk.height || z < 0 || z >= Chunk.depth { return }
        blocks[getIndex(x: x, y: y, z: z)] = type
    }
    
    enum FaceDirection: Int {
        case top = 0, bottom = 1, front = 2, back = 3, left = 4, right = 5
    }
    
    func buildMesh(device: MTLDevice) {
        var vertices: [Vertex] = []
        
        let wx = Float(chunkX * Chunk.width)
        let wz = Float(chunkZ * Chunk.depth)
        
        func getUVs(for blockType: UInt8, face: FaceDirection) -> [SIMD2<Float>] {
            let atlasCols: Float = 6.0
            let atlasRows: Float = 4.0 // INCREASED TO 4 ROWS
            
            let row = Float(blockType - 1)
            let col = Float(face.rawValue)
            
            let startX = col / atlasCols
            let endX = (col + 1) / atlasCols
            let startY = row / atlasRows
            let endY = (row + 1) / atlasRows
            
            return [ [startX, endY], [endX, endY], [startX, startY], [endX, startY] ]
        }
        
        func addFace(v0: SIMD3<Float>, v1: SIMD3<Float>, v2: SIMD3<Float>, v3: SIMD3<Float>, uvs: [SIMD2<Float>], normal: SIMD3<Float>) {
            vertices.append(Vertex(position: v0, texCoord: uvs[0], normal: normal))
            vertices.append(Vertex(position: v1, texCoord: uvs[1], normal: normal))
            vertices.append(Vertex(position: v2, texCoord: uvs[2], normal: normal))
            vertices.append(Vertex(position: v2, texCoord: uvs[2], normal: normal))
            vertices.append(Vertex(position: v1, texCoord: uvs[1], normal: normal))
            vertices.append(Vertex(position: v3, texCoord: uvs[3], normal: normal))
        }
        
        for x in 0..<Chunk.width {
            for y in 0..<Chunk.height {
                for z in 0..<Chunk.depth {
                    let type = getBlock(x: x, y: y, z: z)
                    if type == BlockType.air.rawValue { continue }
                    
                    let pX = Float(x) + wx
                    let pY = Float(y)
                    let pZ = Float(z) + wz
                    
                    if getBlock(x: x, y: y + 1, z: z) == 0 {
                        addFace(v0: [pX, pY+1, pZ+1], v1: [pX+1, pY+1, pZ+1], v2: [pX, pY+1, pZ], v3: [pX+1, pY+1, pZ], uvs: getUVs(for: type, face: .top), normal: [0, 1, 0])
                    }
                    if getBlock(x: x, y: y - 1, z: z) == 0 {
                        addFace(v0: [pX, pY, pZ], v1: [pX+1, pY, pZ], v2: [pX, pY, pZ+1], v3: [pX+1, pY, pZ+1], uvs: getUVs(for: type, face: .bottom), normal: [0, -1, 0])
                    }
                    if getBlock(x: x, y: y, z: z + 1) == 0 {
                        addFace(v0: [pX, pY, pZ+1], v1: [pX+1, pY, pZ+1], v2: [pX, pY+1, pZ+1], v3: [pX+1, pY+1, pZ+1], uvs: getUVs(for: type, face: .front), normal: [0, 0, 1])
                    }
                    if getBlock(x: x, y: y, z: z - 1) == 0 {
                        addFace(v0: [pX+1, pY, pZ], v1: [pX, pY, pZ], v2: [pX+1, pY+1, pZ], v3: [pX, pY+1, pZ], uvs: getUVs(for: type, face: .back), normal: [0, 0, -1])
                    }
                    if getBlock(x: x + 1, y: y, z: z) == 0 {
                        addFace(v0: [pX+1, pY, pZ+1], v1: [pX+1, pY, pZ], v2: [pX+1, pY+1, pZ+1], v3: [pX+1, pY+1, pZ], uvs: getUVs(for: type, face: .right), normal: [1, 0, 0])
                    }
                    if getBlock(x: x - 1, y: y, z: z) == 0 {
                        addFace(v0: [pX, pY, pZ], v1: [pX, pY, pZ+1], v2: [pX, pY+1, pZ], v3: [pX, pY+1, pZ+1], uvs: getUVs(for: type, face: .left), normal: [-1, 0, 0])
                    }
                }
            }
        }
        
        self.vertexCount = vertices.count
        if vertexCount > 0 {
            self.vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertexCount, options: .storageModeShared)
        } else {
            self.vertexBuffer = nil
        }
    }
}
