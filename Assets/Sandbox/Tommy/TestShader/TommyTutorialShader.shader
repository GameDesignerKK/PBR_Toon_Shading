Shader "Tommy/TutorialShader"
{
	Properties //用于在材质面板中显示和编辑的属性
	{

	}

	Subshader //用于不同配置的子着色器 (高配)
	{
		LOD 600
		pass
		{
			HLSLPROGRAM

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			#pragma vertex vert //顶点着色器入口函数从三维空间转换到投影空间
			#pragma fragment frag //顶点构成的三角形内部的每个显示在屏幕上的像素的着色

			struct appdata //顶点数据
			{
				//字段类型 字段名称 ： 字段语义
				float3 pos : POSITION;
			};

			struct v2f //顶点构成的三角形内部的每个显示在屏幕上的像素的数据
			{
				float4 pos : SV_POSITION;
			};

			v2f vert(appdata IN)
			{
				v2f OUT = (v2f)0;

				OUT.pos = mul(UNITY_MATRIX_MVP , float4(IN.pos,1));
				return OUT;
			}

			float4 frag(v2f IN) : SV_TARGET
			{
				return float4(1,0,0,1);
			}

			ENDHLSL
		}
	}

	Subshader //用于不同配置的子着色器 (低配)
	{
		LOD 200
		pass
		{
			HLSLPROGRAM

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			#pragma vertex vert //顶点着色器入口函数从三维空间转换到投影空间
			#pragma fragment frag //顶点构成的三角形内部的每个显示在屏幕上的像素的着色

			struct appdata //顶点数据
			{
				//字段类型 字段名称 ： 字段语义
				float3 pos : POSITION;
			};

			struct v2f //顶点构成的三角形内部的每个显示在屏幕上的像素的数据
			{
				float4 pos : SV_POSITION;
			};

			v2f vert(appdata IN)
			{
				v2f OUT = (v2f)0;

				OUT.pos = mul(UNITY_MATRIX_MVP , float4(IN.pos,1));
				return OUT;
			}

			float4 frag(v2f IN) : SV_TARGET
			{
				return float4(0,1,0,1);
			}

			ENDHLSL
		}
	}

	Fallback "Hidden/Universal Render Pipeline/FallbackError" //填写故障情况下的最保守shader的pass路径和名称
}
