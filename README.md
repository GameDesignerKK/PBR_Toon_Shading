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

# Visual Showcase

### Custom PBR Shading  
<img width="421" height="343" alt="CSCI580_Final_Project" src="https://github.com/user-attachments/assets/b4a33dfe-8459-4ad2-a378-0cac7620962c" />

### Outline + Rim Lighting  
<img width="426" height="355" alt="CSCI580_Final_Project (1)" src="https://github.com/user-attachments/assets/4e34a908-1fa9-4c63-baae-2bdc483056f5" />

### Ramp Shading + Normal Mapping  
<img width="374" height="433" alt="CSCI580_Final_Project (2)" src="https://github.com/user-attachments/assets/612dea21-64d3-48b7-9507-c1f1c88f26f5" />

---

## 2. Final Hybrid PBR + NPR Result  

### Final Rendered Output  

![5263f3c50290b6a23761163736b50cf7](https://github.com/user-attachments/assets/4d2a156c-b7ae-4375-bbd4-38f9860956ad)

https://github.com/user-attachments/assets/753df12f-65ff-4de8-9381-45eeecf90220

---

## 3. Demo Video  
*A demonstration of the hybrid PBR + NPR shading pipeline.*

## Project Demo
[Download Demo Video](https://github.com/GameDesignerKK/PBR_Toon_Shading/releases/download/demo/4590_raw.mp4)

---

# Contributors
- Xiaoyu Zhao
- Tommy Hu
- Yukun Fang
- Xiaojun Gong
