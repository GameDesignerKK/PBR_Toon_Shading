Shader "YK/HairShader"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _HighLightMask("HighLightMask", 2D) = "white"{}
        [HDR]_SpecularColor("Specular Color", Color) = (1, 1, 1, 1)
        _Shininess("Shininess", Range(1, 128)) = 8
        _ShadowColor("ShadowColor",Color) = (0,0,0,1)
        _ShadowEdgeA("ShadowEdgeA", Range(0,1)) = 0.45
        _ShadowEdgeB("ShadowEdgeB", Range(0,1)) = 0.5
        [MainTexture] _BaseMap("Base Map", 2D) = "white"{}
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "LightMode" = "UniversalForward" "Queue" = "Geometry" }
        //#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            //#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"

            half3 SampleSH_L1(half3 normalWS)
            {
                //  Sample Spherical Harmonics L1
                return SHEvalLinearL0L1(normalWS, unity_SHAr, unity_SHAg, unity_SHAb);
            }

            half3 SampleSH_OnlyL0(half3 normalWS)
            {
                // 只取 L0 常数项（unity_SHAr/g/b 的 w 分量）
                return half3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);
            }

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float4 normalOS : NORMAL;
                float4 tangentOS  : TANGENT;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                half3 normalWS : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
                half3 diffuseGI : TEXCOORD3;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_HighLightMask);
            SAMPLER(sampler_HighLightMask);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half4 _SpecularColor;
                half _Shininess;
                float _ShadowEdgeA;
                float _ShadowEdgeB;
                half4 _ShadowColor;
                float4 _BaseMap_ST;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                //  Transform position from Object Space to Homogeneous Clip Space
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                //  Transform normal from Object Space to World Space
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS.xyz);
                //  Transform position from Object Space to World Space
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);

                //  Transform UVs
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);

                //  Sample ambient diffuse from Spherical Harmonics (only L0)
                OUT.diffuseGI = SampleSH_L1(OUT.normalWS);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                //  Normalize the interpolated normal
                half3 normalWS_n = normalize(IN.normalWS);
                //  Get Main Light data
                Light mainLight = GetMainLight();
                //  Calculate normalized light direction and view direction
                half3 lightDirWS_n = normalize(mainLight.direction);
                half3 viewDirWS_n = normalize(_WorldSpaceCameraPos - IN.positionWS);

                //  Lambert
                //half NdotL = saturate(dot(normalWS_n, lightDirWS_n));
                half NdotL = dot(normalWS_n, lightDirWS_n)*0.5 + 0.5;
                //  Light and Shadow Binarization
                float shadowStep = saturate(smoothstep(_ShadowEdgeA,_ShadowEdgeB,NdotL));
                //  Calculate diffuse term
                half3 diffuse = lerp(_ShadowColor.rgb, mainLight.color * _BaseColor.rgb, shadowStep);

                //  Calculate light reflection direction
                half3 reflectDirWS = reflect(-lightDirWS_n, normalWS_n);
                //  Calculate VdotR
                half VdotR = saturate(dot(viewDirWS_n, reflectDirWS));
                //  Calculate specular term
                half3 specular = mainLight.color * _SpecularColor.rgb * pow(VdotR, _Shininess);

                //  Sample HighLightMask
                half highLightMask = SAMPLE_TEXTURE2D(_HighLightMask, sampler_HighLightMask, IN.uv).r;
                specular *= highLightMask;

                // Calculate ambient term
                half3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * _BaseColor.rgb;

                //  Sample texture
                half4 texColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;

                //  Combine terms
                half3 finalColor = texColor.rgb * (diffuse + ambient + specular);

                //  Add Diffuse Global Illumination
                finalColor.rgb += IN.diffuseGI;

                return half4(finalColor,1.0);
            }
            ENDHLSL
        }
    }
}
