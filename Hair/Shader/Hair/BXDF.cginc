#ifndef BXDF_INCLUDE
#define BXDF_INCLUDE

inline float acosFast(float inX)
{
    float x = abs(inX);
    float res = -0.156583f * x + (0.5 * UNITY_PI);
    res *= sqrt(1.0f - x);
    return (inX >= 0) ? res : UNITY_PI - res;
}
#define SQRT2PI 2.50663
inline float Hair_G(float B, float Theta)
{
    return exp(-0.5 * pow(Theta, 2) / (B*B)) / (SQRT2PI * B);
}
inline float3 SpecularFresnel(float3 F0, float vDotH)
{
    return F0 + (1.0f - F0) * pow(1 - vDotH, 5);
}
inline float3 SpecularFresnelLayer(float3 F0, float vDotH, float layer)
{
    float3 fresnel = SpecularFresnel(F0,  vDotH);
    return (fresnel * layer) / (1 + (layer-1) * fresnel);
}
inline float HairIOF(float Eccentric)
{
    float n = 1.55;
    float a = 1 - Eccentric;
    float ior1 = 2 * (n - 1) * (a * a) - n + 2;
    float ior2 = 2 * (n - 1) / (a * a) - n + 2;
    return 0.5f * ((ior1 + ior2) + 0.5f * (ior1 - ior2)); //assume cos2PhiH = 0.5f 
}

