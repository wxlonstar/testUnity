#ifndef MYRP_LIT1_INCLUDED
#define MYRP_LIT1_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Shadow/ShadowSamplingTent.hlsl"

//difference between HLSL and CG, you need to explicitly declare
CBUFFER_START(UnityPerFrame)
float4x4 unity_MatrixVP;
CBUFFER_END

CBUFFER_START(UnityPerDraw)
float4x4 unity_ObjectToWorld;
float4 unity_LightIndicesOffsetAndCount;
//.y : number of lights affecting object
float4 unity_4LightIndices0, unity_4LightIndices1;
//2 floats for light indices
CBUFFER_END

#define MAX_VISIBLE_LIGHTS 16
CBUFFER_START(_LightBuffer)
float4 _VisibleLightColors[MAX_VISIBLE_LIGHTS];
float4 _VisibleLightDirectionsOrPositions[MAX_VISIBLE_LIGHTS];
float4 _VisibleLightAttenuations[MAX_VISIBLE_LIGHTS];
float4 _VisibleLightSpotDirections[MAX_VISIBLE_LIGHTS];
CBUFFER_END

CBUFFER_START(_ShadowBuffer)
float4x4 _WorldToShadowMatrices[MAX_VISIBLE_LIGHTS];
float4 _ShadowData[MAX_VISIBLE_LIGHTS];
float4 _ShadowMapSize;  //input this for soft shadows
CBUFFER_END

TEXTURE2D_SHADOW(_ShadowMap);
SAMPLER_CMP(sampler_ShadowMap);

float HardShadowAttenuation(float4 shadowPos) {
	return SAMPLE_TEXTURE2D_SHADOW(_ShadowMap, sampler_ShadowMap, shadowPos.xyz);
}

float SoftShadowAttenuation(float4 shadowPos) {
	//tent filter for soft shadows
	real tentWeights[9];
	real2 tentUVs[9];
	SampleShadow_ComputeSamples_Tent_5x5(
		_ShadowMapSize, shadowPos.xy, tentWeights, tentUVs);

	float attenuation = 0;
	for (int i = 0; i < 9; i++) {
		attenuation += tentWeights[i] * SAMPLE_TEXTURE2D_SHADOW(
			_ShadowMap, sampler_ShadowMap, float3(tentUVs[i].xy, shadowPos.z));
	}
	return attenuation;
}

float ShadowAttenuation(int index , float3 worldPos) {
	
	//cast no shadows
	#if !defined(_SHADOWS_HARD) && !defined(_SHADOWS_SOFT)
		return 1.0;
	#endif

	if (_ShadowData[index].x <= 0) { //shadow strength <=0
		return 1.0; 
	}

	float4 shadowPos = mul(_WorldToShadowMatrices[index], float4(worldPos, 1.0));
	shadowPos.xyz /= shadowPos.w;   //converted to shadow space
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

float3 DiffuseLight(int index, float3 normal, float3 worldPos, float shadowAttenuation) {
	float3 lightColor = _VisibleLightColors[index].rgb;
	float4 lightPositionOrDirection = _VisibleLightDirectionsOrPositions[index];	
	float4 lightAttenuation = _VisibleLightAttenuations[index];
	float3 spotDirection = _VisibleLightSpotDirections[index].xyz;

	//for directional light lightPositionOrDirection.w = 1,
	//for point light = 0
	float3 lightVector = lightPositionOrDirection.xyz -
								worldPos * lightPositionOrDirection.w;
	float3 lightDirection = normalize(lightVector);
	float diffuse = saturate(dot(normal, lightDirection));

	float rangeFade = dot(lightVector, lightVector) * lightAttenuation.x;
	rangeFade = saturate(1.0 - rangeFade * rangeFade);
	rangeFade *= rangeFade;

	float spotFade = dot(spotDirection, lightDirection);
	spotFade = saturate(spotFade * lightAttenuation.z + lightAttenuation.w);
	spotFade *= spotFade;

	float distanceSqr = max(dot(lightVector, lightVector), 0.00001);
	diffuse *= shadowAttenuation * spotFade * rangeFade / distanceSqr;

	return diffuse * lightColor;
}

#define UNITY_MATRIX_M unity_ObjectToWorld

//this must come after our self-defined macros
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

//Instanced Color
UNITY_INSTANCING_BUFFER_START(PerInstance)  //PerInstance is defined in macro
UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
UNITY_INSTANCING_BUFFER_END(PerInstance)


struct VertexInput {
	float4 pos : POSITION;
	float3 normal : NORMAL;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct VertexOutput {
	float4 clipPos : SV_POSITION;
	float3 normal : TEXCOORD0;
	float3 worldPos : TEXCOORD1;
	float3 vertexLighting : TEXCOORD2;

	UNITY_VERTEX_INPUT_INSTANCE_ID
};


VertexOutput LitPassVertex(VertexInput input) {
	VertexOutput output;
	UNITY_SETUP_INSTANCE_ID(input);
	UNITY_TRANSFER_INSTANCE_ID(input, output);  //fragment shader also need this
	float4 worldPos = mul(UNITY_MATRIX_M, float4(input.pos.xyz, 1.0));
	output.clipPos = mul(unity_MatrixVP, worldPos);

	output.normal = mul((float3x3)UNITY_MATRIX_M, input.normal);
	output.worldPos = worldPos.xyz;

	//move 4~8 light to vertex light
	output.vertexLighting = 0;
	for (int i = 4; i < min(unity_LightIndicesOffsetAndCount.y, 8); i++) {
		int lightIndex = unity_4LightIndices1[i - 4];
		output.vertexLighting +=
			DiffuseLight(lightIndex, output.normal, output.worldPos, 1);
	}
	return output;
}

float4 LitPassFragment(VertexOutput input) : SV_TARGET{
	UNITY_SETUP_INSTANCE_ID(input);  //you have to re-setup instance id in fragment shader
	
	input.normal = normalize(input.normal);

	float3 albedo = UNITY_ACCESS_INSTANCED_PROP(PerInstance, _Color).rgb;

	float3 diffuseLight = input.vertexLighting;
	for (int i = 0; i < min(unity_LightIndicesOffsetAndCount.y, 4); i++) {
		int lightIndex = unity_4LightIndices0[i];
		float shadowAttenuation = ShadowAttenuation(lightIndex, input.worldPos);
		diffuseLight += DiffuseLight(lightIndex, input.normal, input.worldPos, shadowAttenuation);
	}

	float3 color = diffuseLight * albedo;
	return float4(color, 1);
}

#endif