using System;
using UnityEngine;
using UnityEngine.Serialization;

public class Cloud2 : MonoBehaviour
{
    public Material material;
    public Transform box;
    
    public Texture2D blueNoise;
    public float blueNoiseScale = 2;

    public Texture2D maskNoise;
    public Texture2D weatherMap;
    public Texture3D shapeNoise;
    public Texture3D detailNoise;

    public float shapeSpeedScale;
    public float shapeUVWTiling;
    public float shapeSampleOffset;
    public float detailSpeedScale;
    public float detailUVWTiling;
    public float detailSampleOffset;

    public float heightWeight;
    public Vector4 shapeNoiseWeight;
    public float densityOffset;
    public float detailWeight;
    public float detailNoiseWeight;
    public float densityMultiplier;

    public float lightAbsorptionThroughCloud;
    public float lightAbsorptionTowardSun;
    public Color colorA;
    public Color colorB;
    public float colorOffsetA;
    public float colorOffsetB;
    
    private RenderTexture downSampleDepth;
    private RenderTexture downSampleColor;
    
    private void Awake()
    {
        downSampleDepth = RenderTexture.GetTemporary(Screen.width / 1, Screen.height / 1);
        downSampleColor = RenderTexture.GetTemporary(Screen.width / 1, Screen.height / 1);
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, downSampleDepth, material, 0);
        material.SetTexture("_DownSampleDepth", downSampleDepth);
        
        material.SetMatrix("_InvProj", GL.GetGPUProjectionMatrix(Camera.main!.projectionMatrix, false).inverse);
        material.SetMatrix("_InvView", Camera.main!.cameraToWorldMatrix);
        
        material.SetVector("_Min", box.position - box.localScale / 2);
        material.SetVector("_Max", box.position + box.localScale / 2);
        
        material.SetTexture("_BlueNoise", blueNoise);
        material.SetVector("_BlueNoise_ST", new Vector4(Screen.width / (float)blueNoise.width, Screen.height / (float)blueNoise.height, 0, 0));
        material.SetFloat("_BlueNoiseScale", blueNoiseScale);

        material.SetTexture("_MaskNoise", maskNoise);
        material.SetTexture("_WeatherMap", weatherMap);
        material.SetTexture("_ShapeNoise", shapeNoise);
        material.SetTexture("_DetailNoise", detailNoise);

        material.SetFloat("_ShapeSpeedScale", shapeSpeedScale);
        material.SetFloat("_ShapeUVWTiling", shapeUVWTiling);
        material.SetFloat("_ShapeSampleOffset", shapeSampleOffset);
        material.SetFloat("_DetailSpeedScale", detailSpeedScale);
        material.SetFloat("_DetailUVWTiling", detailUVWTiling);
        material.SetFloat("_DetailSampleOffset", detailSampleOffset);
        
        material.SetFloat("_HeightWeight", heightWeight);
        material.SetVector("_ShapeNoiseWeight", shapeNoiseWeight);
        material.SetFloat("_DensityOffset", densityOffset);
        material.SetFloat("_DetailWeight", detailWeight);
        material.SetFloat("_DetailNoiseWeight", detailNoiseWeight);
        material.SetFloat("_DensityMultiplier", densityMultiplier);
        
        material.SetFloat("_LightAbsorptionThroughCloud", lightAbsorptionThroughCloud);
        material.SetFloat("_LightAbsorptionTowardSun", lightAbsorptionTowardSun);
        material.SetColor("_ColorA", colorA);
        material.SetColor("_ColorB", colorB);
        material.SetFloat("_ColorOffsetA", colorOffsetA);
        material.SetFloat("_ColorOffsetB", colorOffsetB);
        
        Graphics.Blit(source, downSampleColor, material, 1);
        material.SetTexture("_DownSampleColor", downSampleColor);
        
        Graphics.Blit(source, destination, material, 2);
    }
}