using UnityEngine;

namespace MarchingCube.Demo
{
    
    [RequireComponent(typeof(Rigidbody))]
    public class FlyingCameraRigidBody : MonoBehaviour
    {
        private Rigidbody rb;

        [Header("The camera movement speed (in meters per second).")]
        public float movementSpeed = 20f;

        [Header("The camera rotation speed (in degrees per second).")]
        public float lookSpeed = 500f;

        private float pitch = 0f;
        private float yaw = 0f;

        // Start is called before the first frame update
        void Start()
        {
            rb = GetComponent<Rigidbody>();
            Cursor.lockState = CursorLockMode.Locked;
            pitch = transform.rotation.eulerAngles.x;
            yaw = transform.rotation.eulerAngles.y;
        }

        // Update is called once per frame
        void Update()
        {
            pitch -= Input.GetAxis("Mouse Y") * lookSpeed * Time.deltaTime;
            pitch = Mathf.Clamp(pitch, -90f, 90f);
            yaw += Input.GetAxis("Mouse X") * lookSpeed * Time.deltaTime;
            transform.rotation = Quaternion.Euler(pitch, yaw, 0f);

            float upDownAxis = Input.GetKey(KeyCode.Space) ? 1f : 0f;
            upDownAxis += Input.GetKey(KeyCode.LeftShift) ? -1f : 0f;
            rb.MovePosition(transform.position
                            + transform.forward * Input.GetAxis("Vertical") * movementSpeed * Time.deltaTime
                            + transform.right * Input.GetAxis("Horizontal") * movementSpeed * Time.deltaTime
                            + transform.up * upDownAxis * movementSpeed * Time.deltaTime);      
        }
    }
}
