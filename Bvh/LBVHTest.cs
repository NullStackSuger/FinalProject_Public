using System.Collections.Generic;
using LBVH;
using UnityEngine;

public class LBVHTest : MonoBehaviour
{
    public Mesh mesh;

    private List<AABB> aabbs;
    private RadixTreeSpace space;

    private RadixTreeNode[] nodes;
    
    private void OnEnable()
    {
        aabbs = new List<AABB>();
        
        // 1.为每个元素计算AABB
        var triangles = Triangle.Build(mesh);
        foreach (Triangle triangle in triangles)
        {
            aabbs.Add(triangle.aabb);
        }

        // 2.初始化Node,计算莫顿码
        var leafs = RadixTreeNode.Build(aabbs, mesh.bounds);
        // 3.按莫顿码排序
        space = new RadixTreeSpace(leafs);
        space.Sort();
        // 4.看不懂
        nodes = space.Build();
        RadixTreeSpace.Build(nodes, space.leafs);
    }

    private void OnDrawGizmos()
    {
        if (nodes == null) return;
        foreach (var node in nodes)
        {
            var aabb = node.aabb;
            Gizmos.DrawWireCube(aabb.center, aabb.size);
        }
    }
}