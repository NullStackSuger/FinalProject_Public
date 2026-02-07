Shader "Bloom"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Luminance ("Luminance", Range(0, 4)) = 0.6
    }
    SubShader
    {
        Cull Off
        ZWrite Off
        ZTest Always
        
        // 提取较亮区域
        Pass
        {
            CGINCLUDE
            #include "UnityCG.cginc"

            #pragma vertex vert_img
            #pragma fragment frag

            sampler2D _MainTex;
            float _Luminance;

            float4 frag(v2f_img input)
            {
                float2 uv = input.uv;
                float4 col = tex2D(_MainTex, uv);
                float luminance = saturate(Luminance(col) - _Luminance);
                return col * luminance;
            }
            ENDCG
        }
        // 竖直方向高斯模糊
        Pass
        {
            CGINCLUDE
            #include "UnityCG.cginc"

            #pragma vertex vert_img
            #pragma fragment frag

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;
            float _BlurOffset;

            float4 frag(v2f_img input)
            {
                float2 uv = input.uv;

                const float weight[3] = { 0.40f, 0.25f, 0.05f };
                
                float3 sum = 0;
                sum += tex2D(_MainTex, uv) * weight[0];
                sum += tex2D(_MainTex, uv + float2(0, _MainTex_TexelSize.y * 1) * _BlurOffset) * weight[1];
                sum += tex2D(_MainTex, uv - float2(0, _MainTex_TexelSize.y * 1) * _BlurOffset) * weight[1];
                sum += tex2D(_MainTex, uv + float2(0, _MainTex_TexelSize.y * 2) * _BlurOffset) * weight[2];
                sum += tex2D(_MainTex, uv - float2(0, _MainTex_TexelSize.y * 2) * _BlurOffset) * weight[2];
                return float4(sum, 1);
            }
            ENDCG
        }
        // 水平方向高斯模糊
        Pass
        {
            CGINCLUDE
            #include "UnityCG.cginc"

            #pragma vertex vert_img
            #pragma fragment frag

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;
            float _BlurOffset;

            float4 frag(v2f_img input)
            {
                float2 uv = input.uv;

                const float weight[3] = { 0.40f, 0.25f, 0.05f };
                
                float3 sum = 0;
                sum += tex2D(_MainTex, uv) * weight[0];
                sum += tex2D(_MainTex, uv + float2(_MainTex_TexelSize.x * 1, 0) * _BlurOffset) * weight[1];
                sum += tex2D(_MainTex, uv - float2(_MainTex_TexelSize.x * 1, 0) * _BlurOffset) * weight[1];
                sum += tex2D(_MainTex, uv + float2(_MainTex_TexelSize.x * 2, 0) * _BlurOffset) * weight[2];
                sum += tex2D(_MainTex, uv - float2(_MainTex_TexelSize.x * 2, 0) * _BlurOffset) * weight[2];
                return float4(sum, 1);
            }
            ENDCG
        }
        // Blend
        Pass
        {
            CGINCLUDE
            #include "UnityCG.cginc"

            #pragma vertex vert
            #pragma fragment frag

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;
            sampler2D _Bloom;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1;
                float4 vertex : SV_POSITION;
            };

            v2f vert(appdata input)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(input.vertex);

                o.uv = input.uv;
                o.uv2 = input.uv;
                #if UNITY_UV_STARTS_AT_TOP
                if (_MainTex_TexelSize.y < 0)
                    o.uv2.y = 1 - o.uv2.y;
                #endif

                return o;
            }
            
            float4 frag(v2f input)
            {
                //return float4(0, 0, 0, 1);
                //return float4(input.uv, 0, 1);
                return tex2D(_MainTex, input.uv) + tex2D(_Bloom, input.uv2);
            }
            ENDCG
        }
    }
}