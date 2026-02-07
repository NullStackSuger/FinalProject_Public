Shader "Cloud/Cloud2"
{
    Properties
    {
        
    }
    SubShader
    {
        Cull Off ZWrite Off ZTest Always
        Pass
        {
            CGPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert_img
            #pragma fragment frag

            sampler2D _CameraDepthTexture;
            float4 _CameraDepthTexture_TexelSize;

            // 找最小深度
            float4 frag(v2f_img i) : SV_Target
            {
                //return tex2D(_CameraDepthTexture, i.uv);
                float2 texelSize = 0.5 * _CameraDepthTexture_TexelSize.xy;
                float depth1 = tex2D(_CameraDepthTexture, i.uv + float2(-1, -1) * texelSize);
                float depth2 = tex2D(_CameraDepthTexture, i.uv + float2(-1,  1) * texelSize);
                float depth3 = tex2D(_CameraDepthTexture, i.uv + float2( 1, -1) * texelSize);
                float depth4 = tex2D(_CameraDepthTexture, i.uv + float2( 1,  1) * texelSize);
                return min(depth1, min(depth2, min(depth3, depth4)));
            }
            ENDCG
        }
        Pass
        {
            CGPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert_img
            #pragma fragment frag

            float remap(float original_value, float original_min, float original_max, float new_min, float new_max)
            {
                return new_min + (((original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
            }
            
            sampler2D _DownSampleDepth;

            float4x4 _InvProj;
            float4x4 _InvView;
            float3 GetWorldPos(float depth, float2 uv)
            {
                // 屏幕空间 --> 视锥空间
                float4 view_vector = mul(_InvProj, float4(2.0 * uv - 1.0, depth, 1.0));
                view_vector.xyz /= view_vector.w;
                //视锥空间 --> 世界空间
                float4x4 l_matViewInv = _InvView;
                float4 world_vector = mul(l_matViewInv, float4(view_vector.xyz, 1));
                return world_vector.xyz;
            }

            float3 _Min;
            float3 _Max;
            float2 RayCast(float3 pos, float3 dir)
            {
                float3 invDir = 1 / dir;

                float3 t0 = (_Min - pos) * invDir;
                float3 t1 = (_Max - pos) * invDir;
                float3 tmin = min(t0, t1);
                float3 tmax = max(t0, t1);

                float dstA = max(max(tmin.x, tmin.y), tmin.z); //进入点
                float dstB = min(tmax.x, min(tmax.y, tmax.z)); //出去点

                float dstToBox = max(0, dstA);
                float dstInsideBox = max(0, dstB - dstToBox);
                return float2(dstToBox, dstInsideBox);
            }

            // Henyey-Greenstein
            float hg(float a, float g)
            {
                float g2 = g * g;
                return (1 - g2) / (4 * 3.1415 * pow(1 + g2 - 2 * g * (a), 1.5));
            }
            float Phase(float a)
            {
                float blend = .5;
                float hgBlend = hg(a, 0.78) * (1 - blend) + hg(a, -0.25) * blend;
                return 0.29 + hgBlend * 0.6;
            }

            sampler2D _MaskNoise;
            sampler2D _WeatherMap;
            sampler3D _ShapeNoise;
            sampler3D _DetailNoise;
            
            float _ShapeSpeedScale;
            float _ShapeUVWTiling;
            float _ShapeSampleOffset;
            float _DetailSpeedScale;
            float _DetailUVWTiling;
            float _DetailSampleOffset;
            
            float _HeightWeight;
            float4 _ShapeNoiseWeight;
            float _DensityOffset;
            float _DetailWeight;
            float _DetailNoiseWeight;
            float _DensityMultiplier;
            float Density(float3 pos)
            {
                float3 center = (_Min + _Max) * 0.5;
                float3 size = _Max - _Min;

                float shapeSpeed = _Time.y * _ShapeSpeedScale;
                float detailSpeed = _Time.y * _DetailSpeedScale;
                float3 shapeUVW = pos * _ShapeUVWTiling + float3(shapeSpeed, shapeSpeed * 0.2, 0);
                float3 detailUVW = pos * _DetailUVWTiling + float3(detailSpeed, detailSpeed * 0.2, 0);
                float2 uv = (size.xz * 0.5 + pos.xz - center.xz) / max(size.x, size.z);

                float maskNoise = tex2D(_MaskNoise, uv + float2(shapeSpeed * 0.5, 0)).r;
                float weatherMap = tex2D(_WeatherMap, uv + float2(shapeSpeed * 0.4, 0)).r;
                float4 shapeNoise = tex3D(_ShapeNoise, shapeUVW + maskNoise * _ShapeSampleOffset * 0.1);
                float4 detailNoise = tex3D(_DetailNoise, detailUVW + shapeNoise.r * _DetailSampleOffset * 0.1);

                // 边缘衰减
                const float edgeFadeDist = 10;
                float distX = min(edgeFadeDist, min(pos.x - _Min.x, _Max.x - pos.x));
                float distZ = min(edgeFadeDist, min(pos.z - _Min.z, _Max.z - pos.z));
                float edgeWeight = min(distZ, distX) / edgeFadeDist;

                // 高度衰减
                float gmin = remap(weatherMap, 0, 1, 0.1, 0.6); // 找到云底部密度
                float gmax = remap(weatherMap, 0, 1, gmin, 0.9); // 找到云顶部密度
                float heightPercent = (pos.y - _Min.y) / size.y; // 0: pos处于云层底部 1: pos处于云层顶部
                float heightGradient =
                    saturate(remap(heightPercent, 0, gmin, 0, 1)) * // 从底部开始变密
                    saturate(remap(heightPercent, 1, gmax, 0, 0.9)); // 到顶部变稀疏
                float heightGradient2 =
                    saturate(remap(heightPercent, 0, weatherMap, 1, 0)) *
                    saturate(remap(heightPercent, 0, gmin, 0, 1));
                heightGradient = saturate(lerp(heightGradient, heightGradient2, _HeightWeight));
                heightGradient *= edgeWeight;

                float4 normShapeNoiseWeight = _ShapeNoiseWeight / dot(_ShapeNoiseWeight, 1); // 把ShapeNoise4个通道加权平均
                float shapeFBM = dot(shapeNoise, normShapeNoiseWeight) * heightGradient;
                float baseShapeDensity = shapeFBM + _DensityOffset * 0.01;
                if (baseShapeDensity > 0)
                {
                    // 侵蚀
                    float detailFBM = pow(detailNoise.r, _DetailWeight);
                    float oneMinusShape = 1 - baseShapeDensity;
                    float detailErodeWeight = oneMinusShape * oneMinusShape * oneMinusShape;
                    float cloudDensity = baseShapeDensity - detailFBM * detailErodeWeight * _DetailNoiseWeight;
                    return saturate(cloudDensity * _DensityMultiplier);
                }
                return 0;
            }

            sampler2D _BlueNoise;
            float4 _BlueNoise_ST;
            float _BlueNoiseScale;

            float _LightAbsorptionThroughCloud;
            float _LightAbsorptionTowardSun;
            float4 _ColorA;
            float4 _ColorB;
            float _ColorOffsetA;
            float _ColorOffsetB;
            float3 Transmittance(float3 pos)
            {
                float3 lightDir = _WorldSpaceLightPos0;

                float distInsideBox = RayCast(pos, lightDir).y;
                float sumDensity = 0;
                const float stepCount = 8;
                float stepSize = distInsideBox / stepCount;
                for(int step = 0; step < stepCount; ++step)
                {
                    pos += lightDir * stepSize;
                    sumDensity += max(0, Density(pos) * stepSize);
                }
                float transmittance = exp(-sumDensity * _LightAbsorptionTowardSun);

                float3 cloudColor = lerp(_ColorA, 1, saturate(transmittance * _ColorOffsetA));
                cloudColor = lerp(_ColorB, cloudColor, saturate(pow(transmittance * _ColorOffsetB, 3)));
                return transmittance * cloudColor;
            }
            float4 frag(v2f_img i) : SV_Target
            {
                float2 uv = i.uv;
                float depth = tex2D(_DownSampleDepth, uv).r;
                float3 cameraPos = _WorldSpaceCameraPos;
                float3 worldPos = GetWorldPos(depth, i.uv);
                float3 viewDir = normalize(worldPos - cameraPos);
                float depthEyeLinear = length(worldPos - cameraPos);

                float2 raycast = RayCast(cameraPos, viewDir);
                float distToBox = raycast.x;
                float distInsideBox = raycast.y;
                float distLimit = min(depthEyeLinear - distToBox, distInsideBox);

                float3 entryPos = cameraPos + viewDir * distToBox;
                float cos_theta = dot(viewDir, _WorldSpaceLightPos0);
                float3 phase = Phase(cos_theta);
                float blue = tex2D(_BlueNoise, i.uv * _BlueNoise_ST.xy + _BlueNoise_ST.zw);
                float moved = blue * _BlueNoiseScale;
                float sumDensity = 1;
                float3 sumEnergy = 0;

                const float stepCount = 512;
                const float stepSize = exp(3.5) * 0.06;
                [loop]
                for (int j = 0; j < stepCount; ++j)
                {
                    if (moved < distLimit)
                    {
                        float3 pos = entryPos + viewDir * moved;
                        float density = Density(pos);
                        if (density > 0)
                        {
                            float3 transmittance = Transmittance(pos);
                            sumEnergy += density * stepSize * sumDensity * transmittance * phase;
                            sumDensity *= exp(-density * stepSize * _LightAbsorptionThroughCloud);

                            if (sumDensity < 0.01) break;
                        }
                    }
                    moved += stepSize;
                }
                return float4(sumEnergy, sumDensity);
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
            sampler2D _DownSampleColor;

            float4 frag(v2f_img i) : SV_Target
            {
                float4 col = tex2D(_MainTex, i.uv);
                float4 cloudCol = tex2D(_DownSampleColor, i.uv);

                col.rgb *= cloudCol.a;
                col.rgb += cloudCol.rgb;
                return col;
            }
            ENDCG
        }
    }
}