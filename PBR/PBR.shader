Shader "PBR"
{
    Properties
    {
        _DiffuseColor ("Diffuse Color", Color) = (1, 1, 1, 1)
        _SpecularColor ("Specular Color", Color) = (1, 1, 1, 1)
        _Smoothness ("Smoothness", Range(0, 1)) = 1
        _Metallic ("Metalness", Range(0, 1)) = 0
        _Anisotropic("Anisotropic",  Range(-20,1)) = 0
        _Ior("Ior", Range(1, 4)) = 1.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque"  "Queue"="Geometry" }
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"

            float4 _DiffuseColor;
            float4 _SpecularColor;
            float _Smoothness;
            float _Metallic;
            float _Anisotropic;
            float _Ior;

            struct VertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 texcoord0 : TEXCOORD0;
                float2 texcoord1 : TEXCOORD1;
            };
            struct VertexOutput
            {
                float4 pos : SV_POSITION;
                float2 uv0 : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float3 positionWS : TEXCOORD3;
                float3 tangentWS : TEXCOORD4;
                float3 bitangentWS : TEXCOORD5;
                LIGHTING_COORDS(6, 7)
                UNITY_FOG_COORDS(8)
            };

            VertexOutput vert(VertexInput i)
            {
                VertexOutput o;
                o.pos = UnityObjectToClipPos(i.vertex);
                o.uv0 = i.texcoord0;
                o.uv1 = i.texcoord1;
                o.normalWS = UnityObjectToWorldNormal(i.normal);
                o.positionWS = mul(unity_ObjectToWorld, i.vertex).xyz;
                o.tangentWS = UnityObjectToWorldDir(i.tangent);
                o.bitangentWS = normalize(cross(o.normalWS, o.tangentWS) * i.tangent.w);
                UNITY_TRANSFER_FOG(o, o.pos);
                return o;
            }
            float BlinnPhong_D(float NoH, float specPow, float specGloss)
            {
                float distribution = pow(NoH, specGloss) * specPow;
                distribution *= (2 + specPow) / (2 * UNITY_PI);
                return distribution;
            }
            float Phong_D(float LRoV, float specPow, float specGloss)
            {
                float distribution = pow(LRoV, specGloss) * specPow;
                distribution *= (2 + specPow) / (2 * UNITY_PI);
                return distribution;
            }
            float Beckman_D(float roughness, float NoH)
            {
                float r2 = roughness * roughness;
                float NoH2 = NoH * NoH;
                float NoH4 = NoH2 * NoH2;
                return max(0.0001, 1 / (UNITY_PI * r2 * NoH4)) * exp((NoH2 - 1) / (r2 * NoH2));
            }
            float Gaussian_D(float roughness, float NoH)
            {
                float r2 = roughness * roughness;
                float thetaH = acos(NoH);
                return exp(-thetaH * thetaH / r2);
            }
            float GGX_D(float roughness, float NoH)
            {
                float r2 = roughness * roughness;
                float NoH2 = NoH * NoH;
                float tanNoH2 = (1 - NoH2) / NoH2;
                return 1 / UNITY_PI * pow(roughness / (NoH * (r2 + tanNoH2)), 2);
            }
            float Trowbridge_D(float roughness, float NoH)
            {
                float r2 = roughness * roughness;
                float distribution = NoH * NoH * (r2 - 1) + 1;
                return r2 / (UNITY_PI * distribution * distribution);
            }
            float TrowbridgeAnisotropic_D(float anisotropic, float NoH, float HoX, float HoY)
            {
                float aspect = sqrt(1 - anisotropic * 0.9);
                float x = max(0.001, pow(1 - _Smoothness, 2) / aspect) * 5;
                float y = max(0.001, pow(1 - _Smoothness, 2) * aspect) * 5;
                return 1 / (UNITY_PI * x * y * pow(pow(HoX / x, 2) + pow(HoY / y, 2) + pow(NoH, 2), 2));
            }
            float WardAnisotropic_D(float anisotropic, float NoL, float NoV, float NoH, float HoX, float HoY)
            {
                float aspect = sqrt(1 - anisotropic * 0.9);
                float x = max(0.001, pow(1 - _Smoothness, 2) / aspect) * 5;
                float y = max(0.001, pow(1 - _Smoothness, 2) * aspect) * 5;
                float exponent = -(pow(HoX / x, 2) + pow(HoY / y, 2)) / pow(NoH, 2);
                float distribution = 1 / (4 * UNITY_PI * x * y * sqrt(NoL * NoV));
                distribution *= exp(exponent);
                return distribution;
            }

            float Implicit_V(float NoL, float NoV)
            {
                float gs = NoL * NoV;
                return gs;
            }
            float AshikhminPremoze_V(float NoL, float NoV)
            {
                float gs = NoL * NoV / (NoL + NoV - NoL * NoV);
                return gs;
            }
            float Duer_V(float3 L, float3 V, float3 N)
            {
                float3 LV = L + V;
                float gs = dot(L, V) * pow(dot(LV, N), -4);
                return gs;
            }
            float Neumann_V(float NoL, float NoV)
            {
                float gs = (NoL * NoV) / max(NoL, NoV);
                return gs;
            }
            float Kelemen_V(float NoL, float NoV, float VoH)
            {
                float gs = (NoL * NoV) / (VoH * VoH);
                return gs;
            }
            float ModifiedKelemen_V(float NoV, float NoL, float roughness)
            {
                float c = 0.797884560802865;
                float k = roughness * roughness * c;
                float gh = NoV * k + (1 - k);
                return gh * gh * NoL;
            }
            float CookTorrence_V(float NoL, float NoV, float VoH, float NoH)
            {
                float gs = min(1, min(2 * NoH * NoV / VoH, 2 * NoH * NoL / VoH));
                return gs;
            }
            float Ward_V(float NoL, float NoV)
            {
                float gs = pow(NoL * NoV, 0.5);
                return gs;
            }
            float Kurt_V(float NoL, float NoV, float VoH, float roughness)
            {
                float gs = NoL * NoV / (VoH * pow(NoL * NoV, roughness));
                return gs;
            }
            float WalterEtAl_V(float NoL, float NoV, float aplha)
            {
                float a2 = aplha * aplha;
                float NoL2 = NoL * NoL;
                float NoV2 = NoV * NoV;
                float smithL = 2 / (1 + sqrt(1 + a2 * (1 - NoL2) / NoL2));
                float smithV = 2 / (1 + sqrt(1 + a2 * (1 - NoV2) / NoV2));
                float gs = smithL * smithV;
                return gs;
            }
            float Beckman_V(float NoL, float NoV, float roughness)
            {
                float r2 = roughness * roughness;
                float NoL2 = NoL * NoL;
                float NoV2 = NoV * NoV;
                float calulationL = NoL / (r2 * sqrt(1 - NoL2));
                float calulationV = NoV / (r2 * sqrt(1 - NoV2));
                float smithL = calulationL < 1.6 ? (3.535 * calulationL + 2.181 * calulationL * calulationL) / (1 + 2.276 * calulationL + 2.577 * calulationL * calulationL) : 1.0;
                float smithV = calulationV < 1.6 ? (3.535 * calulationV + 2.181 * calulationV * calulationV) / (1 + 2.276 * calulationV + 2.577 * calulationV * calulationV) : 1.0;
                float gs = smithL * smithV;
                return gs;
            }
            float GGX_V(float NoL, float NoV, float roughness)
            {
                float r2 = roughness * roughness;
                float NoL2 = NoL * NoL;
                float NoV2 = NoV * NoV;
                float smithL = (2 * NoL) / (NoL + sqrt(r2 + (1 - r2) * NoL2));
                float smithV = (2 * NoV) / (NoV + sqrt(r2 + (1 - r2) * NoV2));
                float gs = smithL * smithV;
                return gs;
            }
            float Schlick_V(float NoL, float NoV, float roughness)
            {
                float r2 = roughness * roughness;
                float smithL = NoL / (NoL * (1 - r2) + r2);
                float smithV = NoV / (NoV * (1 - r2) + r2);
                return smithL * smithV;
            }
            float SchlickBeckmanG_V(float NoL, float NoV, float roughness)
            {
                float r2 = roughness * roughness;
                float k = r2 * 0.797884560802865;
                float smithL = NoL / (NoL * (1 - k) + k);
                float smithV = NoV / (NoV * (1 - k) + k);
                float gs = smithL * smithV;
                return gs;
            }
            float SchlickGGX_V(float NoL, float NoV, float roughness)
            {
                float k = roughness / 2;
                float smithL = NoL / (NoL * (1 - k) + k);
                float smithV = NoV / (NoV * (1 - k) + k);
                float gs = smithL * smithV;
                return gs;
            }
            float MixFunction(float i, float j, float x)
            {
	             return  j * x + i * (1.0 - x);
            }
            float SchlickFresnel(float i)
            {
                float x = clamp(1.0 - i, 0.0, 1.0);
                float x2 = x * x;
                return x2 * x2 * x;
            }
            float F0(float NdotL, float NdotV, float LdotH, float roughness)
            {
                float FresnelLight = SchlickFresnel(NdotL); 
                float FresnelView = SchlickFresnel(NdotV);
                float FresnelDiffuse90 = 0.5 + 2.0 * LdotH*LdotH * roughness;
                return  MixFunction(1, FresnelDiffuse90, FresnelLight) * MixFunction(1, FresnelDiffuse90, FresnelView);
            }
            float3 Schlick_F(float3 SpecularColor, float LdotH)
            {
                return SpecularColor + (1 - SpecularColor) * SchlickFresnel(LdotH);
            }
            float SchlickIOR_F(float ior, float LoH)
            {
                float f0 = pow(ior - 1, 2) / pow(ior + 1, 2);
                return f0 + (1 - f0) * SchlickFresnel(LoH);
            }
            float SphericalGaussian_F(float SpecularColor, float LoH)
            {
                float power = ((-5.55473 * LoH) - 6.98316) * LoH;
                return SpecularColor + (1 - SpecularColor) * pow(2, power);
            }
            float4 frag(VertexOutput i) : SV_Target
            {
                float3 N = normalize(i.normalWS);
                float3 L = normalize(UnityWorldSpaceLightDir(i.positionWS));
                float3 V = normalize(UnityWorldSpaceViewDir(i.positionWS));
                float3 T = normalize(i.tangentWS);
                float3 B = normalize(i.bitangentWS);
                float3 H = normalize(V + L);
                float3 LR = reflect(-L, N);
                float3 VR = reflect(-V, N);

                float NoL = max(dot(N, L), 0);
                float NoV = max(dot(N, V), 0);
                float NoH = max(dot(N, H), 0);
                float LoV = max(dot(L, V), 0);
                float LoH = max(dot(L, H), 0);
                float VoH = max(dot(V, H), 0);
                float LRoV = max(dot(LR, V), 0);
                float HoT = dot(H, T);
                float HoB = dot(H, B);

                float attenuation = LIGHT_ATTENUATION(i);
                float3 lightColor = _LightColor0.rgb;

                float roughness = pow(1 - _Smoothness * _Smoothness, 2);

                float3 diffuseColor = _DiffuseColor.rgb * (1 - _Metallic);

                float3 specularColor = lerp(_DiffuseColor.rgb, _SpecularColor.rgb, _Metallic);
                // D
                //specularColor *= BlinnPhong_D(NoH, _Smoothness, max(1, _Smoothness * 40));
                //specularColor *= Phong_D(LRoV, _Smoothness, max(1, _Smoothness * 40));
                //specularColor *= Beckman_D(roughness, NoH);
                //specularColor *= Gaussian_D(roughness, NoH);
                specularColor *= GGX_D(roughness, NoH);
                //specularColor *= Trowbridge_D(roughness, NoH);
                //specularColor *= TrowbridgeAnisotropic_D(_Anisotropic, NoH, HoT, HoB);
                //specularColor *= WardAnisotropic_D(_Anisotropic, NoL, NoV, NoH, HoT, HoB);
                // V
                //specularColor *= Implicit_V(NoL, NoV);
                //specularColor *= AshikhminPremoze_V(NoL, NoV);
                //specularColor *= Duer_V(L, V, N);
                //specularColor *= Neumann_V(NoL, NoV);
                //specularColor *= Kelemen_V(NoL, NoV, VoH);
                //specularColor *= ModifiedKelemen_V(NoV, NoL, roughness);
                //specularColor *= CookTorrence_V(NoL, NoV, VoH, NoH);
                //specularColor *= Ward_V(NoL, NoV);
                //specularColor *= Kurt_V(NoL, NoV, VoH, roughness);
                //specularColor *= WalterEtAl_V(NoL, NoV, roughness);
                //specularColor *= Beckman_V(NoL, NoV, roughness);
                //specularColor *= GGX_V(NoL, NoV, roughness);
                //specularColor *= Schlick_V(NoL, NoV, roughness);
                //specularColor *= SchlickBeckmanG_V(NoL, NoV, roughness);
                specularColor *= SchlickGGX_V(NoL, NoV, roughness);
                // F
                //specularColor *= Schlick_F(_SpecularColor, LoH);
                //specularColor *= SchlickIOR_F(_Ior, LoH);
                specularColor *= SphericalGaussian_F(_SpecularColor, LoH);
                // Mix
                specularColor /= 4 * NoL * NoV;
                
                return float4((diffuseColor + specularColor) * NoL * attenuation * lightColor, 1);
            }
            ENDCG
        }
    }
}