using UnityEngine;

public class WaveGenerator : MonoBehaviour
{
    public ComputeShader waveGeneratorShader;
    public ComputeShader fftShader;
    public Texture2D noise;

    [Header("Wave Parameters")] 
    public int size = 256;
    public float waterDepth = 500; // 水深
    public float lambda = 1;
    public int sampleCount0 = 250;
    public int sampleCount1 = 17;
    public int sampleCount2 = 5;

    [Header("Spectrum Parameters")] 
    public float scale;
    public float windDir; // 欧拉角
    public float windSpeed;
    public float windLength; // 风吹过水面距离
    public float spreadBlend; // 波浪方向分布宽窄
    public float swell; // 海涌强度
    public float peakEnhancement;
    public float shortWaveFade; // 抑制小波浪

    private FFT fft;
    public WaveCascade wave0;
    public WaveCascade wave1;
    public WaveCascade wave2;
    
    private void Awake()
    {
        fft = new(size, fftShader);
        
        float boundary1 = 2 * Mathf.PI / sampleCount1 * 6f;
        float boundary2 = 2 * Mathf.PI / sampleCount2 * 6f;
        
        wave0 = new(size, sampleCount0, 0.0001f, boundary1,   waterDepth, lambda, scale, windDir, windSpeed, windLength, spreadBlend, swell, peakEnhancement, shortWaveFade, fft, waveGeneratorShader, noise);
        wave1 = new(size, sampleCount1, boundary1, boundary2, waterDepth, lambda, scale, windDir, windSpeed, windLength, spreadBlend, swell, peakEnhancement, shortWaveFade, fft, waveGeneratorShader, noise);
        wave2 = new(size, sampleCount2, boundary2, 9999,      waterDepth, lambda, scale, windDir, windSpeed, windLength, spreadBlend, swell, peakEnhancement, shortWaveFade, fft, waveGeneratorShader, noise);
    }

    private void Update()
    {
        wave0.Update();
        wave1.Update();
        wave2.Update();
    }
}

public class FFT
{
    private readonly int size;
    private readonly ComputeShader fftShader;
    private int initKernel => fftShader.FindKernel("Init");
    private int horizontalIFFTKernel => fftShader.FindKernel("HorizontalIFFT");
    private int verticalIFFTKernel => fftShader.FindKernel("VerticalIFFT");
    private int permuteKernel => fftShader.FindKernel("Permute");
    
    public readonly RenderTexture precomputeBuffer;

    public FFT(int size, ComputeShader fftShader)
    {
        this.size = size;
        this.fftShader = fftShader;
        
        
        // 预计算蝶形运算的旋转因子和输入顺序
        int logSize = (int)Mathf.Log(size, 2);
        precomputeBuffer = new RenderTexture(logSize, size, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear)
        {
            filterMode = FilterMode.Point,
            wrapMode = TextureWrapMode.Repeat,
            enableRandomWrite = true,
        };
        precomputeBuffer.Create();
        
        fftShader.SetInt("N", size);
        fftShader.SetTexture(initKernel, "PrecomputeBuffer", precomputeBuffer);
        fftShader.Dispatch(initKernel, logSize, size / (2 * 8), 1);
    }

    public void IFFT2D(RenderTexture input, RenderTexture tmp, bool outputToInput = false, bool permute = false)
    {
        int logSize = (int)Mathf.Log(size, 2);
        bool pingPong = false;
        
        fftShader.SetTexture(horizontalIFFTKernel, "PrecomputeBuffer", precomputeBuffer);
        fftShader.SetTexture(horizontalIFFTKernel, "Buffer0", input);
        fftShader.SetTexture(horizontalIFFTKernel, "Buffer1", tmp);
        for (int i = 0; i < logSize; i++)
        {
            pingPong = !pingPong;
            fftShader.SetInt("Step", i);
            fftShader.SetBool("PingPong", pingPong);
            fftShader.Dispatch(horizontalIFFTKernel, size / 8, size / 8, 1);
        }
        
        fftShader.SetTexture(verticalIFFTKernel, "PrecomputeBuffer", precomputeBuffer);
        fftShader.SetTexture(verticalIFFTKernel, "Buffer0", input);
        fftShader.SetTexture(verticalIFFTKernel, "Buffer1", tmp);
        for (int i = 0; i < logSize; i++)
        {
            pingPong = !pingPong;
            fftShader.SetInt("Step", i);
            fftShader.SetBool("PingPong", pingPong);
            fftShader.Dispatch(verticalIFFTKernel, size / 8, size / 8, 1);
        }

        if (pingPong && outputToInput)
        {
            Graphics.Blit(tmp, input);
        }
        if (!pingPong && !outputToInput)
        {
            Graphics.Blit(input, tmp);
        }
        if (permute)
        {
            fftShader.SetTexture(permuteKernel, "Buffer0", outputToInput ? input : tmp);
            fftShader.Dispatch(permuteKernel, size / 8, size / 8, 1);
        }
    }
}

