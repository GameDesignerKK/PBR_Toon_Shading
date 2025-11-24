Shader "Custom/pbr_shader_example"
{
    Properties
    {
        _Albedo("Albedo", Color) = (1,1,1,1)
        _Metallic("Metallic", Range(0,1)) = 0
        _Smoothness("Smoothness", Range(0,1)) = 0.5
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "Lit"
        }
        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags {"LightMode" = "UniversalForward"}

            HLSLPROGRAM
            #pragma target 2.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fragment _ _ENVIRONMENT_REFLECTIONS_OFF
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_ATLAS
            #pragma multi_compile_fragment _ _ENVIRONMENTREFLECTIONS_OFF
            #pragma multi_compile _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normalWS : NORMAL;
                float3 positionWS : TEXCOORD0;
            };

            float4 _Albedo;
            float _Metallic;
            float _Smoothness;

            Varyings vert (Attributes IN)
            {
                Varyings OUT;
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.normalWS = normalize(TransformObjectToWorldNormal(IN.normalOS));
                OUT.positionHCS = TransformWorldToHClip(OUT.positionWS);
                return OUT;
            }

            half4 frag (Varyings IN) : SV_Target
            {
                // Material parameters
                float3 albedo = _Albedo.rgb;
                float metallic = _Metallic;
                float smoothness = _Smoothness;
                float roughness = 1 - smoothness;

                Light main_light = GetMainLight();
                // L
                float3 light_direction = normalize(main_light.direction);
                // V
                float3 view = normalize(_WorldSpaceCameraPos - IN.positionWS);
                // N
                float3 normal = normalize(IN.normalWS);
                // H
                float3 half_vector = normalize(light_direction + view);

                float NdotL = saturate(dot(normal, light_direction));
                float NdotV = saturate(dot(normal, view));
                float NdotH = saturate(dot(normal, half_vector));
                float VdotH = saturate(dot(view, half_vector));

                // Fresnel (Schlick) F
                float3 F0 = lerp(0.04.xxx, albedo, metallic);
                float3 F = F0 + (1 - F0) * pow(1 - VdotH, 5);

                // GGX NDF D
                float a = roughness * roughness;
                float a2 = a * a;
                float denom = (NdotH * NdotH) * (a2 - 1) + 1;
                float D = a2 / (PI * denom * denom + 1e-7);

                // Geometry term G (Smith-Schlick)
                float k = (roughness + 1) * (roughness + 1) / 8;
                float G_V = NdotV / (NdotV * (1 - k) + k);
                float G_L = NdotL / (NdotL * (1 - k) + k);
                float G = G_L * G_V;

                float denomSpec = max(4.0 * NdotL * NdotV, 0.001);
                float3 specDirect = (D * F * G) / denomSpec;

                // Diffuse BRDF
                // Kd = (1 - metallic) * (1 - F) --- (Disney style)
                // float minDiffuseForMetal = 0.1; fake
                // float3 KdDielectric = (1.0 - metallic) * (1.0 - F);
                // float3 KdMetalBoost = minDiffuseForMetal * metallic;
                // float3 Kd = KdDielectric + KdMetalBoost;
                // float3 diffuseDirect = Kd * albedo / PI;

                // Diffuse BRDF
                float3 Kd = (1.0 - metallic) * (1.0 - F);
                float3 diffuseDirect = Kd * albedo / PI;

                // Direct lighting from main light
                float3 directColor = (diffuseDirect + specDirect) * main_light.color * NdotL;

                // IBL / Environment
                // 1) Environment diffuse (SH-based GI / sky)
                float3 envDiffuse = SampleSH(normal);
                float3 iblDiffuse = envDiffuse * Kd * albedo;

                // 2) Environment specular
                float3 R = reflect(-view, normal);
                float perceptualRoughness = roughness;
                float occlusion = 1.0;

                float3 envSpec = GlossyEnvironmentReflection(R, perceptualRoughness, occlusion);
                float3 iblSpec = envSpec * F;

                float3 color = directColor + iblDiffuse + iblSpec;

                return float4(color, 1.0);
                //return float4(envSpec, 1.0);
            }
            ENDHLSL
        }
    }
}