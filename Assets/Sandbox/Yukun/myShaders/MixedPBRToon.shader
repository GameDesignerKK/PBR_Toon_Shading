Shader "YK/MixedPBRToon"
{
    Properties
    {
        _Albedo("Albedo", Color) = (1,1,1,1)
        _BaseMap("BaseMap", 2D) = "white" {}
        _RMOMap("RMOMap", 2D) = "white" {}
        _NormalMap("NormalMAP", 2D) = "bump" {}
        _BumpScale("NormalScale", Float) = 1.0
        _Metallic("Metallic", Range(0,1)) = 1
        _Smoothness("Smoothness", Range(0,1)) = 1
        _AOPower("AOPower",Float) = 1

        _RampTex("RampTex", 2D) = "white" {}
        _ToonDiffuseWeight("Toon Weight", Range(0,1)) = 1
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
            Cull Off

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

            half3 SampleSH_L1(half3 normalWS)
            {
                //  Sample Spherical Harmonics L1
                return SHEvalLinearL0L1(normalWS, unity_SHAr, unity_SHAg, unity_SHAb);
            }

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            TEXTURE2D(_RMOMap);
            SAMPLER(sampler_RMOMap);

            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);

            TEXTURE2D(_RampTex);
            SAMPLER(sampler_RampTex);

            //TEXTURE2D(_MetallicMap);
            //SAMPLER(sampler_MetallicMap);

            //TEXTURE2D(_SmoothnessMap);
            //SAMPLER(sampler_SmoothnessMap);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
                float4 tangentOS  : TANGENT;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float2 uv : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float3 tangentWS  : TEXCOORD3;
                float3 BiNormalWS : TEXCOORD4;
                half3 diffuseGI : TEXCOORD5;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _Albedo;
                float _Metallic;
                float _Smoothness;
                float _BumpScale;
                float _AOPower;
                float _ToonDiffuseWeight;
            CBUFFER_END

            Varyings vert (Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                OUT.normalWS = normalize(TransformObjectToWorldNormal(IN.normalOS));
                OUT.tangentWS = normalize(TransformObjectToWorld(IN.tangentOS.xyz));
                OUT.BiNormalWS = cross(OUT.normalWS, OUT.tangentWS) * IN.tangentOS.w;

                OUT.diffuseGI = SampleSH_L1(OUT.normalWS);
                return OUT;
            }

            half4 frag (Varyings IN) : SV_Target
            {
                // ==== Normal Map: Tangent Space to World Space ====
                float3 normalTex = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, IN.uv),_BumpScale);

                float3 N   = IN.normalWS;
                float3 T   = IN.tangentWS;
                float3 B   = IN.BiNormalWS;
                
                float3x3 TBN = float3x3(T, B, N);
                float3 normalWS = normalize(mul(normalTex, TBN));   // 转换到世界空间并归一化

                // Material parameters
                float3 albedo = _Albedo.rgb;
                float2 uv = IN.uv;

                float4 albedoSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
                albedo *= albedoSample.rgb;

                float4 rmoSample = SAMPLE_TEXTURE2D(_RMOMap, sampler_RMOMap, uv);
                float metallicTex   = rmoSample.g;
                float roughnessTex = rmoSample.r;
                float aoTex = rmoSample.b;

                float metallic   = _Metallic   * metallicTex;
                float smoothness = _Smoothness * (1-roughnessTex);
                float roughness = 1.0 - smoothness;

                Light main_light = GetMainLight();
                // L
                float3 light_direction = normalize(main_light.direction);
                // V
                float3 view = normalize(_WorldSpaceCameraPos - IN.positionWS);
                // N
                float3 normal = normalWS;
                // H
                float3 half_vector = normalize(light_direction + view);

                float NdotL = saturate(dot(normal, light_direction));
                float NdotV = saturate(dot(normal, view));
                float NdotH = saturate(dot(normal, half_vector));
                float VdotH = saturate(dot(view, half_vector));
                float LdotH = saturate(dot(light_direction, half_vector));

                // Fresnel (Schlick) F
                float3 F0 = lerp(0.04.xxx, albedo, metallic);
                float3 F = F0 + (1 - F0) * pow(1 - LdotH, 5);

                // GGX NDF D
                float a = max(roughness * roughness, 0.03);
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
                
                //  Direct Lighting Specular (PBR Featured)
                float3 directSpec = specDirect * main_light.color * NdotL * PI;

                // Diffuse BRDF
                float3 Kd = (1.0 - metallic) * (1.0 - F);
                float3 diffuseDirect = Kd * albedo / PI;
                //  Diffuse Toon
                //  Use half-lambert to sample ramp texture
                float lambert = dot(normal, light_direction) * 0.5 + 0.5;
                float2 rampUV = float2(lambert, 0.5);
                float4 rampColor = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, rampUV);

                float3 DiffusePBRColor = diffuseDirect * NdotL * PI;
                float3 DiffuseToonColor = rampColor.rgb * albedo;

                float3 directDiffuse = lerp(DiffusePBRColor, DiffuseToonColor, _ToonDiffuseWeight) * main_light.color;
                float3 directColor = directDiffuse + directSpec;

                // Direct lighting from main light
                //float3 directColor = (diffuseDirect + specDirect) * main_light.color * NdotL;
                // Hemisphere Calculus
                //directColor *= PI;

                // IBL / Environment
                // 1) Environment diffuse (SH-based GI / sky)
                //float3 envDiffuse = SampleSH_L1(normal);
                //float3 iblDiffuse = envDiffuse * Kd * albedo;
                float3 iblDiffuse = IN.diffuseGI * albedo;

                // 2) Environment specular
                float3 R = reflect(-view, normal);
                float perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(smoothness);
                float occlusion = 1.0;

                float3 envSpec = GlossyEnvironmentReflection(R, perceptualRoughness, occlusion);
                float3 iblSpec = envSpec * F;

                float3 color = directColor + iblDiffuse + iblSpec;

                color *= pow(aoTex,_AOPower);

                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}