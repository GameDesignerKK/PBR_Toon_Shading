Shader "Custom/SDF_Face"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _ShadowColor("ShadowColor",Color) = (0,0,0,1)
        _SDFMap("SDF Face Map", 2D) = "white"
        [MainTexture] _BaseMap("Base Map", 2D) = "white"
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_SDFMap);
            SAMPLER(sampler_SDFMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half4 _ShadowColor;
                float4 _BaseMap_ST;
                float4 _SDFMap_ST;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                //  Get Main Light Data
                Light mainLight = GetMainLight();
                //  Project Light Direction to XZ plane and normalize
                half3 lightDirXZ = mainLight.direction * half3(1, 0, 1);
                half3 lightDirWS_n = normalize(lightDirXZ);
                //  Calculate Front & Right vector
                half3 frontDirWS = mul(unity_ObjectToWorld,half4(0,0,-1,0)).xyz;
                half3 RightDirWS = mul(unity_ObjectToWorld,half4(-1,0,0,0)).xyz;

                //  Front dot Light
                half FdotL = dot(frontDirWS, lightDirWS_n);
                FdotL = (-FdotL * 0.5) + 0.5;
                FdotL = FdotL*FdotL;
                //  Right dot Light
                half RdotL = dot(RightDirWS, lightDirWS_n);

                //  Sample SDF Face Shadow Map
                half sdf_color_rightDir = SAMPLE_TEXTURE2D(_SDFMap, sampler_SDFMap, IN.uv).r;
                half sdf_color_leftDir = SAMPLE_TEXTURE2D(_SDFMap, sampler_SDFMap, float2(1-IN.uv.x,IN.uv.y)).r;

                //  judge Left or Right
                half sdf_color = RdotL > 0 ? sdf_color_leftDir : sdf_color_rightDir;
                //  Step SDF Map
                half sdf_faceShadow = step(FdotL, sdf_color);


                half4 base_color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
                half4 color = lerp(base_color * _ShadowColor, base_color * _BaseColor, sdf_faceShadow);
                return color;
            }
            ENDHLSL
        }
    }
}
