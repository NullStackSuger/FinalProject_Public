using System;
using UnityEngine;

public class Bloom : MonoBehaviour
{
    [SerializeField]
    private Material material;
    [Range(0, 4)]
    public int loop = 3;
    [Range(0.2f, 3)]
    public float blurOffset = 0.6f;
    [Range(1, 8)]
    public int downSample = 1;

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        int width = source.width / downSample;
        int height = source.height / downSample;
		
        RenderTexture rt0 = RenderTexture.GetTemporary(width, height);
        RenderTexture rt1 = null;
		
        Graphics.Blit(source, rt0, material, 0);
        for (int i = 0; i < loop; i++)
        {
            material.SetFloat("_BlurOffset", 1 + i * blurOffset);
			
            rt1 = RenderTexture.GetTemporary(width, height);
            Graphics.Blit(rt0, rt1, material, 1);
            RenderTexture.ReleaseTemporary(rt0);
            rt0 = rt1;
			
            rt1 = RenderTexture.GetTemporary(width, height);
            Graphics.Blit(rt0, rt1, material, 2);
            RenderTexture.ReleaseTemporary(rt0);
            rt0 = rt1;
        }
        
        material.SetTexture("_Bloom", rt0);
        Graphics.Blit(source, destination, material, 3);
		
        RenderTexture.ReleaseTemporary(rt0);
        RenderTexture.ReleaseTemporary(rt1);
    }
}