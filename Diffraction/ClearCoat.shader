Shader "Diffraction/ClearCoat"
{
    Properties
    {
        _Color ("Color", Color) = (1, 1, 1, 1)
        _Smoothness ("Smoothness", Range(0, 1)) = 1
        _Metallic ("Metallic", Range(0, 1)) = 0
        _MainTex ("Albedo Tex", 2D) = "white"{}
        _MetallicTex ("Metallic Tex", 2D) = "black"{}
        _NormalTex ("Normal Tex", 2D) = "black"{}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        CGPROGRAM
        #pragma surface surf Standard fullforwardshadows vertex:vert finalcolor:clearCoat
        #include "UnityCG.cginc"
        #include "UnityPBSLighting.cginc"

        sampler2D _MainTex;
        sampler2D _MetallicTex;
        sampler2D _NormalTex;
        float4 _Color;
        float _Metallic;
        float _Smoothness;

        struct Input
        {
		    float2 uv_MainTex;
		    float2 uv_NormalMap;
		    float3 viewDir;
		    float3 worldPos;
		    float3 worldNormal;
		    float3 originalNormal;
	    };

        void vert (inout appdata_full v, out Input o)
        {
	        UNITY_INITIALIZE_OUTPUT(Input,o);
	        o.originalNormal = UnityObjectToWorldNormal(v.normal);
	    }
        void surf (Input IN, inout SurfaceOutputStandard o)
        {
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			fixed4 meta = tex2D(_MetallicTex, IN.uv_MainTex);
			o.Albedo = c.rgb;
			o.Metallic = meta.r;
			o.Smoothness = meta.a;
			o.Normal = UnpackNormal(tex2D(_NormalTex, IN.uv_NormalMap));
			o.Alpha = c.a;
		}
        half4 UNITY_BRDF_PBS_ClearCoat (half3 diffColor, half3 specColor, half oneMinusReflectivity, half smoothness, float3 normal, float3 viewDir, UnityLight light, UnityIndirect gi)
		{
		    float perceptualRoughness = SmoothnessToPerceptualRoughness(smoothness);
		    float3 halfDir = Unity_SafeNormalize(float3(light.dir) + viewDir);
        	
			float NoV = dot(normal, viewDir);
        	/*normal = NoV < 0 ? normal + viewDir * (-NoV + 1e-5f) : normal;
        	NoV = saturate(dot(normal, viewDir));*/
			float NoL = dot(normal, light.dir);
            float NoH = dot(normal, halfDir);
            float LoV = dot(light.dir, viewDir);
            float LoH = dot(light.dir, halfDir);

		    // Diffuse term
		    float diffuseTerm = DisneyDiffuse(NoV, NoL, LoH, perceptualRoughness) * NoL;

		    // Specular term
		    float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
        	float V = SmithBeckmannVisibilityTerm(NoL, NoV, roughness);
        	float D = NDFBlinnPhongNormalizedTerm(NoH, PerceptualRoughnessToSpecPower(perceptualRoughness));
			/*roughness = max(roughness, 0.002);
		    float V = SmithJointGGXVisibilityTerm (NoL, NoV, roughness);
		    float D = GGXTerm (NoH, roughness);*/
		    float specularTerm = V * D * UNITY_PI;
            specularTerm = max(0, specularTerm * NoL);
            specularTerm *= any(specColor) ? 1.0 : 0.0; // 如果specColor是0, 就没有specularTerm
			specularTerm *= FresnelTerm (specColor, LoH);
            
            // 高光衰减因子
		    float surfaceReduction = 1.0 / (roughness * roughness + 1.0);
			// 高光的边缘补充能量
		    float grazingTerm = saturate(smoothness + (1 - oneMinusReflectivity));
		    float3 color = specularTerm * light.color + surfaceReduction * gi.specular * FresnelLerp(specColor, grazingTerm, NoV);
		    
		    return float4(color, 1);
		}
        inline half4 Standard_ClearCoat(SurfaceOutputStandard s, float3 viewDir, UnityGI gi)
		{
		    s.Normal = normalize(s.Normal);

            // 1 - F0
		    half oneMinusReflectivity;
		    half3 specColor;
		    s.Albedo = DiffuseAndSpecularFromMetallic(s.Albedo, s.Metallic, /*out*/ specColor, /*out*/ oneMinusReflectivity);

		    // 预乘alpha
		    // 因为只有漫反射会受到aplha影响
		    half outputAlpha;
		    s.Albedo = PreMultiplyAlpha(s.Albedo, s.Alpha, oneMinusReflectivity, /*out*/ outputAlpha);

		    half4 c = UNITY_BRDF_PBS_ClearCoat(s.Albedo, specColor, oneMinusReflectivity, s.Smoothness, s.Normal, viewDir, gi.light, gi.indirect);
		    c.a = outputAlpha;
		    return c;
		}
        void clearCoat(Input IN, SurfaceOutputStandard o, inout fixed4 color)
		{
            //fixed3 lightDir = normalize(UnityWorldSpaceLightDir(IN.worldPos));
        	fixed3 lightDir = _WorldSpaceLightPos0.xyz;
            IN.viewDir = normalize(UnityWorldSpaceViewDir(IN.worldPos));

            UnityGI gi;
            UNITY_INITIALIZE_OUTPUT(UnityGI, gi);
            gi.indirect.diffuse = 0; // 只受环境光影响
            gi.indirect.specular = 0;
            gi.light.color = _LightColor0.rgb;
            gi.light.dir = lightDir;
            gi.light.ndotl = 1; // 清漆要表现出光直射

            // Call GI (lightmaps/SH/reflections) lighting function
            UnityGIInput giInput = (UnityGIInput)0;
            //UNITY_INITIALIZE_OUTPUT(UnityGIInput, giInput);
            giInput.light = gi.light;
            giInput.worldPos = IN.worldPos;
            giInput.worldViewDir = IN.viewDir;
            giInput.probeHDR[0] = unity_SpecCube0_HDR;
            giInput.probeHDR[1] = unity_SpecCube1_HDR;
            #if defined(UNITY_SPECCUBE_BLENDING) || defined(UNITY_SPECCUBE_BOX_PROJECTION)
            giInput.boxMin[0] = unity_SpecCube0_BoxMin; // .w holds lerp value for blending
            #endif

            o.Normal = IN.originalNormal;
            o.Smoothness = _Smoothness;
            o.Metallic = _Metallic;

            LightingStandard_GI(o, giInput, gi);
            color += Standard_ClearCoat(o, IN.viewDir, gi);
		}	
        ENDCG
    }
}