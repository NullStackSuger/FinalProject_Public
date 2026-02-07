using System.Collections.Generic;
using UnityEngine;

namespace BVH
{
    public struct AABB
    {
        public Vector3 min;
        public Vector3 max;

        public AABB(Vector3 min, Vector3 max)
        {
            this.min = min;
            this.max = max;
        }

        public Vector3 size => max - min;
        public Vector3 center => (max + min) / 2f;
        public float surface => (size.x * size.y + size.x * size.z + size.y * size.z) * 2.0f;

        public static AABB Default()
        {
            return new AABB(Vector3.one * float.MaxValue, Vector3.one * float.MinValue);
        }

        public static AABB WorldAABB(GameObject obj)
        {
            var meshFilter = obj.GetComponent<MeshFilter>();
            Vector3 localMin = meshFilter.sharedMesh.bounds.min;
            Vector3 localMax = meshFilter.sharedMesh.bounds.max;
            Vector3 worldMin = obj.transform.TransformPoint(localMin);
            Vector3 worldMax = obj.transform.TransformPoint(localMax);
            return new AABB(worldMin, worldMax);
        }

        public AABB Union(AABB aabb)
        {
            min.x = Mathf.Min(min.x, aabb.min.x);
            min.y = Mathf.Min(min.y, aabb.min.y);
            min.z = Mathf.Min(min.z, aabb.min.z);

            max.x = Mathf.Max(max.x, aabb.max.x);
            max.y = Mathf.Max(max.y, aabb.max.y);
            max.z = Mathf.Max(max.z, aabb.max.z);

            return new AABB(min, max);
        }
    }

    public class BvhNode
    {
        public BvhNode left, right;
        public BvhNode parent;
        public GameObject item;
        public AABB aabb;

        public Color color;

        public BvhNode(GameObject item, Color color)
        {
            this.item = item;
            this.color = color;

            this.aabb = AABB.Default();
            if (item == null) return;
            this.aabb.Union(AABB.WorldAABB(item));
        }

        public BvhNode(BvhNode source)
        {
            this.item = source.item;
            this.aabb = source.aabb;
            this.left = source.left;
            this.right = source.right;
            this.color = source.color;
        }

        public bool IsLeaf()
        {
            return item != null;
        }

        public void SetLeaf(BvhNode left, BvhNode right)
        {
            this.left = left;
            if (left != null)
            {
                left.parent = this;
            }

            this.right = right;
            if (right != null)
            {
                right.parent = this;
            }

            this.item = null;
        }

        // 获取兄弟节点
        public BvhNode GetSibling()
        {
            return parent?.GetTheOtherNode(this);
        }

        //获取另一个节点
        public BvhNode GetTheOtherNode(BvhNode node)
        {
            if (this.left == node) return this.right;
            if (this.right == node) return this.left;
            return null;
        }

        public BvhNode Root()
        {
            if (parent != null)
            {
                return parent.Root();
            }

            return this;
        }

        public bool Contains(BvhNode node)
        {
            return left == node || right == node;
        }

        public void BroadCast()
        {
            if (parent != null)
            {
                parent.UpdateAABB();
                parent.BroadCast();
            }
        }

        public void UpdateAABB()
        {
            aabb = AABB.Default();
            if (left != null)
            {
                aabb.Union(left.aabb);
            }

            if (right != null)
            {
                aabb.Union(right.aabb);
            }
        }

        // 合并2个节点
        public static BvhNode Combine(BvhNode target, BvhNode insert)
        {
            var newNode = new BvhNode(target);
            target.aabb.Union(insert.aabb);
            target.BroadCast();
            target.SetLeaf(newNode, insert);
            return newNode;
        }

        // 分离一个节点
        public static BvhNode Separate(BvhNode node)
        {
            BvhNode parent = node.parent;
            if (parent != null && parent.Contains(node))
            {
                var siblingNode = node.GetSibling();
                var siblingAABB = siblingNode.aabb;
                parent.SetLeaf(siblingNode.left, siblingNode.right);
                parent.aabb = siblingAABB;
                parent.BroadCast();
                parent.item = siblingNode.item;
                return parent;
            }
            else
            {
                Debug.LogError("分离节点失败，目标节点父级为null或者父级不含有目标节点");
                return null;
            }
        }
    }

    public class DynamicBvhSpace
    {
        public BvhNode root;
        private readonly List<BvhNode> leafs; // 所有叶子节点
        public readonly Dictionary<GameObject, BvhNode> item2Node;

        public DynamicBvhSpace()
        {
            leafs = new();
            item2Node = new();
        }

        public void Update(GameObject item)
        {
            // 物体移动
            if (Remove(item))
            {
                Add(item);
            }
        }

        public void Update(BvhNode node)
        {
            GameObject item = node.item;
            if (item != null)
            {
                item2Node[item] = node;
            }
        }

        public BvhNode Add(GameObject item)
        {
            BvhNode leaf = new BvhNode(item, Color.red);
            Update(leaf);
            Build(leaf);
            return leaf;
        }

        public bool Remove(GameObject item)
        {
            if (!item2Node.TryGetValue(item, out BvhNode node))
                return false;

            leafs.Remove(node);
            leafs.Remove(node.GetSibling());
            BvhNode subTree = BvhNode.Separate(node);
            if (subTree.IsLeaf())
            {
                leafs.Add(subTree);
                Update(subTree);
            }

            return true;
        }

        public void Build(BvhNode node)
        {
            if (root == null)
            {
                root = node;
                leafs.Add(node);
                return;
            }

            BvhNode target = SAH(node);
            if (target == null)
            {
                Debug.LogError("SAH 未找到合适的node");
                return;
            }

            leafs.Remove(target);
            BvhNode newNode = BvhNode.Combine(target, node);
            leafs.Add(node);
            leafs.Add(newNode);
            Update(newNode);
            root = newNode.Root();
        }

        private BvhNode SAH(BvhNode newLeaf)
        {
            //return leafs.Count == 0 ? null : leafs[0];

            float minCost = float.MaxValue;
            BvhNode minCostNode = null;

            foreach (BvhNode leaf in leafs)
            {
                // 把新节点与其他所有节点结合,计算surface增量
                AABB aabb = leaf.aabb; // 文章里这里似乎有问题, 不去拷贝一份aabb直接去改, 会导致SAH找到的子节点的包围盒和父节点一样大
                var newBranchAABB = aabb.Union(newLeaf.aabb);
                float deltaCost = newBranchAABB.surface;
                float wholeCost = deltaCost;

                // 统计所有祖先节点的表面积差
                BvhNode parent = leaf.parent;
                while (parent != null)
                {
                    float s2 = parent.aabb.surface;
                    var unionAABB = parent.aabb.Union(newLeaf.aabb);
                    float s3 = unionAABB.surface;
                    deltaCost = s3 - s2;
                    wholeCost += deltaCost;
                    parent = parent.parent;
                }

                //返回最小的目标
                if (wholeCost < minCost)
                {
                    minCostNode = leaf;
                    minCost = wholeCost;
                }
            }

            return minCostNode;
        }
    }
}