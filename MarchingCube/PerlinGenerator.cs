using UnityEngine;

namespace MarchingCube
{
    public class PerlinGenerator : ValueGenerator
    {
        private int mapCount/* = 4*/;
        private Vector3 diff/* = new Vector3(0.05f, 0.05f, 0.05f)*/;
        private float loud/* = 0*/;

        public PerlinGenerator(int mapCount, Vector3 diff, float loud)
        {
            this.mapCount = mapCount;
            this.diff = diff;
            this.loud = loud;
        }

        public override void GenerateValue(ComputeBuffer vertices, Vector3 area, Vector3 cellSize, Vector3 center)
        {
            shader.SetInt("mapCount", mapCount);
            shader.SetVector("diff", diff);
            shader.SetFloat("loud", loud);
            
            base.GenerateValue(vertices, area, cellSize, center);
        }
    }
}