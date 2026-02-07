using System;
using UnityEngine;

[RequireComponent(typeof(WaveGenerator))]
[RequireComponent(typeof(MeshFilter))]
public class MeshGenerator : MonoBehaviour
{
    public Material material;
    private WaveGenerator waveGenerator;
    
    private void Start()
    {
        waveGenerator = GetComponent<WaveGenerator>();
        Mesh mesh = GetComponent<MeshFilter>().mesh;
        MeshRenderer meshRenderer = GetComponent<MeshRenderer>();
        mesh.Clear();
        int size = waveGenerator.size;
        
        Vector3[] X = new Vector3[size * size];
        for (int i = 0; i < size; i++)
        for (int j = 0; j < size; j++)
        {
            X[i * size + j].x = i * 0.1f;
            X[i * size + j].y = 0;
            X[i * size + j].z = j * 0.1f;
        }
        int[] T = new int[(size - 1) * (size - 1) * 6];
        int index = 0;
        for (int i = 0; i < size - 1; i++)
        for (int j = 0; j < size - 1; j++)
        {
            T[index * 6 + 0] = (i + 0) * size + j + 0;
            T[index * 6 + 1] = (i + 0) * size + j + 1;
            T[index * 6 + 2] = (i + 1) * size + j + 1;
            T[index * 6 + 3] = (i + 0) * size + j + 0;
            T[index * 6 + 4] = (i + 1) * size + j + 1;
            T[index * 6 + 5] = (i + 1) * size + j + 0;
            index++;
        }
        mesh.vertices = X;
        mesh.triangles = T;
        mesh.RecalculateNormals();
        
        material.SetInt("SampleCount0", waveGenerator.sampleCount0);
        material.SetInt("SampleCount1", waveGenerator.sampleCount1);
        material.SetInt("SampleCount2", waveGenerator.sampleCount2);
        material.SetTexture("Displacement0", waveGenerator.wave0.displacement);
        material.SetTexture("Derivatives0", waveGenerator.wave0.derivatives);
        material.SetTexture("Turbulence0", waveGenerator.wave0.turbulence);
        material.SetTexture("Displacement1", waveGenerator.wave1.displacement);
        material.SetTexture("Derivatives1", waveGenerator.wave1.derivatives);
        material.SetTexture("Turbulence1", waveGenerator.wave1.turbulence);
        material.SetTexture("Displacement2", waveGenerator.wave2.displacement);
        material.SetTexture("Derivatives2", waveGenerator.wave2.derivatives);
        material.SetTexture("Turbulence2", waveGenerator.wave2.turbulence);
        meshRenderer.material = material;
    }

    void Update()
    {
        
    }
}