//
//  Shaders.metal
//  Macvoxel
//  Copyright (c) Jack Davenport 2026. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#include "ShaderTypes.h"

struct RasterizerData {
float4 position [[position]];
float2 texCoord;
};

// MARK: - Chunk shaders
vertex RasterizerData vertexShader(uint vertexID [[vertex_id]],
constant Vertex *vertices [[buffer(0)]],
constant Uniforms &uniforms [[buffer(1)]]) {

RasterizerData out;

float4 rawPosition = float4(vertices[vertexID].position, 1.0);
out.position = uniforms.modelViewProjectionMatrix * rawPosition;

out.texCoord = vertices[vertexID].texCoord;
return out;


}

fragment float4 fragmentShader(RasterizerData in [[stage_in]],
texture2d<half> colorTexture [[texture(0)]],
sampler textureSampler [[sampler(0)]]) {

half4 texColor = colorTexture.sample(textureSampler, in.texCoord);
return float4(texColor);


}

// MARK: - Wireframe shaders
// A simple secondary pipeline just for drawing the black selection box
vertex RasterizerData wireframeVertexShader(uint vertexID [[vertex_id]],
constant Vertex *vertices [[buffer(0)]],
constant Uniforms &uniforms [[buffer(1)]]) {
RasterizerData out;
float4 rawPosition = float4(vertices[vertexID].position, 1.0);
out.position = uniforms.modelViewProjectionMatrix * rawPosition;
out.texCoord = float2(0,0);
return out;
}

fragment float4 wireframeFragmentShader(RasterizerData in [[stage_in]]) {
// Return solid black for the wireframe lines
return float4(0.0, 0.0, 0.0, 1.0);
}
