#if !defined(MYLIGHTING_INCLUDED)
#define MYLIGHTING_INCLUDED

#include "AutoLight.cginc"
#include "UnityPBSLighting.cginc"

struct VertexData {
float4 position : POSITION;
float3 normal : NORMAL;
float2 uv : TEXCOORD0;
};

struct Interpolators {
float4 position : SV_POSITION;
float2 uv : TEXCOORD0;
float3 normal : TEXCOORD1;
float3 worldPos : TEXCOORD2;

#if defined(VERTEXLIGHT_ON)
float3 vertexLightColor : TEXCOORD3;
#endif

#if defined(SHADOWS_SCREEN)
float4 shadowCoordinates : TEXCOORD4;
#endif

};

sampler2D _MainTex;
float4 _MainTex_ST;
float4 _Tint;
float _Smoothness;
float _Metallic;

void ComputeVertexLightColor(inout Interpolators i) {

	#if defined(VERTEXLIGHT_ON)
		i.vertexLightColor = Shade4PointLights(
			unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
			unity_LightColor[0].rgb, unity_LightColor[1].rgb,
			unity_LightColor[2].rgb, unity_LightColor[3].rgb,
			unity_4LightAtten0, i.worldPos, i.normal
		);
	#endif
}

Interpolators MyVertexProgram(VertexData v) {
	Interpolators i;
	i.uv = TRANSFORM_TEX(v.uv, _MainTex);
	i.position = UnityObjectToClipPos(v.position);
	i.worldPos = mul(unity_ObjectToWorld, v.position);
	i.normal = mul(transpose((float3x3)unity_WorldToObject), v.normal);  //world space normals
	i.normal = normalize(i.normal);

	#if defined(SHADOWS_SCREEN)
		//dx11 upsidedown, -y
		i.shadowCoordinates.xy = (float2(i.position.x, -i.position.y)+ i.position.w) * 0.5;
		i.shadowCoordinates.zw = i.position.zw;
	#endif

	ComputeVertexLightColor(i);
	return i;
}

UnityLight CreateLight(Interpolators i) {
	UnityLight light;
	//for directional light , _WorldSpaceLightPos0 contains direction
	//fir point light, directions need to be calculated
	#if defined(POINT) || defined(POINT_COOKIE) || defined(SPOT)
		light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos);
	#else
		light.dir = _WorldSpaceLightPos0.xyz;
	#endif

	#if defined(SHADOWS_SCREEN)
		float attenuation = tex2D(_ShadowMapTexture, i.shadowCoordinates.xy / i.shadowCoordinates.w);
	#else
		//attenuation should be 0 at maximum light range
		//this function switches with #define POINT in its Pass{}
		UNITY_LIGHT_ATTENUATION(attenuation, 0, i.worldPos);
	#endif

	light.color = _LightColor0.rgb * attenuation;

	light.ndotl = DotClamped(i.normal, light.dir);
	return light;
}

UnityIndirect CreateIndirectLight(Interpolators i) {

	UnityIndirect indirectLight;
	indirectLight.diffuse = 0;
	indirectLight.specular = 0;
	#if defined(VERTEXLIGHT_ON)
		indirectLight.diffuse = i.vertexLightColor;
	#endif

	//spherical harmonics
	#if defined(FORWARD_BASE_PASS)
		indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)));
	#endif
	return indirectLight;
}

float4 MyFragmentProgram(Interpolators i) : SV_TARGET{
	i.normal = normalize(i.normal);

	float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
	float3 albedo = tex2D(_MainTex, i.uv).rgb * _Tint.rgb;  //use Texture as albedo

	float3 specularTint;
	float oneMinusReflectivity;
	albedo = DiffuseAndSpecularFromMetallic(
		albedo, _Metallic, specularTint, oneMinusReflectivity
	);

	UnityLight light = CreateLight(i);

	UnityIndirect indirectLight = CreateIndirectLight(i);

	return UNITY_BRDF_PBS(
		albedo, specularTint,
		oneMinusReflectivity, _Smoothness,
		i.normal, viewDir,
		light, indirectLight
	);
}

#endif