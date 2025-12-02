Shader "Custom/RimLightShader"
{
    Properties
    {
        _RimColor ("Rim Color", Color) = (255,238,140,1)
        _RimSharpness ("Rim Sharpness", Float) = 3.0
        _RimBrightness ("Rim Brightness", Float) = 2.0
        _RimDepthOffset ("Rim Depth Offset", Float) = 0.001
     }

     SubShader
     {
        Tags
        {
            "RenderType" = "Transparent"
            "Queue" = "Transparent+1"
            "RenderPipeline" = "UniversalPipeline"
            "LightMode" = "UniversalForward"
        }

        Pass
        {
            Name "RimLightShader"

            Cull Back 
            ZWrite Off
            ZTest LEqual
            Blend One One

            HLSLPROGRAM
            #pragma vertex RimVert
            #pragma fragment RimFrag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _RimColor;
                float _RimSharpness;
                float _RimBrightness;
                float _RimDepthOffset;
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
                float3 normal : NORMAL;
                float3 wposition : TEXCOORD0;
            };

            Varyings RimVert (Attributes IN)
            {
                Varyings OUT;

                float3 Normal = TransformObjectToWorldNormal(IN.normal);

                float4 PositionWorld4 = mul(unity_ObjectToWorld, IN.position);
                float3 PositionWorld3 = PositionWorld4.xyz; // Drop W from float4 PositionWorld4 

                float3 View = normalize(_WorldSpaceCameraPos - PositionWorld3);
                float3 PositionWorldOffset = PositionWorld3 + View * _RimDepthOffset;
                float4 PositionClip = mul(unity_MatrixVP, float4(PositionWorldOffset, 1.0));

                OUT.position = PositionClip;
                OUT.normal = Normal;
                OUT.wposition = PositionWorld3;

                return OUT;
            }

            float4 RimFrag (Varyings IN) : SV_Target
            {
                float3 Normal = normalize(IN.normal);
                float3 View = normalize(_WorldSpaceCameraPos - IN.wposition);

                float ViewClamp = 1.0 - saturate(dot(Normal, View));
                float Rim = pow(ViewClamp, _RimSharpness);
                float3 RimColor = _RimColor.rgb * Rim * _RimBrightness;

                return float4(RimColor, 1.0);
            }
            
            ENDHLSL
        }
    }
}
