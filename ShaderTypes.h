//
//  ShaderTypes.h
//  Macvoxel
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

/* STREAMING_CHUNK:Defining Vertex struct... */
struct Vertex {
vector_float3 position;
vector_float2 texCoord;
vector_float3 normal;
};

/* STREAMING_CHUNK:Defining Uniforms struct with block breaking variables... */
struct Uniforms {
matrix_float4x4 modelViewProjectionMatrix;
vector_float4 breakingBlockInfo; // x,y,z = block coordinates. w = 1.0 (breaking) or 0.0 (not breaking)
float breakProgress; // 0.0 to 1.0
};

#endif /* ShaderTypes_h */
