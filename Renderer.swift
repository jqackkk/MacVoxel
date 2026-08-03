//
//  Renderer.swift
//  Macvoxel
//

import MetalKit
import simd

class Renderer: NSObject, MTKViewDelegate {

    public let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState
    var depthState: MTLDepthStencilState
    
    var wireframePipelineState: MTLRenderPipelineState
    var wireframeBuffer: MTLBuffer?
    var wireframeVertexCount: Int = 24
    
    var textureAtlas: MTLTexture?
    var samplerState: MTLSamplerState?
    var chunks: [Chunk] = []
    
    var cameraPosition: SIMD3<Float> = SIMD3<Float>(32, 40, 32)
    var cameraPitch: Float = 0
    var cameraYaw: Float = 0
    var keysPressed: Set<UInt16> = []
    var mouseSensitivity: Float = 0.005
    
    var playerVelocityY: Float = 0.0
    let gravity: Float = -25.0
    let jumpForce: Float = 8.0
    var isGrounded: Bool = false

    var highlightedBlock: SIMD3<Int>?
    var placeBlockPosition: SIMD3<Int>?
    var activeBlockType: UInt8 = BlockType.grass.rawValue
    
    var isBreaking: Bool = false
    var breakProgress: Float = 0.0
    var breakingBlockPosition: SIMD3<Int>?

    init?(metalKitView: MTKView) {
        guard let device = metalKitView.device else { return nil }
        self.device = device
        guard let queue = self.device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        
        let library = device.makeDefaultLibrary()
        let vertexFunction = library?.makeFunction(name: "vertexShader")
        let fragmentFunction = library?.makeFunction(name: "fragmentShader")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        let wireDescriptor = MTLRenderPipelineDescriptor()
        wireDescriptor.vertexFunction = library?.makeFunction(name: "wireframeVertexShader")
        wireDescriptor.fragmentFunction = library?.makeFunction(name: "wireframeFragmentShader")
        wireDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        wireDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        wireframePipelineState = try! device.makeRenderPipelineState(descriptor: wireDescriptor)
        
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        self.depthState = device.makeDepthStencilState(descriptor: depthDescriptor)!
        
        super.init()
        
        setupTexture()
        setupWireframe()
        
        for x in 0..<4 {
            for z in 0..<4 {
                let chunk = Chunk(chunkX: x, chunkZ: z)
                chunk.buildMesh(device: self.device)
                chunks.append(chunk)
            }
        }
    }
    
