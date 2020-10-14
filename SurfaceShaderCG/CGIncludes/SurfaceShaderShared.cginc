#ifndef SURFACE_SHADER_SHARED_INCLUDED
#define SURFACE_SHADER_SHARED_INCLUDED

#include "SurfaceShaderStructs.cginc"

#ifdef _SPECULAR_WORKFLOW
	#define GET_FRAGMENT_DATA getSpecularFragmentCommonData
	#ifndef GET_SURFACE_PROPERTIES 
		#define GET_SURFACE_PROPERTIES getDefaultSpecularSurfaceOuput
	#endif
#else
	#define GET_FRAGMENT_DATA getFragmentCommonData
	#ifndef GET_SURFACE_PROPERTIES 
		#define GET_SURFACE_PROPERTIES getDefaultSurfaceOuput
	#endif
#endif

#ifndef UPDATE_VERTEX 
	#define UPDATE_VERTEX dontUpdateVertex
#endif
	
#ifndef UPDATE_SURFACE_FINAL_COLOR
	#define UPDATE_SURFACE_FINAL_COLOR dontUpdateFinalColor
#endif

////////////////////////////////////////
// Helper Functions
//

inline float4 getTexCoords(VertexInputSurface v)
{
    float4 texcoord;
    texcoord.xy = TRANSFORM_TEX(v.uv0, _MainTex); // Always source from uv0
    texcoord.zw = TRANSFORM_TEX(((_UVSec == 0) ? v.uv0 : v.uv1), _DetailAlbedoMap);
    return texcoord;
}

inline void calcAmbientOrLightmapUV(VertexInputSurface v, inout VertexOutput output, float3 normalWorld)
{
	output.ambientOrLightmapUV = 0;
	// Static lightmaps
    #ifdef LIGHTMAP_ON
        output.ambientOrLightmapUV.xy = v.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
        output.ambientOrLightmapUV.zw = 0;
    // Sample light probe for Dynamic objects only (no static or dynamic lightmaps)
    #elif UNITY_SHOULD_SAMPLE_SH
        #ifdef VERTEXLIGHT_ON
            // Approximated illumination from non-important point lights
            output.ambientOrLightmapUV.rgb = Shade4PointLights (
                unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
                unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
                unity_4LightAtten0, output.posWorld, normalWorld);
        #endif

        output.ambientOrLightmapUV.rgb = ShadeSHPerVertex (normalWorld, output.ambientOrLightmapUV.rgb);
    #endif

    #ifdef DYNAMICLIGHTMAP_ON
        output.ambientOrLightmapUV.zw = v.uv2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    #endif
}

#if defined(_PER_PIXEL_NORMALS) || defined(_PARALLAXMAP) 
inline float4 calcBinormal(float3 normal, float3 tangent, float tangentSign)
{
    // For odd-negative scale transforms we need to flip the sign
    half sign = tangentSign * unity_WorldTransformParams.w;
    half3 binormal = cross(normal, tangent) * sign;
	return float4(binormal, 1);
}

#endif

#if defined(_PARALLAXMAP) 
inline float3 calcViewForParallax(VertexOutput i)
{
	return float3(i.normalWorld.w, i.tangentWorld.w, i.binormalWorld.w);
}
#endif

inline void calcNormalMapVectors(VertexInputSurface v, inout VertexOutput output)
{
#if defined(_PER_PIXEL_NORMALS) || defined(_PARALLAXMAP) 
	output.tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), 1);
	output.binormalWorld = calcBinormal(output.normalWorld.xyz, output.tangentWorld.xyz, v.tangent.w);
	
#ifdef _PARALLAXMAP
	TANGENT_SPACE_ROTATION;
	half3 viewDirForParallax = mul (rotation, ObjSpaceViewDir(v.vertex));
	output.normalWorld.w = viewDirForParallax.x;
	output.tangentWorld.w = viewDirForParallax.y;
	output.binormalWorld.w = viewDirForParallax.z;
#endif

#endif	
}

inline void dontUpdateVertex(inout VertexInputSurface i)
{
}

inline void dontUpdateFinalColor(VertexOutput i, inout FragmentCommonData d, inout fixed4 color)
{
}

