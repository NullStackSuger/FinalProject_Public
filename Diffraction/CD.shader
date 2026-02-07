Shader "Diffraction/CD"
{
    Properties
    {
        _Color ("Color", Color) = (1, 1, 1, 1)
        _MainTex ("Texture", 2D) = "white"{}
        _Glossiness("Smoothness", Range(0, 1)) = 0.5
        _Metallic("Metallic", Range(0, 1)) = 0
        _Distance("Grating Distance", Range(0, 10000)) = 1600
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        CGPROGRAM
        #pragma surface surf Diffraction fullforwardshadows
        #include "UnityPBSLighting.cginc"
        
        struct Input
        {
            float2 uv_MainTex;
        };
        
        sampler2D _MainTex;
        float _Glossiness;
        float _Metallic;
        float4 _Color;
        float _Distance;

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
            o.Albedo = c.rgb;
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = c.a;

            float2 uv = IN.uv_MainTex * 2 - 1;
            uv = normalize(uv);
            float3 tangentUV = float3(-uv.y, 0, uv.x);
            float3 worldTangent = normalize(mul(unity_ObjectToWorld, float4(tangentUV, 0)));
            o.Emission = worldTangent;
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
        
        float4 LightingDiffraction(SurfaceOutputStandard s, float3 viewDir, UnityGI gi/*, Input IN*/)
        {
            float3 worldTangent = s.Emission;
            s.Emission = 0;
            float4 pbr = LightingStandard(s, viewDir, gi);
            
            float3 L = gi.light.dir;
            float3 V = viewDir;
            float3 T = worldTangent;
            float d = _Distance;
            float cos_ThetaL = dot(L, T);
            float cos_ThetaV = dot(V, T);
            float u = abs(cos_ThetaL - cos_ThetaV);
            if (u == 0) return pbr;
            
            float3 color = 0;
            for(int n = 1; n <= 8; ++n)
            {
                float waveLength = u * d / n;
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
        }
        ENDCG
    }
    FallBack "Diffuse"
}