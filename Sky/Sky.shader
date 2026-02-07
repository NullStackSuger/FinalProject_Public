Shader "Sky/Sky"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white"{}
    }
    SubShader
    {
        Cull Off ZWrite Off ZTest Always
        Pass
        {
            CGPROGRAM
            #include "UnityCG.cginc"
            #include "AtmosphereParameter.cginc"
            #include "RayMarching.cginc"
            #pragma vertex vert_img
            #pragma fragment frag

            float4 frag(v2f_img i) : SV_Target
            {
                AtmosphereParameter param = GetAtmosphereParameter();

                float2 uv = i.uv;
                float bottomRadius = param.PlanetRadius;
                float topRadius = param.PlanetRadius + param.AtmosphereHeight;
                float2 lutParam = UVToLutParam(bottomRadius, topRadius, uv);
                float cos_theta = lutParam.x;
                float r = lutParam.y;
                float sin_theta = sqrt(1.0 - cos_theta * cos_theta);
                float3 viewDir = float3(sin_theta, cos_theta, 0);
                float3 eyePos = float3(0, r, 0);

                // 视线与大气层交点
                float atmoDist = RayIntersectSphere(0, topRadius, eyePos, viewDir);
                float3 hitPoint = eyePos + viewDir * atmoDist;

                float3 col = Transmittance(param, eyePos, hitPoint);
                return float4(col, 1);
            }
            ENDCG
        }
        Pass
        {
            CGPROGRAM
            #include "UnityCG.cginc"
            #include "AtmosphereParameter.cginc"
            #include "RayMarching.cginc"
            #pragma vertex vert_img
            #pragma fragment frag

            sampler2D _MainTex;

            float4 frag(v2f_img i) : SV_Target
            {
                AtmosphereParameter param = GetAtmosphereParameter();

                float2 uv = i.uv;
                float3 viewDir = UVToViewDir(uv);
                float3 lightDir = normalize(_WorldSpaceLightPos0);
                float h = _WorldSpaceCameraPos.y - param.SeaLevel + param.PlanetRadius;
                float3 eyePos = float3(0, h, 0);

                float3 col = GetSkyView(param, eyePos, viewDir, lightDir, _MainTex);
                return float4(col, 1); // 这里下半部分是黑的, 因为它在地壳内部
            }
            ENDCG
        }
        Pass
        {
            CGPROGRAM
            #include "UnityCG.cginc"
            #include "AtmosphereParameter.cginc"
            #include "RayMarching.cginc"
            #pragma vertex vert
            #pragma fragment frag

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }
            
            sampler2D _MainTex;
            
            float4 frag (v2f i) : SV_Target
            {
                float3 viewDir = normalize(i.worldPos);
                float3 col = tex2D(_MainTex, ViewDirToUV(viewDir));
                return float4(col, 1);
            }
            
            ENDCG
        }
    }
}