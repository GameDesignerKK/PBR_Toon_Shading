/*
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

            // ***** Lighting keywords from URP Lit shader *****
            #pragma multi_compile_fragment _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            // ***** Reflection Probes keywords *****
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_ATLAS
            #pragma multi_compile_fragment _ _ENVIRONMENT_REFLECTIONS

            // ***** SSAO *****
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/BRDF.hlsl"

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

            CBUFFER_START(UnityPerMaterial)
                float4 _Albedo;
                float _Metallic;
                float _Smoothness;
            CBUFFER_END

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
                float roughness = 1.0 - smoothness;

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
                float perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(smoothness);
                float occlusion = 1.0;

                float3 envSpec = GlossyEnvironmentReflection(R, perceptualRoughness, occlusion);
                float3 iblSpec = envSpec * F;

                float3 color = directColor + iblDiffuse + iblSpec;

                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}
*/
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

            // ***** Lighting keywords from URP Lit shader *****
            #pragma multi_compile_fragment _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            // ***** Reflection Probes keywords *****
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_ATLAS
            #pragma multi_compile_fragment _ _ENVIRONMENT_REFLECTIONS

            // ***** SSAO *****
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/BRDF.hlsl"

            // ===== 手动采样 reflection probe 的声明部分 =====
            // 这些一般在内置里已经有声明，但这样写更直观
            //TEXTURECUBE(unity_SpecCube0);
            //SAMPLER(samplerunity_SpecCube0);
            //float4 unity_SpecCube0_HDR;

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

            CBUFFER_START(UnityPerMaterial)
                float4 _Albedo;
                float _Metallic;
                float _Smoothness;
                TEXTURECUBE(unity_SpecCube0);
                SAMPLER(samplerunity_SpecCube0);
                float4 unity_SpecCube0_HDR;
            CBUFFER_END

            Varyings vert (Attributes IN)
            {
                Varyings OUT;
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.normalWS = normalize(TransformObjectToWorldNormal(IN.normalOS));
                OUT.positionHCS = TransformWorldToHClip(OUT.positionWS);
                return OUT;
            }

            // 简单封装一个采样 reflection probe 的函数
            float3 SampleReflectionProbe(float3 R, float perceptualRoughness)
            {
                #ifdef _ENVIRONMENT_REFLECTIONS
                    // 使用 roughness 控制 mip（越糙 → mip 越高）
                    float mip = perceptualRoughness * UNITY_SPECCUBE_LOD_STEPS;

                    float4 encoded = SAMPLE_TEXTURECUBE_LOD(
                        unity_SpecCube0,
                        samplerunity_SpecCube0,
                        R,
                        mip
                    );

                    // HDR 解码，得到真正的环境反射颜色
                    float3 reflColor = DecodeHDREnvironment(encoded, unity_SpecCube0_HDR);
                    return reflColor;
                #else
                    return 0;
                #endif
            }

            half4 frag (Varyings IN) : SV_Target
            {
                // ===== Material parameters =====
                float3 albedo = _Albedo.rgb;
                float metallic = _Metallic;
                float smoothness = _Smoothness;
                float roughness = 1.0 - smoothness;

                // ===== 基础向量 =====
                Light main_light = GetMainLight();
                float3 light_direction = normalize(main_light.direction);                     // L
                float3 view = normalize(_WorldSpaceCameraPos - IN.positionWS);                // V
                float3 normal = normalize(IN.normalWS);                                       // N
                float3 half_vector = normalize(light_direction + view);                       // H

                float NdotL = saturate(dot(normal, light_direction));
                float NdotV = saturate(dot(normal, view));
                float NdotH = saturate(dot(normal, half_vector));
                float VdotH = saturate(dot(view, half_vector));

                // ===== Fresnel F (Schlick) =====
                float3 F0 = lerp(0.04.xxx, albedo, metallic);
                float3 F = F0 + (1 - F0) * pow(1 - VdotH, 5);

                // ===== GGX NDF D =====
                float a = roughness * roughness;
                float a2 = a * a;
                float denom = (NdotH * NdotH) * (a2 - 1) + 1;
                float D = a2 / (PI * denom * denom + 1e-7);

                // ===== Geometry term G (Smith-Schlick) =====
                float k = (roughness + 1) * (roughness + 1) / 8;
                float G_V = NdotV / (NdotV * (1 - k) + k);
                float G_L = NdotL / (NdotL * (1 - k) + k);
                float G = G_L * G_V;

                float denomSpec = max(4.0 * NdotL * NdotV, 0.001);
                float3 specDirect = (D * F * G) / denomSpec;

                // ===== Diffuse BRDF =====
                float3 Kd = (1.0 - metallic) * (1.0 - F);    // 保证能量守恒
                float3 diffuseDirect = Kd * albedo / PI;

                // ===== Direct lighting from main light =====
                float3 directColor = (diffuseDirect + specDirect) * main_light.color * NdotL;

                // ===== IBL / Environment =====

                // 1) Environment diffuse (SH-based GI / sky)
                float3 envDiffuse = SampleSH(normal);
                float3 iblDiffuse = envDiffuse * Kd * albedo;

                // 2) Environment specular (Reflection Probe + Box Projection)
                float3 R = reflect(-view, normal);
                float perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(smoothness);
                float occlusion = 1.0;   // 需要的话可以乘上 AO

                // Box Projection（如果 probe 是 box 模式）
                float3 Rproj = R;
                #if defined(_REFLECTION_PROBE_BOX_PROJECTION)
                    Rproj = BoxProjectedCubemapDirection(
                        R,
                        IN.positionWS,
                        unity_SpecCube0_ProbePosition,
                        unity_SpecCube0_BoxMin,
                        unity_SpecCube0_BoxMax
                    );
                #endif

                // 手动采样 reflection probe
                float3 envSpec = SampleReflectionProbe(Rproj, perceptualRoughness);

                // 和 Fresnel 结合
                float3 iblSpec = envSpec * F * occlusion;

                // ===== Final color =====
                float3 color = directColor + iblDiffuse + iblSpec;

                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}
