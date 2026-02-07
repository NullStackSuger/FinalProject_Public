Shader "ToneMapping"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        
        _Slope ("Slope", Float) = 2.51
        _Toe ("Toe", Float) = 0.03
        _Shoulder ("Shoulder", Float) = 2.43
        _BlackClip ("Back Clip", Float) = 0.59
        _WhiteClip ("White Clip", Float) = 0.14
        
        _PostExposure ("Post Exposure", Float) = 1
    }
    SubShader
    {
        Cull Off
        ZWrite Off
        ZTest Always
        
        Pass
        {
            CGPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert_img
            #pragma fragment frag

            sampler2D _MainTex;
            float _Slope;
            float _Toe;
            float _Shoulder;
            float _BlackClip;
            float _WhiteClip;
            float _PostExposure;

            float3 ACES(float3 linearColor, float a, float b, float c, float d, float e)
            {
                const float ExposureMultiplier  = _PostExposure; // 曝光
                const float3x3 PRE_TONEMAPPING_TRANSFORM = // 色调映射
                {
                 0.575961650, 0.344143820, 0.079952030,
                 0.070806820, 0.827392350, 0.101774690,
                 0.028035252, 0.131523770, 0.840242300
                };
                const float3x3 EXPOSED_PRE_TONEMAPPING_TRANSFORM = ExposureMultiplier * PRE_TONEMAPPING_TRANSFORM;    // 整个场景的色调 = 曝光 * 色调映射
                const float3x3 POST_TONEMAPPING_TRANSFORM = // Gamma校正
                {
                    1.666954300, -0.601741150, -0.065202855,
                    -0.106835220, 1.237778600, -0.130948950,
                    -0.004142626, -0.087411870, 1.091555000
                };

                float3 Color = mul(EXPOSED_PRE_TONEMAPPING_TRANSFORM, linearColor);
                Color = saturate((Color * (a * Color + b)) / (Color * (c * Color + d) + e));
                return clamp(mul(POST_TONEMAPPING_TRANSFORM, Color), 0.0f, 1.0f);
            }

            float4 frag(v2f_img input) : SV_Target
            {
                float4 col = tex2D(_MainTex, input.uv);
                col.xyz = ACES(col.xyz, _Slope, _Toe, _Shoulder, _BlackClip, _WhiteClip);
                return col;
            }
            
            ENDCG
        }
    }
}