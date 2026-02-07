Shader "AA/TAA"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
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
            sampler2D _CameraDepthTexture;
            float4 _CameraDepthTexture_TexelSize;
            sampler2D _CameraMotionVectorsTexture;
            float4 _CameraMotionVectorsTexture_TexelSize;
            sampler2D _HistoryTex;
            
            float2 _Jitter;
            int _IgnoreHistory;

            float2 GetClosestFragment(float2 uv)
            {
                float2 k = _CameraDepthTexture_TexelSize.xy;

                float4 neighborhood;
                neighborhood.x = tex2D(_CameraDepthTexture, saturate(uv + float2(-k.x, -k.y))).r;
                neighborhood.y = tex2D(_CameraDepthTexture, saturate(uv + float2(k.x, -k.y))).r;
                neighborhood.z = tex2D(_CameraDepthTexture, saturate(uv + float2(-k.x, k.y))).r;
                neighborhood.w = tex2D(_CameraDepthTexture, saturate(uv + float2(k.x, k.y))).r;

                #if UNITY_REVERSED_Z
                    #define COMPARE_DEPTH(a, b) step(b, a)
                #else
                    #define COMPARE_DEPTH(a, b) step(a, b)
                #endif

                // 找深度最近的
                // 比如当前uv对应背景,而uv+(1,1)对应前景,那应该使用uv+(1,1)
                float3 result = float3(0, 0, tex2D(_CameraDepthTexture, uv).r);
                result = lerp(result, float3(-1, -1, neighborhood.x), COMPARE_DEPTH(neighborhood.x, result.z));
                result = lerp(result, float3(1, -1, neighborhood.y), COMPARE_DEPTH(neighborhood.y, result.z));
                result = lerp(result, float3(-1.0,  1.0, neighborhood.z), COMPARE_DEPTH(neighborhood.z, result.z));
                result = lerp(result, float3( 1.0,  1.0, neighborhood.w), COMPARE_DEPTH(neighborhood.w, result.z));
                return uv + result.xy * k;
            }

            float3 RGBToYCoCg( float3 RGB )
            {
                float Y  = dot( RGB, float3(  1, 2,  1 ) );
                float Co = dot( RGB, float3(  2, 0, -2 ) );
                float Cg = dot( RGB, float3( -1, 2, -1 ) );
                
                float3 YCoCg = float3( Y, Co, Cg );
                return YCoCg;
            }

            float3 YCoCgToRGB( float3 YCoCg )
            {
                float Y  = YCoCg.x * 0.25;
                float Co = YCoCg.y * 0.25;
                float Cg = YCoCg.z * 0.25;

                float R = Y + Co - Cg;
                float G = Y + Cg;
                float B = Y - Co - Cg;

                float3 RGB = float3( R, G, B );
                return RGB;
            }

            float3 ClipHistory(float3 History, float3 BoxMin, float3 BoxMax)
            {
                float3 Filtered = (BoxMin + BoxMax) * 0.5f;
                float3 RayOrigin = History;
                float3 RayDir = Filtered - History;
                RayDir = abs( RayDir ) < (1.0/65536.0) ? (1.0/65536.0) : RayDir;
                float3 InvRayDir = rcp( RayDir );
            
                float3 MinIntersect = (BoxMin - RayOrigin) * InvRayDir;
                float3 MaxIntersect = (BoxMax - RayOrigin) * InvRayDir;
                float3 EnterIntersect = min( MinIntersect, MaxIntersect );
                float ClipBlend = max( EnterIntersect.x, max(EnterIntersect.y, EnterIntersect.z ));
                ClipBlend = saturate(ClipBlend);
                return lerp(History, Filtered, ClipBlend);
            }

            float4 frag(v2f_img input) : SV_Target
            {
                float2 uv = input.uv - _Jitter; // 还原出正确的uv
                float4 col = tex2D(_MainTex, uv);
                if (_IgnoreHistory) return col;

                // 找出周围像素中里相机最近的
                // 找出合适的uv
                float2 closest = GetClosestFragment(input.uv);
                float2 motion = tex2D(_CameraMotionVectorsTexture, closest).xy;

                float2 preUV = input.uv - motion;
                float4 preCol = tex2D(_HistoryTex, preUV);

                // 找到这一帧图片最大最小颜色, 用于截断上一帧颜色
                float3 aabbMin, aabbMax;
                aabbMin = aabbMax = RGBToYCoCg(col);
                for(int y = -1; y <= 1; ++y)
                {
                    for (int x = -1; x <= 1; ++x)
                    {
                        float3 c = RGBToYCoCg(tex2D(_MainTex, uv + float2(x, y)));
                        aabbMin = min(aabbMin, c);
                        aabbMax = max(aabbMax, c);
                    }
                }
                float3 preC = RGBToYCoCg(preCol);
                preCol.rgb = YCoCgToRGB(ClipHistory(preC, aabbMin, aabbMax));

                float BlendFactor = saturate(0.05 + length(motion) * 1000);
                if(preUV.x < 0 || preUV.y < 0 || preUV.x > 1.0f || preUV.y > 1.0f)
                {
                    BlendFactor = 1.0f;
                }

                return lerp(preCol, col, BlendFactor);
            }
            ENDCG
        }
    }
}