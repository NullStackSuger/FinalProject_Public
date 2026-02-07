Shader "Custom/Fabric_SilkCotton_VertFrag"
{
    Properties
    {
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _ThreadMap("ThreadMap (R:AO, G:NormalX, A:NormalY, B:Smooth)", 2D) = "white" {}
        _FuzzMap("Fuzz Map (Color Variation)", 2D) = "white" {}
        _BumpMap("Normal Map (optional)", 2D) = "bump" {}

        _Metallic("Metallic", Range(0,1)) = 0
        _Smoothness("Smoothness (fallback)", Range(0,1)) = 0.5
        _NormalStrength("Thread Normal Strength", Range(0,2)) = 1.0
        _AOIntensity("AO Intensity (threadmap R)", Range(0,2)) = 1.0
        _FuzzIntensity("Fuzz Intensity", Range(0,1)) = 0.5

        _SilkAniso("Silk Anisotropy (0..1)", Range(0,1)) = 0.6
        _SilkSpecular("Silk Specular Intensity", Range(0,5)) = 1.2

        _ScaleObject("Object UV scale (Object Space)", Vector) = (1,1,0,0)
        _MaterialType("Material Type (0=Cotton,1=Silk)", Float) = 0
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 300

        Cull Off
        
        Pass
        {
            Name "FORWARD"
            Tags { "LightMode"="ForwardBase" }

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile __ MATERIAL_TYPE_SILK MATERIAL_TYPE_COTTON
            #pragma target 3.0

            #include "UnityCG.cginc"

            sampler2D _MainTex;
            sampler2D _ThreadMap;
            sampler2D _FuzzMap;
            sampler2D _BumpMap;

            float _Metallic;
            float _Smoothness;
            float _NormalStrength;
            float _AOIntensity;
            float _FuzzIntensity;
            float _SilkAniso;
            float _SilkSpecular;
            float4 _ScaleObject;
            float _MaterialType;

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uvMain : TEXCOORD0;
                float2 uvThread : TEXCOORD1;
                float2 uvFuzz : TEXCOORD2;
                float3 worldPos : TEXCOORD3;
                float3 viewDir : TEXCOORD4; // view direction in world space
                float3 worldN : TEXCOORD5;
                float3 worldT : TEXCOORD6;
                float3 worldB : TEXCOORD7;
                UNITY_FOG_COORDS(1)
            };

            // Reconstruct normal Z from X,Y packed in [0,1] (G/A)
            float3 ReconstructFromThreadMapNormal(float2 packedXY)
            {
                float2 xy = packedXY * 2.0 - 1.0; // [0,1] -> [-1,1]
                float x = xy.x;
                float y = xy.y;
                float zSq = 1.0 - saturate(x*x + y*y);
                float z = sqrt(max(0.0, zSq));
                return float3(x, y, z);
            }

            // Combine base world normal and threadmap normal (thread normal is in tangent space)
            float3 CombineNormalsWS(float3 baseN_ws, float3 worldT, float3 worldB, float3 threadNormalTS, float strength)
            {
                float3 threadWS = normalize(threadNormalTS.x * worldT + threadNormalTS.y * worldB + threadNormalTS.z * baseN_ws);
                return normalize(lerp(baseN_ws, threadWS, saturate(strength)));
            }

            // Simple anisotropic specular approximation (similar idea to Ashikhmin-ish)
            float AnisoSpecularApprox(float3 N, float3 V, float3 L, float3 T, float3 B, float roughnessX, float roughnessY)
            {
                float3 H = normalize(V + L);
                float nDotH = saturate(dot(N, H));
                float tDotH = dot(T, H);
                float bDotH = dot(B, H);

                float ax = max(0.001, roughnessX);
                float ay = max(0.001, roughnessY);

                // exponent-like term
                float denom = max(1e-6, 1.0 - nDotH*nDotH);
                float exponent = ( (tDotH*tDotH)/(ax*ax) + (bDotH*bDotH)/(ay*ay) ) / denom;
                exponent = saturate(exponent);
                // produce a spec weight
                float spec = exp(-exponent) * max(0.0, dot(N, H));
                return spec;
            }

            // Fresnel Schlick for dielectric/metal mix
            float3 FresnelSchlick(float3 F0, float cosTheta)
            {
                return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
            }

            v2f vert(appdata v)
            {
                v2f o;
                // position
                o.pos = UnityObjectToClipPos(v.vertex);

                // UVs
                o.uvMain = v.uv;
                o.uvThread = v.uv2; // assume threadmap stored in uv2 (if not, use uv)
                o.uvFuzz = v.uv;

                // world pos
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldPos = worldPos;

                // world normal/tangent/binormal
                float3 worldN = UnityObjectToWorldNormal(v.normal);
                worldN = normalize(worldN);
                float3 worldT = UnityObjectToWorldDir(v.tangent.xyz);
                worldT = normalize(worldT);
                // tangent.w contains handedness
                float tangentSign = v.tangent.w;
                float3 worldB = cross(worldN, worldT) * tangentSign;
                worldB = normalize(worldB);

                o.worldN = worldN;
                o.worldT = worldT;
                o.worldB = worldB;

                // view direction (from point to camera) in world space
                float3 camPos = _WorldSpaceCameraPos;
                o.viewDir = normalize(camPos - worldPos);

                UNITY_TRANSFER_FOG(o, o.pos);
                return o;
            }

            fixed4 frag(v2f IN) : SV_Target
            {
                // Sample textures
                float4 albedoSamp = tex2D(_MainTex, IN.uvMain);
                float3 baseColor = albedoSamp.rgb;

                float4 thread = tex2D(_ThreadMap, IN.uvThread);
                float ao = thread.r * _AOIntensity;
                float smoothThread = thread.b;
                float3 threadNormalTS = ReconstructFromThreadMapNormal(float2(thread.g, thread.a));

                float4 fuzz = tex2D(_FuzzMap, IN.uvFuzz);
                float3 fuzzTint = lerp(float3(1,1,1), fuzz.rgb, _FuzzIntensity);
                baseColor *= fuzzTint;

                // Unpack provided normal map (if any)
                float3 baseNormal_ws = IN.worldN;
                #if defined(_BUMPMAP)
                    // UnpackNormal expects tangent-space normal; we need to transform it to world
                    float3 bumpTS = UnpackNormal(tex2D(_BumpMap, IN.uvMain));
                    // bumpTS -> world: bumpTS.x * T + bumpTS.y * B + bumpTS.z * N
                    baseNormal_ws = normalize(bumpTS.x * IN.worldT + bumpTS.y * IN.worldB + bumpTS.z * IN.worldN);
                #endif

                // Merge threadmap normal (threadNormalTS is tangent-space like XY packed)
                float3 combinedNormal = CombineNormalsWS(baseNormal_ws, IN.worldT, IN.worldB, threadNormalTS, _NormalStrength);

                // Determine smoothness: prefer threadmap smoothness where available, else property
                float smoothness = lerp(_Smoothness, smoothThread, smoothThread);

                // Lighting setup: use main directional light (_WorldSpaceLightPos0 with w==0)
                float3 N = normalize(combinedNormal);
                float3 V = normalize(IN.viewDir);
                float3 L;
                float NdotL;
                float3 lightColor = float3(0.0,0.0,0.0);
                // Get main directional light direction/color
                // _WorldSpaceLightPos0.w == 0 for directional lights; direction = normalize(_WorldSpaceLightPos0.xyz)
                float4 worldLight = _WorldSpaceLightPos0;
                if (worldLight.w == 0.0)
                {
                    L = normalize(worldLight.xyz);
                    NdotL = saturate(dot(N, L));
                    lightColor = 1;
                }
                else
                {
                    // fallback simple directional if not directional
                    L = normalize(worldLight.xyz - IN.worldPos);
                    NdotL = saturate(dot(N, L));
                    lightColor = 1;
                }

                // Ambient
                float3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb * baseColor;

                // Occlusion applied to diffuse
                float3 diffuse = (baseColor / UNITY_PI) * NdotL * ao;

                // Decide material branch
                #if defined(MATERIAL_TYPE_SILK)
                    bool isSilk = true;
                #elif defined(MATERIAL_TYPE_COTTON)
                    bool isSilk = false;
                #else
                    bool isSilk = (_MaterialType > 0.5);
                #endif

                float3 result = 0;
                if (isSilk)
                {
                    // Silk: anisotropic specular
                    float rough = 1.0 - smoothness;
                    // map roughness to anisotropic components (smaller value => shinier)
                    float rx = clamp(0.05 + rough * (1.0 - _SilkAniso), 0.01, 1.0);
                    float ry = clamp(0.05 + rough * (1.0 + _SilkAniso), 0.01, 1.0);

                    // F0 dielectric / metallic mix
                    float3 F0 = lerp(float3(0.04,0.04,0.04), baseColor, saturate(_Metallic));

                    float specTerm = AnisoSpecularApprox(N, V, L, IN.worldT, IN.worldB, rx, ry);
                    float3 F = FresnelSchlick(F0, saturate(dot(V, normalize(V+L))));
                    float3 specular = _SilkSpecular * F * specTerm * NdotL;

                    result = diffuse + specular;
                }
                else
                {
                    // Cotton/Wool: heavier diffuse + fuzz/broad spec
                    // Wrap lighting to simulate subsurface / scatter
                    float wrap = 0.45;
                    float wrapped = saturate((dot(N, L) + wrap) / (1.0 + wrap));
                    float3 diffuseWrapped = (baseColor / UNITY_PI) * wrapped * ao;

                    // broad fuzzy specular
                    float rough = 1.0 - smoothness; // rough ~1 for fuzzy
                    float R = max(0.0001, rough + 0.01);
                    float3 Rr = reflect(-L, N);
                    float broadSpec = pow(saturate(dot(Rr, V)), 1.0 / R);
                    broadSpec *= 0.15 * (1.0 - smoothness + 0.2);

                    result = diffuseWrapped + broadSpec * baseColor * 0.7;
                }

                // Apply light color and simple gamma correction
                float3 lit = result * lightColor + ambient * 0.15;

                // apply simple tone (clamp)
                lit = saturate(lit);

                // output
                return float4(lit, 1.0);
            }

            ENDCG
        }
    }

    FallBack "Diffuse"
}
