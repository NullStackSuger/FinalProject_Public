using UnityEngine;

namespace MarchingCube
{
    public class EditorGenerator : ValueGenerator
    {
        public float maxDistance { get; private set; }/* = 10;*/
        public float radius { get; private set; }/* = 3;*/
        
        private float maxValue;

        public RaycastHit hit;

        public EditorGenerator(float maxDistance, float radius, float maxValue)
        {
            this.maxDistance = maxDistance;
            this.radius = radius;
            this.maxValue = maxValue;
        }

        public override void GenerateValue(ComputeBuffer vertices, Vector3 area, Vector3 cellSize, Vector3 center)
        {
            shader.SetFloat("radius", radius);
            shader.SetFloat("maxValue", maxValue);
            shader.SetVector("hitPos", hit.point);
            shader.SetVector("hitNormal", hit.normal);
            
            base.GenerateValue(vertices, area, cellSize, center);
        }
    }
}