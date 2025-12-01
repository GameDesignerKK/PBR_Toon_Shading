Shader "Tommy/NormalMapping"
{
    Properties {
        _MainTex("Albedo", 2D) = "white" {}
        _NormalMap("Normal Map", 2D) = "bump" {}
        _NormalScale("Normal Scale", Range(0,2)) = 1
    }
    
    SubShader {
        Tags { "RenderPipeline"="UniversalPipeline" }
        
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        ENDHLSL
        
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            struct Attributes {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
            };
            
            struct Varyings {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 tangentWS : TEXCOORD2;
            };
            
            sampler2D _MainTex;
            sampler2D _NormalMap;
            float _NormalScale;
            
            Varyings vert(Attributes IN) {
                Varyings OUT;
                // Vertex transofrmation
                VertexPositionInputs posInput = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionCS = posInput.positionCS;
                OUT.uv = IN.uv;
                
                // NORMAL and TANGENT transformation
                VertexNormalInputs normInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                OUT.normalWS = normInput.normalWS;
                OUT.tangentWS = float4(normInput.tangentWS, IN.tangentOS.w);
                
                return OUT;
            }
            
            half4 frag(Varyings IN) : SV_Target {
                // Normal mapping Sampling
                float4 normalSample = tex2D(_NormalMap, IN.uv);
                float3 tangentNormal = UnpackNormalScale(normalSample, _NormalScale);
                
                // TBN Matrix Construction
                float3 normalWS = IN.normalWS;
                float3 tangentWS = IN.tangentWS.xyz;
                float3 bitangentWS = cross(normalWS, tangentWS) * IN.tangentWS.w;
                float3x3 TBN = float3x3(tangentWS, bitangentWS, normalWS);
                
                // Convert to World Space Normal
                float3 finalNormal = mul(tangentNormal, TBN);
                
                // Lighting calculation (simple diffuse lighting)
                Light mainLight = GetMainLight();
                float NdotL = saturate(dot(finalNormal, mainLight.direction));
                half3 albedo = tex2D(_MainTex, IN.uv).rgb;
                half3 diffuse = albedo * NdotL * mainLight.color;
                
                return half4(diffuse, 1);
            }
            ENDHLSL
        }
    }
}
