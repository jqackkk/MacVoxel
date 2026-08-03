//
//  Shaders.metal
//  Macvoxel
//

#include <metal_stdlib>
using namespace metal;

#include "ShaderTypes.h"

struct RasterizerData {
float4 position [[position]];
float2 texCoord;
float3 normal;
float3 worldPos;
};

/* STREAMING_CHUNK:Vertex Shader... */
// MARK: - Chunk shaders
vertex RasterizerData vertexShader(uint vertexID [[vertex_id]],
constant Vertex *vertices [[buffer(0)]],
constant Uniforms &uniforms [[buffer(1)]]) {
RasterizerData out;
float4 rawPosition = float4(vertices[vertexID].position, 1.0);
out.position = uniforms.modelViewProjectionMatrix * rawPosition;
out.texCoord = vertices[vertexID].texCoord;
out.normal = vertices[vertexID].normal;
out.worldPos = vertices[vertexID].position;
return out;
}

/* STREAMING_CHUNK:Fragment Shader with Crack Texture Overlay... */
fragment float4 fragmentShader(RasterizerData in [[stage_in]],
constant Uniforms &uniforms [[buffer(1)]],
texture2d<half> colorTexture [[texture(0)]],
sampler textureSampler [[sampler(0)]]) {

half4 texColor = colorTexture.sample(textureSampler, in.texCoord);

// Calculate Lighting
float3 sunDirection = normalize(float3(0.6, 0.8, 0.4));
float lightIntensity = max(dot(in.normal, sunDirection), 0.0);
float ambientLight = 0.45;
float totalLight = ambientLight + (lightIntensity * 0.55);

// --- Block Breaking Overlay ---
if (uniforms.breakingBlockInfo.w > 0.5) {
    // Push slightly inside the block to get accurate integer coordinates
    float3 insidePos = in.worldPos - (in.normal * 0.01);
    float3 blockCoord = floor(insidePos);
    float3 targetBlock = uniforms.breakingBlockInfo.xyz;
    
    // If this pixel belongs to the block currently being mined...
    if (abs(blockCoord.x - targetBlock.x) < 0.1 &&
        abs(blockCoord.y - targetBlock.y) < 0.1 &&
        abs(blockCoord.z - targetBlock.z) < 0.1) {
        
        // Extract local 0.0-1.0 UV coordinates for the face using a fract math trick!
        float2 localUV = fract(in.texCoord * float2(6.0, 4.0));
        
        // Our atlas has 6 columns and 4 rows. Cracks are on Row 4 (index 3).
        int stage = int(uniforms.breakProgress * 5.99); // Maps 0.0-1.0 to Frame 0-5
        float startX = float(stage) / 6.0;
        float startY = 3.0 / 4.0;
        
        // Map the local pixel to the correct crack frame
        float2 breakUV = float2(startX + (localUV.x / 6.0), startY + (localUV.y / 4.0));
        half4 breakTex = colorTexture.sample(textureSampler, breakUV);
        
        // Blend the crack texture over the block (using its transparency)
        if (breakTex.a > 0.1) {
            texColor.rgb = mix(texColor.rgb, breakTex.rgb, float(breakTex.a));
        }
    }
}

return float4(texColor.r * totalLight, texColor.g * totalLight, texColor.b * totalLight, texColor.a);


}

/* STREAMING_CHUNK:Wireframe Shaders... */
// MARK: - Wireframe shaders
vertex RasterizerData wireframeVertexShader(uint vertexID [[vertex_id]],
constant Vertex *vertices [[buffer(0)]],
constant Uniforms &uniforms [[buffer(1)]]) {
RasterizerData out;
float4 rawPosition = float4(vertices[vertexID].position, 1.0);
out.position = uniforms.modelViewProjectionMatrix * rawPosition;
out.texCoord = float2(0,0);
out.normal = float3(0,0,0);
return out;
}

fragment float4 wireframeFragmentShader(RasterizerData in [[stage_in]]) {
// Keep the selection box a solid black outline!
return float4(0.0, 0.0, 0.0, 1.0);
}
