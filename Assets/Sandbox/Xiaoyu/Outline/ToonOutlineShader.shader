Shader "Custom/ToonOutlineShader"
{
    Properties
    {
        _OutlineColor ("Outline Color", Color) = (0,0,0,1)
        _OutlineWidth ("OutlineWidth", Float) = 0.05
     }

     SubShader
     {
        Tags
        {
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Name "OutlineShader"

            Cull Front
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM 
            #pragma vertex OutlineVert
            #pragma fragment OutlineFrag

            float4 _OutlineColor;
            float _OutlineWidth;

            float4x4 unity_ObjectToWorld;
            float4x4 unity_MatrixVP;

            // Object Space
            struct InputData
            {
                float4 position : POSITION;
                float3 normal : NORMAL;
            };

            // Vertex Shader to Fragment Shader
            struct FragData
            {
                float4 position : SV_POSITION;
            };

            FragData OutlineVert (InputData IN)
            {
                FragData OUT;

                float3x3 ObjToWorldRS = (float3x3)unity_ObjectToWorld;
                float3 NormalOToW = mul(ObjToWorldRS, IN.normal);
                NormalOToW = normalize(NormalOToW);

                float4 PositionWithW = mul(unity_ObjectToWorld, IN.position);
                float3 PositionWorld = PositionWithW.xyz; // Drop W in float 4
                PositionWorld += NormalOToW * _OutlineWidth;

                float4 PositionClip = mul(unity_MatrixVP, float4(PositionWorld, 1.0));
                OUT.position = PositionClip;

                return OUT;
            }

            float4 OutlineFrag (FragData IN) : SV_Target
            {
                return _OutlineColor;
            }
            
            ENDHLSL
        }
    }
}
