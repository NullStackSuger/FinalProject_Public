Shader "Diffraction/Diffraction"
{
    Properties
    {
        _NoiseTex("Noise Tex", 2D) = "white"{}
        _NoiseStrength("Noise Strength", Range(0, 1)) = 1
        _NoiseOffset ("Noise Offset", Float) = 0
        _Alpha("Alpha", Range(0, 1)) = 1
        _DiffuseColor("Diffuse Color", Color) = (0.1, 0.1, 0.1, 1)
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" }

        Pass
        {
            CGPROGRAM
            /*#pragma surface surf Diffraction fullforwardshadows
            #include "UnityPBSLighting.cginc"
            
            struct Input
            {
                float2 uv_MainTex;
            };
            
            sampler2D _NoiseTex;
            float _NoiseStrength;
            float _Alpha;
            float4 _DiffuseColor;

            void surf (Input IN, inout SurfaceOutputStandard o)
            {
                o.Albedo = _DiffuseColor.rgb;
                o.Alpha = _Alpha;
                o.Smoothness = 1;
                o.Metallic = 0;
            }
            
            inline fixed3 bump3y (fixed3 x, fixed3 yoffset)
            {
                float3 y = 1 - x * x;
                y = saturate(y-yoffset);
                return y;
            }
            fixed3 spectral_zucconi6 (float w)
            {
                // w: [400, 700]
                // x: [0,   1]
                fixed x = saturate((w - 400.0)/ 300.0);
                const float3 c1 = float3(3.54585104, 2.93225262, 2.41593945);
                const float3 x1 = float3(0.69549072, 0.49228336, 0.27699880);
                const float3 y1 = float3(0.02312639, 0.15225084, 0.52607955);
                const float3 c2 = float3(3.90307140, 3.21182957, 3.96587128);
                const float3 x2 = float3(0.11748627, 0.86755042, 0.66077860);
                const float3 y2 = float3(0.84897130, 0.88445281, 0.73949448);
                return bump3y(c1 * (x - x1), y1) + bump3y(c2 * (x - x2), y2) ;
            }
            
            float4 LightingDiffraction(SurfaceOutputStandard s, float3 viewDir, UnityGI gi)
            {
                float4 pbr = LightingStandard(s, viewDir, gi);
                
                float3 L = gi.light.dir;
                float3 N = worldNormal;
                float d = _Distance;
                float cos_ThetaL = dot(L, N);
                float thetaL = acos(cos_ThetaL);
                float sin_ThetaR = _N1 / _N2 * sin(thetaL);
                float thetaR = asin(sin_ThetaR);
                float u = _N2 * 2 * d * abs(cos(thetaR));
                
                float3 color = 0;
                for(int n = 1; n <= 8; ++n)
                {
                    float waveLength = u / n;
                    color += spectral_zucconi6(waveLength);
                }
                color = saturate(color);
                
                pbr.rgb += color;
                return pbr;
            }
            float4 LightingDiffraction_Spec(SurfaceOutputStandard s, float3 viewDir, UnityGI gi, Input IN)
            {
                return LightingDiffraction(s, viewDir, gi);
            }
            void LightingDiffraction_GI(SurfaceOutputStandard s, UnityGIInput data, inout UnityGI gi)
            {
                LightingStandard_GI(s, data, gi);
            }*/
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "UnityPBSLighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };
            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float3 worldPosition : TEXCOORD2;
            };

            float2 UVCombine(float2 uv, float4 st)
            {
                return uv * st.xy + st.zw;
            }
            float remap(float original_value, float original_min, float original_max, float new_min, float new_max)
            {
                return new_min + (original_value - original_min) / (original_max - original_min) * (new_max - new_min);
            }

            sampler2D _NoiseTex;
            float4 _NoiseTex_ST;
            float _NoiseStrength;
            float _NoiseOffset;
            float _Alpha;
            float4 _DiffuseColor;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.worldPosition = mul(unity_ObjectToWorld, v.vertex);
                return o;
            }
            inline fixed3 bump3y (fixed3 x, fixed3 yoffset)
            {
                float3 y = 1 - x * x;
                y = saturate(y-yoffset);
                return y;
            }
            fixed3 spectral_zucconi6 (float w)
            {
                // w: [400, 700]
                // x: [0,   1]
                fixed x = saturate((w - 400.0)/ 300.0);
                const float3 c1 = float3(3.54585104, 2.93225262, 2.41593945);
                const float3 x1 = float3(0.69549072, 0.49228336, 0.27699880);
                const float3 y1 = float3(0.02312639, 0.15225084, 0.52607955);
                const float3 c2 = float3(3.90307140, 3.21182957, 3.96587128);
                const float3 x2 = float3(0.11748627, 0.86755042, 0.66077860);
                const float3 y2 = float3(0.84897130, 0.88445281, 0.73949448);
                return bump3y(c1 * (x - x1), y1) + bump3y(c2 * (x - x2), y2) ;
            }
            float4 frag (v2f i ) : SV_Target
            {
                float3 N = normalize(i.normal);
                float3 V = normalize( UnityWorldSpaceViewDir(i.worldPosition.xyz));
                float NoV = abs(dot(N, V));

                float noise = tex2D(_NoiseTex, UVCombine(i.uv, _NoiseTex_ST)).r;
                noise = remap(noise, 0, 1, -1, 1);
                noise = noise * _NoiseStrength + _NoiseOffset;
                noise = remap(noise, 0, 1, 0, 450);

                float3 color = 0;
                float value = 2.66 * NoV * noise;
                for (int n = -4; n <= 4; ++n)
                {
                    float waveLength = value / (n + 0.5);
                    color += spectral_zucconi6(waveLength);
                }
                color = saturate(color);
                
                return float4(_DiffuseColor.rgb + color, _Alpha);
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}