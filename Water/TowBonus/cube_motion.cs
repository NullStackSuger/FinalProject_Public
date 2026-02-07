using UnityEngine;

public class cube_motion : MonoBehaviour
{
	private const float g = -9.8f;
	
	private new Collider collider;
	
	[HideInInspector]
	public Vector3 Flotage; // 浮力
	[HideInInspector]
	public Vector3 Torque; // 扭矩力
	private Vector3 v;
	private Vector3 w;
	
	public float mass = 1;
	public float dt = 0.01f;
	
	private Matrix4x4 Inertia;
	
	private bool pressed;
	private bool moved;
	private Vector3 moveOffset;
	
	void Start()
    {
	    collider = GetComponent<Collider>();

	    float ix = (mass * collider.bounds.size.x * collider.bounds.size.x) / 12;
	    float iy = (mass * collider.bounds.size.y * collider.bounds.size.y) / 12;
	    float iz = (mass * collider.bounds.size.z * collider.bounds.size.z) / 12;
	    Inertia = Matrix4x4.identity;
	    Inertia[0, 0] = ix;
	    Inertia[1, 1] = iy;
	    Inertia[2, 2] = iz;
	}
	
	Quaternion Add(Quaternion a, Quaternion b)
	{
		Quaternion q = new Quaternion(a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w);
		return q;
	}

	void Simulation()
    {
	    Vector3 force = Vector3.zero;
	    force.y += mass * g; // 重力
	    force.y += Flotage.y; // 浮力
	    v += force * dt;
	    v *= 0.99f; // 阻力
	    transform.position += v * dt;

	    Matrix4x4 R = Matrix4x4.Rotate(transform.rotation);
	    Matrix4x4 I = R * Inertia * R.transpose;
	    Vector3 dw = dt * I.inverse.MultiplyPoint(Torque);
	    w += dw;
	    w *= 0.99f;
	    Quaternion currentQ = transform.rotation;
	    float dt2 = dt / 2;
	    Quaternion tmpQ = new Quaternion(w.x * dt2, w.y * dt2, w.z * dt2, 0);
	    transform.rotation = Quaternion.Normalize(Add(currentQ, tmpQ * currentQ));

	}
	
	void Update () 
	{
		Simulation();

		if (Input.GetMouseButtonDown(0))
		{
			pressed = true;
			Ray ray = Camera.main!.ScreenPointToRay(Input.mousePosition);
			moved = Vector3.Cross(ray.direction, transform.position - ray.origin).magnitude < 0.8f;
			moveOffset = Input.mousePosition - Camera.main.WorldToScreenPoint(transform.position);
		}
		if (Input.GetMouseButtonUp(0))
		{
			pressed = false;
			moved = false;
		}

		if (pressed && moved)
		{
			Vector3 mouse = Input.mousePosition;
			mouse -= moveOffset; // moveOffset是按下那刻的, 而鼠标会一直移动不抬起
			mouse.z = Camera.main!.WorldToScreenPoint(transform.position).z;
			Vector3 p = Camera.main.ScreenToWorldPoint(mouse);
			p.y = transform.position.y;
			transform.position = p;
		}
	}
}