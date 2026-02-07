using UnityEngine;

public class wave_motion : MonoBehaviour
{
	private const float g = 9.8f;
	private const float rho = 0.01f; // 密度
	public int size = 100;
	public float rate = 0.005f;
	public float gamma = 0.004f;
	public float damping = 0.996f;
	
	private block_motion blockMotion;
	private Collider blockCollider;
	private cube_motion cubeMotion;
	private Collider cubeCollider;
	private Mesh waveMesh;
	
	float[,] 	oldH;
	float[,]	underH;
	bool [,]	mask;
	
	float[,]	x;
	float[,]	b;
	float[,]	p;
	float[,]	rk;
	float[,]	ap;
	
	void Start() 
	{
		GameObject cube = GameObject.Find("Cube");
		cubeCollider = cube.GetComponent<Collider>();
		cubeMotion = cube.GetComponent<cube_motion>();
		GameObject block = GameObject.Find("Block");
		blockCollider = block.GetComponent<Collider>();
		blockMotion = block.GetComponent<block_motion>();
		waveMesh = GetComponent<MeshFilter>().mesh;
		waveMesh.Clear();

		Vector3[] X=new Vector3[size*size];
		for (int i = 0; i < size; i++)
		for (int j = 0; j < size; j++) 
		{
			X[i * size + j].x = i * 0.1f - size * 0.05f;
			X[i * size + j].y = 0;
			X[i * size + j].z = j * 0.1f - size * 0.05f;
		}
		int[] T = new int[(size - 1) * (size - 1) * 6];
		int index = 0;
		for (int i = 0; i < size - 1; i++)
		for (int j = 0; j < size - 1; j++)
		{
			T[index * 6 + 0] = (i + 0) * size + j + 0;
			T[index * 6 + 1] = (i + 0) * size + j + 1;
			T[index * 6 + 2] = (i + 1) * size + j + 1;
			T[index * 6 + 3] = (i + 0) * size + j + 0;
			T[index * 6 + 4] = (i + 1) * size + j + 1;
			T[index * 6 + 5] = (i + 1) * size + j + 0;
			index++;
		}
		waveMesh.vertices  = X;
		waveMesh.triangles = T;
		waveMesh.RecalculateNormals();

		underH  = new float[size, size];
		oldH 	= new float[size,size];
		mask	= new bool [size,size];
		x 	  	= new float[size,size];
		b 	  	= new float[size,size];
		p 	= new float[size,size];
		rk 	= new float[size,size];
		ap 	= new float[size,size];
	}

	void UpdateMask(Collider collider, ref bool[,] mask, out int l, out int r, out int d, out int t)
	{
		Vector3[] X = waveMesh.vertices;
		Vector3 min = collider.bounds.min;
		Vector3 max = collider.bounds.max;

		l = r = d = t = 0;
		
		if(min.y < 0)
		{
			r = size - 1; t = size - 1;
			l = 0; d = 0;
			for (int k = 0; k < size * size; k++)
			{
				if (min.x < X[k].x && X[k].x < max.x && min.z < X[k].z && X[k].z < max.z)
				{
					int i = k / size;
					int j = k % size;
					mask[i, j] = true;

					if (i < r) r = i;
					if (i > l) l = i;
					if (j < t) t = j;
					if (j > d) d = j;
				}
			}
			for (int i = r; i <= l; i++)
			{
				for (int j = t; j <= d; j++)
				{
					// 从-2向-3看
					Ray ray = new Ray(new Vector3(X[i * size + j].x, -2, X[i * size + j].z), new Vector3(0, 1, 0));
					if (Physics.Raycast(ray, out var hit))
					{
						if (hit.collider != null)
						{
							underH[i, j] = hit.point.y;
						}
					}
				}
			}
		} 
	}
	
