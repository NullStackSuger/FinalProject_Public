Shader "Hair/DepthPeeling/DepthPeeling"
{
    Properties
    {
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            UNITY_DECLARE_TEX2DARRAY(_FinalClips);
            int _DepthLayer;

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float4 col = 0;
                float4 top = 0;
                for (int t = 0; t < _DepthLayer + 1; ++t)
                {
                    float4 front = UNITY_SAMPLE_TEX2DARRAY(_FinalClips, float3(i.uv, _DepthLayer - t));
                    col = col * (1 - front.a) + front * front.a;
                    top = col;
                }
                col.a = saturate(col.a);
                col.rgb += top.rgb * (1 - col.a);
                col.a = 1;
                return col;
            }
            
            ENDCG
        }
    }
}