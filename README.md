# Project: PBR Toon Shading  
**Course:** CSCI 580 - 3D Graphics and Rendering  
**Engine:** Unity URP  

---

## Overview  
This project combines Physically Based Rendering (PBR) with Non Photorealistic Rendering (NPR) techniques to create a hybrid visual style. PBR is mainly used for realistic materials such as clothing and accessories, while NPR is applied to character skin and stylized effects. The goal is to allow stylized characters to visually blend into more realistic environments.

---

## Custom PBR Features  

### Custom PBR Lighting  
A custom PBR shader is implemented using a microfacet BRDF lighting model to achieve physically based diffuse and specular reflections.

### Normal Mapping  
Normal maps are used to enhance surface detail for PBR materials.

### Metallic and Smoothness Control  
Metallic and smoothness values are controlled through both material parameters and texture data.

### RMO Texture  
An RMO texture is used where roughness, metallic, and ambient occlusion are stored in different channels.

### Environment Lighting  
Environment diffuse lighting is sampled using spherical harmonics. Environment specular reflection is sampled from reflection probes.

### Ambient Occlusion  
Ambient occlusion from the RMO texture is applied to enhance depth in shadowed areas.

---

## NPR Features Implemented  

### Normal Mapping  
Normal mapping is also applied to toon shaded materials to improve lighting detail.

### Ramp Shading  
Ramp textures are used to control lighting transitions and create two tone toon shading.

### Bangs Shadow and SDF Face Shadow  
SDF based face shadow is used to generate stable facial shadows. Bangs shadow is added to improve the shadow transition around the forehead and hair.

### Light Probe  
Light probes are used to sample indirect diffuse lighting for toon shaded objects.

### Outline Rendering  
Outline is implemented by rendering back faces only and expanding each vertex along its normal to create a black silhouette.

### Rim Lighting  
Rim lighting is rendered on front faces only. Rim intensity is computed using the dot product between normal and view direction to enhance object contours.

### Render Feature Integration  
Outline and rim lighting are integrated into the URP pipeline using a custom Render Feature for a unified final result.

---

## Notes  
PBR and NPR effects are combined using a mask based blending method, allowing different shading styles to coexist on the same character while maintaining visual consistency.
