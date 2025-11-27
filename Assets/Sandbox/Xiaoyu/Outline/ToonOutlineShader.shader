Shader "Custom/ToonOutlineShader"
{
    Properties
    {
        _BaseColor ("BaseColor", Color) = (1,1,1,1)
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
            #pragma vertex vert
            #pragma fragment frag

            float4 _OutlineColor
            float _OutlineWidth

            float4x4 ObjectToWorld
            float4x4 ViewProjectionMatrix

            struct data
            {
                float4 vertex : Position
            }
        }
    }
}
