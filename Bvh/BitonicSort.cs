using System.Text;
using UnityEngine;

public class BitonicSort : MonoBehaviour
{
    public int[] arr = { 10, 20, 5, 9, 3, 8, 12, 14, 90, 0, 60, 40, 23, 35, 95, 18 };
    public int[] res;
    
    /*
     * 正向过程
     * [1, 4, 6, 8 | 7, 5, 3, 2]
     * (1,7)(4,5)(6,3)(8,2) => [1, 4 | 3, 2] [7, 5 | 6, 8]
     * (1,3)(4,2) => [1, 2] [3, 4]
     * (7,6)(5,8) => [5, 6] [7, 8]
     */
    
    /*
     * 反向过程
     * [ 7, 2, 5, 3, 8, 1, 6, 4 ]
     * 
     * => [2, 7]↑ [5, 3]↓ [1, 8]↑ [6, 4]↓ // 构造22一组的交替的单调序列
     * => [2, 7 | 5, 3] [ 1, 8 | 6, 4 ] // 合并
     * (2,5)(7,3) => (2,5)不变(7,3)交换 => [2, 3 | 5, 7]
     * (1,6)(8,4) => (1,6)不变(8,4)交换 => [1, 4 | 6, 8]
     * 
     * => [2, 3, 5, 7]↑ [8, 6, 4, 1]↓ // 构造44一组的交替的单调序列
     * => [2, 3, 5, 7 | 8, 6, 4, 1] // 合并
     * (2,8)(3,6)(5,4)(7,1) => (2,8)不变(3,6)不变(5,4)交换(7,1)交换 => [2, 3, 4, 1 | 8, 6, 5, 7]
     * (2,4)(3,1) => (2,4)不变(3,1)交换 => [2, 1 | 4, 3]
     * (8,5)(6,7) => (8,5)交换(6,7)不变 => [5, 6 | 8, 7]
     * (2,1) => (2,1)交换 => [1, 2]
     * (4,3) => (4,3)交换 => [3, 4]
     * (5,6) => (5,6)不变 => [5, 6]
     * (8,7) => (8,7)交换 => [7, 8]
     */
    
    private void OnEnable()
    {
        int[] data = arr.Clone() as int[];
        
        Compare(data, 0, 1, 1, true);
        Compare(data, 2, 3, 1, false);
        Compare(data, 4, 5, 1, true);
        Compare(data, 6, 7, 1, false);
        Compare(data, 8, 9, 1, true);
        Compare(data, 10, 11, 1, false);
        Compare(data, 12, 13, 1, true);
        Compare(data, 14, 15, 1, false);

        res = Sort(arr);

        StringBuilder sb = new();
        foreach (int i in res)
        {
            sb.Append($"{i}, ");
        }
        Debug.Log(sb.ToString());
    }

    public static int[] Sort(int[] arr)
    {
        int[] data = arr.Clone() as int[];
        int dataLength = data!.Length;
        
        // 生成双调序列
        {
            int signLength = 2;
            while (signLength < dataLength)
            {
                int compareLength = signLength / 2;
                while (compareLength > 0)
                {
                    int index = 0;
                    while (index < dataLength)
                    {
                        bool sign = (index / signLength) % 2 == 0;
                        Compare(data, index, index + compareLength, compareLength, sign);
                        index += 2 * compareLength;
                    }
                    compareLength /= 2;
                }
                signLength *= 2;
            }
        }
        
        // 序列排序
        {
            int compareLength = dataLength / 2;
            int iterCount = 1;
            while (compareLength != 0)
            {
                int startIndex = 0;
                for (int i = 0; i < iterCount; i++)
                {
                    Compare(data, startIndex, startIndex + compareLength, compareLength);
                    startIndex += 2 * compareLength;
                }
                compareLength /= 2;
                iterCount *= 2;
            }
        }
        
        return data;
    }
    private static void Compare(int[] arr, int start, int end, int length, bool increase)
    {
        for (int i = start; i < end; i++)
        {
            int a = arr[i];
            int b = arr[i + length];
            
            if (increase && a > b)
            {
                arr[i] = b;
                arr[i + length] = a;
            }
            else if (!increase && a < b)
            {
                arr[i] = b;
                arr[i + length] = a;
            }
        }
    }
    private static void Compare(int[] arr, int start, int end, int length)
    {
        for (int i = start; i < end; i++)
        {
            int a = arr[i];
            int b = arr[i + length];

            if (a > b)
            {
                arr[i] = b;
                arr[i + length] = a;
            }
        }
    }
}