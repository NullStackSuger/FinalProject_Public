Shader "AO/HBAO"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "" {}
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
            sampler2D _CameraDepthTexture;
            sampler2D _CameraDepthNormalsTexture;

            int _Direction;
            int _Step;

            float4 _UV2View;
            float4 _TexelSize;
            float _RadiusPixel;
            float _Radius;
            float _MaxRadiusPixel;
            float _AngleBias;
            float _AOStrength;

            inline float random(float2 uv)
            {
                return frac(sin(dot(uv.xy, float2(12.9898, 78.233))) * 43758.5453123);
            }

            inline float FetchDepth(float2 uv)
            {
                return SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
            }
            inline float3 FetchViewPos(float2 uv)
            {
                float depth = LinearEyeDepth(FetchDepth(uv));
                return float3((uv * _UV2View.xy + _UV2View.zw) * depth, depth);
            }
            inline float3 FetchViewNormal(float2 uv)
            {
                float3 normal = DecodeViewNormalStereo(tex2D(_CameraDepthNormalsTexture, uv));
                return float3(normal.x, normal.y, -normal.z);
            }
            inline float FallOff(float dist)
            {
                return 1 - dist / _Radius;
            }
            inline float SimpleAO(float3 pos, float3 stepPos, float3 normal, inout float top)
            {
                float3 h = stepPos - pos;
                float dist = sqrt(dot(h, h));
                // dot(normal, h) = |h|cos
                // dot(normal, h) / dist = cos
                float sinBlock = dot(normal, h) / dist;
                float diff = max(sinBlock - top, 0);
                top = max(sinBlock, top);
                // FallOff : 越远权重越小
                return diff * saturate(FallOff(dist)); // 这里算的是ao增量, 最终会收敛
            }
            
            float4 frag(v2f_img input) : SV_Target
            {
                float ao = 0;
                float3 viewPos = FetchViewPos(input.uv);
                float3 viewNormal = FetchViewNormal(input.uv);

                float stepSize = min(_RadiusPixel / viewPos.z, _MaxRadiusPixel) / (_Step + 1);
                if (stepSize < 1) return float4(1, 1, 1, 1);

                float delta = 2 * UNITY_PI / _Direction; // 每个方向占的角度
                float deltaOffset = random(input.uv * 10); // 方向角偏移
                UNITY_UNROLL
                for (int i = 0; i < 6; ++i)
                {
                    float angle = delta * (i + deltaOffset); // 方向角
                    float cos, sin;
                    sincos(angle, sin, cos);
                    float2 dir = float2(cos, sin); // 方向角对应的单位向量

                    float rayPixel = 1; // 步进像素距离
                    float top = _AngleBias; // 顶角初始值
                    UNITY_UNROLL
                    for (int j = 0; j < 6; ++j)
                    {
                        // uv按_Step递增
                        // 但是stepViewPos是屏幕上uv对应的位置, 与uv不相关
                        float2 stepUV = round(rayPixel * dir) * _TexelSize.xy + input.uv;
                        float3 stepViewPos = FetchViewPos(stepUV);

                        ao += SimpleAO(viewPos, stepViewPos, viewNormal, top);
                        rayPixel += stepSize;
                    }
                }
                ao /= _Step * _Direction;
                ao = pow(abs(ao * _AOStrength), 0.6); // 让结果更尖锐
                float col = saturate(1 - ao);
                return col.xxxx;
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
            sampler2D _HbaoTex;

            float4 frag(v2f_img input) : SV_Target
            {
                float4 ao = tex2D(_HbaoTex, input.uv);
                float4 col = tex2D(_MainTex, input.uv);
                col.rgb *= ao.a;
                return col;
            }
            
            ENDCG
        }
    }
}