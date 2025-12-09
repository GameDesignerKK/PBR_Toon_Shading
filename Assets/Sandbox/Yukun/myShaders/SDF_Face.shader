Shader "YK/SDF_Face"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _ShadowColor("ShadowColor",Color) = (0,0,0,1)
        _SDFMap("SDF Face Map", 2D) = "white"{}
        [MainTexture] _BaseMap("Base Map", 2D) = "white"{}

        [Header(Stencil)]
        _StencilRef ("Stencil Ref", Range(0, 255)) = 128

        [Enum(UnityEngine.Rendering.CompareFunction)]
        _StencilComp ("Stencil Comp", Float) = 8

        _HairShadowDistace ("HairShadowDistance", Float) = 1
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        ENDHLSL

        Pass
        {
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"

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
                float4 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                half3 normalWS : TEXCOORD1;
                half3 diffuseGI : TEXCOORD2;
                float4 positionSS : TEXCOORD3;
                float posNDCw: TEXCOORD4;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_SDFMap);
            SAMPLER(sampler_SDFMap);
            TEXTURE2D(_HairSoildColor);
            SAMPLER(sampler_HairSoildColor);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half4 _ShadowColor;
                float4 _BaseMap_ST;
                float4 _SDFMap_ST;
                float _HairShadowDistace;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                //  Transform normal from Object Space to World Space
                OUT.normalWS = normalize(TransformObjectToWorldNormal(IN.normalOS.xyz));
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);

                OUT.diffuseGI = SampleSH_L1(OUT.normalWS);

                OUT.positionSS = ComputeScreenPos(OUT.positionHCS);

                OUT.posNDCw = OUT.positionHCS.w;

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


                //  刘海投影部分！
                float2 screenPos = IN.positionSS.xy / IN.positionSS.w;
                //获取屏幕信息
                float4 scaledScreenParams = GetScaledScreenParams();
                //计算View Space的光照方向
                float3 viewSpaceLightDir = normalize(TransformWorldToViewDir(mainLight.direction)) * (1 / IN.posNDCw);
                //计算采样点，其中_HairShadowDistace用于控制采样距离
                float2 samplingPoint = screenPos + _HairShadowDistace * viewSpaceLightDir.xy * float2(1 / scaledScreenParams.x, 1 / scaledScreenParams.y);
                //若采样点在阴影区内,则取得的value为1,作为阴影的话还得用1 - value;
                float hairShadow = SAMPLE_TEXTURE2D(_HairSoildColor, sampler_HairSoildColor, samplingPoint);

                float shadowArea = hairShadow + (1-sdf_faceShadow);
                shadowArea = 1 - step(0.5,shadowArea);

                half4 baseMap_color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
                half4 LiangMian_color = _BaseColor * half4(mainLight.color,1.0);
                half4 AnMian_color = _ShadowColor;
                half4 color = baseMap_color * lerp(AnMian_color, LiangMian_color, shadowArea);

                //  Add Diffuse Global Illumination
                color.rgb += IN.diffuseGI * baseMap_color;

                return color;
            }
            ENDHLSL
        }

        Pass
        {
            Name "FaceDepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ColorMask 0

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
            };
            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                return half4(0,0,0,1);
            }
            ENDHLSL
        }
    }
}
