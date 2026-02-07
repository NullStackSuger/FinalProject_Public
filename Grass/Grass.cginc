#if !defined(GRASS)
#define GRASS

#include "UnityShadowLibrary.cginc"
#include "UnityCG.cginc"
#include "CustomTessellation.cginc"

#define BLADE_SEGMENTS 3

struct geometryOutput
{
    float4 pos : SV_POSITION;
    float3 normal : NORMAL;
    float2 uv : TEXCOORD0;
    unityShadowCoord4 _ShadowCoord : TEXCOORD1;
};

float4 _TopColor;
float4 _BottomColor;

float _BendRotationRandom;

float _BladeHeight;
float _BladeHeightRandom;	
float _BladeWidth;
float _BladeWidthRandom;

sampler2D _WindDistortionMap;
float4 _WindDistortionMap_ST;
float2 _WindFrequency;
float _WindStrength;

float _BladeForward;
float _BladeCurve;

float3 _PlayerPos;
float _PlayerRadius;
float _PlayerStrength;

float3 UsePlayerMove(float3 localPos)
{
    float3 playerObjectPos = mul(unity_WorldToObject, float4(_PlayerPos, 1)).xyz;
    float3 dir = normalize(localPos - playerObjectPos);
    float dis = distance(playerObjectPos, localPos);
    float falloff = 1 - saturate(dis /  _PlayerRadius);
    float3 disp = clamp(dir * falloff * _PlayerStrength, -0.8, 0.8);
    localPos += disp;
    return localPos;
}
geometryOutput VertexOutput(float3 pos, float3 normal, float2 uv)
{
	geometryOutput o;
	o.pos = UnityObjectToClipPos(pos);
    o.normal = UnityObjectToWorldNormal(normal);
    o.uv = uv;
    o._ShadowCoord = ComputeScreenPos(o.pos);
    #if UNITY_PASS_SHADOWCASTER
    o.pos = UnityApplyLinearShadowBias(o.pos);
    #endif
	return o;
}
geometryOutput GenerateGrassVertex(float3 vertexPosition, float width, float height, float forward, float2 uv, float3x3 transformMatrix)
{
	float3 tangentPoint = float3(width, forward, height);
    float3 tangentNormal = float3(0, -1, forward);
    float3 localNormal = mul(transformMatrix, tangentNormal);
	float3 localPosition = vertexPosition + mul(transformMatrix, tangentPoint);
    localPosition = UsePlayerMove(localPosition);
    
	return VertexOutput(localPosition, localNormal, uv);
}

float rand(float3 co)
{
    return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
}

float3x3 AngleAxis3x3(float angle, float3 axis)
{
    float c, s;
    sincos(angle, s, c);
    float t = 1 - c;
    float x = axis.x;
    float y = axis.y;
    float z = axis.z;
    return float3x3(
        t * x * x + c, t * x * y - s * z, t * x * z + s * y,
        t * x * y + s * z, t * y * y + c, t * y * z - s * x,
        t * x * z - s * y, t * y * z + s * x, t * z * z + c);
}

[maxvertexcount(BLADE_SEGMENTS * 2 + 1)]
void geo(triangle vertexOutput IN[3] : SV_POSITION, inout TriangleStream<geometryOutput> triStream)
{
    geometryOutput o;

    float3 pos = IN[0].vertex;
    float3 normal = IN[0].normal;
    float4 tangent = IN[0].tangent;
    float3 binormal = cross(normal, tangent) * tangent.w;

    float3x3 tangentToLocal = float3x3(
        tangent.x, binormal.x, normal.x,
        tangent.y, binormal.y, normal.y,
        tangent.z, binormal.z, normal.z);

    float3x3 facingRotationMatrix = AngleAxis3x3(rand(pos) * UNITY_TWO_PI, float3(0,0,1));

    float3x3 bendRotationMatrix = AngleAxis3x3(rand(pos.zzx) * _BendRotationRandom * UNITY_PI * 0.5, float3(-1, 0, 0));

    float2 uv = pos.xz * _WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + _WindFrequency * _Time.y;
    float2 windSample = (tex2Dlod(_WindDistortionMap, float4(uv, 0, 0)).xy * 2 - 1) * _WindStrength;
	float3 wind = normalize(float3(windSample.x, windSample.y, 0)); // Wind Vector
    float3x3 windRotation = AngleAxis3x3(UNITY_PI * windSample, wind);

    float3x3 transformationMatrixFacing = mul(tangentToLocal, facingRotationMatrix);
    float3x3 transformationMatrix = mul(mul(transformationMatrixFacing, bendRotationMatrix), windRotation);

    float height = (rand(pos.zyx) * 2 - 1) * _BladeHeightRandom + _BladeHeight;
    float width = (rand(pos.xzy) * 2 - 1) * _BladeWidthRandom + _BladeWidth;
    float forward = rand(pos.yyz) * _BladeForward;
    
    for (int i = 0; i < BLADE_SEGMENTS; i++)
    {
	    float t = i / (float)BLADE_SEGMENTS;
        float segmentHeight = height * t;
	    float segmentWidth = width * (1 - t);
        float segmentForward = pow(t, _BladeCurve) * forward;

        float3x3 transformMatrix = i == 0 ? transformationMatrixFacing : transformationMatrix;

        triStream.Append(GenerateGrassVertex(pos, 2 * segmentWidth, segmentHeight, segmentForward, float2(0, t), transformMatrix));
        triStream.Append(GenerateGrassVertex(pos, 0, segmentHeight, segmentForward, float2(1, t), transformMatrix));
    }
    triStream.Append(GenerateGrassVertex(pos, 0, height, forward, float2(0.5, 1), transformationMatrix));
}

#endif