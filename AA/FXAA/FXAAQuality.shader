Shader "AA/FXAAQuality"
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
                float e = Luminance(tex2D(_MainTex, uv + float2(texelSize.x, 0)));
                float w = Luminance(tex2D(_MainTex, uv + float2(-texelSize.x, 0)));
                float n = Luminance(tex2D(_MainTex, uv + float2(0, texelSize.y)));
                float s = Luminance(tex2D(_MainTex, uv + float2(0, -texelSize.y)));
                float nw = Luminance(tex2D(_MainTex, uv + float2(-texelSize.x, texelSize.y)));
                float ne = Luminance(tex2D(_MainTex, uv + float2(texelSize.x, texelSize.y)));
                float sw = Luminance(tex2D(_MainTex, uv + float2(-texelSize.x, -texelSize.y)));
                float se = Luminance(tex2D(_MainTex, uv + float2(texelSize.x, -texelSize.y)));

                // 判断是否是边缘
                float maxLuma = max(max(max(n, e), max(w, s)), m);
                float minLuma = min(min(min(n, e), min(w, s)), m);
                float contrast = maxLuma - minLuma;
                if (contrast < max(_ContrastThreshold, maxLuma * _RelativeThreshold)) return col;

                // 计算混合系数
                float filter = (2 * (n + s + w + e) + (nw + ne + sw + se)) / 12;
                filter = abs(filter - m);
                filter = saturate(filter / contrast);
                float pixelBlend = smoothstep(0, 1, filter);
                pixelBlend = pixelBlend * pixelBlend;

                // 确认边界朝向
                float vertical = abs(n - m + s - m) * 2 + abs(ne - e + se - e) + abs(nw - w + sw - w);
                float horizontal = abs(e - m + w - m) * 2 + abs(ne - n + nw - n) + abs(se - s + sw - s);
                bool IsVertical = vertical > horizontal; // 锯齿是否为水平方向
                float positive = abs((IsVertical ? n : e) - m);
                float negative = abs((IsVertical ? s : w) - m);
                float2 pixelStep; float gradient; float oppositeLuminance;
                if (positive > negative)
                {
                    gradient = positive;
                    oppositeLuminance = IsVertical ? n : e;

                    pixelStep = IsVertical ? float2(0, texelSize.y) : float2(texelSize.x, 0);
                }
                else
                {
                    gradient = negative;
                    oppositeLuminance = IsVertical ? s : w;

                    pixelStep = IsVertical ? float2(0, -texelSize.y) : float2(-texelSize.x, 0);
                }

                // 计算边界范围
                float2 uvEdge = uv + pixelStep * 0.5; // 向前方+0.5采样, 能采到2个texel混合
                float2 step = IsVertical ? float2(texelSize.x, 0) : float2(0, texelSize.y);
                const int searchSteps = 15; // 搜索步长
                const int guessSteps = 8; // 没找到边界时, 猜测的步长
                float edgeLuminance = (m + oppositeLuminance) * 0.5; // 对应uvEdge的Luminance
                float gradientThreshold = gradient * 0.25;
                float positiveLuminanceDelta = 0, negativeLuminanceDelta = 0, positiveDistance = 0, negativeDistance = 0;
                // 向正方向寻找
                for(int i = 1; i <= searchSteps; ++i)
                {
                    positiveLuminanceDelta = Luminance(tex2D(_MainTex, uvEdge + i * step)) - edgeLuminance;
                    if (abs(positiveLuminanceDelta) > gradientThreshold) // Luminance差值过大说明找到边界了
                    {
                        positiveDistance = i * (IsVertical ? step.x : step.y);
                        break;
                    }
                    if (i == searchSteps + 1) // 没找到用猜测的距离
                    {
                        positiveDistance = guessSteps * step;
                    }
                }
                // 向负方向寻找
                for(int i = 1; i <= searchSteps; ++i)
                {
                    negativeLuminanceDelta = Luminance(tex2D(_MainTex, uvEdge - i * step)) - edgeLuminance;
                    if (abs(negativeLuminanceDelta) > gradientThreshold)
                    {
                        negativeDistance = i * (IsVertical ? step.x : step.y);
                        break;
                    }
                    if (i == searchSteps + 1)
                    {
                        negativeDistance = guessSteps * step;
                    }
                }

                float edgeBlend;
                if (positiveDistance < negativeDistance)
                {
                    // sign判断是否同号
                    if (sign(positiveLuminanceDelta) == sign(m - edgeLuminance)) // 上面和前面的差值同号说明找到的可能不是边界
                    {
                        edgeBlend = 0;
                    }
                    else
                    {
                        edgeBlend = 0.5 - positiveDistance / (positiveDistance + negativeDistance); // positiveDistance越大,混合系数越小
                    }
                }
                else
                {
                    if (sign(negativeLuminanceDelta) == sign(m - edgeLuminance))
                    {
                        edgeBlend = 0;
                    }
                    else
                    {
                        edgeBlend = 0.5 - negativeDistance / (positiveDistance + negativeDistance);
                    }
                }

                float blend = max(pixelBlend, edgeBlend);
                return tex2D(_MainTex, uv + step * blend);
            }
            ENDCG
        }
    }
}