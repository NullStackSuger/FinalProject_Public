Shader "Grass"
{
    Properties
    {
        _TessellationUniform("曲面细分",Range(1,64)) = 1
        
        _TopColor ("草尖颜色", Color) = (1,1,1,1)
        _BottomColor ("草根颜色", Color) = (1,1,1,1)
        
        _BendRotationRandom("抗倒伏", Range(0, 1)) = 0.2
        _TranslucentGain ("透光率", Range(0, 2)) = 0.5
        
        _BladeWidth("宽度", Float) = 0.05
        _BladeWidthRandom("宽度随机", Float) = 0.02
        _BladeHeight("高度", Float) = 0.5
        _BladeHeightRandom("高度随机", Float) = 0.3
        
        _WindDistortionMap("Flow Map", 2D) = "white" {}
        _WindFrequency("Wind Frequency 风频率", Vector) = (0.05, 0.05, 0, 0)
        _WindStrength("Wind Strength 风强度", Float) = 1
        
        _BladeForward("草弯曲程度", Float) = 0.38
        _BladeCurve("草叶段数", Range(1, 4)) = 2
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        
        Pass
        {
            CULL Off
            
            CGPROGRAM
            #pragma hull hullProgram
            #pragma domain domain
            #pragma geometry geo
            #pragma vertex tessvert
            #pragma fragment frag
            #pragma multi_compile_fwdbase // 接收阴影
            #pragma require geometry
            #pragma require tessellation

            #include "AutoLight.cginc"
            #include "Lighting.cginc"
            #include "Grass.cginc"

            float _TranslucentGain;

            float4 frag(geometryOutput input, fixed facing : VFACE) : SV_Target
            {
                float shadow = SHADOW_ATTENUATION(input);
                float3 normal = facing > 0 ? input.normal : -input.normal;
                float NdotL = saturate(saturate(dot(normal, _WorldSpaceLightPos0)) + _TranslucentGain) * shadow;
                float3 ambient = ShadeSH9(float4(normal, 1));
                // 如果不max会导致草叶尖端全黑
                float4 lightIntensity = max(NdotL * _LightColor0 + float4(ambient, 1), 0.35);
                float4 col = lerp(_BottomColor, _TopColor * lightIntensity, input.uv.y);
                return col;
            }
            ENDCG
        }
        Pass
        {
            Tags
            {
                "LightMode" = "ShadowCaster"
            }
            
            CGPROGRAM
            #pragma hull hullProgram
            #pragma domain domain
            #pragma geometry geo
            #pragma vertex tessvert
            #pragma fragment frag
            #pragma multi_compile_shadowcaster
            #pragma require geometry
            #pragma require tessellation

            #include "Grass.cginc"

            float4 frag(geometryOutput i) : SV_Target
	        {
		        SHADOW_CASTER_FRAGMENT(i)
	        }
            ENDCG
        }
    }
}