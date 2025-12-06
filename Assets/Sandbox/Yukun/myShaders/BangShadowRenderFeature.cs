using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;

public class BangShadowRenderFeature : ScriptableRendererFeature
{
    public BangShadowRenderFeatureSettings settings = new BangShadowRenderFeatureSettings();
    BangShadowRenderFeaturePass m_ScriptablePass;
    // 全局纹理 ID（和 Shader 里采样的名字保持一致）
    static readonly int HairSolidColorID = Shader.PropertyToID("_HairSoildColor");

    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new BangShadowRenderFeaturePass(settings);

        // Configures where the render pass should be injected.
        m_ScriptablePass.renderPassEvent = settings.passEvent;

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
        if(settings.material == null)
        {
            return;
        }
        renderer.EnqueuePass(m_ScriptablePass);
    }

    // Use this class to pass around settings from the feature to the pass
    [Serializable]
    public class BangShadowRenderFeatureSettings
    {
        public RenderPassEvent passEvent = RenderPassEvent.BeforeRenderingOpaques;

        //标记头发模型的Layer
        public LayerMask hairLayer;
        //标记脸部模型的Layer
        public LayerMask faceLayer;

        //Render Queue的设置
        [Range(1000, 5000)]
        public int queueMin = 2000;
        [Range(1000, 5000)]
        public int queueMax = 3000;

        //使用的Material
        public Material material;
    }

    class BangShadowRenderFeaturePass : ScriptableRenderPass
    {
        readonly BangShadowRenderFeatureSettings settings;

        //用于储存之后申请来的RT的ID
        public int soildColorID = 0;

        //  ShaderTagId，用于构建RendererList
        public ShaderTagId shaderTag = new ShaderTagId("UniversalForward");
        public ShaderTagId shaderTagFace = new ShaderTagId("DepthOnly");

        FilteringSettings filtering0;
        FilteringSettings filtering1;

        public BangShadowRenderFeaturePass(BangShadowRenderFeatureSettings settings)
        {
            this.settings = settings;

            //创建queue以用于两个FilteringSettings的赋值
            RenderQueueRange queue = new RenderQueueRange();
            queue.lowerBound = Mathf.Min(settings.queueMax, settings.queueMin);
            queue.upperBound = Mathf.Max(settings.queueMax, settings.queueMin);

            filtering0 = new FilteringSettings(queue, settings.faceLayer);
            filtering1 = new FilteringSettings(queue, settings.hairLayer);
        }

        // This class stores the data needed by the RenderGraph pass.
        // It is passed as a parameter to the delegate function that executes the RenderGraph pass.
        private class PassData
        {
            public RendererListHandle rendererList0;
            public RendererListHandle rendererList1;
        }

        // This static method is passed as the RenderFunc delegate to the RenderGraph render pass.
        // It is used to execute draw commands.
        static void ExecutePass(PassData data, RasterGraphContext context)
        {
            context.cmd.DrawRendererList(data.rendererList0);
            context.cmd.DrawRendererList(data.rendererList1);
        }

        // RecordRenderGraph is where the RenderGraph handle can be accessed, through which render passes can be added to the graph.
        // FrameData is a context container through which URP resources can be accessed and managed.
        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            const string passName = "Hair Solid Color Pass";

            // This adds a raster render pass to the graph, specifying the name and the data type that will be passed to the ExecutePass function.
            using (var builder = renderGraph.AddRasterRenderPass<PassData>(passName, out var passData))
            {
                // 从 frameData 里取各种渲染数据
                var renderingData = frameData.Get<UniversalRenderingData>();
                var cameraData = frameData.Get<UniversalCameraData>();
                var resourceData = frameData.Get<UniversalResourceData>();
                var lightData = frameData.Get<UniversalLightData>();

                // ★ 1. 创建一个和相机 color 一样规格的临时 RT Description，用来存放刘海纯色 buffer
                TextureDesc desc = resourceData.activeColorTexture.GetDescriptor(renderGraph);
                desc.name = "HairSolidColorRT";
                desc.clearBuffer = true;          // 相当于老版SRF的 ConfigureClear
                desc.clearColor = Color.black;   // 清成全黑
                soildColorID = HairSolidColorID;

                // 在 RenderGraph 里创建这个 RT
                TextureHandle hairTexture = renderGraph.CreateTexture(desc);
                // 把这个 RT 当作颜色输出目标
                builder.SetRenderAttachment(hairTexture, 0, AccessFlags.Write);
                // 深度使用当前相机的 depth，这样深度测试正常
                builder.SetRenderAttachmentDepth(resourceData.activeDepthTexture, AccessFlags.ReadWrite);

                // ★ 2. 构建两套 RendererList（对应 Pass0写入face深度 / Pass1画头发纯色buffer）
                var sortFlags = cameraData.defaultOpaqueSortFlags;

                // 第一次绘制（overrideMaterialPassIndex = 0）
                DrawingSettings drawSettings0 = CreateDrawingSettings(shaderTagFace, renderingData, cameraData, lightData, sortFlags);
                drawSettings0.overrideMaterial = settings.material;
                drawSettings0.overrideMaterialPassIndex = 0;

                //  create RendererListParams for first draw (face depth)
                var rlParams0 = new RendererListParams(renderingData.cullResults, drawSettings0, filtering0);
                // 转成 RenderGraph 用的 handle
                passData.rendererList0 = renderGraph.CreateRendererList(rlParams0);
                // 声明这个 Pass 会用到这份 RendererList0
                builder.UseRendererList(passData.rendererList0);

                // 第二次绘制（overrideMaterialPassIndex = 1）
                DrawingSettings drawSettings1 = CreateDrawingSettings(shaderTag, renderingData, cameraData, lightData, sortFlags);
                drawSettings1.overrideMaterial = settings.material;
                drawSettings1.overrideMaterialPassIndex = 1;

                //  create RendererListParams for first draw (face depth)
                var rlParams1 = new RendererListParams(renderingData.cullResults, drawSettings1, filtering1);
                // 转成 RenderGraph 用的 handle
                passData.rendererList1 = renderGraph.CreateRendererList(rlParams1);
                // 声明这个 Pass 会用到这份 RendererList0
                builder.UseRendererList(passData.rendererList1);

                // ★ 3. 把这个 RT 设置成全局纹理 传给 _HairSoildColor，供后续 Shader 采样
                builder.SetGlobalTextureAfterPass(hairTexture, HairSolidColorID);
                builder.AllowGlobalStateModification(true); // 允许修改 global state :contentReference[oaicite:1]{index=1}

                // Setup pass inputs and outputs through the builder interface.
                // Eg:
                // builder.UseTexture(sourceTexture);
                // TextureHandle destination = UniversalRenderer.CreateRenderGraphTexture(renderGraph, cameraData.cameraTargetDescriptor, "Destination Texture", false);

                // This sets the render target of the pass to the active color texture. Change it to your own render target as needed.
                //builder.SetRenderAttachment(resourceData.activeColorTexture, 0);

                // ★ 4. 真正执行的函数：只画两次 RendererList
                builder.SetRenderFunc((PassData data, RasterGraphContext context) => ExecutePass(data, context));
            }
        }
    }
}
