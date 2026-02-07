Shader "AO/SSAO"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Radius("Radius", Range(0, 1)) = 1
        _RangeStrength("Range Strength", Range(0, 1)) = 0.001
        _DepthBias("Depth Bias", Range(0, 1)) = 0.1
        _StepCount("Step Count", Float) = 32
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

            #pragma vertex vert
            #pragma fragment frag

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 viewVec : TEXCOORD1;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            sampler2D _CameraDepthTexture;
            sampler2D _CameraDepthNormalsTexture;

            float _Radius;
            float _RangeStrength;
            float _DepthBias;
            float _StepCount;

            float4 GetDepthAndNormal(float2 uv)
            {
                float3 viewNormal = 0;
                float linear01Depth = 0;
                float4 depthNormal = tex2D(_CameraDepthNormalsTexture, uv);
                DecodeDepthNormal(depthNormal, linear01Depth, viewNormal);
                return float4(viewNormal, linear01Depth);
            }
            float3 GetPosition(float2 uv, float depth)
            {
                float4 screenPos = float4(uv.x, uv.y, 1, 1);
                float4 ndcPos = (screenPos / screenPos.w) * 2 - 1;
                float3 clipVec = float3(ndcPos.x, ndcPos.y, 1) * _ProjectionParams.z;
                float3 viewVec = mul(unity_CameraInvProjection, clipVec.xyz).xyz;
                return depth * viewVec;
            }

            float Random(float2 p) 
            {
                return frac(sin(dot(p ,float2(12.9898,78.233))) * 43758.5453);
            }
            float3 Random(float i)
            {
                float x = frac(sin(float(i) * 12.9898) * 43758.5453) * 2.0 - 1.0;
                float y = frac(sin(float(i) * 78.233) * 43758.5453) * 2.0 - 1.0;
                float z = frac(sin(float(i) * 53.313)) * 1.0; // [0,1]

                float3 sampleDir = normalize(float3(x, y, z));

                float scale = float(i) / 64.0;
                scale = lerp(0.1, 1.0, scale * scale);
                return sampleDir * scale;
            }

            

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;

                float4 screenPos = ComputeScreenPos(o.vertex);
                float4 ndcPos = (screenPos / screenPos.w) * 2 - 1;
                float3 clipVec = float3(ndcPos.x, ndcPos.y, 1) * _ProjectionParams.z;
                o.viewVec = mul(unity_CameraInvProjection, clipVec.xyzz).xyz;
                
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float4 depthNormal = tex2D(_CameraDepthNormalsTexture, i.uv);
                float3 viewNormal;
                float linear01Depth;
                DecodeDepthNormal(depthNormal, linear01Depth, viewNormal);
                float3 viewPos = linear01Depth * i.viewVec;

                viewNormal = normalize(viewNormal) * float3(1, 1, -1);
                float3 randVec = normalize(float3(1, 1, 1));
                float3 tangent = normalize(randVec - viewNormal * dot(randVec, viewNormal));
                float3 bitangent = cross(viewNormal, tangent);
                float3x3 TBN = float3x3(tangent, bitangent, viewNormal);

                float ao = 0;
                for(int t = 0; t < _StepCount; ++t)
                {
                    // 随机采样点
                    float3 randomVec = mul(Random(t), TBN);
                    float3 randomPos = viewPos + randomVec * _Radius;
                    float3 rclipPos = mul((float3x3)unity_CameraProjection, randomPos);
                    float2 rscreenPos = (rclipPos.xy / rclipPos.z) * 0.5 + 0.5;

                    // 采样点深度
                    float randomDepth;
                    float3 randomNormal;
                    float4 rcdn = tex2D(_CameraDepthNormalsTexture, rscreenPos);
                    DecodeDepthNormal(rcdn, randomDepth, randomNormal);

                    float range = abs(randomDepth - linear01Depth) > _RangeStrength ? 1 : 0 ;
                    float selfCheck = randomDepth + _DepthBias < linear01Depth ? 1 : 0; // 自遮挡
                    // 自己测试加这块之后随机性太大导致经常闪动
                    //float weight = smoothstep(0, 0.2, length(randomVec.xy)); // 软ao
                    ao += range * selfCheck/* * weight*/;
                }
                
                return float4(ao.xxx, 1);
            }

            ENDCG
        }
    }
}