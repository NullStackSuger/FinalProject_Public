using System;
using System.Collections.Generic;
using UnityEngine;

namespace MarchingCube
{
    public class MarchingCube : IDisposable
    {
        private float maxValue/* = 0*/;
        /// <summary>
        /// 视野范围
        /// </summary>
        private Vector3 seeArea/* = new Vector3(2, 2, 2)*/;
        /// <summary>
        /// 每个Cell的大小
        /// </summary>
        private Vector3 cellSize/* = new Vector3(16, 16, 16)*/;
        
        private PerlinGenerator mapValues;
        private EditorGenerator editorValues;

        private GameObject cellPrefabe;
        
        private ComputeShader shader;
        private ComputeBuffer verticesBuffer;
        private ComputeBuffer trianglesBuffer;
        
        private Dictionary<Vector3Int, Cell> cells = new();
        private List<Vector3Int> see = new();

        private int verticesCount;
        private int cellsCount;

        public MarchingCube(float maxValue, Vector3 seeArea, Vector3 cellSize, PerlinGenerator mapValues, EditorGenerator editorValues)
        {
            this.maxValue = maxValue;
            this.seeArea = seeArea;
            this.cellSize = cellSize;
            this.mapValues = mapValues;
            this.editorValues = editorValues;
            
            this.cellPrefabe = Resources.Load<GameObject>("MarchingCube/CellPrefabe");
            this.shader = Resources.Load<ComputeShader>("MarchingCube/MarchingCube");
            
            this.verticesCount = (int)((cellSize.x + 1) * (cellSize.y + 1) * (cellSize.z + 1));
            this.cellsCount = (int)(cellSize.x * cellSize.y * cellSize.z);
            trianglesBuffer = new ComputeBuffer(cellsCount * 5, sizeof(float) * 3 * 3, ComputeBufferType.Append);
            verticesBuffer = new ComputeBuffer(verticesCount, sizeof(float) * 4);
        }
        
        public void UpdateCells(Vector3 curPos)
        {
            Vector3Int curCellPos = ToCellPos(curPos);
            
            // 减少seeCell
            for (int i = see.Count - 1; i >= 0; i--)
            {
                Vector3Int cellPos = see[i];
                Vector3 distance = cellPos - curCellPos;
                if (Mathf.Abs(distance.x) > seeArea.x || Mathf.Abs(distance.y) > seeArea.y || Mathf.Abs(distance.z) > seeArea.z)
                {
                    cells[see[i]].gameObject.SetActive(false);
                    see.RemoveAt(i);
                }
            }
            
            // 增加seeCell
            int areaX = Mathf.CeilToInt(seeArea.x);
            int areaY = Mathf.CeilToInt(seeArea.y);
            int areaZ = Mathf.CeilToInt(seeArea.z);
            for (int x = -areaX; x <= areaX; x++)
            {
                for (int y = -areaY; y <= areaY; y++)
                {
                    for (int z = -areaZ; z <= areaZ; z++)
                    {
                        Vector3Int cellPos = new Vector3Int(x, y, z) + curCellPos;
                        if (cells.ContainsKey(cellPos))
                        {
                            if (!see.Contains(cellPos)) see.Add(cellPos);
                            cells[cellPos].gameObject.SetActive(true);
                        }
                        else
                        {
                            Vector3 distance = cellPos - curCellPos;
                            if (Mathf.Abs(distance.x) > seeArea.x || Mathf.Abs(distance.y) > seeArea.y || Mathf.Abs(distance.z) > seeArea.z) continue;
                        
                            Bounds bounds = new Bounds(ToWorldPos(cellPos), cellSize);
                            if (!IsVisibleFrom(bounds, Camera.main)) continue;

                            GameObject cellObj = GameObject.Instantiate(cellPrefabe);
                            cellObj.name = $"Cell ({cellPos.x}, {cellPos.y}, {cellPos.z})";
                            Cell cell = cellObj.GetComponent<Cell>();
                            cell.cellPos = cellPos;
                        
                            see.Add(cellPos);
                            cells.Add(cellPos, cell);

                            MapMesh(cell);
                        }
                    }
                }
            }
            
            // 编辑网格
            if (Input.GetMouseButtonDown(0))
            {
                Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
                
                if (Physics.Raycast(ray, out RaycastHit hit, editorValues.maxDistance))
                {
                    // 获取命中的cell
                    Cell cell = hit.transform.GetComponent<Cell>();
                    if (cell == null) return;
                    
                    // 根据画笔半径计算命中的所有cells
                    // TODO r * 3
                    Collider[] colliders = Physics.OverlapSphere(hit.point, editorValues.radius * 3);
                    foreach (Collider collider in colliders)
                    {
                        cell = collider.gameObject.GetComponent<Cell>();
                        if (cell == null) continue;
                        
                        EditorMesh(cell, hit);
                    }
                }
            }
        }
        
