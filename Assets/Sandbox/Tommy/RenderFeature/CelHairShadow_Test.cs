using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;

public class CelHairShadow_Stencil : ScriptableRendererFeature
{
    [Serializable]
    public class Setting
    {
        [Header("Visual")]
        public Color hairShadowColor = Color.black;

        [Range(0, 0.1f)]
        public float offset = 0.02f;

        [Header("Stencil")]
        [Range(0, 255)]
        public int stencilReference = 128;

        public CompareFunction stencilComparison = CompareFunction.Equal;

        [Header("Render Settings")]
        public RenderPassEvent passEvent = RenderPassEvent.BeforeRenderingTransparents;

        public LayerMask hairLayer = -1;

        [Range(1000, 5000)]
        public int queueMin = 2000;

        [Range(1000, 5000)]
        public int queueMax = 3000;

        [Header("Material")]
        public Material material;
    }

    public Setting setting = new Setting();

    class CustomRenderPass : ScriptableRenderPass
    {
        public ShaderTagId shaderTag = new ShaderTagId("UniversalForward");
        public Setting setting;
        FilteringSettings filtering;

        public CustomRenderPass(Setting setting)
        {
            this.setting = setting;

            RenderQueueRange queue = new RenderQueueRange
            {
                lowerBound = Mathf.Min(setting.queueMax, setting.queueMin),
                upperBound = Mathf.Max(setting.queueMax, setting.queueMin)
            };

            filtering = new FilteringSettings(queue, setting.hairLayer);
        }

        // Unity 6 RenderGraph API
        private class PassData
        {
            internal RendererListHandle rendererList;
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            // 检查材质
            if (setting.material == null)
                return;

            // 获取渲染数据
            var renderingData = frameData.Get<UniversalRenderingData>();
            var cameraData = frameData.Get<UniversalCameraData>();
            var lightData = frameData.Get<UniversalLightData>();
            var resourceData = frameData.Get<UniversalResourceData>();

            using (var builder = renderGraph.AddRasterRenderPass<PassData>("Hair Shadow Pass", out var passData))
            {
                // ============ 配置材质参数（替代原来的 Configure） ============
                setting.material.SetColor("_Color", setting.hairShadowColor);
                setting.material.SetInt("_StencilRef", setting.stencilReference);
                setting.material.SetInt("_StencilComp", (int)setting.stencilComparison);
                setting.material.SetFloat("_Offset", setting.offset);

                // ============ 获取主光源方向并转换到相机空间 ============
                Vector2 lightDirSS = Vector2.down;

                if (lightData.mainLightIndex >= 0 && lightData.mainLightIndex < lightData.visibleLights.Length)
                {
                    var mainLight = lightData.visibleLights[lightData.mainLightIndex];

                    // 获取光源方向（世界空间）
                    Vector3 lightDirWS = -mainLight.localToWorldMatrix.GetColumn(2);

                    // 转换到相机空间（View Space）
                    Matrix4x4 worldToView = cameraData.GetViewMatrix();
                    Vector3 lightDirVS = worldToView.MultiplyVector(lightDirWS);

                    // 取 xy 分量作为屏幕空间方向
                    lightDirSS = new Vector2(lightDirVS.x, lightDirVS.y);
                    if (lightDirSS.sqrMagnitude > 0.0001f)
                    {
                        lightDirSS.Normalize();
                    }
                }

                setting.material.SetVector("_LightDirSS", lightDirSS);

                // ============ 设置渲染目标 ============
                // 写入颜色缓冲和读取深度缓冲
                builder.SetRenderAttachment(resourceData.activeColorTexture, 0, AccessFlags.Write);
                builder.SetRenderAttachmentDepth(resourceData.activeDepthTexture, AccessFlags.Read);

                // ============ 创建 RendererList（替代原来的 DrawRenderers） ============
                var sortingCriteria = cameraData.defaultOpaqueSortFlags;
                var drawSettings = RenderingUtils.CreateDrawingSettings(
                    shaderTag,
                    renderingData,
                    cameraData,
                    lightData,
                    sortingCriteria
                );

                drawSettings.overrideMaterial = setting.material;
                drawSettings.overrideMaterialPassIndex = 0;

                var rlParams = new RendererListParams(renderingData.cullResults, drawSettings, filtering);
                var rendererList = renderGraph.CreateRendererList(rlParams);

                passData.rendererList = rendererList;
                builder.UseRendererList(rendererList);

                // ============ 执行渲染（替代原来的 Execute） ============
                builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
                {
                    context.cmd.DrawRendererList(data.rendererList);
                });
            }
        }
    }

    CustomRenderPass m_ScriptablePass;

    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass(setting);
        m_ScriptablePass.renderPassEvent = setting.passEvent;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (setting.material != null)
            renderer.EnqueuePass(m_ScriptablePass);
    }
}