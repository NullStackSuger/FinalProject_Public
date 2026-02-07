using UnityEngine;

[RequireComponent(typeof(MeshRenderer))]
[ExecuteAlways]
public class Fur : MonoBehaviour
{
    private Mesh mesh;
    private Material material;
    [Range(1, 32)]
    public int shellCount = 32;

    private Matrix4x4[] matrices;
    private MaterialPropertyBlock[] props;
    
    private void Awake()
    {
        material = GetComponent<MeshRenderer>().sharedMaterial;
        mesh = GetComponent<MeshFilter>().sharedMesh;
    }

    private void OnValidate()
    {
        matrices = new Matrix4x4[shellCount];
        props = new MaterialPropertyBlock[shellCount];
        for (int i = 0; i < shellCount; i++)
        {
            matrices[i] = transform.localToWorldMatrix;
            props[i] = new MaterialPropertyBlock();
            props[i].SetFloat("_ShellIndex", i);
            props[i].SetFloat("_ShellCount", shellCount);
        }
    }

    private void Update()
    {
        //同步更新壳层世界位置
        for (int i = 0; i < shellCount; i++)
        {
            matrices[i] = transform.localToWorldMatrix;
            props[i].SetFloat("_ShellIndex", i);
        }
        
        //使用DrawMesh API渲染多壳层
        for (int i = 0; i < shellCount; i++)
        {
            Graphics.DrawMesh(
                mesh,
                matrices[i],
                material,           
                0,
                null,
                0,
                props[i],           
                UnityEngine.Rendering.ShadowCastingMode.Off,
                false
            );
        }
    }
}