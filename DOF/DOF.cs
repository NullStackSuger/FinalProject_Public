using System;
using UnityEngine;

[RequireComponent(typeof(Camera))]
public class DOF : MonoBehaviour
{
    [SerializeField]
    private Material material;

    [Range(1, 4)] 
    public int blurCount = 1;

    [Range(1, 10)] 
    public int downSample = 1;

    private new Camera camera;
    
    private void Awake()
    {
        camera = GetComponent<Camera>();
        camera.depthTextureMode |= DepthTextureMode.Depth;
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        int width = (int)(source.width / downSample);
        int height = (int)(source.height / downSample);
        
        RenderTexture rt1 = RenderTexture.GetTemporary(width, height);
        RenderTexture rt2 = RenderTexture.GetTemporary(width, height);
        
        Graphics.Blit(source, rt1, material, 0);
        
        // DownSample
        for (int i = 0; i < blurCount; i++)
        {
            RenderTexture.ReleaseTemporary(rt1);
            width /= 2;
            height /= 2;
            rt2 = RenderTexture.GetTemporary(width, height);
            Graphics.Blit(rt1, rt2, material, 0);
        }
        
        // UpSample
        for (int i = 0; i < blurCount; i++)
        {
            RenderTexture.ReleaseTemporary(rt2);
            width *= 2;
            height *= 2;
            rt1 = RenderTexture.GetTemporary(width, height);
            Graphics.Blit(rt2, rt1, material, 0);
        }
        
        material.SetTexture("_BlurTex", rt1);
        Graphics.Blit(source, destination, material, 1);
        
        RenderTexture.ReleaseTemporary(rt1);
        RenderTexture.ReleaseTemporary(rt2);
    }
}