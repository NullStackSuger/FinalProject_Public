using System.Collections.Generic;
using Octree;
using UnityEngine;
using Random = UnityEngine.Random;

public class OctreeTest : MonoBehaviour
{
    // 生成物体数量
    public int objCount = 100;
    // 最大深度
    public int maxDepth = 3;
    public float radius = 50;

    public Color[] colors;

    public Transform checkPos;
    private OctreeNode checkNode;
    
    private readonly List<GameObject> objs = new();
    private OctreeNode root;
    
    private void OnEnable()
    {
        // 生成物体
        for (int i = 0; i < objCount; i++)
        {
            GameObject obj = GameObject.CreatePrimitive(PrimitiveType.Cube);
            obj.transform.parent = this.transform;
            obj.transform.position = new Vector3(Random.Range(-radius, radius), Random.Range(-radius, radius), Random.Range(-radius, radius));
            objs.Add(obj);
        }
        
        // 构建tree
        root = new OctreeNode(transform.position, radius * 2, maxDepth, objs);
        GenerateOctree(root, maxDepth);
    }
    private static void GenerateOctree(OctreeNode node, int depth)
    {
        if (depth <= 0) return;

        // 划分子节点范围
        float kidSize = node.size / 2.0f;
        float kidOffset = node.size / 4.0f;
        
        node[-1, -1, -1] = new OctreeNode(node.center + new Vector3(-1, -1, -1) * kidOffset, kidSize, depth - 1);
        node[ 1, -1, -1] = new OctreeNode(node.center + new Vector3( 1, -1, -1) * kidOffset, kidSize, depth - 1);
        node[-1,  1, -1] = new OctreeNode(node.center + new Vector3(-1,  1, -1) * kidOffset, kidSize, depth - 1);
        node[ 1,  1, -1] = new OctreeNode(node.center + new Vector3( 1,  1, -1) * kidOffset, kidSize, depth - 1);
        node[-1, -1,  1] = new OctreeNode(node.center + new Vector3(-1, -1,  1) * kidOffset, kidSize, depth - 1);
        node[ 1, -1,  1] = new OctreeNode(node.center + new Vector3( 1, -1,  1) * kidOffset, kidSize, depth - 1);
        node[-1,  1,  1] = new OctreeNode(node.center + new Vector3(-1,  1,  1) * kidOffset, kidSize, depth - 1);
        node[ 1,  1,  1] = new OctreeNode(node.center + new Vector3( 1,  1,  1) * kidOffset, kidSize, depth - 1);
        
        // 把obj赋值给子节点
        foreach (GameObject item in node.items)
        {
            if (node[-1, -1, -1].Contains(item.transform.position))
                node[-1, -1, -1].Add(item);
            else if (node[ 1, -1, -1].Contains(item.transform.position))
                node[ 1, -1, -1].Add(item);
            else if (node[-1,  1, -1].Contains(item.transform.position))
                node[-1,  1, -1].Add(item);
            else if (node[ 1,  1, -1].Contains(item.transform.position))
                node[ 1,  1, -1].Add(item);
            else if (node[-1, -1,  1].Contains(item.transform.position))
                node[-1, -1,  1].Add(item);
            else if (node[ 1, -1,  1].Contains(item.transform.position))
                node[ 1, -1,  1].Add(item);
            else if (node[-1,  1,  1].Contains(item.transform.position))
                node[-1,  1,  1].Add(item);
            else
                node[ 1,  1,  1].Add(item);
        }
        
        if (node[-1, -1, -1].Count() >= 2)
            GenerateOctree(node[-1, -1, -1], depth - 1);
        if (node[ 1, -1, -1].Count() >= 2)
            GenerateOctree(node[ 1, -1, -1], depth - 1);
        if (node[-1,  1, -1].Count() >= 2)
            GenerateOctree(node[-1,  1, -1], depth - 1);
        if (node[ 1,  1, -1].Count() >= 2)
            GenerateOctree(node[ 1,  1, -1], depth - 1);
        if (node[-1, -1,  1].Count() >= 2)
            GenerateOctree(node[-1, -1,  1], depth - 1);
        if (node[ 1, -1,  1].Count() >= 2)
            GenerateOctree(node[ 1, -1,  1], depth - 1);
        if (node[-1,  1,  1].Count() >= 2)
            GenerateOctree(node[-1,  1,  1], depth - 1);
        if (node[ 1,  1,  1].Count() >= 2)
            GenerateOctree(node[ 1,  1,  1], depth - 1);
    }

    private void Update()
    {
        if (checkPos == null) return;
        
        Vector3 pos = checkPos.position;
        if (root.Contains(pos))
        {
            var node = QueryOctree(pos, root);
            if (node != null) checkNode = node;
        }
        else
        {
            checkNode = null;
        }
    }
    private static OctreeNode QueryOctree(Vector3 pos, OctreeNode node)
    {
        if (node[-1, -1, -1]?.Contains(pos) ?? false) return QueryOctree(pos, node[-1, -1, -1]);
        if (node[ 1, -1, -1]?.Contains(pos) ?? false) return QueryOctree(pos, node[ 1, -1, -1]);
        if (node[-1,  1, -1]?.Contains(pos) ?? false) return QueryOctree(pos, node[-1,  1, -1]);
        if (node[ 1,  1, -1]?.Contains(pos) ?? false) return QueryOctree(pos, node[ 1,  1, -1]);
        if (node[-1, -1,  1]?.Contains(pos) ?? false) return QueryOctree(pos, node[-1, -1,  1]);
        if (node[ 1, -1,  1]?.Contains(pos) ?? false) return QueryOctree(pos, node[ 1, -1,  1]);
        if (node[-1,  1,  1]?.Contains(pos) ?? false) return QueryOctree(pos, node[-1,  1,  1]);
        if (node[ 1,  1,  1]?.Contains(pos) ?? false) return QueryOctree(pos, node[ 1,  1,  1]);
        return node;
    }

    private void OnDrawGizmos()
    {
        if (root == null) return;
        
        Queue<OctreeNode> queue = new();
        queue.Enqueue(root);
        while (queue.Count != 0)
        {
            OctreeNode node = queue.Dequeue();
            foreach (OctreeNode kid in node.kids)
            {
                if (kid == null) continue;
                queue.Enqueue(kid);
            }

            if (node.Count() == 1)
            {
                Gizmos.color = colors[node.depth];
                Gizmos.DrawWireCube(node.center, Vector3.one * node.size);   
            }
        }
        
        if (checkNode == null) return;

        Gizmos.color = Color.black;
        Gizmos.DrawWireCube(checkNode.center, Vector3.one * checkNode.size);   
    }
}