        /// <summary>
        /// 返回Cell空间下坐标
        /// </summary>
        private Vector3Int ToCellPos(Vector3 pos)
        {
            return new Vector3Int(
                Mathf.RoundToInt(pos.x / cellSize.x), 
                Mathf.RoundToInt(pos.y / cellSize.y),
                Mathf.RoundToInt(pos.z / cellSize.z));
        }
        /// <summary>
        /// 返回世界坐标系的坐标
        /// </summary>
        private Vector3 ToWorldPos(Vector3Int pos)
        {
            return new Vector3(
                pos.x * cellSize.x, 
                pos.y * cellSize.y, 
                pos.z * cellSize.z);
        }
        
        /// <summary>
        /// 生成Mesh(不会去计算顶点)
        /// </summary>
        private void CreatMesh(Cell cell) 
        {
            // 记录顶点信息
            cell.vertices = new Vector4[this.verticesCount];
            verticesBuffer.GetData(cell.vertices);
            
            trianglesBuffer.SetCounterValue(0);
            shader.SetBuffer(0, "vertices", verticesBuffer);
            shader.SetBuffer(0, "triangles", trianglesBuffer);
            shader.SetVector("area", cellSize);
            shader.SetFloat("maxValue", maxValue);
            
            shader.GetKernelThreadGroupSizes(0, out var x, out var y, out var z);
            shader.Dispatch(0, Mathf.CeilToInt(cellSize.x / x), Mathf.CeilToInt(cellSize.y / y), Mathf.CeilToInt(cellSize.z / z));
            
            ComputeBuffer countBuffer = new ComputeBuffer(1, sizeof(int), ComputeBufferType.Raw);
            ComputeBuffer.CopyCount(trianglesBuffer, countBuffer, 0);
            int[] countArr = { 0 };
            countBuffer.GetData(countArr);
            countBuffer?.Release();
            countBuffer?.Dispose();
            int count = countArr[0];
            
            Triangle[] tris = new Triangle[count];
            trianglesBuffer.GetData(tris);
            
            var vertices = new Vector3[count * 3];
            var triangles = new int[count * 3];
            for (int i = 0; i < count; i++)
            {
                for (int j = 0; j < 3; j++)
                {
                    triangles[i * 3 + j] = i * 3 + j;
                    vertices[i * 3 + j] = tris[i][j];
                }
            }
            
            cell.UpdateMesh(vertices, triangles);
        }
        /// <summary>
        /// 采样cell, 生成网格
        /// </summary>
        /// <param name="cell"></param>
        private void MapMesh(Cell cell)
        {
            mapValues.GenerateValue(verticesBuffer, cellSize, Vector3.one, ToWorldPos(cell.cellPos));
            CreatMesh(cell);
        }
        /// <summary>
        /// 编辑网格
        /// </summary>
        private void EditorMesh(Cell cell, RaycastHit hit)
        {
            // 先设置顶点数据到buffer
            verticesBuffer.SetData(cell.vertices);
            // 计算顶点信息
            editorValues.hit = hit;
            editorValues.GenerateValue(verticesBuffer, cellSize, Vector3.one, ToWorldPos(cell.cellPos));
            // 赋回给buffer
            cell.vertices = new Vector4[this.verticesCount];
            // 重新计算网格信息
            CreatMesh(cell);
        }
        
        private bool IsVisibleFrom(Bounds bounds, Camera camera)
        {
            Plane[] planes = GeometryUtility.CalculateFrustumPlanes(camera);
            return GeometryUtility.TestPlanesAABB(planes, bounds);
        }

        /*void OnDrawGizmos()
        {
            Gizmos.color = Color.black;
            foreach (var chunk in cells.Values)
            {
                Gizmos.DrawWireCube(ToWorldPos(chunk.cellPos), cellSize);
            }
        }*/
        
        public void Dispose()
        {
            verticesBuffer?.Release();
            verticesBuffer?.Dispose();
            trianglesBuffer?.Release();
            trianglesBuffer?.Dispose();
        }

        ~MarchingCube()
        {
            Dispose();
        }
    }
    
    struct Triangle
    {
        public Vector3 a;
        public Vector3 b;
        public Vector3 c;

        public Vector3 this[int i]
        {
            get
            {
                switch (i)
                {
                    case 0:
                        return a;
                    case 1:
                        return b;
                    default:
                        return c;
                }
            }
        }
    }
}
