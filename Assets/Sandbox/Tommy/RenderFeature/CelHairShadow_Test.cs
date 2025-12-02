using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;


public class CelHairShadow_Test : ScriptableRendererFeature
{
    [SerializeField] CelHairShadow_TestSettings settings;
    CelHairShadow_TestPass m_ScriptablePass;


    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new CelHairShadow_TestPass(settings);

        // Configures where the render pass should be injected.
        m_ScriptablePass.renderPassEvent = RenderPassEvent.BeforeRenderingOpaques;

        // You can request URP color texture and depth buffer as inputs by uncommenting the line below,
        // URP will ensure copies of these resources are available for sampling before executing the render pass.
        // Only uncomment it if necessary, it will have a performance impact, especially on mobiles and other TBDR GPUs where it will break render passes.
        //m_ScriptablePass.ConfigureInput(ScriptableRenderPassInput.Color | ScriptableRenderPassInput.Depth);

        // You can request URP to render to an intermediate texture by uncommenting the line below.
        // Use this option for passes that do not support rendering directly to the backbuffer.
        // Only uncomment it if necessary, it will have a performance impact, especially on mobiles and other TBDR GPUs where it will break render passes.
        //m_ScriptablePass.requiresIntermediateTexture = true;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_ScriptablePass);
    }

    // Use this class to pass around settings from the feature to the pass
    [Serializable]
    public class CelHairShadow_TestSettings
    {
        public Color hairShadowColor;
        [Range(0, 0.1f)]
        public float offset = 0.02f;
        [Range(0, 255)]
        public int stencilReference = 1;
        public CompareFunction stencilComparison;

        public RenderPassEvent passEvent = RenderPassEvent.BeforeRenderingTransparents;
        public LayerMask hairLayer;
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

        // This class stores the data needed by the RenderGraph pass.
        // It is passed as a parameter to the delegate function that executes the RenderGraph pass.
        private class PassData
        {
            public RendererListHandle rendererList;
            public Material material;
            public Vector2 lightDirSS;
        }

        // This static method is passed as the RenderFunc delegate to the RenderGraph render pass.
        // It is used to execute draw commands.
        static void ExecutePass(PassData data, RasterGraphContext context)
        {
            
        }

        // RecordRenderGraph is where the RenderGraph handle can be accessed, through which render passes can be added to the graph.
        // FrameData is a context container through which URP resources can be accessed and managed.
        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            // 从 frameData 里拿各种数据
            var renderingData = frameData.Get<UniversalRenderingData>();
            var cameraData = frameData.Get<UniversalCameraData>();
            var lightData = frameData.Get<UniversalLightData>();
            var resourceData = frameData.Get<UniversalResourceData>();

            // This adds a raster render pass to the graph, specifying the name and the data type that will be passed to the ExecutePass function.
            using (var builder = renderGraph.AddRasterRenderPass<PassData>(passName, out var passData))
            {
                // ============ 1. 设置材质参数（原来 Configure 里的逻辑） ============

                if (settings.material == null)
                    return;

                settings.material.SetColor("_Color", settings.hairShadowColor);
                settings.material.SetFloat("_Offset", settings.offset);
                settings.material.SetInt("_StencilRef", settings.stencilReference);
                settings.material.SetInt("_StencilComp", (int)settings.stencilComparison);

                // 从 UniversalLightData 拿主光方向（世界空间）
                int mainLightIndex = lightData.mainLightIndex;
                Vector2 lightDirSS = Vector2.down; // 默认值

                if (mainLightIndex >= 0 && mainLightIndex < lightData.visibleLights.Length)
                {
                    VisibleLight mainLight = lightData.visibleLights[mainLightIndex];

                    // Directional Light 的 forward 在第 2 列，取反得到“来自光的方向”
                    Vector3 lightDirWS = -mainLight.localToWorldMatrix.GetColumn(2);
                    lightDirWS.Normalize();

                    // 转到相机空间
                    Matrix4x4 worldToView = cameraData.GetViewMatrix(0);
                    Vector3 lightDirVS = worldToView.MultiplyVector(lightDirWS);

                    // 取 xy 当作你原来用的“屏幕空间方向”（你原来的代码也是这么用的）
                    lightDirSS = new Vector2(lightDirVS.x, lightDirVS.y).normalized;
                }

                settings.material.SetVector("_LightDirSS", lightDirSS);

                passData.material = settings.material;
                passData.lightDirSS = lightDirSS;

                // ============ 2. 深度缓冲（ZTest 用） ============

                // 我们不创建颜色 RT，这个 Pass 只利用当前的颜色 RT + 深度
                // 如果你的 Shader 是只写 Stencil、不改颜色，就是直接在现有颜色缓冲上操作
                builder.SetRenderAttachmentDepth(resourceData.activeDepthTexture, AccessFlags.ReadWrite);
                builder.SetRenderAttachment(resourceData.activeColorTexture, 0);

                // ============ 3. 创建 RendererList（相当于旧版 DrawRenderers 的参数） ============

                var sorting = cameraData.defaultOpaqueSortFlags;
                var drawSettings = RenderingUtils.CreateDrawingSettings(
                    shaderTag, renderingData, cameraData, lightData, sorting);

                drawSettings.overrideMaterial = settings.material;
                drawSettings.overrideMaterialPassIndex = 0; // 只用材质的第 0 个 Pass

                RendererListParams rlParams = new RendererListParams(
                    renderingData.cullResults,
                    drawSettings,
                    filtering);

                var rendererList = renderGraph.CreateRendererList(rlParams);
                passData.rendererList = rendererList;

                builder.UseRendererList(rendererList);

                // ============ 4. 真正绘制（替代 Execute 里调用 context.DrawRenderers） ============

                builder.SetRenderFunc((PassData data, RasterGraphContext ctx) =>
                {
                    // 不清屏，只在现有 RT 上画（Stencil/颜色由 shader 决定）
                    ctx.cmd.DrawRendererList(data.rendererList);
                });
            }
        }
    }
}
