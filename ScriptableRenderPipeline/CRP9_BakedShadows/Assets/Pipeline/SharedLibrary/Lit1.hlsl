#ifndef MYRP_LIT1_INCLUDED
#define MYRP_LIT1_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Shadow/ShadowSamplingTent.hlsl"

#define UNITY_MATRIX_M unity_ObjectToWorld
#define UNITY_MATRIX_I_M unity_WorldToObject

//manually enable shadowmask with instancing
#if !defined(LIGHTMAP_ON)
	#if defined(_SHADOWMASK) || defined(_DISTANCE_SHADOWMASK)  || \
		defined(_SUBTRACTIVE_LIGHTING)
			#define SHADOWS_SHADOWMASK
	#endif
#endif

//this must come after our self-defined UNITY_MATRIX_M
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

//for PerceptualRoughnessToMipmapLevel()
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"
//for DecodeHDREnvironment()
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"

#include "Lighting1.hlsl"   //surface struct

struct VertexInput {
	float4 pos : POSITION;
	float3 normal : NORMAL;
	float2 uv : TEXCOORD0;
	float2 lightmapUV : TEXCOORD1;
	float2 dynamicLightmapUV : TEXCOORD2;

	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct VertexOutput {
	float4 clipPos : SV_POSITION;
	float3 normal : TEXCOORD0;
	float3 worldPos : TEXCOORD1;
	float3 vertexLighting : TEXCOORD2;
	float2 uv : TEXCOORD3;
	#if defined(LIGHTMAP_ON)
		float2 lightmapUV : TEXCOORD4;
	#endif
	#if defined(DYNAMICLIGHTMAP_ON)
		float2 dynamicLightmapUV : TEXCOORD5;
	#endif
	UNITY_VERTEX_INPUT_INSTANCE_ID
};


//difference between HLSL and CG, you need to explicitly declare
CBUFFER_START(UnityPerFrame)
float4x4 unity_MatrixVP;
CBUFFER_END

CBUFFER_START(UnityPerDraw)
float4x4 unity_ObjectToWorld, unity_WorldToObject;
float4 unity_LightIndicesOffsetAndCount;
//.y : number of lights affecting object
float4 unity_4LightIndices0, unity_4LightIndices1;
//2 floats for light indices
float4 unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax;
float4 unity_SpecCube0_ProbePosition, unity_SpecCube0_HDR;
float4 unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax;
float4 unity_SpecCube1_ProbePosition, unity_SpecCube1_HDR;

float4 unity_LightmapST, unity_DynamicLightmapST;
//spherical harmonics
float4 unity_SHAr, unity_SHAg, unity_SHAb;
float4 unity_SHBr, unity_SHBg, unity_SHBb;
float4 unity_SHC;

//lightprobe shadows
float4 unity_ProbesOcclusion;

CBUFFER_END

CBUFFER_START(UnityPerCamera)
float3 _WorldSpaceCameraPos;
CBUFFER_END

CBUFFER_START(UnityPerMaterial)
float4 _MainTex_ST;
float _Cutoff;
CBUFFER_END

UNITY_INSTANCING_BUFFER_START(PerInstance)  //PerInstance is defined in macro
UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
UNITY_DEFINE_INSTANCED_PROP(float, _Smoothness)
UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
UNITY_DEFINE_INSTANCED_PROP(float4, _EmissionColor)
UNITY_INSTANCING_BUFFER_END(PerInstance)

#define MAX_VISIBLE_LIGHTS 16
CBUFFER_START(_LightBuffer)
float4 _VisibleLightColors[MAX_VISIBLE_LIGHTS];
float4 _VisibleLightDirectionsOrPositions[MAX_VISIBLE_LIGHTS];
float4 _VisibleLightAttenuations[MAX_VISIBLE_LIGHTS];
float4 _VisibleLightSpotDirections[MAX_VISIBLE_LIGHTS];
float4 _VisibleLightOcclusionMasks[MAX_VISIBLE_LIGHTS];  //shadowmask for each light
CBUFFER_END

CBUFFER_START(_ShadowBuffer)
float4x4 _WorldToShadowMatrices[MAX_VISIBLE_LIGHTS];
float4 _ShadowData[MAX_VISIBLE_LIGHTS];
float4 _ShadowMapSize;  //input this for soft shadows
float4 _GlobalShadowData;

float4x4 _WorldToShadowCascadeMatrices[5];
float4 _CascadedShadowMapSize;
float _CascadedShadowStrength;
float4 _CascadeCullingSpheres[4];
float _CascadeNumbers;

float4 _SubtractiveShadowColor;   //for subtractive lighting
CBUFFER_END

TEXTURE2D_SHADOW(_ShadowMap);
SAMPLER_CMP(sampler_ShadowMap);

TEXTURE2D_SHADOW(_CascadedShadowMap);
SAMPLER_CMP(sampler_CascadedShadowMap);

TEXTURE2D(_MainTex);
SAMPLER(sampler_MainTex);

TEXTURECUBE(unity_SpecCube0);
TEXTURECUBE(unity_SpecCube1);
SAMPLER(samplerunity_SpecCube0);

TEXTURE2D(unity_Lightmap);
SAMPLER(samplerunity_Lightmap);

TEXTURE2D(unity_ShadowMask);
SAMPLER(samplerunity_ShadowMask);

//LPPV
CBUFFER_START(UnityProbeVolume)
float4 unity_ProbeVolumeParams;
float4x4 unity_ProbeVolumeWorldToObject;
float3 unity_ProbeVolumeSizeInv;
float3 unity_ProbeVolumeMin;
CBUFFER_END

TEXTURE3D_FLOAT(unity_ProbeVolumeSH);
SAMPLER(samplerunity_ProbeVolumeSH);

TEXTURE2D(unity_DynamicLightmap);
SAMPLER(samplerunity_DynamicLightmap);


float3 SampleLightProbes(LitSurface s) {
	
	if (unity_ProbeVolumeParams.x) {
		//use LPPV
		return SampleProbeVolumeSH4(
			TEXTURE3D_PARAM(unity_ProbeVolumeSH, samplerunity_ProbeVolumeSH),
			s.position, s.normal, unity_ProbeVolumeWorldToObject,
			unity_ProbeVolumeParams.y, unity_ProbeVolumeParams.z,
			unity_ProbeVolumeMin, unity_ProbeVolumeSizeInv
		);
	}
	else {
		//use light map, spherical harmonics
		float4 coefficients[7];
		coefficients[0] = unity_SHAr;
		coefficients[1] = unity_SHAg;
		coefficients[2] = unity_SHAb;
		coefficients[3] = unity_SHBr;
		coefficients[4] = unity_SHBg;
		coefficients[5] = unity_SHBb;
		coefficients[6] = unity_SHC;
		return max(0.0, SampleSH9(coefficients, s.normal));
	}

}

float InsideCascadeCullingSphere(int index, float3 worldPos) {
	float4 s = _CascadeCullingSpheres[index];
	return dot(worldPos - s.xyz, worldPos - s.xyz) < s.w;
}

float RealtimeToBakedShadowsInterpolator(float3 worldPos) {
	//return blend factor of shadows at shadow distance
	float d = distance(worldPos, _WorldSpaceCameraPos);
	return saturate(d * _GlobalShadowData.y + _GlobalShadowData.z);
}

float MixRealtimeAndBakedShadowAttenuation(
	float realtime, float4 bakedShadows, int lightIndex, 
	float3 worldPos, bool isMainLight = false) {

	float t = RealtimeToBakedShadowsInterpolator(worldPos);  //blend 
	float fadedRealtime = saturate(realtime+t); //realtime = 0 or 1
	float4 occlusionMask = _VisibleLightOcclusionMasks[lightIndex];

	float baked = dot(bakedShadows, occlusionMask);
	bool hasBakedShadows = occlusionMask.x >= 0.0;

	#if defined(_SHADOWMASK)
		if (hasBakedShadows) {
			return min(fadedRealtime, baked);
		}
	#elif defined(_DISTANCE_SHADOWMASK)
		if (hasBakedShadows) {
			bool bakedOnly = _VisibleLightSpotDirections[lightIndex].w > 0.0;
			// >0 is point light
			if (!isMainLight && bakedOnly) {
				return baked;
			}
			return lerp(realtime, baked, t);
		}
	#elif defined(_SUBTRACTIVE_LIGHTING)
		#if !defined(LIGHTMAP_ON)
			if (isMainLight) {
				return min(fadedRealtime, bakedShadows.x);
			}
		#endif
		#if !defined(_CASCADED_SHADOWS_HARD) && !defined(_CASCADED_SHADOWS_SOFT)
			if (lightIndex == 0) {
				return bakedShadows.x;
			}
		#endif
	#endif
	return fadedRealtime;
}

bool SkipRealtimeShadows(float3 worldPos) {
	//flag of realtime shadows
	return RealtimeToBakedShadowsInterpolator(worldPos) >= 1.0;
}

float HardShadowAttenuation(float4 shadowPos, bool cascade = false) {
	if (cascade) {
		return SAMPLE_TEXTURE2D_SHADOW(_CascadedShadowMap, sampler_CascadedShadowMap, shadowPos.xyz);
	}
	else {
		return SAMPLE_TEXTURE2D_SHADOW(_ShadowMap, sampler_ShadowMap, shadowPos.xyz);
	}
}

float SoftShadowAttenuation(float4 shadowPos, bool cascade = false) {
	//tent filter for soft shadows
	real tentWeights[9];
	real2 tentUVs[9];

	float4 size = cascade ? _CascadedShadowMapSize : _ShadowMapSize;

	SampleShadow_ComputeSamples_Tent_5x5(
		size, shadowPos.xy, tentWeights, tentUVs);

	float attenuation = 0;
	for (int i = 0; i < 9; i++) {
		attenuation += tentWeights[i] * HardShadowAttenuation(
					float4(tentUVs[i].xy, shadowPos.z, 0), cascade);
	}
	return attenuation;
}


float ShadowAttenuation(int index , float3 worldPos) {
	
	//cast no shadows
	#if !defined(_RECEIVE_SHADOWS)
		return 1.0;
	#elif !defined(_SHADOWS_HARD) && !defined(_SHADOWS_SOFT)
		return 1.0;
	#endif

	if (_ShadowData[index].x <= 0 || SkipRealtimeShadows(worldPos) ) { 
		//shadow strength <=0  OR  beyond shadow distance
		return 1.0; 
	}

	float4 shadowPos = mul(_WorldToShadowMatrices[index], float4(worldPos, 1.0));
	shadowPos.xyz /= shadowPos.w;   //converted to shadow space

	//clamp and move to tiled position
	shadowPos.xy = saturate(shadowPos.xy);
	shadowPos.xy = shadowPos.xy * _GlobalShadowData.x + _ShadowData[index].zw;

	float attenuation;
	
	#if defined(_SHADOWS_HARD)
		#if defined(_SHADOWS_SOFT)
			//Case1 : exist both hard and soft 
			if (_ShadowData[index].y == 0) {  //hard shadows
				attenuation = HardShadowAttenuation(shadowPos);
			}
			else {
				attenuation = SoftShadowAttenuation(shadowPos);
			}
		#else 
			//Case2 : exist only hard
			attenuation = HardShadowAttenuation(shadowPos);
		#endif
	#else
		//Case3 : exist only soft
		attenuation = SoftShadowAttenuation(shadowPos);
	#endif

	return lerp(1, attenuation, _ShadowData[index].x);
	
}


float CascadedShadowAttenuation(float3 worldPos, bool applyStrength = true) {
	
	#if !defined(_RECEIVE_SHADOWS)
		return 1.0;
	#elif !defined(_CASCADED_SHADOWS_HARD) && !defined(_CASCADED_SHADOWS_SOFT)
		return 1.0;
	#endif
	
	if(!InsideCascadeCullingSphere(_CascadeNumbers -1, worldPos)){
		return 1.0;
	}
	
	if ( SkipRealtimeShadows(worldPos) ) {
		return 1.0;
	}

	float4 cascadeFlags = float4(
		InsideCascadeCullingSphere(0, worldPos),
		InsideCascadeCullingSphere(1, worldPos),
		InsideCascadeCullingSphere(2, worldPos),
		InsideCascadeCullingSphere(3, worldPos)
		);
	/*	(1, 1, 1, 1) ->(1, 0, 0, 0) -> 0
		(0, 1, 1, 1) ->(0, 1, 0, 0) -> 1
		(0, 0, 1, 1) ->(0, 0, 1, 0) -> 2
		(0, 0, 0, 1) ->(0, 0, 0, 1) -> 3
		(0, 0, 0, 0) ->(0, 0, 0, 0) -> 4 */
	//	return dot(cascadeFlags, 0.25);  //if you wish to visualize cascade ranges
	cascadeFlags.yzw = saturate(cascadeFlags.yzw - cascadeFlags.xyz);
	float cascadeIndex = 4 - dot(cascadeFlags, float4(4,3,2,1));

	float4 shadowPos = mul(
		_WorldToShadowCascadeMatrices[cascadeIndex], float4(worldPos, 1.0)
	);
	float attenuation;
	#if defined(_CASCADED_SHADOWS_HARD)
		attenuation = HardShadowAttenuation(shadowPos, true);
	#else
		attenuation = SoftShadowAttenuation(shadowPos, true);
	#endif

	if (applyStrength) {
		return lerp(1, attenuation, _CascadedShadowStrength);
	}
	else {
		return attenuation;   // for subtractive lighting
	}
}

float3 MainLight(LitSurface s, float shadowAttenuation) {
	//a DiffuseLight applied only to light index 0
	float3 lightColor = _VisibleLightColors[0].rgb;
	float3 lightDirection = _VisibleLightDirectionsOrPositions[0].xyz;
	float3 color = LightSurface(s, lightDirection);
	color *= shadowAttenuation;
	return color * lightColor;
}

float3 GenericLight(int index, LitSurface s, float shadowAttenuation) {
	float3 lightColor = _VisibleLightColors[index].rgb;
	float4 lightPositionOrDirection = _VisibleLightDirectionsOrPositions[index];	
	float4 lightAttenuation = _VisibleLightAttenuations[index];
	float3 spotDirection = _VisibleLightSpotDirections[index].xyz;

	//for directional light lightPositionOrDirection.w = 1,
	//for point light = 0
	float3 lightVector = lightPositionOrDirection.xyz -
								s.position * lightPositionOrDirection.w;
	float3 lightDirection = normalize(lightVector);
	float3 color = LightSurface(s, lightDirection);

	float rangeFade = dot(lightVector, lightVector) * lightAttenuation.x;
	rangeFade = saturate(1.0 - rangeFade * rangeFade);
	rangeFade *= rangeFade;

	float spotFade = dot(spotDirection, lightDirection);
	spotFade = saturate(spotFade * lightAttenuation.z + lightAttenuation.w);
	spotFade *= spotFade;

	float distanceSqr = max(dot(lightVector, lightVector), 0.00001);
	color *= shadowAttenuation * spotFade * rangeFade / distanceSqr;

	return color * lightColor;
}

VertexOutput LitPassVertex(VertexInput input) {
	VertexOutput output;
	UNITY_SETUP_INSTANCE_ID(input);
	UNITY_TRANSFER_INSTANCE_ID(input, output);  //fragment shader also need this
	float4 worldPos = mul(UNITY_MATRIX_M, float4(input.pos.xyz, 1.0));
	output.clipPos = mul(unity_MatrixVP, worldPos);

	#if defined(UNITY_ASSUME_UNIFORM_SCALING)
		output.normal = mul((float3x3)UNITY_MATRIX_M, input.normal);
	#else
		output.normal = normalize(mul(input.normal, (float3x3)UNITY_MATRIX_I_M));
	#endif
	output.worldPos = worldPos.xyz;

	//move 4~8 light to vertex light
	LitSurface surface = GetLitSurfaceVertex(output.normal, output.worldPos);
	output.vertexLighting = 0;
	for (int i = 4; i < min(unity_LightIndicesOffsetAndCount.y, 8); i++) {
		int lightIndex = unity_4LightIndices1[i - 4];
		output.vertexLighting +=
			GenericLight(lightIndex, surface, 1);
	}

	output.uv = TRANSFORM_TEX(input.uv, _MainTex);
	#if defined(LIGHTMAP_ON)
		output.lightmapUV =
			input.lightmapUV * unity_LightmapST.xy + unity_LightmapST.zw;
	#endif

	#if defined(DYNAMICLIGHTMAP_ON)
		output.dynamicLightmapUV =
			input.dynamicLightmapUV * unity_DynamicLightmapST.xy +
			unity_DynamicLightmapST.zw;
	#endif
	return output;
}


float3 BoxProjection(
	float3 direction, float3 position,
	float4 cubemapPosition, float4 boxMin, float4 boxMax
) {
	UNITY_BRANCH
		if (cubemapPosition.w > 0) {
			float3 factors =
				((direction > 0 ? boxMax.xyz : boxMin.xyz) - position) / direction;
			float scalar = min(min(factors.x, factors.y), factors.z);
			direction = direction * scalar + (position - cubemapPosition.xyz);
		}
	return direction;
}


float3 SampleEnvironment(LitSurface s) {
	//sample environment from reflection probe

	float3 reflectVector = reflect(-s.viewDir, s.normal);
	float mip = PerceptualRoughnessToMipmapLevel(s.perceptualRoughness);

	float3 uvw = BoxProjection(
		reflectVector, s.position, unity_SpecCube0_ProbePosition,
		unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax
	);
	float4 sample = SAMPLE_TEXTURECUBE_LOD(
		unity_SpecCube0, samplerunity_SpecCube0, uvw, mip
	);
	float3 color = DecodeHDREnvironment(sample, unity_SpecCube0_HDR);

	// blend with a second probe
	float blend = unity_SpecCube0_BoxMin.w;
	if (blend < 0.99999) {
		uvw = BoxProjection(
			reflectVector, s.position,
			unity_SpecCube1_ProbePosition,
			unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax
		);
		sample = SAMPLE_TEXTURECUBE_LOD(
			unity_SpecCube1, samplerunity_SpecCube0, uvw, mip
		);
		color = lerp(DecodeHDREnvironment(sample, unity_SpecCube0_HDR), color, blend);
	}
	return color;
}


float3 SampleLightmap(float2 uv) {
	return SampleSingleLightmap(
		TEXTURE2D_PARAM(unity_Lightmap, samplerunity_Lightmap), uv,
		float4(1,1,0,0),
		#if defined(UNITY_LIGHTMAP_FULL_HDR)
			false,
		#else
			true,
		#endif
		float4(LIGHTMAP_HDR_MULTIPLIER, LIGHTMAP_HDR_EXPONENT, 0.0, 0.0)
	);
}

float3 SampleDynamicLightmap(float2 uv) {
	return SampleSingleLightmap(
		TEXTURE2D_PARAM(unity_DynamicLightmap, samplerunity_DynamicLightmap), uv,
		float4(1, 1, 0, 0), false,
		float4(LIGHTMAP_HDR_MULTIPLIER, LIGHTMAP_HDR_EXPONENT, 0.0, 0.0)
	);
}

float3 SubtractiveLighting(LitSurface s, float3 bakedLighting) {
	//a second processing for baked lighting
	float3 lightColor = _VisibleLightColors[0].rgb;
	float3 lightDirection = _VisibleLightDirectionsOrPositions[0].xyz;
	float3 diffuse = lightColor * saturate(dot(lightDirection, s.normal));
	float shadowAttenuation = saturate(
		CascadedShadowAttenuation(s.position, false) +
		RealtimeToBakedShadowsInterpolator(s.position)
	);
	float3 shadowedLightingGuess = diffuse * (1.0 - shadowAttenuation);
	float3 subtractedLighting = bakedLighting - shadowedLightingGuess;
	subtractedLighting = max(subtractedLighting, _SubtractiveShadowColor);
	subtractedLighting =
		lerp(bakedLighting, subtractedLighting, _CascadedShadowStrength);

	return min(bakedLighting, subtractedLighting);
}

float3 GlobalIllumination(VertexOutput input, LitSurface surface) {
	#if defined(LIGHTMAP_ON)
		float3 gi = SampleLightmap(input.lightmapUV);
		#if defined(_SUBTRACTIVE_LIGHTING)
			gi = SubtractiveLighting(surface, gi);
		#endif

		#if defined(DYNAMICLIGHTMAP_ON)
			//double map 
			gi += SampleDynamicLightmap(input.dynamicLightmapUV);
		#endif
		return gi;
	#elif defined(DYNAMICLIGHTMAP_ON)
		return SampleDynamicLightmap(input.dynamicLightmapUV);
	#else
		return SampleLightProbes(surface);
	#endif
	return 0;
}

float4 BakedShadows(VertexOutput input, LitSurface surface) {
	#if defined(LIGHTMAP_ON)
		#if defined(_SHADOWMASK) || defined(_DISTANCE_SHADOWMASK)
			return SAMPLE_TEXTURE2D(
				unity_ShadowMask, samplerunity_ShadowMask, input.lightmapUV
			);
		#endif
	#elif defined(_SHADOWMASK) || defined(_DISTANCE_SHADOWMASK)  || \
			defined(_SUBTRACTIVE_LIGHTING)
		if (unity_ProbeVolumeParams.x) {
			//LPPV Shadows
			return SampleProbeOcclusion(
				TEXTURE3D_PARAM(unity_ProbeVolumeSH, samplerunity_ProbeVolumeSH),
				surface.position, unity_ProbeVolumeWorldToObject,
				unity_ProbeVolumeParams.y, unity_ProbeVolumeParams.z,
				unity_ProbeVolumeMin, unity_ProbeVolumeSizeInv
			);
		}
		return  unity_ProbesOcclusion;
	#endif
	return 1.0;
}

float4 LitPassFragment(VertexOutput input, 
	FRONT_FACE_TYPE isFrontFace : FRONT_FACE_SEMANTIC ) : SV_TARGET{
	UNITY_SETUP_INSTANCE_ID(input);  //you have to re-setup instance id in fragment shader
	
	input.normal = normalize(input.normal);
	input.normal = IS_FRONT_VFACE(isFrontFace, input.normal, -input.normal);

	float4 albedoAlpha = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
	albedoAlpha *= UNITY_ACCESS_INSTANCED_PROP(PerInstance, _Color);

	//transparency , cutoff mode
	#if defined(_CLIPPING_ON)
		clip(albedoAlpha.a - _Cutoff);
	#endif
	
	//surface processing
	float3 viewDir = normalize(_WorldSpaceCameraPos - input.worldPos.xyz);
	LitSurface surface = GetLitSurface(
		input.normal, input.worldPos, viewDir,
		albedoAlpha.rgb, 
		UNITY_ACCESS_INSTANCED_PROP(PerInstance, _Metallic),
		UNITY_ACCESS_INSTANCED_PROP(PerInstance, _Smoothness)
	);

	#if defined(_PREMULTIPLY_ALPHA)
		PremultiplyAlpha(surface, albedoAlpha.a);
	#endif

	float4 bakedShadows = BakedShadows(input, surface);

	float3 color = input.vertexLighting * surface.diffuse;

	#if defined(_CASCADED_SHADOWS_HARD) || defined(_CASCADED_SHADOWS_SOFT)
		#if !(defined(LIGHTMAP_ON) && defined(_SUBTRACTIVE_LIGHTING))
		//blend realtime shadow with baked
		float shadowAttenuation = MixRealtimeAndBakedShadowAttenuation(
			CascadedShadowAttenuation(surface.position), bakedShadows, 
			0, surface.position, true
		);
		color += MainLight(surface, shadowAttenuation);
		#endif
	#endif

	for (int i = 0; i < min(unity_LightIndicesOffsetAndCount.y, 4); i++) {
		int lightIndex = unity_4LightIndices0[i];
		float shadowAttenuation = MixRealtimeAndBakedShadowAttenuation(
			ShadowAttenuation(lightIndex, surface.position), bakedShadows,
			lightIndex, surface.position
		);
		color += GenericLight(lightIndex, surface, shadowAttenuation);
	}

	color += ReflectEnvironment(surface, SampleEnvironment(surface));
	
	color += GlobalIllumination(input, surface) * surface.diffuse;
	//color = GlobalIllumination(input, surface);

	color += UNITY_ACCESS_INSTANCED_PROP(PerInstance, _EmissionColor).rgb;

	return float4(color, albedoAlpha.a);
}

#endif