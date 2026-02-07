using UnityEngine;

[RequireComponent(typeof(Camera))]
public class HBAO : MonoBehaviour
{
    [SerializeField]
    private Material material;

    public int direction = 6;
    public int step = 6;
    
    public float aoStrength = 0.54f;
    public int maxRadiusPixel = 218;
    public float radius = 1.243f;
    public float angleBias = 0.173f;
    
    public int blurRadiusPixel = 20;
    public int blurSamples = 10;
    
    private new Camera camera;
    
    private void Awake()
    {
        camera = GetComponent<Camera>();
        camera.depthTextureMode = DepthTextureMode.Depth | DepthTextureMode.DepthNormals;
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        material.SetInt("_Direction", direction);
        material.SetInt("_Step", step);
        
        var tanHalfFovY = Mathf.Tan(camera.fieldOfView * 0.5f * Mathf.Deg2Rad);
        var tanHalfFovX = tanHalfFovY * ((float)camera.pixelWidth / camera.pixelHeight);
        material.SetVector("_UV2View", new Vector4(2 * tanHalfFovX, 2 * tanHalfFovY, -tanHalfFovX, -tanHalfFovY));
        material.SetVector("_TexelSize", new Vector4(1f / camera.pixelWidth, 1f / camera.pixelHeight, camera.pixelHeight, camera.pixelWidth));
        material.SetFloat("_RadiusPixel", camera.pixelHeight * radius / tanHalfFovY / 2);
        material.SetFloat("_Radius", radius);
        material.SetFloat("_MaxRadiusPixel", maxRadiusPixel);
        material.SetFloat("_AngleBias", angleBias);
        material.SetFloat("_AOStrength", aoStrength);
        
        material.SetFloat("_BlurRadiusPixel", blurRadiusPixel);
        material.SetInt("_BlurSamples", blurSamples);
        
        RenderTexture tmp = RenderTexture.GetTemporary(source.width, source.height);
        Graphics.Blit(source, tmp, material, 0);
        //Graphics.Blit(tmp, destination, material, 0);
        material.SetTexture("_HbaoTex", tmp);
        Graphics.Blit(source, destination, material, 1);
        RenderTexture.ReleaseTemporary(tmp);
    }
}