	void AX(bool[,] mask, float[,] x, float[,] Ax, int l, int r, int d, int t)
	{
		for(int i = r; i <= l; i++)
		for(int j = t; j <= d; j++)
			if(0 <= i && i < size && 0 <= j && j < size && mask[i,j])
			{
				Ax[i,j]=0;
				if(i!=0)		Ax[i,j]-=x[i-1,j]-x[i,j];
				if(i!=size-1)	Ax[i,j]-=x[i+1,j]-x[i,j];
				if(j!=0)		Ax[i,j]-=x[i,j-1]-x[i,j];
				if(j!=size-1)	Ax[i,j]-=x[i,j+1]-x[i,j];
			}
	}

	float Dot(bool[,] mask, float[,] x, float[,] y, int l, int r, int d, int t)
	{
		float ret=0;
		for(int i = r; i <= l; i++)
		for(int j = t; j <= d; j++)
			if(0 <= i && i < size && 0 <= j && j < size && mask[i,j])
			{
				ret+=x[i,j]*y[i,j];
			}
		return ret;
	}

	void Conjugate_Gradient(bool[,] mask, float[,] b, float[,] x, int l, int r, int d, int t)
	{
		// P0 = r0 = b - A * x0
		// ak = dot(rk, rk) / dot(A * Pk, Pk)
		// Xk+1 = Xk + ak * Pk
		// rk+1 = rk - ak * A * Pk
		// bk = dot(rk+1, rk+1) / dot(rk, rk)
		// Pk+1 = rk+1 + bk * Pk
		
		
		
		AX(mask, x, rk, l, r, d, t);

		for(int i = r; i <= l; i++)
		for(int j = t; j <= d; j++)
			if(0 <= i && i < size && 0 <= j && j < size && mask[i,j])
				p[i,j] = rk[i,j] = b[i,j] - rk[i,j];

		float dotRk = Dot(mask, rk, rk, l, r, d, t);

		for(int k = 0; k < 128; k++)
		{
			if(dotRk < 1e-10f)	break;
			AX(mask, p, ap, l, r, d, t);
			float alpha = dotRk / Dot(mask, p, ap, l, r, d, t);

			for(int i = r; i <= l; i++)
			for(int j = t; j <= d; j++)
				if(0 <= i && i < size && 0 <= j && j < size && mask[i,j])
				{
					x[i,j] += alpha * p[i,j];
					rk[i,j] -=alpha * ap[i,j];
				}

			float dotRk1 = Dot(mask, rk, rk, l, r, d, t);
			float beta = dotRk1 / dotRk;
			dotRk = dotRk1;

			for(int i = r; i <= l; i++)
			for(int j = t; j <= d; j++)
				if(0 <= i && i < size && 0 <= j && j < size && mask[i,j])
					p[i,j] = rk[i,j] + beta * p[i,j];
		}
	}
	
