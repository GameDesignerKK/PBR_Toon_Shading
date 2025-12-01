Shader "Tommy/Ramp"
{
   Properties
    {
        _BaseMap("MainTex", 2D) = "white" {}
        _BaseColor("BaseColor", Color) = (1.0, 1.0, 1.0, 1.0)
        _SpecColor("Specular", Color) = (1.0, 1.0, 1.0, 1.0)
        _Smoothness("Gloss", Range(8.0, 256)) = 20
        _BumpScale("Scale", Float) = 1.0
        _BumpMap("Normal Map", 2D) = "bump" {}
        _RampTex("RampTex", 2D) = "white" {}
    }

    SubShader
    {
        // URP shader 必须声明使用 UniversalRenderPipeline
        Tags
        {
            "RenderPipeline" = "UniversalRenderPipeline"
            "RenderType"     = "Opaque"
        }

        HLSLINCLUDE

            // URP Core / Lighting / LitInput
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float4 tangentOS  : TANGENT;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float2 uv         : TEXCOORD1;
                float3 normalWS   : TEXCOORD2;
                float4 tangentWS  : TEXCOORD3;
            };

            // Ramp 纹理（1D/2D 都可以，按 U 采样）
            TEXTURE2D(_RampTex);
            SAMPLER(sampler_RampTex);

        ENDHLSL

        Pass
        {
            // 实际是有光照的 Forward Lit Ramp
            Name "ForwardRampLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM

                #pragma vertex vert
                #pragma fragment frag

                Varyings vert(Attributes input)
                {
                    VertexPositionInputs vertexInput      = GetVertexPositionInputs(input.positionOS.xyz);
                    VertexNormalInputs   vertexNormalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                    real sign = input.tangentOS.w * GetOddNegativeScale();

                    Varyings output;
                    output.uv         = TRANSFORM_TEX(input.uv, _BaseMap);
                    output.positionCS = vertexInput.positionCS;
                    output.positionWS = vertexInput.positionWS;
                    output.normalWS   = vertexNormalInput.normalWS;
                    output.tangentWS  = real4(vertexNormalInput.tangentWS, sign);

                    return output;
                }

                half4 frag(Varyings input) : SV_Target
                {
                    // 世界空间位置
                    real3 positionWS = input.positionWS;

                    // ==== Normal Map: Tangent Space to World Space ====
                    real3 normalTS = UnpackNormalScale(
                        SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv),
                        _BumpScale
                    );

                    real  sgn = input.tangentWS.w;                 // +1 or -1
                    real3 N   = normalize(input.normalWS.xyz);
                    real3 T   = normalize(input.tangentWS.xyz);
                    real3 B   = normalize(sgn * cross(N, T));

                    real3x3 TBN = real3x3(T, B, N);
                    real3 normalWS = normalize(mul(normalTS, TBN));   // 转换到世界空间并归一化

                    // ==== 主光源 ====
                    Light mainLight = GetMainLight();
                    real3 lightColor = mainLight.color;

                    // URP 的 direction 通常是从光指向物体，这里取反得到“指向光源”的方向
                    real3 lightDir = normalize(-mainLight.direction);

                    // Albedo（贴图 * 颜色）
                    real4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;

                    // ==== 环境光（简单常量环境光）====
                    real3 ambientColor = real3(0.03, 0.03, 0.03);
                    real4 ambient      = real4(ambientColor, 1.0) * albedo;

                    // ==== Ramp Diffuse ====
                    real lambert = saturate(dot(normalWS, lightDir));

                    // 使用 lambert 作为 U 采样 ramp；V 可以用 0.5 或 lambert，看你的贴图设计
                    real2 rampUV = real2(lambert, lambert);
                    real4 rampColor = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, rampUV);

                    real4 diffuse = rampColor * real4(lightColor, 1.0) * albedo;

                    // ==== Specular ====
                    real3 viewDir = SafeNormalize(GetCameraPositionWS() - positionWS);
                    real3 h       = SafeNormalize(viewDir + lightDir);

                    real  NdotH   = saturate(dot(normalWS, h));
                    real  specPow = pow(NdotH, _Smoothness);

                    real3 specColor = specPow * lightColor * saturate(_SpecColor.rgb);
                    real4 specular  = real4(specColor, 0.0);

                    // 合成最终颜色
                    real4 color = ambient + diffuse + specular;
                    color.a = 1.0;

                    return color;
                }

            ENDHLSL
        }
    }
}
