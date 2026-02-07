using System.Collections.Generic;
using UnityEngine;

namespace Octree
{
    [System.Serializable]
    public class OctreeNode
    {
        public readonly List<GameObject> items; // 存储的元素
        public readonly OctreeNode[] kids; // 子节点
        public Vector3 center;
        public float size;
        public int depth;

        public OctreeNode(Vector3 center, float size, int depth)
        {
            this.items = new List<GameObject>();
            this.kids = new OctreeNode[8];
            this.center = center;
            this.size = size;
            this.depth = depth;
        }

        public OctreeNode(Vector3 center, float size, int depth, List<GameObject> items)
        {
            this.items = new List<GameObject>();
            this.kids = new OctreeNode[8];
            this.center = center;
            this.size = size;
            this.depth = depth;
            this.items = items;
        }

        // (-1, -1, -1) 0
        // ( 1, -1, -1) 1
        // (-1,  1, -1) 2
        // ( 1,  1, -1) 3
        // (-1, -1,  1) 4
        // ( 1, -1,  1) 5
        // (-1,  1,  1) 6
        // ( 1,  1,  1) 7
        public OctreeNode this[int x, int y, int z]
        {
            get
            {
                x = x == -1 ? 0 : 1;
                y = y == -1 ? 0 : 1;
                z = z == -1 ? 0 : 1;
                return kids[z * 2 * 2 + y * 2 + x];
            }
            set
            {
                x = x == -1 ? 0 : 1;
                y = y == -1 ? 0 : 1;
                z = z == -1 ? 0 : 1;
                kids[z * 2 * 2 + y * 2 + x] = value;
            }
        }

        public bool Contains(Vector3 point)
        {
            return Mathf.Abs(point.x - center.x) * 2 <= size &&
                   Mathf.Abs(point.y - center.y) * 2 <= size &&
                   Mathf.Abs(point.z - center.z) * 2 <= size;
        }

        public void Add(GameObject item)
        {
            items.Add(item);
        }

        public void Clear()
        {
            items.Clear();
        }

        public int Count()
        {
            return items.Count;
        }
    }
}