public class WaveCascade
{
    private readonly int size;
    private readonly FFT fft;
    private readonly ComputeShader waveGeneratorShader;
    private int computeH0kKernel => waveGeneratorShader.FindKernel("ComputeH0k");
    private int computeH0kStarKernel => waveGeneratorShader.FindKernel("ComputeH0kStar");
    private int computeDxDyDzKernel => waveGeneratorShader.FindKernel("ComputeDxDyDz");
    private int mergerKernel => waveGeneratorShader.FindKernel("Merger");

    private readonly ComputeBuffer spectrum;
    private readonly RenderTexture h0k;
    private readonly RenderTexture h0kStar;
    private readonly RenderTexture waveData;
    private readonly RenderTexture wk;
    
    private readonly RenderTexture dxDz;
    private readonly RenderTexture dyDxz;
    private readonly RenderTexture dyxDyz;
    private readonly RenderTexture dxxDzz;

    public readonly RenderTexture displacement;
    public readonly RenderTexture derivatives;
    public readonly RenderTexture turbulence;
    
    public WaveCascade(
        int size, int sampleCount, float minWave, float maxWave, float waterDepth, float lambda,
        float scale, float windDir, float windSpeed, float windLength, float spreadBlend, float swell, float peakEnhancement, float shortWaveFade,
        FFT fft, ComputeShader waveGeneratorShader, Texture2D noise)
    {
        this.size = size;
        this.fft = fft;
        this.waveGeneratorShader = waveGeneratorShader;
        
        waveGeneratorShader.SetInt("N", size);
        waveGeneratorShader.SetInt("L", sampleCount);
        waveGeneratorShader.SetFloat("MaxK", maxWave);
        waveGeneratorShader.SetFloat("MinK", minWave);
        waveGeneratorShader.SetFloat("WaterDepth", waterDepth);
  
        // Spectrum
        spectrum = new(1, 1 * sizeof(float) * 8);
        spectrum.SetData(new[] { SpectrumParameters.Create(scale, windDir, windSpeed, windLength, spreadBlend, swell, peakEnhancement, shortWaveFade) });

        // H0k
        h0k = CreateTexture2D(size);
        
        // H0kStar
        h0kStar = CreateTexture2D(size);
        
        // WaveData
        waveData = CreateTexture2D(size, RenderTextureFormat.ARGBFloat);
        
        waveGeneratorShader.SetTexture(computeH0kKernel, "Noise", noise);
        waveGeneratorShader.SetBuffer(computeH0kKernel, "Spectrum", spectrum);
        waveGeneratorShader.SetTexture(computeH0kKernel, "H0k", h0k);
        waveGeneratorShader.SetTexture(computeH0kKernel, "H0kStar", h0kStar);
        waveGeneratorShader.SetTexture(computeH0kKernel, "WaveData", waveData);
        waveGeneratorShader.Dispatch(computeH0kKernel, size / 8, size / 8, 1);
        
        waveGeneratorShader.SetTexture(computeH0kStarKernel, "H0k", h0k);
        waveGeneratorShader.SetTexture(computeH0kStarKernel, "H0kStar", h0kStar);
        waveGeneratorShader.Dispatch(computeH0kStarKernel, size / 8, size / 8, 1);
        
        // DxDz
        dxDz = CreateTexture2D(size);
        
        // DyDxz
        dyDxz = CreateTexture2D(size);
        
        // DyxDyz
        dyxDyz = CreateTexture2D(size);
        
        // DxxDzz
        dxxDzz = CreateTexture2D(size);
        
        // Displacement
        displacement = CreateTexture2D(size, RenderTextureFormat.ARGBFloat);
        
        // Derivatives
        derivatives = CreateTexture2D(size, RenderTextureFormat.ARGBFloat, true);
        
        // Turbulence
        turbulence = CreateTexture2D(size, RenderTextureFormat.ARGBFloat, true);
        
        // Lambda
        waveGeneratorShader.SetFloat("Lambda", lambda);
    }

