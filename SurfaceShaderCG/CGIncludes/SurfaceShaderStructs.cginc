#ifndef SURFACE_SHADER_STRUCTS_INCLUDED
#define SURFACE_SHADER_STRUCTS_INCLUDED

#include "UnityCG.cginc"
#include "UnityStandardCore.cginc"
#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"

#if defined(_NORMALMAP) && !defined(_PER_PIXEL_NORMALS)
#define _PER_PIXEL_NORMALS
#endif

////////////////////////////////////////
// Vertex structs
//
		
struct VertexInputSurface
{
	float4 vertex   : POSITION;
    half3 normal    : NORMAL;
	half4 tangent   : TANGENT;
	float4 color 	: COLOR;
    float4 uv0      : TEXCOORD0;
    float4 uv1      : TEXCOORD1;
#if defined(DYNAMICLIGHTMAP_ON) || defined(UNITY_PASS_META)
    float2 uv2      : TEXCOORD3;
#endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct VertexOutput
{
	float4 pos : SV_POSITION;				
	float4 texcoord : TEXCOORD0;
	float3 viewDir : TEXCOORD1;
	float4 posWorld : TEXCOORD2;
	float4 normalWorld : TEXCOORD3;
	half4 ambientOrLightmapUV : TEXCOORD4;
	LIGHTING_COORDS(5, 6)
	UNITY_FOG_COORDS(7)
#if defined(_PER_PIXEL_NORMALS) || defined(_PARALLAXMAP) 
	float4 tangentWorld : TEXCOORD8;
	float4 binormalWorld : TEXCOORD9;
#endif
#if defined(_REQUIRES_SCREEN_POS)
	float4 screenPos : TEXCOORD10;
#endif
#if defined(_REQUIRES_WORLD_REFL)
  float3 worldRefl 	: TEXCOORD10;
#endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};


////////////////////////////////////////
// Shared Functions
//

inline float3 getTangentSpaceNormal(VertexOutput i)
{
#ifdef _NORMALMAP
	return NormalInTangentSpace(i.texcoord);
#else
   return float3(0,0,1);
#endif
}

inline float3 getPerPixelWorldNormal(VertexOutput i, half3 normalTangent)
{
#if defined(_PER_PIXEL_NORMALS)

	half3 tangent = i.tangentWorld.xyz;
    half3 binormal = i.binormalWorld.xyz;
    half3 normal = i.normalWorld.xyz;

    #if UNITY_TANGENT_ORTHONORMALIZE
        normal = NormalizePerPixelNormal(normal);

        // ortho-normalize Tangent
        tangent = normalize (tangent - normal * dot(tangent, normal));

        // recalculate Binormal
        half3 newB = cross(normal, tangent);
        binormal = newB * sign (dot (newB, binormal));
    #endif
	
    return NormalizePerPixelNormal(tangent * normalTangent.x + binormal * normalTangent.y + normal * normalTangent.z);
	
#else
	return NormalizePerPixelNormal(i.normalWorld.xyz);
#endif
}

#endif // SURFACE_SHADER_STRUCTS_INCLUDED