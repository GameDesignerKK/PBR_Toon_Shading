using System;
using UnityEditor.Rendering;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

public class CelHairShadow_Stencil : ScriptableRendererFeature
{
    [Serializable]
    public class Setting
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

    public Setting setting = new Setting();

    class CustomRenderPass : ScriptableRenderPass
    {
        public ShaderTagId shaderTag = new ShaderTagId("UniversalForward");
        public Setting setting;
        FilteringSettings filtering;

        static readonly int LightDirSSID = Shader.PropertyToID("_LightDirSS");
        static readonly int ColorID = Shader.PropertyToID("_Color");
        static readonly int OffsetID = Shader.PropertyToID("_Offset");
        static readonly int StencilRefID = Shader.PropertyToID("_StencilRef");
        static readonly int StencilCompID = Shader.PropertyToID("_StencilComp");

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

        private class PassData
        {
            internal RendererListHandle rendererList;
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            if (setting.material == null)
            {
                Debug.LogError("【ERROR】Material is NULL!");
                return;
            }

            var renderingData = frameData.Get<UniversalRenderingData>();
            var cameraData = frameData.Get<UniversalCameraData>();
            var lightData = frameData.Get<UniversalLightData>();
            var resourceData = frameData.Get<UniversalResourceData>();

            // ===== 计算光照方向 =====
            Vector2 lightDirSS = Vector2.down;
            if (lightData.mainLightIndex >= 0 && lightData.mainLightIndex < lightData.visibleLights.Length)
            {
                var mainLight = lightData.visibleLights[lightData.mainLightIndex];
                Vector3 lightDirWS = -mainLight.localToWorldMatrix.GetColumn(2);
                Matrix4x4 worldToView = cameraData.GetViewMatrix();
                Vector3 lightDirVS = worldToView.MultiplyVector(lightDirWS);
                lightDirSS = new Vector2(lightDirVS.x, lightDirVS.y);
                if (lightDirSS.sqrMagnitude > 0.0001f) lightDirSS.Normalize();
            }

            // ===== 设置材质参数（使用 Property ID）=====
            setting.material.SetVector(LightDirSSID, new Vector4(lightDirSS.x, lightDirSS.y, 0, 0));
            setting.material.SetColor(ColorID, setting.hairShadowColor);
            setting.material.SetFloat(OffsetID, setting.offset);
            setting.material.SetInt(StencilRefID, setting.stencilReference);
            setting.material.SetInt(StencilCompID, (int)setting.stencilComparison);

            // ===== 验证设置 =====
            Vector4 verify = setting.material.GetVector(LightDirSSID);

            using (var builder = renderGraph.AddRasterRenderPass<PassData>("Hair Shadow", out var passData))
            {
                builder.SetRenderAttachment(resourceData.activeColorTexture, 0, AccessFlags.Write);
                builder.SetRenderAttachmentDepth(resourceData.activeDepthTexture, AccessFlags.Read);

                var drawSettings = RenderingUtils.CreateDrawingSettings(
                    shaderTag, renderingData, cameraData, lightData, cameraData.defaultOpaqueSortFlags);
                drawSettings.overrideMaterial = setting.material;
                drawSettings.overrideMaterialPassIndex = 0;

                var rlParams = new RendererListParams(renderingData.cullResults, drawSettings, filtering);
                passData.rendererList = renderGraph.CreateRendererList(rlParams);
                builder.UseRendererList(passData.rendererList);

                builder.SetRenderFunc((PassData data, RasterGraphContext ctx) =>
                {
                    ctx.cmd.DrawRendererList(data.rendererList);
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