//
//  MathUtilities.swift
//  Macvoxel
//  Copyright (c) Jack Davenport 2026. All rights reserved.
//

import simd

extension matrix_float4x4 {
    
    init(translationX x: Float, y: Float, z: Float) {
        self.init(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(x, y, z, 1)
        )
    }
    
    init(rotationY angle: Float) {
        let c = cos(angle)
        let s = sin(angle)
        self.init(
            SIMD4<Float>( c, 0, s, 0),
            SIMD4<Float>( 0, 1, 0, 0),
            SIMD4<Float>(-s, 0, c, 0),
            SIMD4<Float>( 0, 0, 0, 1)
        )
    }
    
    init(rotationX angle: Float) {
        let c = cos(angle)
        let s = sin(angle)
        self.init(
            SIMD4<Float>(1,  0, 0, 0),
            SIMD4<Float>(0,  c, s, 0),
            SIMD4<Float>(0, -s, c, 0),
            SIMD4<Float>(0,  0, 0, 1)
        )
    }

    // Creates a perspective camera projection
    init(perspectiveProjectionFov fovRadians: Float, aspectRatio: Float, nearZ: Float, farZ: Float) {
        let ys = 1 / tanf(fovRadians * 0.5)
        let xs = ys / aspectRatio
        let zs = farZ / (nearZ - farZ)
        
        self.init(
            SIMD4<Float>(xs,  0, 0,   0),
            SIMD4<Float>( 0, ys, 0,   0),
            SIMD4<Float>( 0,  0, zs, -1),
            SIMD4<Float>( 0,  0, zs * nearZ, 0)
        )
    }
}

// Matrix multiplication helper
func * (left: matrix_float4x4, right: matrix_float4x4) -> matrix_float4x4 {
    return matrix_multiply(left, right)
}

// SIMD3 Math Helpers for the camera
func + (left: SIMD3<Float>, right: SIMD3<Float>) -> SIMD3<Float> {
    return SIMD3<Float>(left.x + right.x, left.y + right.y, left.z + right.z)
}

func += (left: inout SIMD3<Float>, right: SIMD3<Float>) {
    left = left + right
}

func * (vector: SIMD3<Float>, scalar: Float) -> SIMD3<Float> {
    return SIMD3<Float>(vector.x * scalar, vector.y * scalar, vector.z * scalar)
}

// A simple procedural noise function to generate natural looking hills
func smoothNoise(x: Float, z: Float) -> Float {
    let integerX = Int(floor(x))
    let integerZ = Int(floor(z))
    let fractionalX = x - floor(x)
    let fractionalZ = z - floor(z)
    
    func randomHash(_ ix: Int, _ iz: Int) -> Float {
        var h = Float(ix) * 37.0 + Float(iz) * 109.0
        return abs(h.truncatingRemainder(dividingBy: 43758.5453) / 43758.5453)
    }
    
    let v1 = randomHash(integerX, integerZ)
    let v2 = randomHash(integerX + 1, integerZ)
    let v3 = randomHash(integerX, integerZ + 1)
    let v4 = randomHash(integerX + 1, integerZ + 1)
    
    let i1 = v1 * (1 - fractionalX) + v2 * fractionalX
    let i2 = v3 * (1 - fractionalX) + v4 * fractionalX
    
    return i1 * (1 - fractionalZ) + i2 * fractionalZ
}
