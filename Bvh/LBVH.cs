using System.Collections.Generic;
using UnityEngine;

namespace LBVH
{
    public static class MortonCoder
    {
        // 把center缩放到[0, 1]
        public static Vector3 Normalize(Vector3 center, Bounds bounds)
        {
            Vector3 min = bounds.min;
            Vector3 max = bounds.max;
            float x = (center.x - min.x) / (max.x - min.x);
            float y = (center.y - min.y) / (max.y - min.y);
            float z = (center.z - min.z) / (max.z - min.z);
            return new Vector3(x, y, z);
        }
        private static int ExpandBits(long v)
        {
            v = (v * 0x00010001u) & 0xFF0000FFu;
            v = (v * 0x00000101u) & 0x0F00F00Fu;
            v = (v * 0x00000011u) & 0xC30C30C3u;
            v = (v * 0x00000005u) & 0x49249249u;
            return (int)v;
        }
        // value ∈ [0, 1]
        // result ∈ [0, 1023]
        public static int Morton3D(Vector3 value)
        {
            var x = Mathf.Min(Mathf.Max(value.x * 1024.0f, 0.0f), 1023.0f);
            var y = Mathf.Min(Mathf.Max(value.y * 1024.0f, 0.0f), 1023.0f);
            var z = Mathf.Min(Mathf.Max(value.z * 1024.0f, 0.0f), 1023.0f);
            int xx = ExpandBits((int)x);
            int yy = ExpandBits((int)y);
            int zz = ExpandBits((int)z);
            return xx * 4 + yy * 2 + zz;
        }
    }
    
    public struct AABB
    {
        public Vector3 min;
        public Vector3 max;

        public Vector3 center => (min + max) * 0.5f;
        public Vector3 size => max - min;
        
        public static AABB Default => new AABB() { min = Vector3.one * float.MaxValue, max = Vector3.one * float.MinValue };

        public AABB Union(Vector3 minCorner, Vector3 maxCorner)
        {
            float minX = Mathf.Min(min.x, minCorner.x);
            float minY = Mathf.Min(min.y, minCorner.y);
            float minZ = Mathf.Min(min.z, minCorner.z);
            float maxX = Mathf.Max(max.x, maxCorner.x);
            float maxY = Mathf.Max(max.y, maxCorner.y);
            float maxZ = Mathf.Max(max.z, maxCorner.z);
            return new AABB()
            {
                min = new Vector3(minX, minY, minZ),
                max = new Vector3(maxX, maxY, maxZ)
            };
        }
    }

    public struct Triangle
    {
        public Vector3 v0, v1, v2;

        public AABB aabb
        {
            get
            {
                Vector3 minCorner = Vector3.one * float.MaxValue;
                Vector3 maxCorner = Vector3.one * float.MinValue;
                minCorner.x = Mathf.Min(minCorner.x, v0.x, v1.x, v2.x);
                minCorner.y = Mathf.Min(minCorner.y, v0.y, v1.y, v2.y);
                minCorner.z = Mathf.Min(minCorner.z, v0.z, v1.z, v2.z);
                maxCorner.x = Mathf.Max(maxCorner.x, v0.x, v1.x, v2.x);
                maxCorner.y = Mathf.Max(maxCorner.y, v0.y, v1.y, v2.y);
                maxCorner.z = Mathf.Max(maxCorner.z, v0.z, v1.z, v2.z);
                return new AABB() { min = minCorner, max = maxCorner };
            }
        }
        
        public static List<Triangle> Build(Mesh mesh)
        {
            List<Triangle> list = new();
            int[] indices = mesh.triangles;
            Vector3[] vertices = mesh.vertices;
            var faceCount = indices.Length / 3;
            for (int i = 0; i < faceCount; i++)
            {
                Vector3 v0 = vertices[indices[i * 3]];
                Vector3 v1 = vertices[indices[i * 3 + 1]];
                Vector3 v2 = vertices[indices[i * 3 + 2]];
                list.Add(new Triangle() { v0 = v0, v1 = v1, v2 = v2 });
            }
            return list;
        }
    }

    public struct RadixTreeNode
    {
        public int parentIndex;
        public int nodeIndex;
        public int leftIndex;
        public int rightIndex;
        public int mortonCode;
        public AABB aabb;

        public override string ToString()
        {
            int code = mortonCode;
            string res = "";
            int count = 0;
            for (int i = 31; i >= 0; --i)
            {
                int bit = (code >> i) & 0b01;
                res += bit.ToString();
                ++count;
                if (count > 7)
                {
                    count = 0;
                    res += " ";
                }
            }
            return res;
        }

        public static RadixTreeNode Default => new RadixTreeNode()
        {
            parentIndex = -1,
            nodeIndex = -1,
            leftIndex = -1,
            rightIndex = -1,
            mortonCode = 0,
            aabb = AABB.Default
        };
        
        public static List<RadixTreeNode> Build(List<AABB> aabbs, Bounds bounds)
        {
            List<RadixTreeNode> leafs = new();
            for (int i = 0; i < aabbs.Count; i++)
            {
                AABB aabb = aabbs[i];
                Vector3 center = MortonCoder.Normalize(aabb.center, bounds);
                int code = MortonCoder.Morton3D(center);
                RadixTreeNode node = new RadixTreeNode()
                {
                    parentIndex = -1,
                    nodeIndex = i,
                    leftIndex = -1,
                    rightIndex = -1,
                    mortonCode = code,
                    aabb = aabb,
                };
                leafs.Add(node);
            }
            return leafs;
        }
    }

