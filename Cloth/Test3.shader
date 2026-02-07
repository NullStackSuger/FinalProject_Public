Shader "Cloth/Test3"
{
     Properties
    {
        _BaseColor ("_BaseColor",Color) = (0.5,0.3,0.2,1)
    	_SpecularColor ("_SpecularColor",Color) = (1, 1, 1, 1)
        _Metallic ("_Metallic",Range(0,1)) = 1
        _Roughness ("_Roughness",Range(0,1)) =1
        _Anisotropy ("_Anisotropy",Float) =0
    	_BaseF0 ("Base F0 (0.04)", Float) = 0.04
    	_FIndex ("F Index",Int) = 1
    	_DIndex ("D Index",Int) = 1
    	_VIndex ("V Index",Int) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "LightMode"="ForwardBase" "Queue" = "Geometry"}
    
        Pass
        {
	        CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma fullforwardshadows
            #pragma multi_compile_fwdbase
            
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            
            #pragma vertex vert
            #pragma fragment frag

	        struct appdata
            {
                float4 vertex : POSITION;
                float4 tangent :TANGENT;
                float3 normal : NORMAL;
                float4 vertexColor : COLOR;
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1;
            };

            struct v2f
            {
                float4 pos              : SV_POSITION; // 必须命名为pos ，因为 TRANSFER_VERTEX_TO_FRAGMENT 是这么命名的，为了正确地获取到Shadow
                float2 uv               : TEXCOORD0;
                float3 tangent          : TEXCOORD1;
                float3 bitangent        : TEXCOORD2; 
                float3 normal           : TEXCOORD3; 
                float3 worldPosition    : TEXCOORD4;
                float3 localPosition    : TEXCOORD5;
                float3 localNormal      : TEXCOORD6;
                float4 vertexColor      : TEXCOORD7;
                float2 uv2              : TEXCOORD8;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.uv2 = v.uv2;
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.worldPosition = mul(unity_ObjectToWorld,v.vertex);
                o.localPosition = v.vertex.xyz;
                o.tangent = UnityObjectToWorldDir(v.tangent);
                o.bitangent = cross(o.normal,o.tangent) * v.tangent.w;
                o.localNormal = v.normal;
                o.vertexColor = v.vertexColor;
                
                return o;
            }

            #ifndef PI
            #define PI 3.141592654
            #endif

            float4 _BaseColor, _SpecularColor;
            float _Roughness,_Metallic;
            float _Anisotropy;
            float _BaseF0;

            inline float pow5(float value)
            {
                return value*value*value*value*value;
            }


            // F 1
            float3 AnisotropicF( float3 f0, float LoH) 
            {
                float f = pow5(1.0 - LoH);
                return f + f0 * (1 - f);
            }
            // F 2
            float3 FresnelTerm(float3 specularColor, float vdoth)
            {
	            float3 fresnel = specularColor + (1.0 - specularColor) * pow(1. - vdoth, 5.);
	            return fresnel;
            }
            // F 3
            float3 SchlickF(float3 specularColor, float vdoth)
            {
	            float fc = pow5(1 - vdoth);
            	return saturate(50 * specularColor.g) * fc + (1 - fc) * specularColor;
            }
            // D 1
            float AnisotropicD(float at, float ab, float ToH, float BoH, float NoH)    
            {
                // Burley 2012, "Physically-Based Shading at Disney"
                float a2 = at * ab;
                float3 d = float3(ab * ToH, at * BoH, a2 * NoH);
                return saturate(a2 * sqrt(a2 / dot(d, d)) * (1.0 / PI));
            }
            // D 2
            float AshikhminD(float roughness, float ndoth)
            {
	            float r2    = roughness * roughness;
	            float cos2h = ndoth * ndoth;
	            float sin2h = max(1.0 - cos2h, 0.0078125);
	            float sin4h = sin2h * sin2h;
	            return (sin4h + 4. * exp(-cos2h / (sin2h * r2))) / (PI * (1. + 4. * r2) * sin4h);
            }
            // D 3
            float CharlieD(float roughness, float NoH)
            {
                 //Estevez and Kulla 2017,"Production Friendly Microfacet sheen BRDF"
                 float invAlpha=1.0/roughness;
                 float cos2h=NoH * NoH;
                 float sin2h=max(1.0 - cos2h, 0.0078125);
                 return (2.0 + invAlpha)* pow(sin2h,invAlpha * 0.5)/(2.0 * PI);
            }
            // V 1
            float AnisotropicV(float at, float ab, float ToV, float BoV,float ToL, float BoL, float NoV, float NoL) 
            {
                // Heitz 2014, "Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs"
                // TODO: lambdaV can be pre-computed for all the lights, it should be moved out of this function
                float lambdaV = NoL * length(float3(at * ToV, ab * BoV, NoL));
                float lambdaL = NoV * length(float3(at * ToL, ab * BoL, NoV));
                float v = 0.5 / (lambdaV + lambdaL);
                return saturate(v);
            }
            // V 2
            float AshikhminV(float ndotv, float ndotl)
            {
	            return 1. / (4. * (ndotl + ndotv - ndotl * ndotv));
            }
            // V 3
            float L(float x, float r)
			{
				r = saturate(r);
				r = 1.0 - (1. - r) * (1. - r);

				float a = lerp( 25.3245,  21.5473, r);
				float b = lerp( 3.32435,  3.82987, r);
				float c = lerp( 0.16801,  0.19823, r);
				float d = lerp(-1.27393, -1.97760, r);
				float e = lerp(-4.85967, -4.32054, r);

				return a / (1. + b * pow(x, c)) + d * x + e;
			}
            float CharlieV(float roughness, float ndotv, float ndotl)
            {
	            float visV = ndotv < .5 ? exp(L(ndotv, roughness)) : exp(2. * L(.5, roughness) - L(1. - ndotv, roughness));
	            float visL = ndotl < .5 ? exp(L(ndotl, roughness)) : exp(2. * L(.5, roughness) - L(1. - ndotl, roughness));

	            return 1. / ((1. + visV + visL) * (4. * ndotv * ndotl));
            }

            struct PixelParams
            {
                float3 anisotropicT;
                float3 anisotropicB;
                float linearRoughness;
                float anisotropy;
                float3 f0;
            };

            int _FIndex;
            int _DIndex;
            int _VIndex;

            float3 BRDF_Anisotropic(in PixelParams pixel,float3 L, float3 V, float3 H,float NoV, float NoL, float NoH, float LoH) 
            {
                float3 t = pixel.anisotropicT;
                float3 b = pixel.anisotropicB;
                float3 v = V;

                float ToV = dot(t, v);
                float BoV = dot(b, v);
                float ToL = dot(t, L);
                float BoL = dot(b, L);
                float ToH = dot(t, H);
                float BoH = dot(b, H);
            	float VoH = dot(v, H);

                // Anisotropic parameters: at and ab are the roughness along the tangent and bitangent
                // to simplify materials, we derive them from a single roughness parameter
                // Kulla 2017, "Revisiting Physically Based Shading at Imageworks"
                float at = max(pixel.linearRoughness * (1.0 + pixel.anisotropy), 0.001);
                float ab = max(pixel.linearRoughness * (1.0 - pixel.anisotropy), 0.001);

                // specular anisotropic BRDF
                float D;
            	if (_DIndex == 1)
            	{
            		D = AnisotropicD(at, ab, ToH, BoH, NoH);
            	}
            	else if (_DIndex == 2)
            	{
            		D = AshikhminD(pixel.f0, NoH);
            	}
	            else
	            {
		            D = CharlieD(pixel.f0, NoH);
	            }

            	// 第2个不太行
                float V_;
            	if (_VIndex == 1)
            	{
            		V_ = AnisotropicV(at, ab, ToV, BoV, ToL, BoL, NoV, NoL);
            	}
            	else if (_VIndex == 2)
            	{
            		V_ = AshikhminV(NoV, NoL);
            	}
	            else
	            {
		            V_ = CharlieV(pixel.f0, NoV, NoL);
	            }

            	// 23效果差不多 但是1不太好表达高光
            	float3 F;
            	if (_FIndex == 1)
            	{
            		F = AnisotropicF(pixel.f0, LoH);
            	}
            	else if (_FIndex == 2)
            	{
            		F = FresnelTerm(_SpecularColor, VoH);
            	}
	            else
	            {
	            	F = SchlickF(_SpecularColor, VoH);
	            }

                return D * V_ * F * PI * NoL;
            }
			
            float4 frag (v2f i ) : SV_Target
            {
                float3 T = normalize(i.tangent);
                float3 N = normalize(i.normal);
                //float3 B = normalize( cross(N,T));
                float3 B = normalize( i.bitangent);
                float3 L = normalize( UnityWorldSpaceLightDir(i.worldPosition.xyz));
                float3 V = normalize( UnityWorldSpaceViewDir(i.worldPosition.xyz));
                float3 H = normalize(V+L);
                
                float NV = dot(N,V);
                float NL = dot(N,L);
                float NH = dot(N,H);
                float LH = dot(L,H);

                float3 F0 = lerp(_BaseF0,_BaseColor,_Metallic);

                PixelParams pixel;
                pixel.anisotropicT = T;
                pixel.anisotropicB = B;
                pixel.linearRoughness = _Roughness;
                pixel.f0 = F0;
                pixel.anisotropy = _Anisotropy;

                float3 brdf = BRDF_Anisotropic(pixel,L,V,H,NV,NL,NH,LH);
                float3 diffuse = _BaseColor * saturate((NL + 0.5) / 2.25);;
            	return float4(brdf, 1);
                return float4(brdf + diffuse, 1);
            }
	        ENDCG
	    }
    }
    Fallback "Diffuse"
}