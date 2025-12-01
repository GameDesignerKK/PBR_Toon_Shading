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

            float4 _RimColor;
            float _RimSharpness;
            float _RimBrightness;
            float _RimDepthOffset;

            float4x4 unity_ObjectToWorld;
            float4x4 unity_MatrixVP;
            float3 _WorldSpaceCameraPos;

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
                float3 normal : NORMAL;
                float3 wposition : TEXCOORD0;
            };

            FragData RimVert (InputData IN)
            {
                FragData OUT;

                float3x3 ObjToWorldRS = (float3x3)unity_ObjectToWorld;
                float3 NormalOToW = mul(ObjToWorldRS, IN.normal);
                NormalOToW = normalize(NormalOToW);

                float4 PositionWithW = mul(unity_ObjectToWorld, IN.position);
                float3 PositionWorld = PositionWithW.xyz; // Drop W from float 4 

                float3 view = normalize(_WorldSpaceCameraPos - PositionWorld);
                float3 PositionWorldOffset = PositionWorld + view * _RimDepthOffset;
                float4 PositionClip = mul(unity_MatrixVP, float4(PositionWorldOffset, 1.0));

                OUT.position = PositionClip;
                OUT.normal = NormalOToW;
                OUT.wposition = PositionWorld;

                return OUT;
            }

            float4 RimFrag (FragData IN) : SV_Target
            {
                float3 normal = normalize(IN.normal);
                float3 view = normalize(_WorldSpaceCameraPos - IN.wposition);

                float ViewClamp = 1.0 - saturate(dot(normal, view));
                float Rim = pow(ViewClamp, _RimSharpness);
                float3 RimColor = _RimColor.rgb * Rim * _RimBrightness;

                return float4(RimColor, 1.0);
            }
            
            ENDHLSL
        }
    }
}
