using System.Text;
using UnityEngine;

public class BitonicSortGPU : MonoBehaviour
{
    public ComputeShader shader;
    private int generateKernel => shader.FindKernel("Generate");
    private int sortKernel => shader.FindKernel("Sort");
    private int lengthKernel;

    public int[] input = { 10, 20, 5, 9, 3, 8, 12, 14, 90, 0, 60, 40, 23, 35, 95, 18 };
    private int inputLength;
    private ComputeBuffer buffer;
    
    private void OnEnable()
    {
        inputLength = input.Length;
        buffer = new ComputeBuffer(inputLength, sizeof(int));
        buffer.SetData(input);
        shader.SetInt("inputLength", inputLength);
        shader.SetBuffer(generateKernel, "buffer", buffer);
        shader.SetBuffer(sortKernel, "buffer", buffer);

        // 生成双调序列
        {
            int signLength = 2;
            while (signLength < inputLength)
            {
                int compareLength = signLength / 2;
                shader.SetInt("signLength", signLength);
                while (compareLength > 0)
                {
                    shader.SetInt("compareLength", compareLength);
                    shader.Dispatch(generateKernel, 1, 1, 1);
                    compareLength /= 2;
                }
                signLength *= 2;
            }
        }
        
        // 序列排序
        {
            int compareLength = inputLength / 2;
            while (compareLength != 0)
            {
                shader.SetInt("compareLength", compareLength);
                shader.Dispatch(sortKernel, 1, 1, 1);
                compareLength /= 2;
            }
        }
        
        int[] tmp = new int[inputLength];
        buffer.GetData(tmp);
        StringBuilder sb = new();
        foreach (int i in tmp)
        {
            sb.Append($"{i}, ");
        }
        Debug.Log(sb.ToString());
    }
}