using System;
using UnityEngine;
using UnityEngine.Serialization;

namespace MarchingCube
{
    public class Cell : MonoBehaviour
    {
        public Vector3Int cellPos;
        public Material material;
        
        public Vector4[] vertices;
        
        Mesh mesh;
        MeshFilter meshFilter;
        MeshRenderer meshRenderer;
        MeshCollider meshCollider;
        
        private void Awake()
        {
            meshFilter = GetComponent<MeshFilter>();
            meshRenderer = GetComponent<MeshRenderer>();
            meshCollider = GetComponent<MeshCollider>();

            if (meshFilter == null)
            {
                meshFilter = gameObject.AddComponent<MeshFilter>();
            }

            if (meshRenderer == null)
            {
                meshRenderer = gameObject.AddComponent<MeshRenderer>();
            }

            if (meshCollider == null)
            {
                meshCollider = gameObject.AddComponent<MeshCollider>();
            }

            mesh = meshFilter.sharedMesh;
            if (mesh == null)
            {
                mesh = new Mesh();
                mesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;
                meshFilter.sharedMesh = mesh;
            }

            if (meshCollider.sharedMesh == null)
            {
                meshCollider.sharedMesh = mesh;
            }
  
            meshCollider.enabled = false;
            meshCollider.enabled = true;

            meshRenderer.material = material;
        }

        public void UpdateMesh(Vector3[] vertices, int[] triangles) 
        {
            this.mesh.Clear();
            this.mesh.vertices = vertices;
            this.mesh.triangles = triangles;
            this.mesh.RecalculateNormals();
            meshCollider.enabled = false;
            meshCollider.enabled = true;
        }
    }
}