    private func setupWireframe() {
        let e: Float = -0.002
        let s: Float = 1.002
        let n: SIMD3<Float> = [0,0,0]
        let vertices: [Vertex] = [
            Vertex(position:[e,e,e], texCoord:[0,0], normal: n), Vertex(position:[s,e,e], texCoord:[0,0], normal: n),
            Vertex(position:[s,e,e], texCoord:[0,0], normal: n), Vertex(position:[s,e,s], texCoord:[0,0], normal: n),
            Vertex(position:[s,e,s], texCoord:[0,0], normal: n), Vertex(position:[e,e,s], texCoord:[0,0], normal: n),
            Vertex(position:[e,e,s], texCoord:[0,0], normal: n), Vertex(position:[e,e,e], texCoord:[0,0], normal: n),
            Vertex(position:[e,s,e], texCoord:[0,0], normal: n), Vertex(position:[s,s,e], texCoord:[0,0], normal: n),
            Vertex(position:[s,s,e], texCoord:[0,0], normal: n), Vertex(position:[s,s,s], texCoord:[0,0], normal: n),
            Vertex(position:[s,s,s], texCoord:[0,0], normal: n), Vertex(position:[e,s,s], texCoord:[0,0], normal: n),
            Vertex(position:[e,s,s], texCoord:[0,0], normal: n), Vertex(position:[e,s,e], texCoord:[0,0], normal: n),
            Vertex(position:[e,e,e], texCoord:[0,0], normal: n), Vertex(position:[e,s,e], texCoord:[0,0], normal: n),
            Vertex(position:[s,e,e], texCoord:[0,0], normal: n), Vertex(position:[s,s,e], texCoord:[0,0], normal: n),
            Vertex(position:[s,e,s], texCoord:[0,0], normal: n), Vertex(position:[s,s,s], texCoord:[0,0], normal: n),
            Vertex(position:[e,e,s], texCoord:[0,0], normal: n), Vertex(position:[e,s,s], texCoord:[0,0], normal: n)
        ]
        wireframeBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count, options: .storageModeShared)
    }
    
    private func setupTexture() {
        let loader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option : Any] = [.generateMipmaps: false, .SRGB: false]
        do { textureAtlas = try loader.newTexture(name: "TextureAtlas", scaleFactor: 1.0, bundle: nil, options: options)
        } catch { print("Failed to load TextureAtlas: \(error)") }
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.magFilter = .nearest
        samplerDescriptor.minFilter = .nearest
        self.samplerState = device.makeSamplerState(descriptor: samplerDescriptor)
    }

    func updateCamera(deltaTime: Float) {
        var velocity = SIMD3<Float>(0, 0, 0)
        let speed: Float = 10.0
        
        let forward = SIMD3<Float>(sin(cameraYaw), 0, -cos(cameraYaw))
        let right = SIMD3<Float>(cos(cameraYaw), 0, sin(cameraYaw))
        
        if keysPressed.contains(13) { velocity += forward * speed }
        if keysPressed.contains(1)  { velocity -= forward * speed }
        if keysPressed.contains(0)  { velocity -= right * speed }
        if keysPressed.contains(2)  { velocity += right * speed }
        
        if keysPressed.contains(49) && isGrounded {
            playerVelocityY = jumpForce
            isGrounded = false
        }
        
        playerVelocityY += gravity * deltaTime
        velocity.y = playerVelocityY
        
        let playerWidth: Float = 0.6
        let playerHeight: Float = 1.8
        let eyeLevel: Float = 1.6
        var feetPos = cameraPosition
        feetPos.y -= eyeLevel
        
        feetPos.y += velocity.y * deltaTime
        if isPlayerColliding(pos: feetPos, width: playerWidth, height: playerHeight) {
            if velocity.y < 0 {
                feetPos.y = ceil(feetPos.y)
                playerVelocityY = 0
                isGrounded = true
            } else if velocity.y > 0 {
                feetPos.y = floor(feetPos.y + playerHeight) - playerHeight - 0.01
                playerVelocityY = 0
            }
        } else { isGrounded = false }
        
        feetPos.x += velocity.x * deltaTime
        if isPlayerColliding(pos: feetPos, width: playerWidth, height: playerHeight) {
            feetPos.x -= velocity.x * deltaTime
        }
        
        feetPos.z += velocity.z * deltaTime
        if isPlayerColliding(pos: feetPos, width: playerWidth, height: playerHeight) {
            feetPos.z -= velocity.z * deltaTime
        }
        
        cameraPosition = feetPos
        cameraPosition.y += eyeLevel
        
        if cameraPosition.y < -20.0 {
            cameraPosition = SIMD3<Float>(32.0, 60.0, 32.0)
            playerVelocityY = 0.0
        }
        
        updateRaycast()
        
        // --- Process Block Mining ---
        if isBreaking {
            if let target = highlightedBlock {
                if target != breakingBlockPosition {
                    breakingBlockPosition = target
                    breakProgress = 0.0
                } else {
                    let blockID = getBlockID(worldX: target.x, worldY: target.y, worldZ: target.z)
                    let breakTime = BlockRegistry.shared.getData(for: blockID).breakTime
                    
                    breakProgress += deltaTime
                    
                    if breakProgress >= breakTime && breakTime > 0 {
                        setBlockID(worldX: target.x, worldY: target.y, worldZ: target.z, type: BlockType.air.rawValue)
                        breakProgress = 0.0
                    }
                }
            } else {
                breakProgress = 0.0
                breakingBlockPosition = nil
            }
        } else {
            breakProgress = 0.0
            breakingBlockPosition = nil
        }
    }
    
    private func isPlayerColliding(pos: SIMD3<Float>, width: Float, height: Float) -> Bool {
        let minX = Int(floor(pos.x - width / 2.0))
        let maxX = Int(floor(pos.x + width / 2.0))
        let minY = Int(floor(pos.y + 0.01))
        let maxY = Int(floor(pos.y + height - 0.01))
        let minZ = Int(floor(pos.z - width / 2.0))
        let maxZ = Int(floor(pos.z + width / 2.0))
        
        for x in minX...maxX {
            for y in minY...maxY {
                for z in minZ...maxZ {
                    if getBlockID(worldX: x, worldY: y, worldZ: z) != BlockType.air.rawValue { return true }
                }
            }
        }
        return false
    }
    
    private func updateRaycast() {
        highlightedBlock = nil
        placeBlockPosition = nil

        let forward3D = SIMD3<Float>(
            sin(cameraYaw) * cos(cameraPitch),
            sin(cameraPitch),
            -cos(cameraYaw) * cos(cameraPitch)
        )
        
        var currentPos = cameraPosition
        let stepDistance: Float = 0.05
        var previousVoxel = SIMD3<Int>(Int(floor(currentPos.x)), Int(floor(currentPos.y)), Int(floor(currentPos.z)))

        for _ in 0..<160 {
            currentPos += forward3D * stepDistance
            
            let voxelX = Int(floor(currentPos.x))
            let voxelY = Int(floor(currentPos.y))
            let voxelZ = Int(floor(currentPos.z))
            let currentVoxel = SIMD3<Int>(voxelX, voxelY, voxelZ)

            if currentVoxel != previousVoxel {
                if getBlockID(worldX: voxelX, worldY: voxelY, worldZ: voxelZ) != BlockType.air.rawValue {
                    highlightedBlock = currentVoxel
                    placeBlockPosition = previousVoxel
                    return
                }
                previousVoxel = currentVoxel
            }
        }
    }
    
    func interact() {
        guard let target = placeBlockPosition else { return }
        if target.y >= Chunk.height || target.y < 0 { return }
        if activeBlockType == BlockType.air.rawValue { return }
        
        let playerX = Int(floor(cameraPosition.x))
        let playerY = Int(floor(cameraPosition.y - 1.5))
        let playerZ = Int(floor(cameraPosition.z))
        if target.x == playerX && (target.y == playerY || target.y == playerY + 1) && target.z == playerZ { return }
        
        setBlockID(worldX: target.x, worldY: target.y, worldZ: target.z, type: activeBlockType)
    }
    
    private func getBlockID(worldX: Int, worldY: Int, worldZ: Int) -> UInt8 {
        for chunk in chunks {
            let startX = chunk.chunkX * Chunk.width
            let startZ = chunk.chunkZ * Chunk.depth
            if worldX >= startX && worldX < startX + Chunk.width && worldZ >= startZ && worldZ < startZ + Chunk.depth {
                return chunk.getBlock(x: worldX - startX, y: worldY, z: worldZ - startZ)
            }
        }
        return 0
    }
    
    private func setBlockID(worldX: Int, worldY: Int, worldZ: Int, type: UInt8) {
        for chunk in chunks {
            let startX = chunk.chunkX * Chunk.width
            let startZ = chunk.chunkZ * Chunk.depth
            if worldX >= startX && worldX < startX + Chunk.width && worldZ >= startZ && worldZ < startZ + Chunk.depth {
                chunk.setBlock(x: worldX - startX, y: worldY, z: worldZ - startZ, type: type)
                chunk.buildMesh(device: self.device)
                break
            }
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        
        let deltaTime = 1.0 / Float(view.preferredFramesPerSecond)
        updateCamera(deltaTime: deltaTime)

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setCullMode(.none)
        
        if let texture = textureAtlas, let sampler = samplerState {
            renderEncoder.setFragmentTexture(texture, index: 0)
            renderEncoder.setFragmentSamplerState(sampler, index: 0)
        }
        
        let aspectRatio = Float(view.bounds.width / view.bounds.height)
        let projectionMatrix = matrix_float4x4(perspectiveProjectionFov: Float.pi / 3, aspectRatio: aspectRatio, nearZ: 0.1, farZ: 1000.0)
        
        let rotX = matrix_float4x4(rotationX: -cameraPitch)
        let rotY = matrix_float4x4(rotationY: -cameraYaw)
        let trans = matrix_float4x4(translationX: -cameraPosition.x, y: -cameraPosition.y, z: -cameraPosition.z)
        let viewMatrix = matrix_multiply(matrix_multiply(rotX, rotY), trans)
        let finalMatrix = matrix_multiply(projectionMatrix, viewMatrix)
                          
        // Calculate the uniform data for the block breaking animation
        var isBreakingFloat: Float = 0.0
        var targetPos = SIMD3<Float>(0,0,0)
        var currentProgress: Float = 0.0
        
        if isBreaking, let target = breakingBlockPosition {
            isBreakingFloat = 1.0
            targetPos = SIMD3<Float>(Float(target.x), Float(target.y), Float(target.z))
            
            let blockID = getBlockID(worldX: target.x, worldY: target.y, worldZ: target.z)
            let breakTime = BlockRegistry.shared.getData(for: blockID).breakTime
            if breakTime > 0 { currentProgress = min(breakProgress / breakTime, 1.0) }
        }
        
        let breakInfo = SIMD4<Float>(targetPos.x, targetPos.y, targetPos.z, isBreakingFloat)
        var uniforms = Uniforms(modelViewProjectionMatrix: finalMatrix, breakingBlockInfo: breakInfo, breakProgress: currentProgress)
        
        // Pass the uniforms to BOTH the vertex and fragment shaders!
        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        renderEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        
        for chunk in chunks {
            if let vBuffer = chunk.vertexBuffer, chunk.vertexCount > 0 {
                renderEncoder.setVertexBuffer(vBuffer, offset: 0, index: 0)
                renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: chunk.vertexCount)
            }
        }

        if let target = highlightedBlock, let wBuffer = wireframeBuffer {
            renderEncoder.setRenderPipelineState(wireframePipelineState)
            
            let blockTrans = matrix_float4x4(translationX: Float(target.x), y: Float(target.y), z: Float(target.z))
            var wireUniforms = Uniforms(modelViewProjectionMatrix: matrix_multiply(finalMatrix, blockTrans), breakingBlockInfo: SIMD4<Float>(0,0,0,0), breakProgress: 0.0)
            
            renderEncoder.setVertexBytes(&wireUniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
            renderEncoder.setVertexBuffer(wBuffer, offset: 0, index: 0)
            renderEncoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: wireframeVertexCount)
        }

        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
