Shader "Hair/LongHair"
{
    Properties
    {
        _MainTex ("Clip Map", 2D) = "white" {}
        _FlowMap("Flow Map", 2D) = "white" {}
        
        _RootColor ("Root Color", Color) = (0, 0, 0, 1)
        _TopColor ("Top Color", Color) = (0, 0, 0, 1)
        
        _RoughnessMin("Roughness Min", Float) = 0.3
        _RoughnessMax("Roughness Max", Float) = 0.5
        
        _EccentricityMean("EccentricityMean", Float) = 0
    }
    SubShader
    {
		Pass
		{
			Tags { "RenderType"="AlphaTest" }
			Cull Off
			
			CGPROGRAM
	        #pragma vertex vert
	        #pragma fragment frag
	        #include "UnityCG.cginc"
	        #include "BXDF.cginc"

	        struct appdata
		    {
		        float4 vertex : POSITION;
		        float3 normal : NORMAL;
		        float2 uv     : TEXCOORD0;
		    };
		    
		    struct v2f
			{
		        float4 vertex      : SV_POSITION;
			    float2 uv          : TEXCOORD0;
			    float3 worldNormal : TEXCOORD1;
		    	float3 worldPos    : TEXCOORD2;
			};

	        sampler2D _MainTex;
	        sampler2D _FlowMap;

	        float4 _TopColor;
	        float4 _RootColor;

	        float _RoughnessMin;
	        float _RoughnessMax;

	        float _EccentricityMean;

	        v2f vert(appdata v)
	        {
		        v2f o;
        		o.vertex = UnityObjectToClipPos(v.vertex);
        		o.uv = v.uv;
        		o.worldNormal = UnityObjectToWorldNormal(v.normal);
	        	o.worldPos = mul(unity_ObjectToWorld, v.vertex);
        		return o;
	        }

	        float3 rgb2hsv(float3 c)
			{
				float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
				float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
				float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

				float d = q.x - min(q.w, q.y);
				float e = 1.0e-10;
				return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
			}
			float3 hsv2rgb(float3 c)
			{
				float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
				float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
				return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
			}
	        float ScreenDitherToAlpha(float x, float y, float c0)
			{
				const float dither[64] =
				{
					0, 32, 8, 40, 2, 34, 10, 42,
					48, 16, 56, 24, 50, 18, 58, 26 ,
					12, 44, 4, 36, 14, 46, 6, 38 ,
					60, 28, 52, 20, 62, 30, 54, 22,
					3, 35, 11, 43, 1, 33, 9, 41,
					51, 19, 59, 27, 49, 17, 57, 25,
					15, 47, 7, 39, 13, 45, 5, 37,
					63, 31, 55, 23, 61, 29, 53, 21
				};

				int xMat = int(x) & 7;
				int yMat = int(y) & 7;

				float limit = (dither[yMat * 8 + xMat] + 11.0) / 64.0;
				return lerp(limit*c0, 1.0, c0);
			}

	        float4 frag(v2f i) : SV_Target
	        {
				LongHair hair;

	        	// r: eccentric
	        	// g: 粗糙度
	            // b: 发根还是发梢
				// a: 透明度
	            float4 property = tex2D(_MainTex, i.uv);
	            float4 flow = tex2D(_FlowMap, i.uv);
	            hair.albedo = lerp(_RootColor, _TopColor, property.b);
	        	hair.normal = flow * 2 - 1;
	        	hair.worldNormal = i.worldNormal;
	        	hair.roughness = lerp(_RoughnessMin, _RoughnessMax, property.g);
	        	float2 pixelPos = i.uv * _ScreenParams.xy + _Time.yz * 100; // 像素坐标 随时间抖动
				hair.alpha = ScreenDitherToAlpha(pixelPos.x, pixelPos.y, property.a);
	        	hair.eccentric = lerp(0, _EccentricityMean * 2, property.r);

	        	clip(hair.alpha - 0.5f);

	        	float3 result = 0;
	        	
	        	float3 lightDir = normalize(_WorldSpaceLightPos0 - i.worldPos.xyz);
	        	float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos.xyz);
        		float3 lightColor = unity_LightColor[0].rgb; // 这个是0
        		float3 indirectDiffuse = ShadeSH9(float4(i.worldNormal, 1.0)); // 这个是0

	        	result += /*lightColor * */LongHairBXDF(hair, hair.normal, viewDir, lightDir, 1, 1, 0);
				result += /*indirectDiffuse **/ 6.28 * LongHairBXDF(hair, hair.normal, viewDir, lightDir, 1, 0, 0.2);

	        	return float4(result, hair.alpha);
	        }
	        ENDCG
		}
		Pass
		{
			Tags { "LightMode" = "ShadowCaster" }
			ZWrite On
			ZTest Less
			Cull Off
			Offset 1, 1
			
			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_shadowcaster
			#pragma fragmentoption ARB_precision_hint_fastest
			#include "UnityCG.cginc"

			struct v2f
			 {
				 V2F_SHADOW_CASTER;
				 half2 uv:TEXCOORD1;
			 };

			sampler2D _ClipMap;

			 v2f vert(appdata_base v)
			 {
				 v2f o;
				 o.uv = v.texcoord;
				 TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				 return o;
			 }

			 float4 frag(v2f i) : COLOR
			 {
				 fixed alpha = tex2D(_ClipMap, i.uv).a;
				 clip(alpha - 0.5f);
				 SHADOW_CASTER_FRAGMENT(i)
			 }
			ENDCG
		}
    }
}