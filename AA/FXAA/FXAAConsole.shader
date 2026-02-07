Shader "AA/FXAAConsole"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _ContrastThreshold ("ContrastThreshold", Range(0.0312, 0.0833)) = 0.05
        _RelativeThreshold ("RelativeThreshold", Range(0.063, 0.333)) = 0.125
    }
    SubShader
    {
        Cull Off
		ZTest Always
		ZWrite Off

        Pass
        {
            CGPROGRAM
            #include "UnityCG.cginc"
            
            #pragma vertex vert_img
            #pragma fragment frag

            sampler2D _MainTex;
		    float4 _MainTex_TexelSize;
            float _ContrastThreshold;
            float _RelativeThreshold;

            float4 frag(v2f_img input) : SV_Target
            {
                float2 uv = input.uv;
                float2 texelSize = _MainTex_TexelSize.xy;

                float4 col = tex2D(_MainTex, uv);
                float m = Luminance(col);
                float nw = Luminance(tex2D(_MainTex, uv + float2(-texelSize.x, texelSize.y)));
                float ne = Luminance(tex2D(_MainTex, uv + float2(texelSize.x, texelSize.y)));
                float sw = Luminance(tex2D(_MainTex, uv + float2(-texelSize.x, -texelSize.y)));
                float se = Luminance(tex2D(_MainTex, uv + float2(texelSize.x, -texelSize.y)));

                // 判断是否是边缘
                float maxLuma = max(max(max(nw, ne), max(sw, se)), m);
                float minLuma = min(min(min(nw, ne), min(sw, se)), m);
                float contrast = maxLuma - minLuma;
                if (contrast < max(_ContrastThreshold, maxLuma * _RelativeThreshold)) return col;

                ne += 1 / 384;
                float2 dir;
                dir.x = -nw - ne + sw + se;
                dir.y = ne + se - nw - sw;
                dir = normalize(dir);

                float2 dir1 = dir * _MainTex_TexelSize.xy * 0.5;
                float4 n1 = tex2D(_MainTex, uv - dir1);
                float4 p1 = tex2D(_MainTex, uv + dir1);
                float4 result = (n1 + p1) * 0.5;
                
                float dirAbsMinTimesC = min(abs(dir1.x), abs(dir1.y)) * 8;
                float2 dir2 = clamp(dir1.xy / dirAbsMinTimesC, -2, 2) * 2;
                float4 n2 = tex2D(_MainTex, uv - dir2 * _MainTex_TexelSize.xy);
                float4 p2 = tex2D(_MainTex, uv + dir2 * _MainTex_TexelSize.xy);
                float4 result2 = result * 0.5 + (n2 + p2) * 0.25;

                float newLuma = Luminance(result2);
                if (minLuma <= newLuma && newLuma <= maxLuma)
                {
                    return result2;
                }
                return result;
            }
            ENDCG
        }
    }
}