	void Shallow_Wave(float[,] oldH, float[,] curH, float [,] newH)
	{
        for (int i = 0; i < size; i++)
        {
            for (int j = 0; j < size; j++)
            {
				newH[i,j] = curH[i, j] + damping * (curH[i,j]- oldH[i,j]);

                if (i - 1 >= 0)		newH[i, j] += rate * (curH[i - 1, j] - curH[i, j]);
				if (i + 1 < size)	newH[i, j] += rate * (curH[i + 1, j] - curH[i, j]);
				if (j - 1 >= 0)		newH[i, j] += rate * (curH[i, j - 1] - curH[i, j]);
				if (j + 1 < size)	newH[i, j] += rate * (curH[i, j + 1] - curH[i, j]);
			}
        }
		
		UpdateMask(cubeCollider, ref mask, out int cubeL, out int cubeR, out int cubeD, out int cubeT);
		UpdateMask(blockCollider, ref mask, out int blockL, out int blockR, out int blockD, out int blockT);

		for (int i = 0; i < size; i++)
		for (int j = 0; j < size; j++)
			if (mask[i, j]) 
				b[i, j] = (newH[i, j] - underH[i, j]) / rate;

		Conjugate_Gradient(mask, b, x, cubeL, cubeR, cubeD, cubeT);
		Conjugate_Gradient(mask, b, x, blockL, blockR, blockD, blockT);
		
		for (int i = 0; i < size; i++)
		{
			for (int j = 0; j < size; j++)
			{
				if (i - 1 >= 0) newH[i, j] += gamma * rate * (x[i - 1, j] - x[i, j]);
				if (i + 1 < size) newH[i, j] += gamma * rate * (x[i + 1, j] - x[i, j]);
				if (j - 1 >= 0) newH[i, j] += gamma * rate * (x[i, j - 1] - x[i, j]);
				if (j + 1 < size) newH[i, j] += gamma * rate * (x[i, j + 1] - x[i, j]);
			}
		}
		
		Vector3[] X = waveMesh.vertices;
		Vector3 cubeFlotage = new Vector3();
		Vector3 cubeTorque = new Vector3();
		for (int i = cubeR; i <= cubeL; i++)
		{
			for (int j = cubeT; j <= cubeD; j++)
			{
				Vector3 f = new Vector3(0, rho * 0.01f * x[i, j] * g, 0);
				cubeFlotage += f ;

				Vector3 hitPoint = new Vector3(X[i * size + j].x, underH[i,j], X[i * size + j].z);
				Vector3 r = hitPoint - cubeMotion.transform.position;
				Vector3 torque = Vector3.Cross(r, f);
				cubeTorque += torque;
			}
		}
		cubeMotion.Flotage = cubeFlotage;
		cubeMotion.Torque = cubeTorque;
		Vector3 blockTorque = new Vector3();
		Vector3 blockFlotage = new Vector3();
		for (int i = blockR; i <= blockL; i++)
		{
			for (int j = blockT; j <= blockD; j++)
			{
				Vector3 f = new Vector3(0, rho * 0.01f * x[i, j] * g, 0);
				blockFlotage += f;

				Vector3 hitPoint = new Vector3(X[i * size + j].x, underH[i, j], X[i * size + j].z);
				Vector3 r = hitPoint - blockMotion.transform.position;
				Vector3 torque = Vector3.Cross(r, f);
				blockTorque += torque;
			}
		}
		blockMotion.Flotage = blockFlotage;
		blockMotion.Torque = blockTorque;
		
		for (int i = 0; i < size; i++)
		{
			for (int j = 0; j < size; j++)
			{
				oldH[i, j] = curH[i, j];
				curH[i, j] = newH[i, j];
			}
		}
		
		for (int i = 0; i < size; i++)
		{
			for (int j = 0; j < size; j++)
			{
				mask[i, j] = false;
				underH[i, j] = 0;
				b[i, j] = 0;
				x[i, j] = 0;
				p[i, j] = 0;
				rk[i, j] = 0;
				ap[i, j] = 0;
			}
		}
	}
	
	void Update() 
	{
		Vector3[] X = waveMesh.vertices;
		float[,] newH = new float[size, size];
		float[,] curH = new float[size, size];
		
        for (int i = 0; i < X.Length; i++)
        {
			curH[i / size, i % size] = X[i].y;
        }

		if (Input.GetKeyDown("r"))
		{
			float r = Random.Range(0.5f, 1.0f);
			int randomI = Random.Range(1, size - 2);
			int randomJ = Random.Range(1, size - 2);
			curH[randomI, randomJ] += r;
			
			for (int i = 0; i < size; i++)
			for (int j = 0; j < size; j++)
				if (i != randomI && j != randomJ)
					curH[i, j] -= r / (size * size - 1);
		}

		for (int l = 0; l < 8; l++)
		{
			Shallow_Wave(oldH, curH, newH);
		}
		
        for (int i = 0; i < size; i++)
        for (int j = 0; j < size; j++)
	        X[ i * size + j].y = curH[i,j];

		waveMesh.vertices = X;
		waveMesh.RecalculateNormals();
	}
}