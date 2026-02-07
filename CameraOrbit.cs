using UnityEngine;

public class CameraOrbit : MonoBehaviour
{
    public Transform target;      // 被绕的目标
    public float rotateSpeed = 30f; // 角速度（度/秒）
    public Vector3 offset = new Vector3(0, 2, -5);

    void LateUpdate()
    {
        if (target == null) return;

        // 围绕目标的世界 Y 轴旋转
        transform.RotateAround(
            target.position,
            Vector3.up,
            rotateSpeed * Time.deltaTime
        );

        // 始终看向目标
        transform.LookAt(target.position);
    }
}