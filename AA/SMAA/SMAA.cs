using UnityEngine;

public class SMAA : MonoBehaviour
{
    [SerializeField]
    private Material material;
    
    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        RenderTexture edge = RenderTexture.GetTemporary(source.width, source.height, 0, RenderTextureFormat.RG16);
        RenderTexture blend = RenderTexture.GetTemporary(source.width, source.height, 0, RenderTextureFormat.BGRA32);
        
        Graphics.Blit(source, edge, material, 0);
        Graphics.Blit(edge, blend, material, 1);
        material.SetTexture("_BlendTex", blend);
        Graphics.Blit(source, destination, material, 2);
        
        RenderTexture.ReleaseTemporary(edge);
        RenderTexture.ReleaseTemporary(blend);
    }
}