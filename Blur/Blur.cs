using UnityEngine;

public class Blur : MonoBehaviour
{
    public enum BlurType
    {
        Gaussian = 0,
        Box,
        Kawase,
        Double,
        Radial,
        Bokeh,
    }

    [SerializeField]
    private Material material;
    
    [SerializeField]
    public BlurType blurType = BlurType.Gaussian;

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, destination, material, (int)blurType);
    }
}