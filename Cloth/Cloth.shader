Shader "Cloth"
{
    Properties
    {
    	/*_BaseMap ("Base Map", 2D) = "white"{}
    	_BaseColor ("Base Color", Color) = (0, 0, 0, 1)
    	_SpecularColor ("Specular Color", Color) = (0, 0, 0, 1)
    	
    	_NormalMap ("Normal Map", 2D) = "white"{}
		_NormalMapStrength ("Normal Map Strength", Range(0, 8)) = 1
		
		_FuzzMap("Fuzz Map", 2D) = "white"{}
		_FuzzMapStrength ("Fuzz Map Strength", Range(0, 2)) = 0
    	
    	_MaskMap ("Mask Map", 2D) = "white"{} // G: AO  S: Smoothness
    	
    	_SmoothnessMin ("Smoothness Min", Range(0, 1)) = 0
    	_SmoothnessMax ("Smoothness Max", Range(0, 1)) = 0
    	_Anisotropy ("Anisotropy", Range(-1, 1)) = 0
    	
    	_UseThreadMap ("Use Thread Map", int) = 0
    	_ThreadMap ("Thread Map", 2D) = "white"{}
        _ThreadAOStrength ("Thread AO Strength", Range(0, 1)) = 0
    	_ThreadNormalStrength ("Thread Normal Strength", Range(0, 2)) = 0
    	_ThreadSmoothnessScale ("Thread Smoothness Scale", Range(0, 1)) = 0*/
    	
    	_DiffuseColor ("Diffuse Color", Color) = (0, 0, 0, 1)
    	_SpecularColor ("Specular Color", Color) = (0, 0, 0, 1)
    	_Roughness ("Roughness", Range(0, 1)) = 0.5
    }
    SubShader
    {
        Cull Off
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
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            /*float remap(float original_value, float original_min, float original_max, float new_min, float new_max)
            {
                return new_min + (((original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
            }
            float2 UVCombine(float2 uv, float4 st)
            {
                return uv * st.xy + st.zw;
            }
            float3 tex2DNormal(sampler2D tex, float2 uv)
			{
			    float4 c = tex2D(tex, uv);
            	
			    float3 n;
			    n.xy = c.xy * 2 - 1;
			    n.z  = sqrt(saturate(1 - dot(n.xy, n.xy)));
            	
			    return normalize(n);
			}
            float3 NormalStrength(float3 normal, float strength)
            {
	            return float3(normal.xy * strength, lerp(1, normal.z, strength));
            }
            float3 NormalBlend(float3 a, float3 b)
            {
	            return normalize(float3(a.xy + b.xy, a.z * b.z));
            }
            float3 Branch(bool b, float3 trueRet, float3 falseRet)
            {
	            if (b)
	            {
		            return trueRet;
	            }
	            else
	            {
	            	return falseRet;
	            }
            }
            float3 Branch(int b, float3 trueRet, float3 falseRet)
            {
	            return Branch(b > 0, trueRet, falseRet);
            }
           
            sampler2D _BaseMap;
            float4 _BaseMap_ST;
            float4 _BaseColor;
            float4 _SpecularColor;
            
            sampler2D _NormalMap;
            float4 _NormalMap_ST;
            float _NormalMapStrength;
            
            sampler2D _FuzzMap;
            float4 _FuzzMap_ST;
            float _FuzzMapStrength;
            
            sampler2D _MaskMap;
            
            float _SmoothnessMin;
            float _SmoothnessMax;
            float _Anisotropy;
            
            int _UseThreadMap;
            sampler2D _ThreadMap;
            float4 _ThreadMap_ST;
            float _ThreadAOStrength;
            float _ThreadNormalStrength;
            float _ThreadSmoothnessScale;*/

            /*void ThreadMapDetail(bool useThreadMap, sampler2D threadMap, float2 uv, float3 normal, float smoothness, float alpha, float ambientOcclusion, float threadAOStrength, float threadNormalStrength, float threadSmoothnessStrength, out float3 outNormal, out float outSmoothness, out float outAmbientOcclusion, out float outAlpha)
            {
	            outNormal = 0;
            	outSmoothness = 0;
            	outAmbientOcclusion = 0;
            	outAlpha = 0;

            	float4 threadColor = tex2D(threadMap, uv);

            	// Normal Party
            	float3 v = float3(threadColor.a, threadColor.g, 1);
            	float3 s = normalize(UnpackNormal(float4(v, 0))) * threadNormalStrength;
				
            }*/

            // 棉布
            float D_Ashikhmin(float roughness, float NoH)
            {
			     //Ashikhmin 2007,"Distribution-based BRDFs"
			     float a2=roughness*roughness;
			     float cos2h=NoH*NoH;
			     float sin2h=max(1.0 - cos2h, 0.0078125);//2^(-14/2), so sin2h^2 > 0  in fp16
			     float sin4h=sin2h * sin2h;
			     float cot2= -cos2h / (a2 * sin2h);
			     return 1.0 / (UNITY_PI * (4.0 * a2 + 1.0) * sin4h )* ( 4.0 * exp(cot2) + sin4h );
			}
            float V_Ashikhmin(float ndotv, float ndotl)
			{
				return 1. / (4. * (ndotl + ndotv - ndotl * ndotv));
			}
            float D_Charlie(float roughness, float NoH)
			{
			     //Estevez and Kulla 2017,"Production Friendly Microfacet sheen BRDF"
			     float invAlpha=1.0/roughness;
			     float cos2h=NoH * NoH;
			     float sin2h=max(1.0 - cos2h, 0.0078125);
			     return (2.0 + invAlpha)* pow(sin2h,invAlpha * 0.5)/(2.0 * UNITY_PI);
			}
            float CharlieL (float x, float r)
			{
			    r = saturate(r);
			    r = 1 - (1 - r) * (1 - r);
			    float a = lerp(25.3245, 21.5473, r);
			    float b = lerp(3.32435, 3.82987, r);
			    float c = lerp(0.16801, 0.19823, r);
			    float d = lerp(-1.27393, -1.97760, r);
			    float e = lerp(-4.85967, -4.32054, r);
			    return a / (1 + b * pow(x, c)) + d * x + e;
			}
            float V_Charlie (float NL, float NV, float roughness)
			{
			    float lambdaV = NV < 0.5 ? exp(CharlieL(NV, roughness)) : exp(2 * CharlieL(0.5, roughness) - CharlieL(1 - NV, roughness));
			    float lambdaL = NL < 0.5 ? exp(CharlieL(NL, roughness)) : exp(2 * CharlieL(0.5, roughness) - CharlieL(1 - NL, roughness));
			    return 1 / ((1 + lambdaV + lambdaL) * (4 * NV * NL));
			}

			// 丝绸
            float DisneyDiffuse (float NV, float NL, float LH, float perceptualRoughness)
			{
			    float fd90 = 0.5 + (2 * LH * LH) * perceptualRoughness;
			    float lightScatter = (1 + (fd90 - 1) * pow(1 - NL, 5));
			    float viewScatter = (1 + (fd90 - 1) * pow(1 - NV, 5));
			    return lightScatter * viewScatter * UNITY_INV_PI;
			}
            float DV_SmithJointGGXAniso (float TH, float BH, float NH, float TV, float BV, float NV, float TL, float BL, float NL, float roughness)
			{
			    float a2 = roughness * roughness;
			    float3 v = float3(roughness * TH, roughness * BH, a2 * NH);
			    float s = dot(v, v);
			    float lambdaV = NL * length(float3(roughness * TV, roughness * BV, NV));
			    float lambdaL = NV * length(float3(roughness * TL, roughness * BL, NL));
			    float2 D = float2(a2 * a2 * a2, s * s) * UNITY_INV_PI;
			    float2 G = float2(1, lambdaV + lambdaL) * 0.5;
			    return D.x * G.x / max(D.y * G.y, 1e-7);
			}
			float3 F_Schlick (float3 f0, float LH)
			{
			    return f0 + (1 - f0) * pow(1 - LH, 5);
			}
            
            float4 frag(v2f i) : SV_Target
            {
            	/*// Diffuse
            	float4 baseColor = tex2D(_BaseMap, UVCombine(i.uv, _BaseMap_ST)) * _BaseColor;

            	// Fuzz
            	float fuzz = lerp(0, tex2D(_FuzzMap, UVCombine(UVCombine(i.uv, _ThreadMap_ST), _FuzzMap_ST)).r, _FuzzMapStrength);

            	// Alpha
            	float4 baseColorAndFuzz = saturate(baseColor + fuzz);
            	float alpha = baseColorAndFuzz.a;

            	// AO & Smoothness
            	float4 mask = tex2D(_MaskMap, UVCombine(i.uv, _BaseMap_ST));
            	float ao = mask.g;
            	float smoothness = remap(mask.a, 0, 1, _SmoothnessMin, _SmoothnessMax);

            	// Normal
            	float3 normal = tex2D(_NormalMap, UVCombine(i.uv, _BaseMap_ST));
            	normal = NormalStrength(normal, _NormalMapStrength);
            	normal = normalize(normal);

            	// Thread
            	float4 thread = tex2D(_ThreadMap, UVCombine(i.uv, _ThreadMap_ST));
            	// Thread Normal
            	float3 newNormal = float3(thread.a, thread.g, 1);
            	newNormal = UnpackNormal(float4(newNormal, 1));
            	newNormal = normalize(newNormal);
            	newNormal = NormalStrength(newNormal, _ThreadNormalStrength);
            	newNormal = NormalBlend(normal, newNormal);
            	newNormal = normalize(newNormal);
            	normal = Branch(_UseThreadMap, newNormal, normal);
            	// Thread Smoothness
            	float newSmoothness = remap(thread.b, 0, 1, -1, 1);
            	newSmoothness = lerp(0, newSmoothness, saturate(_ThreadSmoothnessScale));
            	newSmoothness = saturate(smoothness + newSmoothness);
            	smoothness = Branch(_UseThreadMap, newSmoothness, smoothness);
            	// Thread AO
            	float newAO = lerp(1, thread.r, saturate(_ThreadAOStrength));
            	newAO = ao * newAO;
            	ao = Branch(_UseThreadMap, newAO, ao);
            	// Thread Alpha
            	alpha = alpha * thread.r;*/

            	return float4(0, 0, 0, 1);
            }
            ENDCG
        }
    }
}