#ifndef RAY_MARCHING
#define RAY_MARCHING
#include "AtmosphereParameter.cginc"
#define PI 3.1415926

float3 UVToViewDir(float2 uv)
{
    float theta = (1.0 - uv.y) * PI;
    float phi = (uv.x * 2 - 1) * PI;
    
    float x = sin(theta) * cos(phi);
    float z = sin(theta) * sin(phi);
    float y = cos(theta);

    return float3(x, y, z);
}
float2 ViewDirToUV(float3 viewDir)
{
    float2 uv = float2(atan2(viewDir.z, viewDir.x), asin(viewDir.y));
    uv /= float2(2.0 * PI, PI);
    uv += float2(0.5, 0.5);

    return uv; 
}
float2 UVToLutParam(float bottomRadius, float topRadius, float2 uv)
{
    float x_mu = uv.x;
    float x_r = uv.y;

    float H = sqrt(max(0.0f, topRadius * topRadius - bottomRadius * bottomRadius));
    float rho = H * x_r;
    float r = sqrt(max(0.0f, rho * rho + bottomRadius * bottomRadius));

    float d_min = topRadius - r;
    float d_max = rho + H;
    float d = d_min + x_mu * (d_max - d_min);
    float mu = d == 0.0f ? 1.0f : (H * H - rho * rho - d * d) / (2.0f * r * d);
    mu = clamp(mu, -1.0f, 1.0f);

    return float2(mu, r);
}
float2 LutParamToUV(float bottomRadius, float topRadius, float mu, float r)
{
    float H = sqrt(max(0.0f, topRadius * topRadius - bottomRadius * bottomRadius));
    float rho = sqrt(max(0.0f, r * r - bottomRadius * bottomRadius));

    float discriminant = r * r * (mu * mu - 1.0f) + topRadius * topRadius;
    float d = max(0.0f, (-r * mu + sqrt(discriminant)));

    float d_min = topRadius - r;
    float d_max = rho + H;

    float x_mu = (d - d_min) / (d_max - d_min);
    float x_r = rho / H;

    return float2(x_mu, x_r);
}

float RayIntersectSphere(float3 center, float radius, float3 rayStart, float3 rayDir)
{
    float OS = length(center - rayStart);
    float SH = dot(center - rayStart, rayDir);
    float OH = sqrt(OS*OS - SH*SH);
    float PH = sqrt(radius*radius - OH*OH);

    // ray miss sphere
    if(OH > radius) return -1;

    // use min distance
    float t1 = SH - PH;
    float t2 = SH + PH;
    float t = (t1 < 0) ? t2 : t1;

    return t;
}

float3 RayleighCoefficient(in AtmosphereParameter param, float h)
{
    const float3 sigma = float3(5.802, 13.558, 33.1) * 1e-6;
    float H_R = param.RayleighScatteringScalarHeight;
    float rho_h = exp(-(h / H_R));
    return sigma * rho_h;
}
float RayleighPhase(in AtmosphereParameter param, float cos_theta)
{
    return 3.0 / (16.0 * PI) * (1.0 + cos_theta * cos_theta);
}
float3 MieCoefficient(in AtmosphereParameter param, float h)
{
    const float3 sigma = (3.996 * 1e-6).xxx;
    float H_M = param.MieScatteringScalarHeight;
    float rho_h = exp(-(h / H_M));
    return sigma * rho_h;
}
float MiePhase(in AtmosphereParameter param, float cos_theta)
{
    float g = param.MieAnisotropy;

    float a = 3.0 / (8.0 * PI);
    float b = (1.0 - g*g) / (2.0 + g*g);
    float c = 1.0 + cos_theta*cos_theta;
    float d = pow(1.0 + g*g - 2*g*cos_theta, 1.5);
    
    return a * b * (c / d);
}
float3 MieAbsorption(in AtmosphereParameter param, float h)
{
    const float3 sigma = (4.4 * 1e-6).xxx;
    float H_M = param.MieScatteringScalarHeight;
    float rho_h = exp(-(h / H_M));
    return sigma * rho_h;
}
float3 OzoneAbsorption(in AtmosphereParameter param, float h)
{
    #define sigma_lambda (float3(0.650f, 1.881f, 0.085f)) * 1e-6
    float center = param.OzoneLevelCenterHeight;
    float width = param.OzoneLevelWidth;
    float rho = max(0, 1.0 - (abs(h - center) / width));
    return sigma_lambda * rho;
}

