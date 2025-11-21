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
                float3 albedo = _Albedo.rgb;
                float metallic = _Metallic;
                float smoothness = _Smoothness;
                float roughness = 1 - smoothness;

                Light main_light = GetMainLight();
                float3 light_direction = normalize(main_light.direction);
                float3 view = normalize(_WorldSpaceCameraPos - IN.positionWS);
                float3 normal = normalize(IN.normalWS);
                float3 half_vector = normalize(light_direction + view);

                float NdotL = saturate(dot(normal, light_direction));
                float NdotV = saturate(dot(normal, view));
                float NdotH = saturate(dot(normal, half_vector));
                float VdotH = saturate(dot(view, half_vector));

                // Fresnel
                float3 F0 = lerp(0.04.xxx, albedo, metallic);
                float3 F = F0 + (1 - F0) * pow(1 - VdotH, 5);

                // GGX
                float a = roughness * roughness;
                float a2 = a * a;
                float denom = (NdotH * NdotH) * (a2 - 1) + 1;
                float D = a2 / (PI * denom * denom);

                // Geometry
                float k = (roughness + 1) * (roughness + 1) / 8;
                float G_V = NdotV / (NdotV * (1 - k) + k);
                float G_L = NdotL / (NdotL * (1 - k) + k);
                float G = G_L * G_V;

                float3 spec = (D * F * G) / (4 * NdotL * NdotV + 0.001);

                float3 diffuse = (1 - metallic) * albedo / PI;

                float3 color = (diffuse + spec) * main_light.color * NdotL;

                return float4(color, 1);
            }
            ENDHLSL
        }
    }
}
