Shader "Custom/pbr_chatgpt"
{
    Properties
    {
        _Albedo("Albedo", Color) = (1,1,1,1)
        _Metallic("Metallic", Range(0,1)) = 0
        _Smoothness("Smoothness", Range(0,1)) = 0.5
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 300

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
                float3 normalOS   : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normalWS    : TEXCOORD0;
                float3 positionWS  : TEXCOORD1;
            };

            float4 _Albedo;
            float  _Metallic;
            float  _Smoothness;

            Varyings vert (Attributes IN)
            {
                Varyings OUT;
                OUT.positionWS  = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.normalWS    = normalize(TransformObjectToWorldNormal(IN.normalOS));
                OUT.positionHCS = TransformWorldToHClip(OUT.positionWS);
                return OUT;
            }

            half4 frag (Varyings IN) : SV_Target
            {
                // -------- 材质参数 --------
                float3 albedo     = _Albedo.rgb;
                float  metallic   = _Metallic;
                float  smoothness = _Smoothness;
                float  roughness  = 1.0 - smoothness;

                // -------- 基本方向：L / V / N / H --------
                Light  main_light = GetMainLight();

                // L：从表面 -> 光源
                float3 L = normalize(main_light.direction);
                // V：从表面 -> 相机
                float3 V = normalize(_WorldSpaceCameraPos - IN.positionWS);
                // N：世界空间法线
                float3 N = normalize(IN.normalWS);
                // H：半角向量
                float3 H = normalize(L + V);

                float NdotL = saturate(dot(N, L));
                float NdotV = saturate(dot(N, V));
                float NdotH = saturate(dot(N, H));
                float VdotH = saturate(dot(V, H));

                // 防止正面无光时还做一堆计算（只影响 direct 部分，IBL 仍然可以存在）
                float3 directColor = 0;
                if (NdotL > 0.0 && NdotV > 0.0)
                {
                    // -------- Fresnel (Schlick) F --------
                    float3 F0 = lerp(0.04.xxx, albedo, metallic);
                    float3 F  = F0 + (1.0 - F0) * pow(1.0 - VdotH, 5.0);

                    // -------- GGX NDF D --------
                    float a    = roughness * roughness;
                    float a2   = a * a;
                    float denom = (NdotH * NdotH) * (a2 - 1.0) + 1.0;
                    float D    = a2 / (PI * denom * denom + 1e-7);

                    // -------- 几何项 G (Smith-Schlick) --------
                    float k    = (roughness + 1.0);
                    k          = (k * k) / 8.0;
                    float G_V  = NdotV / (NdotV * (1.0 - k) + k);
                    float G_L  = NdotL / (NdotL * (1.0 - k) + k);
                    float G    = G_L * G_V;

                    float  denomSpec = max(4.0 * NdotL * NdotV, 0.001);
                    float3 specDirect = (D * F * G) / denomSpec;

                    // -------- Diffuse BRDF（纯物理版）--------
                    // Kd = (1 - metallic) * (1 - F)
                    float3 Kd = (1.0 - metallic) * (1.0 - F);
                    float3 diffuseDirect = Kd * albedo / PI;

                    // -------- 主光直接光 --------
                    directColor = (diffuseDirect + specDirect) * main_light.color * NdotL;
                }

                // =================================================
                // ===============  IBL / 环境光照  ================
                // =================================================

                // 重新算一次 F0、F（IBL 也需要）
                float3 F0_IBL = lerp(0.04.xxx, albedo, metallic);
                float3 F_IBL  = F0_IBL + (1.0 - F0_IBL) * pow(1.0 - VdotH, 5.0);

                // -------- 环境漫反射（SampleSH）--------
                float3 envDiffuse = SampleSH(N);        // 环境辐照度
                float3 Kd_IBL     = (1.0 - metallic) * (1.0 - F_IBL);
                float3 iblDiffuse = envDiffuse * Kd_IBL * albedo;   // 不再额外加保底 diffuse

                // -------- 环境高光（GlossyEnvironmentReflection）--------
                float3 R = reflect(-V, N);             // 反射方向
                float  perceptualRoughness = roughness;
                float  occlusion           = 1.0;      // 暂时不做 AO

                float3 envSpec = GlossyEnvironmentReflection(R, perceptualRoughness, occlusion);
                float3 iblSpec = envSpec * F_IBL;

                // -------- 最终颜色（完全物理，没有额外 baseAmbient）--------
                float3 color = directColor + iblDiffuse + iblSpec;

                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}
