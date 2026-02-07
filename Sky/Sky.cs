using UnityEngine;

public class Sky : MonoBehaviour
{
    public Material material;
    public RenderTexture transmittanceLUT;
    public RenderTexture skyboxLUT;

    public float seaLevel = 0; // 海平面高度
    public float planetRadius = 6360000; // 地球半径
    public float atmosphereHeight = 60000; // 大气层高度
    public float sunLightIntensity = 31.4f; // 太阳能量
    public Color sunLightColor = Color.white;
    public float rayleighScatteringScale = 1; // 瑞利散射系数
    public float rayleighScatteringScalarHeight = 8000; // 瑞利高度H
    public float mieScatteringScale = 1; // 米氏散射系数
    public float mieAnisotropy = 0.8f; // 光晕大小
    public float mieScatteringScalarHeight = 1200; // 米氏高度H
    public float ozoneAbsorptionScale = 1; // 臭氧吸收系数
    public float ozoneLevelCenterHeight = 25000; // 臭氧高度H
    public float ozoneLevelWidth = 15000; // 臭氧层厚度
    
    private void Awake()
    {
        material.SetFloat("_SeaLevel", seaLevel);
        material.SetFloat("_PlanetRadius", planetRadius);
        material.SetFloat("_AtmosphereHeight", atmosphereHeight);
        material.SetFloat("_SunLightIntensity", sunLightIntensity);
        material.SetVector("_SunLightColor", sunLightColor);
        material.SetFloat("_RayleighScatteringScale", rayleighScatteringScale);
        material.SetFloat("_RayleighScatteringScalarHeight", rayleighScatteringScalarHeight);
        material.SetFloat("_MieScatteringScale", mieScatteringScale);
        material.SetFloat("_MieAnisotropy", mieAnisotropy);
        material.SetFloat("_MieScatteringScalarHeight", mieScatteringScalarHeight);
        material.SetFloat("_OzoneAbsorptionScale", ozoneAbsorptionScale);
        material.SetFloat("_OzoneLevelCenterHeight", ozoneLevelCenterHeight);
        material.SetFloat("_OzoneLevelWidth", ozoneLevelWidth);

        transmittanceLUT = RenderTexture.GetTemporary(256, 64, 0, RenderTextureFormat.ARGBFloat);
        Graphics.Blit(null, transmittanceLUT, material, 0);
        material.SetTexture("_TransmittanceLUT", transmittanceLUT);
        
        skyboxLUT = RenderTexture.GetTemporary(256, 128, 0, RenderTextureFormat.ARGBFloat);
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(transmittanceLUT, skyboxLUT, material, 1);
        Graphics.Blit(skyboxLUT, destination, material, 2);
    }

    private void OnDestroy()
    {
        transmittanceLUT?.Release();
        skyboxLUT?.Release();
    }
}