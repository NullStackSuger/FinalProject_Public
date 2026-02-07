Shader "DOF"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        
        _BlurOffset("Blur Offset", Float) = 1
        
        _DepthOfField ("DOF", Range(0, 10)) = 10
        [Min(0)] _FocusDistance ("Focus Distance", Float) = 1
        _SmoothRange ("Smooth Range", Range(0, 1)) = 0.5
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
            float4 _MainTex_TexelSize;
            float _BlurOffset;
            
            float4 frag(v2f_img input) : SV_Target
            {
                float2 uv = input.uv;
                float2 uvX0 = uv.xy;
                float2 uvX1 = uv + float2(_MainTex_TexelSize.x * 1, 0) * _BlurOffset;
                float2 uvX2 = uv - float2(_MainTex_TexelSize.x * 1, 0) * _BlurOffset;
                float2 uvX3 = uv + float2(_MainTex_TexelSize.x * 2, 0) * _BlurOffset;
                float2 uvX4 = uv - float2(_MainTex_TexelSize.x * 2, 0) * _BlurOffset;
                float2 uvY0 = uv;
                float2 uvY1 = uv + float2(0, _MainTex_TexelSize.y * 1) * _BlurOffset;
                float2 uvY2 = uv - float2(0, _MainTex_TexelSize.y * 1) * _BlurOffset;
                float2 uvY3 = uv + float2(0, _MainTex_TexelSize.y * 2) * _BlurOffset;
                float2 uvY4 = uv - float2(0, _MainTex_TexelSize.y * 2) * _BlurOffset;

                float weight[3] = {0.40, 0.25, 0.05};

                float3 sum = 0;
                sum += tex2D(_MainTex, uvX0).rgb * weight[0];
                sum += tex2D(_MainTex, uvX1).rgb * weight[1];
                sum += tex2D(_MainTex, uvX2).rgb * weight[1];
                sum += tex2D(_MainTex, uvX3).rgb * weight[2];
                sum += tex2D(_MainTex, uvX4).rgb * weight[2];
                sum += tex2D(_MainTex, uvY0).rgb * weight[0];
                sum += tex2D(_MainTex, uvY1).rgb * weight[1];
                sum += tex2D(_MainTex, uvY2).rgb * weight[1];
                sum += tex2D(_MainTex, uvY3).rgb * weight[2];
                sum += tex2D(_MainTex, uvY4).rgb * weight[2];
                sum /= 2;

                return float4(sum, 1);
            }
            ENDCG
        }
        Pass
        {
            CGPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert_img
            #pragma fragment frag

            sampler2D _MainTex;
            sampler2D _BlurTex;
            sampler2D _CameraDepthTexture;

            float _DepthOfField;
            float _FocusDistance;
            float _SmoothRange;

            float4 frag(v2f_img input) : SV_Target
            {
                float depth = Linear01Depth(tex2D(_CameraDepthTexture, input.uv)) * _ProjectionParams.z; // 远平面
                float focusNear = _FocusDistance - _DepthOfField;
                float focusFar = _FocusDistance + _DepthOfField;

                float finalDepth = 0;
                if (depth >= focusNear && depth <= focusFar){}
                else
                {
                    if (depth < focusNear)
                        finalDepth = saturate(abs(depth - focusNear) * _SmoothRange);
                    if (depth > focusFar)
                        finalDepth = saturate(abs(depth - focusFar) * _SmoothRange);
                }

                float4 col = tex2D(_MainTex, input.uv);
                float4 blurTex = tex2D(_BlurTex, input.uv);
                float4 finalCol = lerp(col, blurTex, finalDepth);
                return float4(finalCol.rgb, 1);
            }
            ENDCG
        }
    }
}