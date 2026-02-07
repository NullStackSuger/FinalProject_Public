using UnityEngine;

public class ToneMapping : MonoBehaviour
{
    [SerializeField]
    private Material material;

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, destination, material);
    }
}