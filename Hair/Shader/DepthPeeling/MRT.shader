Shader "Hair/DepthPeeling/MRT"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque" "LightMode"="ForwardBase"
        }
        Cull Off
        
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "autolight.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv     : TEXCOORD0;
            };
            struct v2f
            {
                float4 pos       : SV_POSITION;
                float3 normal    : NORMAL;
                float2 uv        : TEXCOORD0;
                float3 color     : TEXCOORD1;
                float4 screenPos : TEXCOORD2;
            };
            struct fout
            {
                float4 depth : SV_Target0;
                float4 color : SV_Target1;
            };
            
            sampler2D _MainTex;
            sampler2D _PreDepthTexture;
            int _DepthLayer;

            v2f vert(appdata v)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);
                o.normal = v.normal;
                o.uv = v.uv;
                float3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz; // 环境光
                float3 worldNormal = UnityObjectToWorldNormal(v.normal);
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                float3 diffuse = _LightColor0.rgb * saturate(dot(worldNormal, lightDir));
                o.color = ambient + diffuse;
                o.screenPos = ComputeScreenPos(o.pos);

                return o;
            }

            fout frag(v2f i)
            {
                float4 col = tex2D(_MainTex, i.uv);
                col.rgb *= i.color;
                clip(col.a - 0.001);

                float curDepth = i.pos.z / i.pos.w;
                float preDepth = tex2D(_PreDepthTexture, i.screenPos.xy / i.screenPos.w).r;
                #if UNITY_REVERSED_Z
                if (_DepthLayer > 0 && curDepth >= preDepth - 0.0001) discard;
                #else
                if (_DepthLayer > 0 && curDepth <= preDepth - 0.0001) discard;
                #endif

                fout o;
                o.depth = curDepth;
                o.color = col;
                return o;
            }
            
            ENDCG
        }
    }
}