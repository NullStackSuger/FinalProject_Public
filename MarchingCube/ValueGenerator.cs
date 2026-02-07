using UnityEngine;

namespace MarchingCube
{
    public class ValueGenerator
    {
        protected readonly ComputeShader shader;
        protected readonly int kernel;

        protected ValueGenerator()
        {
            shader = Resources.Load<ComputeShader>($"MarchingCube/{GetType().Name}");
            kernel = 0;
        }
        
        public virtual void GenerateValue(ComputeBuffer vertices, Vector3 area, Vector3 cellSize, Vector3 center)
        {
            shader.SetBuffer(kernel, "vertices", vertices);
            shader.SetVector("area", area);
            shader.SetVector("cellSize", cellSize);
            shader.SetVector("center", center);
            
            shader.GetKernelThreadGroupSizes(kernel, out var x, out var y, out var z);
            shader.Dispatch(kernel, Mathf.CeilToInt((area.x + 1) / x), Mathf.CeilToInt((area.y + 1) / y), Mathf.CeilToInt((area.z + 1) / z));
        }
    }
}