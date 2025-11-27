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
            float4 _OutlineWidth;

            float4x4 unity_ObjectToWorld;
            float4x4 unity_Matrix_VP;

            // Object Space
            struct InputData
            {
                float4 position : POSITION;
                float3 normal : NORMAL;
            };

            // Vertex Shader to Fragment Shader
            struct FragData
            {
                float4 positionClip = SV_POSITION;
            };

            FragData OutlineVertex (InputData IN)
            {
                FragData OUT;

                float3x3 ObjToWorld_RS = (float3x3)unity_ObjectToWorld;
                
                float3 NormalOToW = mul(ObjToWorld_RS, IN.normal);
                NormalOToW = normalize(NormalOToW);


                }

        }
    }
}