    public void Update()
    {
        waveGeneratorShader.SetTexture(computeDxDyDzKernel, "H0k", h0k);
        waveGeneratorShader.SetTexture(computeDxDyDzKernel, "H0kStar", h0kStar);
        waveGeneratorShader.SetTexture(computeDxDyDzKernel, "WaveData", waveData);
        waveGeneratorShader.SetTexture(computeDxDyDzKernel, "DxDz", dxDz);
        waveGeneratorShader.SetTexture(computeDxDyDzKernel, "DyDxz", dyDxz);
        waveGeneratorShader.SetTexture(computeDxDyDzKernel, "DyxDyz", dyxDyz);
        waveGeneratorShader.SetTexture(computeDxDyDzKernel, "DxxDzz", dxxDzz);
        waveGeneratorShader.SetFloat("Time", Time.time);
        waveGeneratorShader.Dispatch(computeDxDyDzKernel, size / 8, size / 8, 1);

        RenderTexture tmp = CreateTexture2D(size);
        fft.IFFT2D(dxDz,   tmp, true, true);
        fft.IFFT2D(dyDxz,  tmp, true,  true);
        fft.IFFT2D(dyxDyz, tmp, true, true);
        fft.IFFT2D(dxxDzz, tmp, true, true);
        
        waveGeneratorShader.SetTexture(mergerKernel, "DxDz", dxDz);
        waveGeneratorShader.SetTexture(mergerKernel, "DyDxz", dyDxz);
        waveGeneratorShader.SetTexture(mergerKernel, "DyxDyz", dyxDyz);
        waveGeneratorShader.SetTexture(mergerKernel, "DxxDzz", dxxDzz);
        waveGeneratorShader.SetTexture(mergerKernel, "Displacement", displacement);
        waveGeneratorShader.SetTexture(mergerKernel, "Derivatives", derivatives);
        waveGeneratorShader.SetTexture(mergerKernel, "Turbulence", turbulence);
        waveGeneratorShader.SetFloat("DeltaTime", Time.deltaTime);
        waveGeneratorShader.Dispatch(mergerKernel, size / 8, size / 8, 1);
    }

    private RenderTexture CreateTexture2D(int size, RenderTextureFormat format = RenderTextureFormat.RGFloat, bool useMipMap = false)
    {
        RenderTexture rt = new RenderTexture(size, size, 0, format, RenderTextureReadWrite.Linear)
        {
            useMipMap = useMipMap,
            autoGenerateMips = false,
            anisoLevel = 6,
            filterMode = FilterMode.Trilinear,
            wrapMode = TextureWrapMode.Repeat,
            enableRandomWrite = true,
        };
        rt.Create();
        return rt;
    }
}

public struct SpectrumParameters
{
    public float scale;
    public float windDir;
    public float spreadBlend;
    public float swell;
    public float alpha;
    public float peakWk;
    public float gamma;
    public float shortWaveFade;

    public static SpectrumParameters Create(float scale, float windDir, float windSpeed, float windLength, float spreadBlend, float swell, float peakEnhancement, float shortWaveFade)
    {
        SpectrumParameters parameters = new();
        
        parameters.scale = scale;
        parameters.windDir = windDir / 180 * Mathf.PI;
        parameters.spreadBlend = spreadBlend;
        parameters.swell = Mathf.Clamp(swell, 0.01f, 1);
        parameters.alpha = JonswapAlpha(windLength, windSpeed);
        parameters.peakWk = JonswapPeakWk(windLength, windSpeed);
        parameters.gamma = peakEnhancement;
        parameters.shortWaveFade = shortWaveFade;
        
        return parameters;
    }
    const float g = 9.81f;
    static float JonswapAlpha(float windLength, float windSpeed)
    {
        return 0.076f * Mathf.Pow(g * windLength / windSpeed / windSpeed, -0.22f);
    }
    static float JonswapPeakWk(float windLength, float windSpeed)
    {
        return 22 * Mathf.Pow(windSpeed * windLength / g / g, -0.33f);
    }
}