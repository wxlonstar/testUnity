﻿// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/TexturedShaderWithDetail"
{
	Properties{
		_MainTex("Texture", 2D) = "white" {}
		_DetailTex("Detail Texture", 2D) = "gray" {}
	}

		SubShader
		{
			Pass{
			CGPROGRAM

			#pragma vertex MyVertexProgram
			#pragma fragment MyFragmentProgram

			#include "UnityCG.cginc"

			struct VertexData {
					float4 position : POSITION;
					float2 uv : TEXCOORD0;
				};

			struct Interpolators {
					float4 position : SV_POSITION;
					float2 uv : TEXCOORD0;
					float2 uvDetail : TEXCOORD1;
				};

			sampler2D _MainTex, _DetailTex;
			float4 _MainTex_ST, _DetailTex_ST;

			Interpolators MyVertexProgram(VertexData v
				) {
					Interpolators i;
					i.position = UnityObjectToClipPos(v.position);
					i.uv = TRANSFORM_TEX(v.uv, _MainTex);
					i.uvDetail = TRANSFORM_TEX(v.uv, _DetailTex);
					return i;
				}

			float4 MyFragmentProgram(Interpolators i) : SV_TARGET{
				float4 color = tex2D(_MainTex, i.uv);
				color *= tex2D(_DetailTex, i.uvDetail) * 2;
				return color;
			}

			ENDCG
			}

		}
}
