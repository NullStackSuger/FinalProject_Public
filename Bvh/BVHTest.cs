using System.Collections.Generic;
using BVH;
using UnityEngine;
using Random = UnityEngine.Random;

public class BVHTest : MonoBehaviour
{
    public GameObject removedObj;
    
    private DynamicBvhSpace space;

    private void OnEnable()
    {
        space = new DynamicBvhSpace();
    }

    private void Update()
    {
        if (Input.GetKeyDown(KeyCode.A))
        {
            GameObject obj = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            obj.transform.parent = transform;
            Vector3 randomPos = Random.insideUnitSphere * 10;
            obj.transform.position = randomPos;
            if (space.root != null)
            {
                
            }
            space.Add(obj);
        }

        if (Input.GetKeyDown(KeyCode.S))
        {
            if (removedObj != null)
            {
                space.Remove(removedObj);
                Destroy(removedObj);
            }
        }

        /*if (removedObj != null)
        {
            space.Update(removedObj);
        }*/
    }

    private void OnDrawGizmos()
    {
        if (space == null || space.root == null) return;

        Queue<BvhNode> queue = new();
        queue.Enqueue(space.root);
        while (queue.Count != 0)
        {
            BvhNode node = queue.Dequeue();
            if (node.left != null) queue.Enqueue(node.left);
            if (node.right != null) queue.Enqueue(node.right);

            Gizmos.color = Color.red;
            Gizmos.DrawWireCube(node.aabb.center, node.aabb.size);
            Gizmos.color = Color.green;
            Gizmos.DrawSphere(node.aabb.min, 0.1f);
            Gizmos.DrawSphere(node.aabb.max, 0.1f);
        }
    }
}