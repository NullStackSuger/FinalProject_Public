Shader "Hair/Fur"
{
    Properties
    {
        //毛发噪声纹理
        _FurTex("Fur Texture", 2D) = "white" {}
        //毛发根部颜色
        [HDR]_RootColor("RootColor",Color)=(0,0,0,1)
        //毛发末端颜色
        [HDR]_TopColor("TopColor",Color)=(1,1,1,1)
        //凹凸纹理
        _BumpTex("Normal Map", 2D) = "bump" {}
        //凹凸强度
        _BumpIntensity("Bump Intensity",Range(0,2))=1
        //毛发长度
        _FurLength("Fur Length", Float) = 0.2
        //壳层总数
        _ShellCount("Shell Count", Float) = 16
        //外发光颜色
        [HDR]_FresnelColor("Fresnel Color", Color) = (1,1,1,1)
        //菲涅尔强度
        _FresnelPower("Fresnel Power", Float) = 5
        //噪声剔除阈值
        _FurAlphaPow("Fur AlphaPow", Range(0,6)) = 1
    }
    SubShader
    {
        Tags { "RenderType" = "Transparent" }
        ZWrite Off
        Cull Back
        Blend SrcAlpha OneMinusSrcAlpha
        
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };
 
            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 viewDir : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
                float shellIndex : TEXCOORD3;
            };
            
            sampler2D _FurTex;
            sampler2D _BumpTex;
            float _FurLength;
            float _ShellCount;
            float4 _FresnelColor;
            float _FresnelPower;
            float _FurAlphaPow;
            float4 _RootColor;
            float4 _TopColor;
            float _ShellIndex;
            
            v2f vert(appdata v)
            {
                v2f o;
                
                float shellIndex = _ShellIndex;
                float shellFrac = shellIndex / _ShellCount;

                float3 worldNormal = UnityObjectToWorldNormal(v.normal);
                float4 worldPos = mul(unity_ObjectToWorld, v.vertex);
                worldPos.xyz += worldNormal * (_FurLength * shellFrac);
 
                o.pos = UnityWorldToClipPos(worldPos);
                o.uv = v.uv;
                o.viewDir = normalize(_WorldSpaceCameraPos - worldPos);
                o.worldNormal = worldNormal;
                o.shellIndex = shellIndex;

                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float4 col = tex2D(_FurTex, i.uv);
                float shellFrac = i.shellIndex / _ShellCount;
                float mask = col.r;
                
                float alpha = saturate(mask - pow(shellFrac, _FurAlphaPow)); // 让末端是尖的
                float3 bump = UnpackNormal(tex2D(_BumpTex, i.uv));
                float3 normalWS = normalize(i.worldNormal + bump * 0.5);
                float fresnel = pow(1.0 - saturate(dot(i.viewDir, normalWS)), _FresnelPower); // 边缘光
                col *= lerp(_RootColor, _TopColor, shellFrac);
                
                col.a = alpha;
                col.rgb += _FresnelColor.rgb * fresnel * alpha;
                return col;
            }
            ENDCG
        }
    }
}