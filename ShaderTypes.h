//
//  ShaderTypes.h
//  Macvoxel
//  Copyright (c) Jack Davenport 2026. All rights reserved.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

// MARK: - Texture support
struct Vertex {
vector_float3 position;
vector_float2 texCoord; // Replaced color with UV coordinates for textures
};

struct Uniforms {
matrix_float4x4 modelViewProjectionMatrix;
};

#endif /* ShaderTypes_h */