    public class RadixTreeSpace
    {
        public List<RadixTreeNode> leafs;

        public RadixTreeSpace(List<RadixTreeNode> leafs)
        {
            this.leafs = leafs;
        }

        public void Sort()
        {
            // 666 冒泡
            int count = leafs.Count;
            for (int i = 0; i < count; i++)
            for (int j = 0; j < count; j++)
                if (leafs[i].mortonCode > leafs[j].mortonCode)
                {
                    (leafs[i], leafs[j]) = (leafs[j], leafs[i]);
                }
        }

        public RadixTreeNode[] Build()
        {
            int count = leafs.Count;
            RadixTreeNode[] nodes = new RadixTreeNode[count - 1];
            for (int i = 0; i < nodes.Length; i++)
            {
                RadixTreeNode node = RadixTreeNode.Default;
                node.nodeIndex = i;
                nodes[i] = node;
            }
            
            for (int i = 0; i < nodes.Length; i++)
            {
                var simRight = Sigma(i, i + 1);
                var simLeft = Sigma(i, i - 1);
                var direction = (int)Sign(simRight - simLeft);
                var sigmaMin = Sigma(i, i - direction); // 用于判断相似程度
                var l_max = 2;
                while (Sigma(i, i + l_max * direction) > sigmaMin)
                {
                    l_max = l_max * 2;
                }
                var l = 0;
                for (int t = l_max; t >= 1; t /= 2)
                {
                    if (Sigma(i, i + (l + t) * direction) > sigmaMin)
                    {
                        l = l + t;
                    }
                }
                var j = i + l * direction;
                var sigmaNode = Sigma(i, j);
                var s = 0;
                var init = Mathf.CeilToInt(l / 2.0f);
                for (int t = init; t >= 1;)
                {
                    if (Sigma(i, i + (s + t) * direction) > sigmaNode)
                    {
                        s = s + t;
                    }

                    if (t == 1)
                    {
                        break;
                    }

                    t = Mathf.CeilToInt(t / 2.0f);
                }
                var gamma = i + s * direction + Mathf.Min(direction, 0);
                RadixTreeNode left;
                RadixTreeNode right;
                if (Mathf.Min(i, j) == gamma)
                {
                    left = leafs[gamma];

                    //这里为了区分index是内部节点还是叶子节点，做了一个偏移
                    left.nodeIndex += count - 1;
                    left.parentIndex = i;

                    leafs[gamma] = left;
                }
                else
                {
                    left = nodes[gamma];
                    nodes[gamma].parentIndex = i;
                }

                if (Mathf.Max(i, j) == gamma + 1)
                {
                    right = leafs[gamma + 1];

                    //这里为了区分index是内部节点还是叶子节点，做了一个偏移
                    right.nodeIndex += count - 1;
                    right.parentIndex = i;

                    leafs[gamma + 1] = right;
                }
                else
                {
                    right = nodes[gamma + 1];
                    nodes[gamma + 1].parentIndex = i;
                }

                nodes[i].nodeIndex = i;
                nodes[i].leftIndex = left.nodeIndex;
                nodes[i].rightIndex = right.nodeIndex;
            }
            return nodes;
        }
        // 计算前导0个数
        private int ComputeLeadingZeros(int value)
        {
            var count = 0;
            for (int i = 31; i >= 0; i--)
            {
                if ((value >> i & 0b01) == 0)
                {
                    count++;
                }
                else
                {
                    return count;
                }
            }

            return count;
        }
        // 计算前缀相同长度
        private int Sigma(int i, int j)
        {
            if (j < 0 || j > leafs.Count - 1) return -1;
            var a = leafs[i].mortonCode;
            var b = leafs[j].mortonCode;
            var xor = a ^ b;
            var count = ComputeLeadingZeros(xor);
            return count;
        }
        // 确定搜索方向
        // 会 Sign(sigmaA - sigmaB), 判断哪边前缀相同长度长
        private float Sign(float value)
        {
            return value / Mathf.Abs(value);
        }

        public static void Build(RadixTreeNode[] nodes, List<RadixTreeNode> leafs)
        {
            // 向上传播更新父节点AABB
            
            int[] visitCounts = new int[nodes.Length];

            foreach (var leaf in leafs)
            {
                var parentIndex = leaf.parentIndex;
                var min = leaf.aabb.min;
                var max = leaf.aabb.max;

                while (parentIndex != -1) // 不是根节点
                {
                    ref var node = ref nodes[parentIndex];
                    
                    // 更新父节点AABB
                    var aabb = node.aabb;
                    node.aabb = aabb.Union(min, max);

                    // 父节点有2个子节点, 只有2个子节点都更新完父节点AABB才能继续传播, 不然遇到一个子节点就向上传播效率太低
                    var visitCount = visitCounts[parentIndex];
                    if (visitCount == 0)
                    {
                        ++visitCounts[parentIndex];
                        break;
                    }
                    
                    parentIndex = node.parentIndex;
                    min = node.aabb.min;
                    max = node.aabb.max;
                }
            }
        }
    }
}
