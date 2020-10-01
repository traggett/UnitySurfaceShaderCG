#ifndef EXAMPLE_SHADER_INCLUDED
#define EXAMPLE_SHADER_INCLUDED

#include "CGIncludes/SurfaceShaderStructs.cginc"
#include "UnityStandardCore.cginc"

////////////////////////////////////////
// Use this to update data in the per vertex pass
//

#define UPDATE_VERTEX updateVertex

inline void updateVertex(inout VertexInputSurface i)
{
	//Stretch vertex position over time
	float3 wobble = _CosTime[3] * i.vertex.x;
	i.vertex.xyz += wobble;
}

////////////////////////////////////////
// Use this to update data in the per pixel pass
//

#define GET_SURFACE_PROPERTIES getSurfaceOuput

SurfaceOutputStandard getSurfaceOuput(VertexOutput o)
{
	SurfaceOutputStandard surfaceOutput;
	
	//This is a standard unity surface
	half2 metallicGloss = MetallicGloss(o.texcoord.xy);
	surfaceOutput.Albedo = Albedo(o.texcoord);
	surfaceOutput.Normal = getTangentSpaceNormal(o);
	surfaceOutput.Emission = Emission(o.texcoord.xy);
	surfaceOutput.Metallic = metallicGloss.x;
	surfaceOutput.Smoothness = metallicGloss.y;
	surfaceOutput.Occlusion = Occlusion(o.texcoord.xy);
	surfaceOutput.Alpha = Alpha(o.texcoord.xy);
	
	//Lerp albedo to red over time
	float flash = (_SinTime[3] + 1) * 0.5;
	surfaceOutput.Albedo = lerp(surfaceOutput.Albedo, half3(1,0,0), flash);
	
	return surfaceOutput;
}

#include "Assets/ThirdParty/UnitySurfaceShaderCG/SurfaceShaderCG/CGIncludes/SurfaceShaderShared.cginc"

#endif // EXAMPLE_SHADER_INCLUDED