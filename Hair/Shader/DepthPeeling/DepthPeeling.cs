using UnityEngine;
using UnityEngine.Rendering;

[RequireComponent(typeof(Camera))]
public class DepthPeeling : MonoBehaviour
{
    [Range(1, 6)]
    public int maxDepthLayer = 5;
    
    public Shader mrtShader;
    public Material finalRender;

    [Range(-1, 5)]
    public int viewLayer;
    
    // 流程
    // 1. 2个相机camera和tmpCamera, tmpCamera只渲染"DepthPeeling"的
    //    有个Bug, SetTargetBuffers中的depthBuffer读取不到, 所以需要把深度作为颜色缓存输出, 需要额外的 tmp = preDepthTexture = depthTexture
    // 2. 循环把每一层颜色赋值给finalClips
    // 3. 
    
    private RenderTexture preColorTexture;
    private RenderTexture preDepthTexture;
    private RenderTexture finalClips;
    private RenderTexture tmp;
    private RenderTexture depthTexture;
    private RenderBuffer depthBuffer;
    private RenderBuffer[] colorBuffer;

    private new Camera camera;
    private Camera tmpCamera;

    private void Awake()
    {
        camera = GetComponent<Camera>();
        tmpCamera = new GameObject().AddComponent<Camera>();
        tmpCamera.enabled = false;
        
        preDepthTexture = new RenderTexture(camera.pixelWidth, camera.pixelHeight, 0, RenderTextureFormat.RFloat);
        preDepthTexture.Create();
        preColorTexture = new RenderTexture(camera.pixelWidth, camera.pixelHeight, 0, RenderTextureFormat.Default);
        preColorTexture.Create();
        
        finalClips = new RenderTexture(camera.pixelWidth, camera.pixelHeight, 0, RenderTextureFormat.Default);
        finalClips.dimension = TextureDimension.Tex2DArray;
        finalClips.volumeDepth = 6;
        finalClips.Create();
        Shader.SetGlobalTexture("_FinalClips", finalClips);
        
        tmp = new RenderTexture(camera.pixelWidth, camera.pixelHeight, 0, RenderTextureFormat.RFloat);
        tmp.Create();
        Shader.SetGlobalTexture("_PreDepthTexture", tmp);
        
        depthTexture = new RenderTexture(camera.pixelWidth, camera.pixelHeight, 16, RenderTextureFormat.Depth);
        depthTexture.Create();
        
        depthBuffer = depthTexture.depthBuffer;
        colorBuffer = new RenderBuffer[2] { preDepthTexture.colorBuffer, preColorTexture.colorBuffer};
    }

    void CopyCamera()
    {
        tmpCamera.CopyFrom(camera);
        tmpCamera.clearFlags = CameraClearFlags.SolidColor;
        tmpCamera.backgroundColor = Color.clear;
        tmpCamera.SetTargetBuffers(colorBuffer, depthBuffer);
        tmpCamera.cullingMask = 1 << LayerMask.NameToLayer("DepthPeeling");
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        CopyCamera();
        
        for (int i = 0; i < maxDepthLayer; i++)
        {
            Graphics.Blit(preDepthTexture, tmp);
            Shader.SetGlobalInt("_DepthLayer", i);
            tmpCamera.RenderWithShader(mrtShader, "");
            Graphics.CopyTexture(preColorTexture, 0, 0, finalClips, i, 0);
        }

        //Graphics.Blit(preColorTexture, destination);
        //Graphics.Blit(preColorTexture, destination);
        if (5 >= viewLayer && viewLayer >= 0)
        {
            Graphics.Blit(finalClips, destination, viewLayer, viewLayer);
        }
        else
        {
            Graphics.Blit(null, destination, finalRender);
        }
    }

    private void OnDestroy()
    {
        preDepthTexture.Release();
        preColorTexture.Release();
        finalClips.Release();
        tmp.Release();
    }
}