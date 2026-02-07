using UnityEngine;

[ExecuteInEditMode]
public class Player : MonoBehaviour
{
    [SerializeField]
    private Material grassMat;
    
    [SerializeField]
    private Transform footPoint;
    
    [SerializeField]
    private float _PlayerStrength = 0.3f;

    [SerializeField] 
    private float _PlayerRadius = 0.5f;
    
    private void Update()
    {
        grassMat.SetVector("_PlayerPos", (footPoint ?? transform).position);
        grassMat.SetFloat("_PlayerStrength", _PlayerStrength);
        grassMat.SetFloat("_PlayerRadius", _PlayerRadius);
    }
}