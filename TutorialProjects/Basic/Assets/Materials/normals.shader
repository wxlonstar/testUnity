﻿// Use color to show vertex normal directions


Shader "Custom/SurfaceShader_01"
{
	SubShader{
		Pass{
		CGPROGRAM

		#pragma vertex vert
		#pragma fragment frag
		
		#include "UnityCG.cginc"

		struct a2v {
		float4 vertex : POSITION;
		float3 normal : NORMAL;
		float4 texcoord : TEXCOORD0;
		};
		
		struct v2f {
			float4 pos : SV_POSITION;
			fixed3 color : COLOR0;
		};
		
		v2f vert(a2v v){
			v2f o;
			o.pos = UnityObjectToClipPos(v.vertex);
			o.color = UnityObjectToWorldNormal(v.normal) * 0.5 + fixed3(0.5, 0.5, 0.5);
			return o;
		}

		fixed4 frag(v2f i) : SV_Target{
			fixed4 c = 0;
			c.rgb = i.color;
			return c;
		}
		ENDCG
		}
	}
}