////////////////////////////////////////
// Specular
//

#ifdef _SPECULAR_WORKFLOW

inline SurfaceOutputStandardSpecular getDefaultSpecularSurfaceOuput(VertexOutput o)
{
	SurfaceOutputStandardSpecular surfaceOutput;
	
	half4 specularGloss = SpecularGloss(o.texcoord.xy);
    surfaceOutput.Albedo = Albedo(o.texcoord);
	surfaceOutput.Specular = specularGloss.rgb;
    surfaceOutput.Normal = getTangentSpaceNormal(o);
    surfaceOutput.Emission = Emission(o.texcoord.xy);
    surfaceOutput.Smoothness = specularGloss.a;
    surfaceOutput.Occlusion = Occlusion(o.texcoord.xy);
    surfaceOutput.Alpha = Alpha(o.texcoord.xy);
	
	return surfaceOutput;
}

inline FragmentCommonData getSpecularFragmentCommonData(VertexOutput o, out float occlusion, out half3 emission)
{
	SurfaceOutputStandardSpecular surfaceOutput = GET_SURFACE_PROPERTIES(o);
	
    FragmentCommonData d = (FragmentCommonData)0;

    half oneMinusReflectivity;
    half3 diffColor = EnergyConservationBetweenDiffuseAndSpecular (surfaceOutput.Albedo, surfaceOutput.Specular, /*out*/ oneMinusReflectivity);

    half outputAlpha;
	diffColor = PreMultiplyAlpha (diffColor, surfaceOutput.Alpha, oneMinusReflectivity, /*out*/ outputAlpha);

#if defined(_ALPHATEST_ON)
	clip (outputAlpha - _Cutoff);
#endif

	d.alpha = outputAlpha;
	d.diffColor = diffColor;
	d.eyeVec = -o.viewDir;
    d.posWorld = o.posWorld;
    d.smoothness = surfaceOutput.Smoothness;
	d.normalWorld = getPerPixelWorldNormal(o, surfaceOutput.Normal);
    d.specColor = surfaceOutput.Specular;
    d.oneMinusReflectivity = oneMinusReflectivity;
    
	occlusion = surfaceOutput.Occlusion;
	emission = surfaceOutput.Emission;
	
	return d;
}

#else

////////////////////////////////////////
// Metallic
//

inline SurfaceOutputStandard getDefaultSurfaceOuput(VertexOutput o)
{
	SurfaceOutputStandard surfaceOutput;
	
	half2 metallicGloss = MetallicGloss(o.texcoord.xy);
	surfaceOutput.Albedo = Albedo(o.texcoord);
	surfaceOutput.Normal = getTangentSpaceNormal(o);
	surfaceOutput.Emission = Emission(o.texcoord.xy);
	surfaceOutput.Metallic = metallicGloss.x;
	surfaceOutput.Smoothness = metallicGloss.y;
	surfaceOutput.Occlusion = Occlusion(o.texcoord.xy);
	surfaceOutput.Alpha = Alpha(o.texcoord.xy);

	return surfaceOutput;
}

inline FragmentCommonData getFragmentCommonData(VertexOutput o, out float occlusion, out half3 emission)
{
	SurfaceOutputStandard surfaceOutput = GET_SURFACE_PROPERTIES(o);

	FragmentCommonData d = (FragmentCommonData)0;

	half oneMinusReflectivity;
	half3 specColor;
	half3 diffColor = DiffuseAndSpecularFromMetallic(surfaceOutput.Albedo, surfaceOutput.Metallic, /*out*/ specColor, /*out*/ oneMinusReflectivity);

	half outputAlpha;
	diffColor = PreMultiplyAlpha(diffColor, surfaceOutput.Alpha, oneMinusReflectivity, /*out*/ outputAlpha);

#if defined(_ALPHATEST_ON)
	clip(outputAlpha - _Cutoff);
#endif

	d.alpha = outputAlpha;
	d.diffColor = diffColor;
	d.eyeVec = -o.viewDir;
	d.posWorld = o.posWorld;
	d.smoothness = surfaceOutput.Smoothness;
	d.normalWorld = getPerPixelWorldNormal(o, surfaceOutput.Normal);
	d.specColor = specColor;
	d.oneMinusReflectivity = oneMinusReflectivity;

	occlusion = surfaceOutput.Occlusion;
	emission = surfaceOutput.Emission;

	return d;
}

