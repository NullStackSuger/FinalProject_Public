Shader "Wave"
{
    Properties
    {
        _Roughness ("Roughness", Range(0, 1)) = 0.311
    }
    SubShader
    {
        Tags {"Queue" = "Transparent" "RenderType" = "Opaque" }
        CGPROGRAM
        #pragma surface surf Standard fullforwardshadows vertex:vert addshadow
        #include "UnityCG.cginc"

        struct Input
        {
            float2 worldUV;
            float4 screenPos;
            float3 viewDir;
            INTERNAL_DATA
        };

        int SampleCount0;
        int SampleCount1;
        int SampleCount2;
        sampler2D Displacement0;
        sampler2D Derivatives0;
        sampler2D Turbulence0;
        sampler2D Displacement1;
        sampler2D Derivatives1;
        sampler2D Turbulence1;
        sampler2D Displacement2;
        sampler2D Derivatives2;
        sampler2D Turbulence2;
        sampler2D _CameraDepthTexture;

        float _Rougness;

        void vert(inout appdata_full v, out Input o)
        {
            UNITY_INITIALIZE_OUTPUT(Input, o);
            float3 worldPos = mul(unity_ObjectToWorld, v.vertex);
            float4 worldUV = float4(worldPos.xz, 0, 0);
            o.worldUV = worldUV.xy;

            o.viewDir = _WorldSpaceCameraPos.xyz - mul(unity_ObjectToWorld, v.vertex);

            float4 displacement = 0;
            displacement += tex2Dlod(Displacement0, worldUV / SampleCount0);
            displacement += tex2Dlod(Displacement1, worldUV / SampleCount1);
            displacement += tex2Dlod(Displacement2, worldUV / SampleCount2);
            v.vertex += mul(unity_WorldToObject, displacement); // ERROR

            o.screenPos = UnityObjectToClipPos(v.vertex);
        }

        float3 WorldToTangentNormalVector(Input i, float3 normal)
        {
            float3 t2w0 = WorldNormalVector(i, float3(1, 0, 0));
            float3 t2w1 = WorldNormalVector(i, float3(0, 1, 0));
            float3 t2w2 = WorldNormalVector(i, float3(0, 0, 1));
            float3x3 t2w = float3x3(t2w0, t2w1, t2w2);
            return normalize(mul(t2w, normal));
        }
        
        void surf(Input i, inout SurfaceOutputStandard o)
        {
            float4 derivatives = 0;
            derivatives += tex2D(Derivatives0, i.worldUV / SampleCount0);
            derivatives += tex2D(Derivatives1, i.worldUV / SampleCount1);
            derivatives += tex2D(Derivatives2, i.worldUV / SampleCount2);
            float2 slope = float2(derivatives.x / (1 + derivatives.z), derivatives.y / (1 + derivatives.w));
            float3 worldNormal = normalize(float3(-slope.x, 1, -slope.y));
            o.Normal = WorldToTangentNormalVector(i, worldNormal);

            float jacobian = tex2D(Turbulence0, i.worldUV / SampleCount0).x;
            jacobian = clamp(0, 1, (-jacobian + 0.84) * 2.4);

            float2 screenUV = i.screenPos.xy / i.screenPos.w;
            float backgroundDepth = LinearEyeDepth(tex2D(_CameraDepthTexture, screenUV)); // 水底深度
            float surfaceDepth = i.screenPos.z; // 水面深度
            float depthDiff = max(0, backgroundDepth - surfaceDepth - 0.1); // 深度差值

            o.Albedo = lerp(0, 1, jacobian);
            o.Smoothness = 0.7;
            o.Metallic = 0;

            float3 viewDir = normalize(i.viewDir);
            float3 h = normalize(-worldNormal + _WorldSpaceLightPos0);
            float vDoth = pow(saturate(dot(viewDir, -h)), 5) * 30 * 0.133;
            float3 color = float3(0.1, 0.2, 0.9);

            float fresnel = dot(worldNormal, viewDir);
            fresnel = saturate(1 - fresnel);
            fresnel = pow(fresnel, 5);

            o.Emission = lerp(color * (1 - fresnel), 0, jacobian);
        }
        
        ENDCG
    }
}