float3 Transmittance(in AtmosphereParameter param, float3 p1, float3 p2)
{
    float3 dir = normalize(p2 - p1);
    float dist = length(p2 - p1);
    const int stepCount = 32;
    float ds = dist / float(stepCount);
    float3 sum = 0;
    float3 p = p1 + dir * ds * 0.5;
    for(int i = 0; i < stepCount; i++)
    {
        float h = length(p) - param.PlanetRadius;
        float3 scattering = RayleighCoefficient(param, h) + MieCoefficient(param, h);
        float3 absorption = OzoneAbsorption(param, h) + MieAbsorption(param, h);
        float3 extinction = scattering + absorption;
        sum += extinction * ds;
        p += dir * ds;
    }
    return exp(-sum);
}
float3 Scattering(in AtmosphereParameter param, float3 p, float3 viewDir, float3 lightDir)
{
    float cos_theta = dot(lightDir, viewDir);
    float h = length(p) - param.PlanetRadius;
    float3 rayleigh = RayleighCoefficient(param, h) * RayleighPhase(param, cos_theta);
    float3 mie = MieCoefficient(param, h) * MiePhase(param, cos_theta);
    return rayleigh + mie;
}

// 点p沿着dir到大气层边缘的transmittance
float3 TransmittanceFromLUT(in AtmosphereParameter param, float3 p, float3 dir, sampler2D transmittanceLUT)
{
    float bottomRadius = param.PlanetRadius;
    float topRadius = param.PlanetRadius + param.AtmosphereHeight;

    float3 upVector = normalize(p);
    float cos_theta = dot(upVector, dir);
    float r = length(p);

    float2 uv = LutParamToUV(bottomRadius, topRadius, cos_theta, r);
    return tex2D(transmittanceLUT, uv);
}
// 使用transmittanceLUT的单次大气散射
float3 GetSkyView(in AtmosphereParameter param, float3 eyePos, float3 viewDir, float3 lightDir, sampler2D transmittanceLUT)
{
    float3 col = 0;

    // 视线与大气层和星球交点
    float atmoDist = RayIntersectSphere(0, param.PlanetRadius + param.AtmosphereHeight, eyePos, viewDir);
    float planetDist = RayIntersectSphere(0, param.PlanetRadius, eyePos, viewDir);
    if (atmoDist < 0) return col; // 和大气层没有交点, 也就没有散射这些, 就没有颜色
    if (planetDist > 0) atmoDist = min(atmoDist, planetDist); // 和地球有交点可能先打到地球

    const int stepCount = 32;
    float ds = atmoDist / float(stepCount);
    float3 p = eyePos + viewDir * ds * 0.5; // 先走半个步长到2次采样的中心, P是当前走过的相机到大气层的位置
    float3 luminance = param.SunLightColor * param.SunLightIntensity; // 太阳能量
    float3 opticalDepth = 0;
    for (int i = 0; i < stepCount; i++)
    {
        float h = length(p) - param.PlanetRadius;
        float3 extinction = RayleighCoefficient(param, h) + MieCoefficient(param, h) + OzoneAbsorption(param, h) + MieAbsorption(param, h);
        opticalDepth += extinction * ds;

        // 点P到太阳的Transmittance
        float3 t1 = TransmittanceFromLUT(param, p, lightDir, transmittanceLUT);
        // 散射
        float3 s = Scattering(param, p, viewDir, lightDir);
        // 点P到相机的Transmittance
        float3 t2 = exp(-opticalDepth);

        // 单次散射
        float3 inScattering = t1 * s * t2 * ds * luminance;
        col += inScattering;

        p += viewDir * ds;
    }

    return col;
}

#endif