struct ShortHair
{
    float3 albedo;
    float3 normal;
    float3 worldNormal;
    float roughness;
    float alpha;
    float kappa;
    float layer;
    float medulaAbsorb;
    float medulaScatter;
};
float3 ShortHairBSDFYan(ShortHair fur, float3 normal, float3 viewDir, float3 lightDir, float shadow, float backLit, float area)
{
    float VOL = dot(viewDir, lightDir);
    float sinThetaL = dot(normal, lightDir);
    float sinThetaV = dot(normal, viewDir);
    float cosThetaL = sqrt(max(0, 1 - sinThetaL * sinThetaL));
    float cosThetaV = sqrt(max(0, 1 - sinThetaV * sinThetaV));
    float cosThetaD = sqrt((1 + cosThetaL * cosThetaV + sinThetaL * sinThetaV) / 2);
    float sinThetaH = sinThetaL + sinThetaV;

    float3 lp = lightDir - sinThetaL * normal;
    float3 vp = viewDir - sinThetaV * normal;
    float cosPhi = dot(lp, vp) * rsqrt(dot(lp, lp) * dot(vp, vp) + 1e-4);
    float cosHalfPhi = sqrt(saturate(0.5 + 0.5 * cosPhi));
    
    float n_prime = 1.19 / cosThetaD + 0.36 * cosThetaD;
    float alpha[] =
    {
        -0.0998,//-Shift * 2,
        0.0499f,// Shift,
        0.1996  // Shift * 4
    };
    float b[] =
    {
        area + pow(fur.roughness, 2),
        area + pow(fur.roughness, 2) / 2,
        area + pow(fur.roughness, 2) * 2
    };
    float F0 = 0.04652;

    float3 result = 0;

    float3 tp;
    float mp, np, fp, a, h, f;
    // R
    mp = Hair_G(b[0], sinThetaH - alpha[0]);
    np = 0.25 * cosHalfPhi;
    fp = SpecularFresnelLayer(F0, sqrt(saturate(0.5 + 0.5 * VOL)), fur.layer);
    result += mp * np * fp * lerp(1, backLit, saturate(-VOL));
    // TT
    mp = Hair_G(b[1], sinThetaH - alpha[1]);
    a = rcp(n_prime);
    h = cosHalfPhi * (1 + a * (0.6 - 0.8 * cosPhi));
    f = SpecularFresnelLayer(F0, cosThetaD * sqrt(saturate(1 - h * h)), fur.layer);
    fp = pow(1 - f, 2);
    float sinGammaTSqr = pow(h * a, 2);
    float sm = sqrt(saturate(pow(fur.kappa, 2) - sinGammaTSqr));
    float sc = sqrt(1 - sinGammaTSqr) - sm;
    tp = pow(fur.albedo, 0.5 * sc / cosThetaD) * pow(fur.medulaAbsorb * fur.medulaScatter, 0.5 * sm / cosThetaD);
    np = exp(-3.65 * cosPhi - 3.98);
    result += mp * np * fp * tp * backLit;
    // TRT
    mp = Hair_G(b[2], sinThetaH - alpha[2]);
    f = SpecularFresnelLayer(F0, cosThetaD * 0.5, fur.layer);
    fp = pow(1 - f, 2) * f;
    sm = sqrt(saturate(pow(fur.kappa, 2) - 0.75));
    sc = 0.5 - sm;
    tp = pow(fur.albedo, sc  / cosThetaD) * pow(fur.medulaAbsorb * fur.medulaScatter, sm / cosThetaD);
    np = exp((6.3f * cosThetaD + 0.7) * cosPhi - (5 * cosThetaD + 2));
    result += mp * np * fp * tp;
    // TTS
    mp = abs(cosThetaL) * 0.5;
    tp = pow(fur.albedo, (sc + 1 - fur.kappa) / (4 * cosThetaD)) * pow(fur.medulaAbsorb, fur.kappa / (4 * cosThetaD));
    np = 0.05 * (2 * cosPhi * cosPhi - 1) + 0.16;
    result += mp * np * fp * tp;
    // TRTS
    float phi = acosFast(cosPhi);
    np = 0.05 * cos(1.5 * phi + 1.7) + 0.18;
    tp = pow(fur.albedo, (3 * sc + 1 - fur.kappa) / (4 * cosThetaD)) * pow(fur.medulaAbsorb, (2 * sm + fur.kappa) / (4 * cosThetaD)) * pow(fur.medulaScatter, sm / (8 * cosThetaD));
    fp = f * (1 - f);
    result += mp * np * fp * tp;
    
    return result;
}
float3 ShortHairDiffuseKajiya(ShortHair fur, float3 normal, float3 viewDir, float3 lightDir, float shadow, float backLit, float area)
{
    float diffuse = 1 - abs(dot(normal, lightDir));
    float3 tb = normalize(viewDir - normal * dot(viewDir, normal)); // viewDir的切线副切线上的分量
    normal = tb;
    float warp = 1;
    float NOL = saturate((dot(normal, lightDir) + warp) / pow(1 + warp, 2));
    float diffuseScatter = 1 / UNITY_PI * lerp(NOL, diffuse, 0.33);
    float luma = Luminance(fur.albedo);
    float3 scatterTint = pow(fur.albedo / luma, 1 - shadow);
    return sqrt(fur.albedo) * diffuseScatter * scatterTint;
}
float3 ShortHairBXDF(ShortHair fur, float3 normal, float3 viewDir, float3 lightDir, float shadow, float backLit /*背光*/, float area)
{
    float3 result = 0;
    
    result += ShortHairBSDFYan(fur, normal, viewDir, lightDir, shadow, backLit, area);
    result += ShortHairDiffuseKajiya(fur, normal, viewDir, lightDir, shadow, backLit, area);
    result = max(result, 0);
    
    return result;
}



