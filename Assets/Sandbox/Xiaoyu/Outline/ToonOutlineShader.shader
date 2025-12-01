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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _OutlineColor;
                float _OutlineWidth;
                //float4x4 unity_ObjectToWorld;
                //float4x4 unity_MatrixVP;
            CBUFFER_END

            // Object Space
            struct Attributes
            {
                float4 position : POSITION;
                float3 normal : NORMAL;
            };

            // Vertex Shader to Fragment Shader
            struct Varyings
            {
                float4 position : SV_POSITION;
            };

            Varyings OutlineVert (Attributes IN)
            {
                Varyings OUT;

                float3 Normal = TransformObjectToWorldNormal(IN.normal);

                float4 PositionWorld4 = mul(unity_ObjectToWorld, IN.position);
                float3 PositionWorld3 = PositionWorld4.xyz; // Drop W from float4 PositionWorld4 
                PositionWorld3 += Normal * _OutlineWidth;

                float4 PositionClip = mul(unity_MatrixVP, float4(PositionWorld3, 1.0));
                OUT.position = PositionClip;

                return OUT;
            }

            float4 OutlineFrag (Varyings IN) : SV_Target
            {
                return _OutlineColor;
            }
            
            ENDHLSL
        }
    }
}
