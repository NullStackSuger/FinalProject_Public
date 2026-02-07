using System.Collections.Generic;
using UnityEngine;

public class Loop : MonoBehaviour
{
    static bool Vector3Equal(Vector3 v1, Vector3 v2)
    {
        for (int i = 0; i < 3; i++)
        {
            if (!FloatEqual(v1[i], v2[i]))
            {
                return false;
            }
        }
        return true;
    }
    static bool FloatEqual(float f1, float f2)
    {
        return Mathf.Abs(f1 - f2) < Mathf.Epsilon;
    }
    static bool IsOnSameEdge(NewVertex v0, NewVertex v1)
    {
        return v0 != null && v1 != null &&
               (v0.nearVertexIndex0 == v1.nearVertexIndex0 && v0.nearVertexIndex1 == v1.nearVertexIndex1 || 
                v0.nearVertexIndex0 == v1.nearVertexIndex1 && v0.nearVertexIndex1 == v1.nearVertexIndex0);
    }
    
    private class OldVertex
    {
        public Vector3 position;
        public int degree; // 顶点的度
        public OldVertex[] nearPoints;

        private static int COUNT;
        private readonly int hashCode;
        public OldVertex()
        {
            hashCode = COUNT++;
        }
        public override int GetHashCode()
        {
            return hashCode;
        }
    
        public static bool operator == (OldVertex vertex0, OldVertex vertex1)
        {
            return !ReferenceEquals(vertex0, null) && 
                   !ReferenceEquals(vertex1, null) &&
                   Vector3Equal(vertex0.position, vertex1.position);
        }
        public static bool operator != (OldVertex vertex0, OldVertex vertex1)
        {
            return !(vertex0 == vertex1);
        }
        public override bool Equals(object obj)
        {
            OldVertex oldVertex = obj as OldVertex;
            return oldVertex != null && oldVertex == this;
        }
    }
    private class NewVertex
    {
        // 新顶点是由2个老顶点中点生成的
        public Vector3 position;
        public int nearVertexIndex0; // 老顶点0
        public int nearVertexIndex1; // 老顶点1
        public Vector3 nearVertexPos0;
        public Vector3 nearVertexPos1;
        public Vector3 oppositeVertexPos0; // 对角顶点0
        public Vector3 oppositeVertexPos1; // 对角顶点1
        
        private static int COUNT;
        private readonly int hashCode;
        public NewVertex()
        {
            hashCode = COUNT++;
        }
        public override int GetHashCode()
        {
            return hashCode;
        }
        
        public static bool operator == (NewVertex vertex0, NewVertex vertex1)
        {
            return !ReferenceEquals(vertex0, null) && 
                   !ReferenceEquals(vertex1, null) && 
                   Vector3Equal(vertex0.position, vertex1.position);
        }
        public static bool operator != (NewVertex vertex0, NewVertex vertex1)
        {
            return !(vertex0 == vertex1);
        }
        public override bool Equals(object obj)
        {
            NewVertex vertex = obj as NewVertex;
            return vertex != null && vertex == this;
        }
    }

    public Mesh mesh;
    public int loopCount = 1;
    
    [Header("Output")]
    private Vector3[] vertices;
    private int[] indices;
    private List<Vector3> repeatVertices;
    private int[] repeatMap;
    private int[] repeatIndices;
    private OldVertex[] oldVertices;
    private NewVertex[] newVertices;
    private Vector3[] outVertices;
    private int[] outIndices;
    
