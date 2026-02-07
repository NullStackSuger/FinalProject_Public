#ifndef ATMOSPHERE_PARAM
#define ATMOSPHERE_PARAM

struct AtmosphereParameter
{
    float SeaLevel;
    float PlanetRadius;
    float AtmosphereHeight;
    float SunLightIntensity;
    float3 SunLightColor;
    float RayleighScatteringScale;
    float RayleighScatteringScalarHeight;
    float MieScatteringScale;
    float MieAnisotropy;
    float MieScatteringScalarHeight;
    float OzoneAbsorptionScale;
    float OzoneLevelCenterHeight;
    float OzoneLevelWidth;
};

float _SeaLevel;
float _PlanetRadius;
float _AtmosphereHeight;
float _SunLightIntensity;
float4 _SunLightColor;
float _RayleighScatteringScale;
float _RayleighScatteringScalarHeight;
float _MieScatteringScale;
float _MieAnisotropy;
float _MieScatteringScalarHeight;
float _OzoneAbsorptionScale;
float _OzoneLevelCenterHeight;
float _OzoneLevelWidth;

AtmosphereParameter GetAtmosphereParameter()
{
    AtmosphereParameter param;

    param.SeaLevel = _SeaLevel;
    param.PlanetRadius = _PlanetRadius;
    param.AtmosphereHeight = _AtmosphereHeight;
    param.SunLightIntensity = _SunLightIntensity;
    param.SunLightColor = _SunLightColor.rgb;
    param.RayleighScatteringScale = _RayleighScatteringScale;
    param.RayleighScatteringScalarHeight = _RayleighScatteringScalarHeight;
    param.MieScatteringScale = _MieScatteringScale;
    param.MieAnisotropy = _MieAnisotropy;
    param.MieScatteringScalarHeight = _MieScatteringScalarHeight;
    param.OzoneAbsorptionScale = _OzoneAbsorptionScale;
    param.OzoneLevelCenterHeight = _OzoneLevelCenterHeight;
    param.OzoneLevelWidth = _OzoneLevelWidth;

    return param;
}

#endif