#endif

////////////////////////////////////////
// Vertex program
//

VertexOutput vert(VertexInputSurface v)
{
	VertexOutput output;
	
	UPDATE_VERTEX(v);
	
	UNITY_SETUP_INSTANCE_ID(v);
    UNITY_INITIALIZE_OUTPUT(VertexOutput, output);
	UNITY_TRANSFER_INSTANCE_ID(v, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

	half3 normal = v.normal;
	
#ifdef _FLIP_NORMALS
	normal = -normal;
#endif	
	
	output.posWorld = mul(unity_ObjectToWorld, v.vertex);
	output.normalWorld = float4(UnityObjectToWorldNormal(normal), 1);
	output.pos = mul(UNITY_MATRIX_VP, output.posWorld);
	
	output.texcoord = getTexCoords(v);
	output.viewDir = WorldSpaceViewDir(v.vertex);

	calcNormalMapVectors(v, output);
	
#if defined(_REQUIRES_WORLD_REFL)
	output.worldRefl = reflect(output.viewDir, output.normalWorld);
#endif
#if defined(_REQUIRES_SCREEN_POS)
	output.screenPos = ComputeScreenPos(output.pos);
#endif
	
	calcAmbientOrLightmapUV(v, output, output.normalWorld);
	
	UNITY_TRANSFER_LIGHTING(output, v.uv1);
	UNITY_TRANSFER_FOG(output, output.pos);
	
	return output;
}

////////////////////////////////////////
// Fragment program
//

fixed4 fragBase(VertexOutput i) : SV_Target
{
	UNITY_SETUP_INSTANCE_ID(i);
	
#if defined(_PARALLAXMAP)
	i.texcoord = Parallax(i.texcoord, calcViewForParallax(i));
#endif	
	i.viewDir = NormalizePerPixelNormal(i.viewDir);
	
	float occlusion;
	half3 emission;
	FragmentCommonData s = GET_FRAGMENT_DATA(i, /*out*/occlusion, /*out*/emission);
	
	UnityLight mainLight = MainLight ();
    UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld);
	
    UnityGI gi = FragmentGI (s, occlusion, i.ambientOrLightmapUV, atten, mainLight);
	
    half4 c = UNITY_BRDF_PBS (s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, i.viewDir, gi.light, gi.indirect);
    c.rgb += emission;
	c.a = s.alpha;
	
	UPDATE_SURFACE_FINAL_COLOR(i, s, c);
	
	UNITY_EXTRACT_FOG(i);
    UNITY_APPLY_FOG(_unity_fogCoord, c.rgb);
	
	return OutputForward(c, c.a);
}

fixed4 fragAdd(VertexOutput i) : SV_Target
{
	UNITY_SETUP_INSTANCE_ID(i);
	
#if defined(_PARALLAXMAP)
	i.texcoord = Parallax(i.texcoord, calcViewForParallax(i));
#endif
	i.viewDir = NormalizePerPixelNormal(i.viewDir);
	
	float occlusion;
	half3 emission;
	FragmentCommonData s = GET_FRAGMENT_DATA(i, /*out*/occlusion, /*out*/emission);
	
	UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld)
	float3 lightWorldDirection = normalize(_WorldSpaceLightPos0.xyz - s.posWorld * _WorldSpaceLightPos0.w);
    UnityLight light = AdditiveLight (lightWorldDirection, atten);
    UnityIndirect noIndirect = ZeroIndirect ();

    half4 c = UNITY_BRDF_PBS (s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, i.viewDir, light, noIndirect);
	
	UPDATE_SURFACE_FINAL_COLOR(i, s, c);
	
	UNITY_EXTRACT_FOG(i);
    UNITY_APPLY_FOG_COLOR(_unity_fogCoord, c.rgb, half4(0,0,0,0)); // fog towards black in additive pass
	
	return OutputForward(c, c.a);
}

#endif // SURFACE_SHADER_SHARED_INCLUDED