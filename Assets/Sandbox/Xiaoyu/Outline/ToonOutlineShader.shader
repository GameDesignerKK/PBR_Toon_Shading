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

                float3 Normal = UnityObjectToWorldNormal(IN.normal);

                float4 Position4 = mul(unity_ObjectToWorld, IN.position);
                float3 Position3 = Position4.xyz; // Drop W from float4 PositionWithW
                Position3 += Normal * _OutlineWidth;

                float4 PositionClip = mul(unity_MatrixVP, float4(Position3, 1.0));
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
