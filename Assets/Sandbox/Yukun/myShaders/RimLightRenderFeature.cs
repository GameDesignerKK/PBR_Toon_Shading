using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;

public class RimLightRenderFeature : ScriptableRendererFeature
{
    //[SerializeField] RimLightRenderFeatureSettings settings;
    public RimLightRenderFeatureSettings settings = new RimLightRenderFeatureSettings();
    RimLightRenderFeaturePass rimLightPass;

    /// <inheritdoc/>
    public override void Create()
    {
        rimLightPass = new RimLightRenderFeaturePass("RimLight Pass",settings);
        rimLightPass.renderPassEvent = settings.passEvent;

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
        if (settings.rimLightMaterial == null)
        {
            return;
        }
        renderer.EnqueuePass(rimLightPass);
    }

    // Use this class to pass around settings from the feature to the pass
    [Serializable]
    public class RimLightRenderFeatureSettings
    {
        [Header("渲染时机")]
        public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingOpaques;

        [Tooltip("哪些Layer的物体会被这个 RimLight 重新绘制")]
        public LayerMask layerMask = ~0;

        [Tooltip("使用你已经写好的 RimLight Shader 创建出来的材质")]
        public Material rimLightMaterial;

        [Header("可选：Shader LightMode Tag")]
        [Tooltip("通常用 UniversalForward / SRPDefaultUnlit，取决于Shader 里的 LightMode")]
        public string lightModeTag = "UniversalForward";

        [Header("可选：只画不透明还是透明")]
        public bool onlyOpaque = true;
    }

    class RimLightRenderFeaturePass : ScriptableRenderPass
    {
        private string profilerTag;
        readonly RimLightRenderFeatureSettings settings;
        private ShaderTagId shaderTagId;
        private Material rimLightMaterial;
        private FilteringSettings filteringSettings;

        public RimLightRenderFeaturePass(string profilerTag, RimLightRenderFeatureSettings settings)
        {
            //this.profilerTag = profilerTag;
            this.settings = settings;

            //renderPassEvent = settings.passEvent;
            //rimLightMaterial = settings.rimLightMaterial;
            //shaderTagId = new ShaderTagId(settings.lightModeTag);

            //var queueRange = settings.onlyOpaque? RenderQueueRange.opaque : RenderQueueRange.all;
            //filteringSettings = new FilteringSettings(queueRange, settings.layerMask);
        }

        // This class stores the data needed by the RenderGraph pass.
        // It is passed as a parameter to the delegate function that executes the RenderGraph pass.
        private class PassData
        {
            public RendererListHandle rendererList;
        }

        // This static method is passed as the RenderFunc delegate to the RenderGraph render pass.
        // It is used to execute draw commands.
        static void ExecutePass(PassData data, RasterGraphContext context)
        {
            context.cmd.DrawRendererList(data.rendererList);
        }

        // RecordRenderGraph is where the RenderGraph handle can be accessed, through which render passes can be added to the graph.
        // FrameData is a context container through which URP resources can be accessed and managed.
        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            if (settings.rimLightMaterial == null)
            {
                return;
            }
            const string passName = "RimLight Pass";

            // This adds a raster render pass to the graph, specifying the name and the data type that will be passed to the ExecutePass function.
            using (var builder = renderGraph.AddRasterRenderPass<PassData>(passName, out var passData))
            {
                //  YK Script
                                // Use this scope to set the required inputs and outputs of the pass and to
                // setup the passData with the required properties needed at pass execution time.

                // Make use of frameData to access resources and camera data through the dedicated containers.
                // Eg:
                // UniversalCameraData cameraData = frameData.Get<UniversalCameraData>();
                var renderingData = frameData.Get<UniversalRenderingData>();
                var cameraData = frameData.Get<UniversalCameraData>();
                var lightData = frameData.Get<UniversalLightData>();
                UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();

                // 排序方式 & 渲染队列
                SortingCriteria sortFlags = settings.onlyOpaque ?
                    cameraData.defaultOpaqueSortFlags : SortingCriteria.CommonTransparent;

                RenderQueueRange queueRange = settings.onlyOpaque ?
                    RenderQueueRange.opaque : RenderQueueRange.all;

                // 过滤设置：根据渲染队列 + LayerMask
                FilteringSettings filterSettings = new FilteringSettings(queueRange, settings.layerMask);

                // 只匹配指定 LightMode Tag 的 Pass
                ShaderTagId shaderTagId = new ShaderTagId(settings.lightModeTag);

                // 创建 DrawingSettings（Unity 提供的工具函数）
                DrawingSettings drawSettings =
                    RenderingUtils.CreateDrawingSettings(shaderTagId,
                        renderingData,
                        cameraData,
                        lightData,
                        sortFlags);

                // 用 RimLight Material 覆盖原材质
                drawSettings.overrideMaterial = settings.rimLightMaterial;

                // 基于剔除结果 + drawing/filter 设置，创建 RendererList
                RendererListParams rendererListParams =
                    new RendererListParams(renderingData.cullResults, drawSettings, filterSettings);

                // 转成 RenderGraph 用的 handle
                passData.rendererList = renderGraph.CreateRendererList(rendererListParams);

                // 声明这个 Pass 会用到这份 RendererList
                builder.UseRendererList(passData.rendererList);

                // Setup pass inputs and outputs through the builder interface.
                // Eg:
                // builder.UseTexture(sourceTexture);
                // TextureHandle destination = UniversalRenderer.CreateRenderGraphTexture(renderGraph, cameraData.cameraTargetDescriptor, "Destination Texture", false);

                // 把当前摄像机的颜色 & 深度贴图作为 RenderTarget
                // This sets the render target of the pass to the active color texture. Change it to your own render target as needed.
                builder.SetRenderAttachment(resourceData.activeColorTexture, 0);
                builder.SetRenderAttachmentDepth(resourceData.activeDepthTexture, AccessFlags.Write);

                // Assigns the ExecutePass function to the render pass delegate. This will be called by the render graph when executing the pass.
                builder.SetRenderFunc((PassData data, RasterGraphContext context) => ExecutePass(data, context));
            }
        }
    }
}