struct LongHair
{
    float3 albedo;
    float3 normal;
    float3 worldNormal;
    float roughness;
    float alpha;
    float eccentric;
};
float3 LongHairSpecularMarschner(LongHair hair, float3 normal, float3 viewDir, float3 lightDir, float shadow, float backLit, float area)
{
    float VOL = dot(viewDir, lightDir);
    float sinThetaL = dot(normal, lightDir);
    float sinThetaV = dot(normal, viewDir);
    float cosThetaL = sqrt(max(0, 1 - sinThetaL * sinThetaL));
    float cosThetaV = sqrt(max(0, 1 - sinThetaV * sinThetaV));
    float cosThetaD = sqrt((1 + cosThetaL * cosThetaV + sinThetaL * sinThetaV) / 2);
    float sinThetaH = sinThetaL + sinThetaV;

    float3 lp = lightDir - sinThetaL * normal;
    float3 vp = viewDir - sinThetaV * normal;
    float cosPhi = dot(lp, vp) * rsqrt(dot(lp, lp) * dot(vp, vp) + 1e-4);
    float cosHalfPhi = sqrt(saturate(0.5 + 0.5 * cosPhi));

    float n_prime = 1.19 / cosThetaD + 0.36 * cosThetaD;
    float alpha[] =
    {
        -0.0998,//-Shift * 2,
        0.0499f,// Shift,
        0.1996  // Shift * 4
    };
    float b[] =
    {
        area + pow(hair.roughness, 2),
        area + pow(hair.roughness, 2) / 2,
        area + pow(hair.roughness, 2) * 2
    };

    float hairIOF = HairIOF(hair.eccentric);
    float F0 = pow((1 - hairIOF) / (1 + hairIOF), 2);

    float3 result = 0;
    
    float3 tp;
    float mp, np, fp, a, h, f;
    // R
    mp = Hair_G(b[0], sinThetaH - alpha[0]);
    np = 0.25 * cosHalfPhi;
    fp = SpecularFresnel(F0, sqrt(saturate(0.5 + 0.5 * VOL)));
    result += mp * np * fp * lerp(1, backLit, saturate(-VOL));
    // TT
    mp = Hair_G(b[1], sinThetaH - alpha[1]);
    a = 1.55f / hairIOF * rcp(n_prime);
    h = cosHalfPhi * (1 + a * (0.6 - 0.8 * cosPhi));
    f = SpecularFresnel(F0, cosThetaD * sqrt(saturate(1 - h * h)));
    fp = pow(1 - f, 2);
    tp = pow(hair.albedo, 0.5 * sqrt(1 - pow(h * a, 2)) / cosThetaD);
    np = exp(-3.65 * cosPhi - 3.98);
    result += mp * np * fp * tp * backLit;
    // TRT
    mp = Hair_G(b[2], sinThetaH - alpha[2]);
    f = SpecularFresnel(F0, cosThetaD * 0.5);
    fp = pow(1 - f, 2) * f;
    tp = pow(hair.albedo, 0.8 / cosThetaD);
    np = exp(17 * cosPhi - 16.78);
    result += mp * np * fp * tp;

    return result;
}
float3 LongHairSpecularKajiya(LongHair hair, float3 tangent1, float3 tangent2, float3 viewDir, float lightDir)
{
    float3 h = normalize(lightDir + viewDir);
    float TDotH1 = dot(tangent1, h);
    float TDotH2 = dot(tangent2, h);
    float sinTH1 = sqrt(1 - saturate(TDotH1 * TDotH1));
    float sinTH2 = sqrt(1 - saturate(TDotH2 * TDotH2));
    float3 fresnel = SpecularFresnel(hair.albedo, saturate(dot(h, viewDir)));

    float3 specular = 0;
    specular += fresnel * hair.albedo * sinTH1;
    specular += (1 - fresnel) * hair.albedo * pow(sinTH2, (1 - hair.roughness) * 100);
    return specular;
}
float3 LongHairDiffuseKajiya(LongHair hair, float3 normal, float3 viewDir, float3 lightDir, float shadow, float backLit, float area)
{
    float diffuse = 1 - abs(dot(normal, lightDir));
    float3 tb = normalize(viewDir - normal * dot(viewDir, normal)); // viewDir的切线副切线上的分量
    normal = tb;
    float warp = 1;
    float NOL = saturate((dot(normal, lightDir) + warp) / pow(1 + warp, 2));
    float diffuseScatter = 1 / UNITY_PI * lerp(NOL, diffuse, 0.33);
    float luma = Luminance(hair.albedo);
    float3 scatterTint = pow(hair.albedo / luma, 1 - shadow);
    return sqrt(hair.albedo) * diffuseScatter * scatterTint;
}
float3 LongHairBXDF(LongHair hair, float3 normal, float3 viewDir, float3 lightDir, float shadow, float backLit, float area)
{
    float3 result = 0;

    //result += LongHairSpecularKajiya(hair, normal, normal, viewDir, lightDir);
    result += LongHairSpecularMarschner(hair, normal, viewDir, lightDir, shadow, backLit, area);
    result += LongHairDiffuseKajiya(hair, normal, viewDir, lightDir, shadow, backLit, area);
    result = max(result, 0);
    
    return result;
}
#endif