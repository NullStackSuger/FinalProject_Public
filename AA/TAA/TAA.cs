using UnityEngine;

[RequireComponent(typeof(Camera))]
public class TAA : MonoBehaviour
{
    [SerializeField]
    private Material material;

    [SerializeField]
    private int frame = -1;
    
    //长度为8的Halton序列
    private readonly Vector2[] HaltonSequence = 
    {
        new Vector2(0.5f, 1.0f / 3),
        new Vector2(0.25f, 2.0f / 3),
        new Vector2(0.75f, 1.0f / 9),
        new Vector2(0.125f, 4.0f / 9),
        new Vector2(0.625f, 7.0f / 9),
        new Vector2(0.375f, 2.0f / 9),
        new Vector2(0.875f, 5.0f / 9),
        new Vector2(0.0625f, 8.0f / 9),
    };

    private new Camera camera;

    private readonly RenderTexture[] historyTextures = new RenderTexture[2];

    private void Awake()
    {
        camera = GetComponent<Camera>();
        camera.depthTextureMode = DepthTextureMode.Depth | DepthTextureMode.MotionVectors;
        camera.useJitteredProjectionMatrixForTransparentRendering = true;
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        ++frame;
        
        var proj = camera.projectionMatrix;
        camera.nonJitteredProjectionMatrix = proj;
        var index = frame % HaltonSequence.Length;
        var jitter = new Vector2((HaltonSequence[index].x - 0.5f) / camera.pixelWidth, (HaltonSequence[index].y - 0.5f) / camera.pixelHeight);
        proj.m02 += jitter.x * 2;
        proj.m12 += jitter.y * 2;
        camera.projectionMatrix = proj;

        bool ignoreHistory = CheckTexture(ref historyTextures[frame % historyTextures.Length]); // history
        CheckTexture(ref historyTextures[(frame + 1) % historyTextures.Length]); // now
        material.SetVector("_Jitter", jitter);
        material.SetTexture("_HistoryTex", historyTextures[frame % historyTextures.Length]);
        material.SetInt("_IgnoreHistory", ignoreHistory ? 1 : 0);
        
        Graphics.Blit(source, historyTextures[(frame + 1) % historyTextures.Length], material);
        Graphics.Blit(historyTextures[(frame + 1) % historyTextures.Length], destination);
        
        // 还原成没有HaltonSequence的proj, 避免ui后处理等出问题
        camera.ResetProjectionMatrix();
    }

    private bool CheckTexture(ref RenderTexture texture)
    {
        if (texture == null || texture.width != Screen.width || texture.height != Screen.height)
        {
            if (texture != null) RenderTexture.ReleaseTemporary(texture);
            texture = RenderTexture.GetTemporary(Screen.width, Screen.height, 0, RenderTextureFormat.ARGBHalf);
            return true;
        }
        return false;
    }
}