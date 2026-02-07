using UnityEngine;

public class FXAA : MonoBehaviour
{
    [SerializeField]
    private Material material;
    
    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, destination, material);
    }
}