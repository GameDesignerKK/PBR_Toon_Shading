using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;

public class CelHairShadow_Test : ScriptableRendererFeature
{
    [SerializeField] CelHairShadow_TestSettings settings;
    CelHairShadow_TestPass m_ScriptablePass;

    public override void Create()
    {
        m_ScriptablePass = new CelHairShadow_TestPass(settings);
        m_ScriptablePass.renderPassEvent = settings.passEvent;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (settings.material != null)
            renderer.EnqueuePass(m_ScriptablePass);
    }

    [Serializable]
    public class CelHairShadow_TestSettings
    {
        public Color hairShadowColor = Color.black;
        [Range(0, 0.1f)]
        public float offset = 0.02f;
        [Range(0, 255)]
        public int stencilReference = 128;  
        public CompareFunction stencilComparison = CompareFunction.Equal;  

        public RenderPassEvent passEvent = RenderPassEvent.BeforeRenderingTransparents;
        public LayerMask hairLayer = -1;
        [Range(1000, 5000)]
        public int queueMin = 2000;
        [Range(1000, 5000)]
        public int queueMax = 3000;
        public Material material;
    }

    class CelHairShadow_TestPass : ScriptableRenderPass
    {
        readonly CelHairShadow_TestSettings settings;
        public ShaderTagId shaderTag = new ShaderTagId("UniversalForward");
        FilteringSettings filtering;

        public CelHairShadow_TestPass(CelHairShadow_TestSettings settings)
        {
            this.settings = settings;

            RenderQueueRange queue = new RenderQueueRange
            {
                lowerBound = Mathf.Min(settings.queueMin, settings.queueMax),
                upperBound = Mathf.Max(settings.queueMin, settings.queueMax)
            };

            filtering = new FilteringSettings(queue, settings.hairLayer);
        }

        private class PassData
        {
            public RendererListHandle rendererList;
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            var renderingData = frameData.Get<UniversalRenderingData>();
            var cameraData = frameData.Get<UniversalCameraData>();
            var lightData = frameData.Get<UniversalLightData>();
            var resourceData = frameData.Get<UniversalResourceData>();

            if (settings.material == null)
                return;

            using (var builder = renderGraph.AddRasterRenderPass<PassData>("Hair Shadow Pass", out var passData))
            {
                // ============ 1. 设置材质参数 ============
                settings.material.SetColor("_Color", settings.hairShadowColor);
                settings.material.SetFloat("_Offset", settings.offset);
                settings.material.SetInt("_StencilRef", settings.stencilReference);
                settings.material.SetInt("_StencilComp", (int)settings.stencilComparison);

                // ============ 2. 获取主光方向 ============
                int mainLightIndex = lightData.mainLightIndex;
                Vector2 lightDirSS = Vector2.down;

                if (mainLightIndex >= 0 && mainLightIndex < lightData.visibleLights.Length)
                {
                    VisibleLight mainLight = lightData.visibleLights[mainLightIndex];
                    Vector3 lightDirWS = -mainLight.localToWorldMatrix.GetColumn(2);
                    lightDirWS.Normalize();

                    Matrix4x4 worldToView = cameraData.GetViewMatrix();
                    Vector3 lightDirVS = worldToView.MultiplyVector(lightDirWS);
                    lightDirSS = new Vector2(lightDirVS.x, lightDirVS.y).normalized;
                }

                settings.material.SetVector("_LightDirSS", lightDirSS);

                // ============ 3. 设置渲染目标 ============
                builder.SetRenderAttachmentDepth(resourceData.activeDepthTexture, AccessFlags.ReadWrite);
                builder.SetRenderAttachment(resourceData.activeColorTexture, 0, AccessFlags.Write);

                // ============ 4. 创建 RendererList ============
                var sorting = cameraData.defaultOpaqueSortFlags;
                var drawSettings = RenderingUtils.CreateDrawingSettings(
                    shaderTag, renderingData, cameraData, lightData, sorting);

                drawSettings.overrideMaterial = settings.material;
                drawSettings.overrideMaterialPassIndex = 0;

                RendererListParams rlParams = new RendererListParams(
                    renderingData.cullResults,
                    drawSettings,
                    filtering);

                var rendererList = renderGraph.CreateRendererList(rlParams);
                passData.rendererList = rendererList;
                builder.UseRendererList(rendererList);

                // ============ 5. 执行绘制 ============
                builder.SetRenderFunc((PassData data, RasterGraphContext ctx) =>
                {
                    ctx.cmd.DrawRendererList(data.rendererList);
                });
            }
        }
    }
}