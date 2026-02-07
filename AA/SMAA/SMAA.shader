Shader "AA/SMAA"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BlendTex ("Texture", 2D) = "white" {}
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

            float4 frag(v2f_img input) : SV_Target
            {
                float2 uv = input.uv;
                float2 texelSize = _MainTex_TexelSize.xy;

                float m = Luminance(tex2D(_MainTex, uv));
                float l = abs(Luminance(tex2D(_MainTex, uv + float2(-texelSize.x, 0))) - m);
                float l2 = abs(Luminance(tex2D(_MainTex, uv + float2(-texelSize.x * 2, 0))) - m);
                float r = abs(Luminance(tex2D(_MainTex, uv + float2(texelSize.x, 0))) - m);
                float t = abs(Luminance(tex2D(_MainTex, uv + float2(0, -texelSize.y))) - m);
                float t2 = abs(Luminance(tex2D(_MainTex, uv + float2(0, -texelSize.y * 2))) - m);
                float b = abs(Luminance(tex2D(_MainTex, uv + float2(0, texelSize.y))) - m);

                float maxLuma = max(max(l, r), max(t, b));

                // 左
                bool el = l > 0.05 && l > max(maxLuma, l2) * 0.5;
                // 上
                bool et = t > 0.05 && t > max(maxLuma, t2) * 0.5;

                return float4(el ? 1 : 0, et ? 1 : 0, 0, 0);
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
            float4 _MainTex_TexelSize;

            // 圆角系数, 保留物体实际的边缘; 若为0 表示全保留, 为1表示不变
            #define ROUNDING_FACTOR 0.25
            // 最大搜索步长
            #define MAXSTEPS 10
            
            // 沿着左侧进行边界搜索
            float SearchXLeft(float2 coord)
            {
                coord -= float2(1.5f, 0);
                float e = 0;
                int i = 0;
                UNITY_UNROLL
                for(; i < MAXSTEPS; i++)
                {
                    // |
                    // |
                    // L__________________
                    // (要找的拐角) (当前coord)
                    // 向左搜索, 如果g==1(也就是上侧是边缘), 说明还没找到
                    e = tex2D(_MainTex, coord * _MainTex_TexelSize.xy).y;
                    [flatten]
                    if (e < 0.9f)  break;
                    coord -= float2(2, 0);
                }
                return min(2.0 * (i +  e), 2.0 * MAXSTEPS);
            }
            float SearchXRight(float2 coord)
            {
                coord += float2(1.5f, 0);
                float e = 0;
                int i = 0;
                UNITY_UNROLL
                for(; i < MAXSTEPS; i++)
                {
                    e = tex2D(_MainTex, coord * _MainTex_TexelSize.xy).y;
                    [flatten]
                    if (e < 0.9f)  break;
                    coord += float2(2, 0);
                }
                return min(2.0 * (i +  e), 2.0 * MAXSTEPS);
            }
            float SearchYUp(float2 coord)
            {
                coord -= float2(0, 1.5f);
                float e = 0;
                int i = 0;
                UNITY_UNROLL
                for(; i < MAXSTEPS; i++)
                {
                    e = tex2D(_MainTex, coord * _MainTex_TexelSize.xy).x;
                    [flatten]
                    if (e < 0.9f)  break;
                    coord -= float2(0, 2);
                }
                return min(2.0 * (i +  e), 2.0 * MAXSTEPS);
            }
            float SearchYDown(float2 coord)
            {
                coord += float2(0, 1.5f);
                float e = 0;
                int i = 0;
                UNITY_UNROLL
                for(; i < MAXSTEPS; i++)
                {
                    e = tex2D(_MainTex, coord * _MainTex_TexelSize.xy).x;
                    [flatten]
                    if (e < 0.9f)  break;
                    coord += float2(0, 2);
                }
                return min(2.0 * (i +  e), 2.0 * MAXSTEPS);
            }

            //这里是根据双线性采样得到的值，来判断边界的模式
            bool4 ModeOfSingle(float value)
            {
                bool4 ret = false;
                if (value > 0.875)
                    ret.yz = bool2(true, true);
                else if(value > 0.5)
                    ret.z = true;
                else if(value > 0.125)
                    ret.y = true;
                return ret;
            }
            //判断两侧的模式
            bool4 ModeOfDouble(float value1, float value2)
            {
                bool4 ret;
                ret.xy = ModeOfSingle(value1).yz;
                ret.zw = ModeOfSingle(value2).yz;
                return ret;
            }

            //  单侧L型, 另一侧没有, d表示总间隔, m表示像素中心距边缘距离
            //  |____
            float L_N_Shape(float d, float m)
            {
                float l = d * 0.5;
                float s = 0;
                [flatten]
                if ( l > (m + 0.5))
                {
                    // 梯形面积, 宽为1
                    s = (l - m) * 0.5 / l;
                }
                else if (l > (m - 0.5))
                {
                    // 三角形面积, a是宽, b是高
                    float a = l - m + 0.5;
                    // float b = a * 0.5 / l;
                    // float s = a * b * 0.5;
                    s = a * a * 0.25 * rcp(l);
                }
                return s;
            }
            //  双侧L型, 且方向相同
            //  |____|
            float L_L_S_Shape(float d1, float d2)
            {
                float d = d1 + d2;
                float s1 = L_N_Shape(d, d1);
                float s2 = L_N_Shape(d, d2);
                return s1 + s2;
            }
            //  双侧L型/或一侧L, 一侧T, 且方向不同, 这里假设左侧向上, 来取正负
            //  |____    |___|    
            //       |       |
            float L_L_D_Shape(float d1, float d2)
            {
                float d = d1 + d2;
                float s1 = L_N_Shape(d, d1);
                float s2 = -L_N_Shape(d, d2);
                return s1 + s2;
            }

            float Area(float2 d, bool4 left, bool4 right)
            {
                // result为正, 表示将该像素点颜色扩散至上/左侧; result为负, 表示将上/左侧颜色扩散至该像素
                float result = 0;
                [branch]
                if(!left.y && !left.z)
                {
                    [branch]
                    if(right.y && !right.z)
                    {
                        result = L_N_Shape(d.y + d.x + 1, d.y + 0.5);
                    }
                    else if (!right.y && right.z)
                    {
                        result = -L_N_Shape(d.y + d.x + 1, d.y + 0.5);
                    }
                }
                else if (left.y && !left.z)
                {
                    [branch]
                    if(right.z)
                    {
                        result = L_L_D_Shape(d.x + 0.5, d.y + 0.5);
                    }
                    else if (!right.y)
                    {
                        result = L_N_Shape(d.y + d.x + 1, d.x + 0.5);
                    }
                    else
                    {
                        result = L_L_S_Shape(d.x + 0.5, d.y + 0.5);
                    }
                }
                else if (!left.y && left.z)
                {
                    [branch]
                    if (right.y)
                    {
                        result = -L_L_D_Shape(d.x + 0.5, d.y + 0.5);
                    }
                    else if (!right.z)
                    {
                        result = -L_N_Shape(d.x + d.y + 1, d.x + 0.5);
                    }
                    else
                    {
                        result = -L_L_S_Shape(d.x + 0.5, d.y + 0.5);
                    }
                }
                else
                {
                    [branch]
                    if(right.y && !right.z)
                    {
                        result = -L_L_D_Shape(d.x + 0.5, d.y + 0.5);
                    }
                    else if (!right.y && right.z)
                    {
                        result = L_L_D_Shape(d.x + 0.5, d.y + 0.5);
                    }
                }

            #ifdef ROUNDING_FACTOR
                bool apply = false;
                if (result > 0)
                {
                    if(d.x < d.y && left.x)
                    {
                        apply = true;
                    }
                    else if(d.x >= d.y && right.x)
                    {
                        apply = true;
                    }
                }
                else if (result < 0)
                {
                    if(d.x < d.y && left.w)
                    {
                        apply = true;
                    }
                    else if(d.x >= d.y && right.w)
                    {
                        apply = true;
                    }
                }
                if (apply)
                {
                    result = result * ROUNDING_FACTOR;
                }
            #endif

                return result;

            }

            float4 frag(v2f_img input) : SV_Target
            {
                float2 uv = input.uv;
                float2 screenPos = input.uv * _MainTex_TexelSize.zw;
                float2 edge = tex2D(_MainTex, uv).xy; // 左方和上方是否为边界
                float4 result = 0;

                // 从上边界左右搜索
                if (edge.y > 0.1)
                {
                    float left = SearchXLeft(screenPos);
                    float right = SearchXRight(screenPos);

                    // 这里不采用0.5而是0.75和1.25是为了区分边界是上开口还是下开口
                    float left1 = tex2D(_MainTex, (screenPos + float2(-left, -1.25)) * _MainTex_TexelSize.xy).x;
                    float left2 = tex2D(_MainTex, (screenPos + float2(-left, 0.75)) * _MainTex_TexelSize.xy).x;
                    float right1 = tex2D(_MainTex, (screenPos + float2(right + 1, -1.25)) * _MainTex_TexelSize.xy).x;
                    float right2 = tex2D(_MainTex, (screenPos + float2(right + 1, 0.75)) * _MainTex_TexelSize.xy).x;

                    bool4 l = ModeOfDouble(left1, left2);
                    bool4 r = ModeOfDouble(right1, right2);

                    float value = Area(float2(left, right), l, r);
                    result.xy = float2(-value, value);
                }
                // 从左边界搜索
                if (edge.x > 0.1)
                {
                    float up = SearchYUp(screenPos);
                    float down = SearchYDown(screenPos);

                    float up1 = tex2D(_MainTex, (screenPos + float2(-1.25, -up)) * _MainTex_TexelSize.xy).y;
                    float up2 = tex2D(_MainTex, (screenPos + float2(0.75, -up)) * _MainTex_TexelSize.xy).y;
                    float down1 = tex2D(_MainTex, (screenPos + float2(-1.25, down + 1)) * _MainTex_TexelSize.xy).y;
                    float down2 = tex2D(_MainTex, (screenPos + float2(0.75, down + 1)) * _MainTex_TexelSize.xy).y;

                    bool4 u = ModeOfDouble(up1, up2);
                    bool4 d = ModeOfDouble(down1, down2);

                    float value = Area(float2(up, down), u, d);
                    result.zw = float2(-value, value);
                }

                return result;
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
            float4 _MainTex_TexelSize;
            sampler2D _BlendTex;

            float4 frag(v2f_img input) : SV_Target
            {
                float2 uv = input.uv;
                int2 texelCoord = uv * _MainTex_TexelSize.zw;

                float4 tl = tex2D(_BlendTex, texelCoord);
                float r = tex2D(_BlendTex, texelCoord + int2(1, 0)).a;
                float b = tex2D(_BlendTex, texelCoord + int2(0, 1)).g;

                float4 a = float4(tl.r, b, tl.b, r);
                float4 w = pow(a, 3);
                float sum = w.x + w.y + w.z + w.w;

                if (sum > 0)
                {
                    float4 o = a * _MainTex_TexelSize.yyxx;
                    float4 color = 0;

                    color = mad(tex2D(_MainTex, uv + float2(0, -o.r)), w.r, color);
                    color = mad(tex2D(_MainTex, uv + float2(0, o.g)), w.g, color);
                    color = mad(tex2D(_MainTex, uv + float2(-o.b, 0)), w.b, color);
                    color = mad(tex2D(_MainTex, uv + float2(o.a, 0)), w.a, color);

                    return color / sum;
                }
                else
                {
                    return tex2D(_MainTex, uv);
                }
            }

            ENDCG
        }
    }
}