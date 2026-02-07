Shader "Blur"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BlurOffsetX ("Blur Offset X", Range(0, 5)) = 1
        _BlurOffsetY ("Blur Offset Y", Range(0, 5)) = 1
        
        // 径向模糊相关
        _Loop ("Loop", Int) = 4 // 循环次数, 越大径向感觉越明显
        _CenterX ("Center X", Float) = 0.5 // 视角聚焦中心
        _CenterY ("Center Y", Float) = 0.5
    }
    SubShader
    {
        Cull Off
        ZWrite Off
        ZTest Always
        
        // Gaussian
        Pass
        {
            CGPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert_img
            #pragma fragment frag

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;
            float _BlurOffsetX;
            float _BlurOffsetY;

            float4 frag(v2f_img input) : SV_Target
            {
                float2 uv = input.uv;
                float2 blurOffset = float2(_BlurOffsetX, _BlurOffsetY);
                
                float2 uvX0 = uv;
                float2 uvX1 = uv + float2(_MainTex_TexelSize.x * 1, 0) * blurOffset;
                float2 uvX2 = uv - float2(_MainTex_TexelSize.x * 1, 0) * blurOffset;
                float2 uvX3 = uv + float2(_MainTex_TexelSize.x * 2, 0) * blurOffset;
                float2 uvX4 = uv - float2(_MainTex_TexelSize.x * 2, 0) * blurOffset;
                float2 uvY0 = uv;
                float2 uvY1 = uv + float2(0, _MainTex_TexelSize.y * 1) * blurOffset;
                float2 uvY2 = uv - float2(0, _MainTex_TexelSize.y * 1) * blurOffset;
                float2 uvY3 = uv + float2(0, _MainTex_TexelSize.y * 2) * blurOffset;
                float2 uvY4 = uv - float2(0, _MainTex_TexelSize.y * 2) * blurOffset;

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
        // Box
        Pass
        {
            CGPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert_img
            #pragma fragment frag

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;
            float _BlurOffsetX;
            float _BlurOffsetY;

            float4 frag(v2f_img input) : SV_Target
            {
                float2 blurOffset = float2(_BlurOffsetX, _BlurOffsetY);
                
                float3 sum = 0;
                for (int x = -1; x <= 1; ++x)
                {
                    for (int y = -1; y <= 1; ++y)
                    {
                        float2 uv = input.uv;
                        uv.x += x * _MainTex_TexelSize.x * blurOffset.x / 3;
                        uv.y += y * _MainTex_TexelSize.y * blurOffset.y / 3;
                        sum += tex2D(_MainTex, uv);
                    }
                }
                sum /= 9;

                return float4(sum, 1);
            }
            ENDCG
        }
        // Kawase
        Pass
        {
            CGPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert_img
            #pragma fragment frag

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;
            float _BlurOffsetX;
            float _BlurOffsetY;

            float4 frag(v2f_img input) : SV_Target
            {
                float2 uv = input.uv;
                float2 blurOffset = float2(_BlurOffsetX, _BlurOffsetY);
                
                float3 sum = 0;
                sum += tex2D(_MainTex, uv);
                sum += tex2D(_MainTex, uv + float2(-1, -1) * _MainTex_TexelSize.xy * blurOffset);
                sum += tex2D(_MainTex, uv + float2(1, -1) * _MainTex_TexelSize.xy * blurOffset);
                sum += tex2D(_MainTex, uv + float2(-1, 1) * _MainTex_TexelSize.xy * blurOffset);
                sum += tex2D(_MainTex, uv + float2(1, 1) * _MainTex_TexelSize.xy * blurOffset);
                sum /= 5;

                return float4(sum, 1);
            }
            ENDCG
        }
        // Double(双重模糊)
        Pass
        {
            CGPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert_img
            #pragma fragment frag

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;
            float _BlurOffsetX;
            float _BlurOffsetY;

            float4 frag(v2f_img input) : SV_Target
            {
                float2 uv = input.uv;
                float2 blurOffset = float2(_BlurOffsetX, _BlurOffsetY);
                
                float3 sum = 0;
                sum += tex2D(_MainTex, uv + float2(-1, -1) * _MainTex_TexelSize.xy * (1 + blurOffset) * 0.5) * 2;
                sum += tex2D(_MainTex, uv + float2(-1, 1) * _MainTex_TexelSize.xy * (1 + blurOffset) * 0.5) * 2;
                sum += tex2D(_MainTex, uv + float2(1, -1) * _MainTex_TexelSize.xy * (1 + blurOffset) * 0.5) * 2;
                sum += tex2D(_MainTex, uv + float2(1, 1) * _MainTex_TexelSize.xy * (1 + blurOffset) * 0.5) * 2;
                sum += tex2D(_MainTex, uv + float2(-2, 0) * _MainTex_TexelSize.xy * (1 + blurOffset) * 0.5);
                sum += tex2D(_MainTex, uv + float2(0, -2) * _MainTex_TexelSize.xy * (1 + blurOffset) * 0.5);
                sum += tex2D(_MainTex, uv + float2(2, 0) * _MainTex_TexelSize.xy * (1 + blurOffset) * 0.5);
                sum += tex2D(_MainTex, uv + float2(0, 2) * _MainTex_TexelSize.xy * (1 + blurOffset) * 0.5);
                sum /= 12;

                return float4(sum, 1);
            }
            ENDCG
        }
        // Radial(径向模糊)
        Pass
        {
            CGPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert_img
            #pragma fragment frag

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;
            float _BlurOffsetX;
            float _BlurOffsetY;

            int _Loop;
            float _CenterX;
            float _CenterY;

            float4 frag(v2f_img input) : SV_Target
            {
                float2 uv = input.uv;
                float2 blurOffset = float2(_BlurOffsetX, _BlurOffsetY);
                float2 center = float2(_CenterX, _CenterY);
                
                float4 sum = 0;
                float2 dir = (center - uv) * blurOffset * 0.01;
                for(int i = 0; i < _Loop; ++i)
                {
                    sum += tex2D(_MainTex, uv + dir * i);
                }
                sum /= _Loop;

                return sum;
            }
            ENDCG
        }
        // Bokeh(散景模糊)
        Pass
        {
            CGPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert_img
            #pragma fragment frag

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;
            float _BlurOffsetX;
            float _BlurOffsetY;

            float _Loop;

            float4 frag(v2f_img input) : SV_Target
            {
                float2 uv = input.uv;
                float2 blurOffset = float2(_BlurOffsetX, _BlurOffsetY);

                float c = cos(2.39996323f);
                float s = sin(2.39996323f);
                float4 goldenRot = float4(c, s, -s, c);
                float2x2 rot = float2x2(goldenRot);
                
                float4 accumvlaor = 0;
                float4 divisor = 0;
                float r = 1;
                float2 angle = blurOffset * 0.001;
                for (int i = 0; i < _Loop; ++i) // Loop控制散景数目
                {
                    r += 1 / r;
                    angle = mul(rot, angle);
                    float4 bokeh = tex2D(_MainTex, uv + 1 * (r - 1) * angle);
                    accumvlaor += bokeh * bokeh;
                    divisor += bokeh;
                }

                return accumvlaor/divisor;
            }
            ENDCG
        }
    }
}