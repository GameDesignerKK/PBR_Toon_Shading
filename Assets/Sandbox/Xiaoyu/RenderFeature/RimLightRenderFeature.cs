using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;

public class RimLightRenderFeature1 : ScriptableRendererFeature
{
    public RimLightRenderFeatureSettings settings = new RimLightRenderFeatureSettings();
    RimLightRenderFeaturePass rimLightPass;

    public override void Create()
    {
        rimLightPass = new RimLightRenderFeaturePass("RimLight Pass",settings);
        rimLightPass.renderPassEvent = settings.passEvent;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (settings.rimLightMaterial == null)
        {
            return;
        }
        renderer.EnqueuePass(rimLightPass);
    }

    public class RimLightRenderFeatureSettings
    {
        public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingOpaques;

        public LayerMask layerMask = ~0;

        public Material rimLightMaterial;

        public string lightModeTag = "UniversalForward";

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
            this.settings = settings;
        }

        private class PassData
        {
            public RendererListHandle rendererList;
        }

        static void ExecutePass(PassData data, RasterGraphContext context)
        {
            context.cmd.DrawRendererList(data.rendererList);
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            if (settings.rimLightMaterial == null)
            {
                return;
            }
            const string passName = "RimLight Pass";

            using (var builder = renderGraph.AddRasterRenderPass<PassData>(passName, out var passData))
            {
                var renderingData = frameData.Get<UniversalRenderingData>();
                var cameraData = frameData.Get<UniversalCameraData>();
                var lightData = frameData.Get<UniversalLightData>();
                UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();

                SortingCriteria sortFlags = settings.onlyOpaque ?
                    cameraData.defaultOpaqueSortFlags : SortingCriteria.CommonTransparent;

                RenderQueueRange queueRange = settings.onlyOpaque ?
                    RenderQueueRange.opaque : RenderQueueRange.all;

                FilteringSettings filterSettings = new FilteringSettings(queueRange, settings.layerMask);

                ShaderTagId shaderTagId = new ShaderTagId(settings.lightModeTag);

                DrawingSettings drawSettings =
                    RenderingUtils.CreateDrawingSettings(shaderTagId,
                        renderingData,
                        cameraData,
                        lightData,
                        sortFlags);

                drawSettings.overrideMaterial = settings.rimLightMaterial;

                RendererListParams rendererListParams =
                    new RendererListParams(renderingData.cullResults, drawSettings, filterSettings);

                passData.rendererList = renderGraph.CreateRendererList(rendererListParams);

=                builder.UseRendererList(passData.rendererList);

                builder.SetRenderAttachment(resourceData.activeColorTexture, 0);
                builder.SetRenderAttachmentDepth(resourceData.activeDepthTexture, AccessFlags.Write);

                builder.SetRenderFunc((PassData data, RasterGraphContext context) => ExecutePass(data, context));
            }
        }
    }
}