    private void OnEnable()
    {
        Mesh targetMesh = this.mesh;
        for (int i = 0; i < loopCount; ++i)
        {
            // Clear
            vertices = null;
            indices = null;
            repeatVertices = null;
            repeatMap = null;
            repeatIndices = null;
            oldVertices = null;
            newVertices = null;
            outVertices = null;
            outIndices = null;
            
            vertices = targetMesh.vertices;
            indices = targetMesh.triangles;
            RemoveRepeatVertex(vertices, indices, out repeatVertices, out repeatMap, out repeatIndices);
            InitOldVertex(vertices, repeatVertices, repeatMap, repeatIndices, out oldVertices);
            InitNewVertex(vertices, indices, repeatIndices, out newVertices);
            ComputeVertexAndIndex(indices, newVertices, oldVertices, out outVertices, out outIndices);
            targetMesh = CreateMesh(outVertices, outIndices);
        }
        this.GetComponent<MeshFilter>().sharedMesh = targetMesh;
    }
    // 去掉重复顶点
    static void RemoveRepeatVertex(Vector3[] vertices, int[] indices, out List<Vector3> repeatVertices, out int[] repeatMap, out int[] repeatIndices)
    {
        repeatVertices = new List<Vector3>();
        repeatMap = new int[vertices.Length]; // vertices中每个顶点对应到repeatedVertices的下标, eg. 0, 1, 2 -> 0, 1, 0, 第2号顶点和第0号重复了
        repeatIndices = new int[indices.Length]; // 把tmp扩充到indices.Length, 使得可以替换原indices
        
        for (int i = 0; i < vertices.Length; i++)
        {
            Vector3 currentVertex = vertices[i];
            bool isRepeated = false; // 顶点是否重复
            foreach (Vector3 compareVertex in repeatVertices)
            {
                if (Vector3Equal(currentVertex, compareVertex))
                {
                    isRepeated = true;
                    break;
                }
            }
            if (isRepeated == false)
            {
                repeatVertices.Add(currentVertex);   
            }
            repeatMap[i] = repeatVertices.IndexOf(currentVertex);
        }

        for (int i = 0; i < indices.Length; i++)
        {
            repeatIndices[i] = repeatMap[indices[i]];
        }
    }
    static void InitOldVertex(Vector3[] vertices, List<Vector3> repeatVertices, int[] repeatMap, int[] repeatIndices, out OldVertex[] oldVertices)
    {
        List<int>[] temp = new List<int>[repeatVertices.Count];
        // 为什么不遍历repeatVertices, 因为知道vertices不能判断是否是邻居, 但是遍历indices隐含了面信息, 2个面6个index只要有2个index相同, 剩下的index指向的顶点一定是相邻的
        // 固定index去逐个面比较
        for (int i = 0; i < repeatIndices.Length; i++)
        {
            int index = repeatIndices[i];

            temp[index] ??= new List<int>();
            List<int> list = temp[index];
            
            for (int j = 0; j < repeatIndices.Length; j += 3)
            {
                // 二进制表示面的哪个顶点和index相同
                // 如果是退化三角形, 那3个顶点中必然有2个=index, 则会添加index和剩下的一个顶点到list
                int flag = 7; // 111
                if (repeatIndices[j] == index) flag = 6; // 110
                if (repeatIndices[j + 1] == index) flag = 5; // 101
                if (repeatIndices[j + 2] == index) flag = 3; // 011

                int offset = 0;
                while (flag != 7 && offset < 3)
                {
                    if ((flag & (1 << offset)) > 0) // 找二进制下为1的位添加
                    {
                        if (!list.Contains(repeatIndices[j + offset]))
                        {
                            list.Add(repeatIndices[j + offset]);
                        }
                    }
                    offset++;
                }
            }
        }
        
        oldVertices = new OldVertex[vertices.Length];
        for (int i = 0; i < oldVertices.Length; i++)
        {
            OldVertex oldVertex = new() { position = vertices[i] };
            int index = repeatMap[i];
            if (index < temp.Length && temp[index] != null)
            {
                int degree = temp[index].Count;
                oldVertex.degree = degree;
                oldVertex.nearPoints = new OldVertex[degree];
                for (int j = 0; j < degree; j++)
                {
                    oldVertex.nearPoints[j] = new OldVertex() { position = repeatVertices[temp[index][j]] };
                }
            }
            oldVertices[i] = oldVertex;
        }
        
        UpdateOldPos(oldVertices);
    }
    static void UpdateOldPos(OldVertex[] oldVertices)
    {
        const float scale = 3.0f / 16.0f;
        for (int i = 0; i < oldVertices.Length; i++)
        {
            OldVertex oldVertex = oldVertices[i];
            Vector3 nearPosSum = Vector3.zero;
            for (int j = 0; j < oldVertex.nearPoints.Length; j++)
            {
                nearPosSum += oldVertex.nearPoints[j].position;
            }
            int degree = oldVertex.degree;

            float u = degree == 3 ? scale : 3.0f / (8 * degree);
            oldVertex.position = (1 - degree * u) * oldVertex.position + u * nearPosSum;
        }
    }
    static void InitNewVertex(Vector3[] vertices, int[] indices, int[] repeatIndices, out NewVertex[] newVertices)
    {
        newVertices = new NewVertex[indices.Length];
        for (int i = 0; i < indices.Length; i += 3)
        {
            int rowIndex0 = indices[i];
            int rowIndex1 = indices[i + 1];
            int rowIndex2 = indices[i + 2];
            
            int repeatIndex0 = repeatIndices[i];
            int repeatIndex1 = repeatIndices[i + 1];
            int repeatIndex2 = repeatIndices[i + 2];

            NewVertex newVertex0 = new()
            {
                position = (vertices[rowIndex0] + vertices[rowIndex1]) * 0.5f,
                nearVertexIndex0 = repeatIndex0,
                nearVertexIndex1 = repeatIndex1,
                nearVertexPos0 = vertices[rowIndex0],
                nearVertexPos1 = vertices[rowIndex1],
                oppositeVertexPos0 = vertices[rowIndex2],
            };
            NewVertex newVertex1 = new()
            {
                position = (vertices[rowIndex1] + vertices[rowIndex2]) * 0.5f,
                nearVertexIndex0 = repeatIndex1,
                nearVertexIndex1 = repeatIndex2,
                nearVertexPos0 = vertices[rowIndex1],
                nearVertexPos1 = vertices[rowIndex2],
                oppositeVertexPos0 = vertices[rowIndex0],
            };
            NewVertex newVertex2 = new()
            {
                position = (vertices[rowIndex2] + vertices[rowIndex0]) * 0.5f,
                nearVertexIndex0 = repeatIndex2,
                nearVertexIndex1 = repeatIndex0,
                nearVertexPos0 = vertices[rowIndex2],
                nearVertexPos1 = vertices[rowIndex0],
                oppositeVertexPos0 = vertices[rowIndex1],
            };
            
            newVertices[i] = newVertex0;
            newVertices[i + 1] = newVertex1;
            newVertices[i + 2] = newVertex2;
        }

        for (int i = 0; i < newVertices.Length; i++)
        {
            NewVertex src = newVertices[i];
            for (int j = 0; j < newVertices.Length; j++)
            {
                if (i == j) continue;
                
                NewVertex dst = newVertices[j];
                if (IsOnSameEdge(src, dst))
                {
                    src.oppositeVertexPos1 = dst.oppositeVertexPos0;
                }
            }
        }
        
        UpdateNewPos(newVertices);
    }
    static void UpdateNewPos(NewVertex[] newVertices)
    {
        for (int i = 0; i < newVertices.Length; i++)
        {
            NewVertex vertex = newVertices[i];
            vertex.position = 0.375f * (vertex.nearVertexPos0 + vertex.nearVertexPos1) + 0.125f * (vertex.oppositeVertexPos0 + vertex.oppositeVertexPos1);
        }   
    }
    static void ComputeVertexAndIndex(int[] indices, NewVertex[] newVertices, OldVertex[] oldVertices, out Vector3[] outVertices, out int[] outIndices)
    {
        int oldVertexCount = oldVertices.Length;
        outVertices = new Vector3[oldVertexCount + newVertices.Length];
        for (int i = 0; i < oldVertexCount; i++)
        {
            outVertices[i] = oldVertices[i].position;
        }
        for (int i = 0; i < newVertices.Length; i++)
        {
            outVertices[i + oldVertexCount] = newVertices[i].position;   
        }

        outIndices = new int[indices.Length * 4];
        int index = 0;
        for (int i = 0; i < indices.Length; i += 3)
        {
            int faceIndex = i / 3;
            int offset = faceIndex * 3;
            
            // 0 A C
            outIndices[index++] = indices[i];
            outIndices[index++] = oldVertexCount + offset;
            outIndices[index++] = oldVertexCount + offset + 2;
            
            // A 1 B
            outIndices[index++] = oldVertexCount + offset;
            outIndices[index++] = indices[i + 1];
            outIndices[index++] = oldVertexCount + offset + 1;
            
            // C B 2
            outIndices[index++] = oldVertexCount + offset + 2;
            outIndices[index++] = oldVertexCount + offset + 1;
            outIndices[index++] = indices[i + 2];
            
            // C A B
            outIndices[index++] = oldVertexCount + offset + 2;
            outIndices[index++] = oldVertexCount + offset;
            outIndices[index++] = oldVertexCount + offset + 1;
        }
    }
    static Mesh CreateMesh(Vector3[] vertices, int[] indices)
    {
        Mesh mesh = new();
        mesh.vertices = vertices;
        mesh.triangles = indices;
        return mesh;
    }
}
