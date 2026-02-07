using System;
using MarchingCube;
using UnityEngine;

namespace MarchingCube.Demo
{
    public class Test1 : MonoBehaviour
    {
        [Header("Perlin")]
        [Min(1)]
        public int mapCount = 4;
        
        public Vector3 diff = new Vector3(0.05f, 0.05f, 0.05f);

        [Header("Editor")] 
        [Min(0)]
        public float maxDistance = 5;
        [Min(0)]
        public float editorRadius = 2;
        
        [Header("Marching Cube")]
        [Min(0)]
        public float maxValue;

        public Vector3 seeArea = new Vector3(2, 2, 2);

        public Vector3 cellSize = new Vector3(16, 16, 16);
        
        [Min(0)]
        public float loud = 0;
        
        private MarchingCube march;
        
        private void Awake()
        {
            var perlin = new PerlinGenerator(mapCount, diff, loud);
            var editor = new EditorGenerator(maxDistance, editorRadius, maxValue);
            march = new MarchingCube(maxValue, seeArea, cellSize, perlin, editor);
        }

        private void Update()
        {
            march?.UpdateCells(Camera.main.transform.position);
        }
        
        private void OnDestroy()
        {
            march?.Dispose();
        }
    }
}