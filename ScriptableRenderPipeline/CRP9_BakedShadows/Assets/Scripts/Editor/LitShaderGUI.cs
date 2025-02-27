﻿using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

public class LitShaderGUI : ShaderGUI {

    MaterialEditor editor;
    Object[] materials;
    MaterialProperty[] properties;
    bool showPresets;

    CullMode Cull
    {
        set
        {
            FindProperty("_Cull", properties).floatValue = (float)value;
        }
    }

    BlendMode SrcBlend
    {
        set
        {
            FindProperty("_SrcBlend", properties).floatValue = (float)value;
        }
    }

    BlendMode DstBlend
    {
        set
        {
            FindProperty("_DstBlend", properties).floatValue = (float)value;
        }
    }

    bool ZWrite
    {
        set
        {
            FindProperty("_ZWrite", properties).floatValue = value ? 1 : 0;
        }
    }

    bool PremultiplyAlpha
    {
        set
        {
            FindProperty("_PremulAlpha", properties).floatValue =
                value ? 1 : 0;
            SetKeywordEnabled("_PREMULTIPLY_ALPHA", value);
        }
    }

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        base.OnGUI(materialEditor, properties);

        editor = materialEditor;
        materials = materialEditor.targets;
        this.properties = properties;

        CastShadowsToggle();

        //whether add emission to GI
        EditorGUI.BeginChangeCheck();
        editor.LightmapEmissionProperty();
        if (EditorGUI.EndChangeCheck())
        {
            foreach (Material m in editor.targets)
            {
                m.globalIlluminationFlags &=
                    ~MaterialGlobalIlluminationFlags.EmissiveIsBlack;
            }
        }

        //presets
        EditorGUILayout.Space();
        showPresets = EditorGUILayout.Foldout(showPresets, "Presets", true);
        if (showPresets)
        {
            OpaquePreset();
            ClipPreset();
            ClipDoubleSidedPreset();
            FadePreset();
            FadeWithShadowsPreset();
            TransparentPreset();
            TransparentWithShadowsPreset();
        }
    }

    void SetPassEnabled(string pass, bool enabled)
    {
        foreach (Material m in materials)
        {
            m.SetShaderPassEnabled(pass, enabled);
        }
    }

    bool? IsPassEnabled(string pass)
    {
        bool enabled = ((Material)materials[0]).GetShaderPassEnabled(pass);
        for (int i = 1; i < materials.Length; i++)
        {
            if (enabled != ((Material)materials[i]).GetShaderPassEnabled(pass))
            {
                return null;
            }
        }
        return enabled;
    }

    void CastShadowsToggle()
    {
        bool? enabled = IsPassEnabled("ShadowCaster");
        if (!enabled.HasValue)
        {
            EditorGUI.showMixedValue = true;
            enabled = false;
        }
        EditorGUI.BeginChangeCheck();
        enabled = EditorGUILayout.Toggle("Cast Shadows", enabled.Value);
        if (EditorGUI.EndChangeCheck())
        {
            editor.RegisterPropertyChangeUndo("Cast Shadows");
            SetPassEnabled("ShadowCaster", enabled.Value);
        }
        EditorGUI.showMixedValue = false;
    }

    void SetKeywordEnabled(string keyword, bool enabled)
    {
        if (enabled)
        {
            foreach (Material m in materials)
            {
                m.EnableKeyword(keyword);
            }
        }
        else
        {
            foreach (Material m in materials)
            {
                m.DisableKeyword(keyword);
            }
        }
    }

    enum ClipMode
    {
        Off, On, Shadows
    }

    ClipMode Clipping
    {
        set
        {
            FindProperty("_Clipping", properties).floatValue = (float)value;
            SetKeywordEnabled("_CLIPPING_OFF", value == ClipMode.Off);
            SetKeywordEnabled("_CLIPPING_ON", value == ClipMode.On);
            SetKeywordEnabled("_CLIPPING_SHADOWS", value == ClipMode.Shadows);
        }
    }

    bool ReceiveShadows
    {
        set
        {
            FindProperty("_ReceiveShadows", properties).floatValue =
                value ? 1 : 0;
            SetKeywordEnabled("_RECEIVE_SHADOWS", value);
        }
    }

    RenderQueue RenderQueue
    {
        set
        {
            foreach (Material m in materials)
            {
                m.renderQueue = (int)value;
            }
        }
    }

    //presets
    void OpaquePreset()
    {
        if (!GUILayout.Button("Opaque"))
        {
            return;
        }
        editor.RegisterPropertyChangeUndo("Opague Preset");
        Clipping = ClipMode.Off;
        Cull = CullMode.Back;
        SrcBlend = BlendMode.One;
        DstBlend = BlendMode.Zero;
        ZWrite = true;
        ReceiveShadows = true;
        SetPassEnabled("ShadowCaster", true);
        RenderQueue = RenderQueue.Geometry;
        PremultiplyAlpha = false;

    }

    void ClipPreset()
    {
        if (!GUILayout.Button("Clip"))
        {
            return;
        }
        editor.RegisterPropertyChangeUndo("Clip Preset");
        Clipping = ClipMode.On;
        Cull = CullMode.Back;
        SrcBlend = BlendMode.One;
        DstBlend = BlendMode.Zero;
        ZWrite = true;
        ReceiveShadows = true;
        SetPassEnabled("ShadowCaster", true);
        RenderQueue = RenderQueue.AlphaTest;
        PremultiplyAlpha = false;

    }

    void ClipDoubleSidedPreset()
    {
        if (!GUILayout.Button("Clip Double-Sided"))
        {
            return;
        }
        editor.RegisterPropertyChangeUndo("Clip Double-Sided Preset");
        Clipping = ClipMode.On;
        Cull = CullMode.Off;
        SrcBlend = BlendMode.One;
        DstBlend = BlendMode.Zero;
        ZWrite = true;
        ReceiveShadows = true;
        SetPassEnabled("ShadowCaster", true);
        RenderQueue = RenderQueue.AlphaTest;
        PremultiplyAlpha = false;

    }

    void FadePreset()
    {
        if (!GUILayout.Button("Fade"))
        {
            return;
        }
        editor.RegisterPropertyChangeUndo("Fade Preset");
        Clipping = ClipMode.Off;
        Cull = CullMode.Back;
        SrcBlend = BlendMode.SrcAlpha;
        DstBlend = BlendMode.OneMinusSrcAlpha;
        ZWrite = false;
        ReceiveShadows = false;
        SetPassEnabled("ShadowCaster", false);
        RenderQueue = RenderQueue.Transparent;
        PremultiplyAlpha = false;

    }

    void FadeWithShadowsPreset()
    {
        if (!GUILayout.Button("Fade with Shadows"))
        {
            return;
        }
        editor.RegisterPropertyChangeUndo("Fade with Shadows Preset");
        Clipping = ClipMode.Shadows;
        Cull = CullMode.Back;
        SrcBlend = BlendMode.SrcAlpha;
        DstBlend = BlendMode.OneMinusSrcAlpha;
        ZWrite = false;
        ReceiveShadows = true;
        SetPassEnabled("ShadowCaster", true);
        RenderQueue = RenderQueue.Transparent;
        PremultiplyAlpha = false;

    }


    void TransparentPreset()
    {
        if (!GUILayout.Button("Fade"))
        {
            return;
        }
        editor.RegisterPropertyChangeUndo("Fade Preset");
        Clipping = ClipMode.Off;
        Cull = CullMode.Back;
        SrcBlend = BlendMode.One;
        DstBlend = BlendMode.OneMinusSrcAlpha;
        ZWrite = false;
        ReceiveShadows = false;
        SetPassEnabled("ShadowCaster", false);
        RenderQueue = RenderQueue.Transparent;
        PremultiplyAlpha = true;

    }

    void TransparentWithShadowsPreset()
    {
        if (!GUILayout.Button("Fade with Shadows"))
        {
            return;
        }
        editor.RegisterPropertyChangeUndo("Fade with Shadows Preset");
        Clipping = ClipMode.Shadows;
        Cull = CullMode.Back;
        SrcBlend = BlendMode.One;
        DstBlend = BlendMode.OneMinusSrcAlpha;
        ZWrite = false;
        ReceiveShadows = true;
        SetPassEnabled("ShadowCaster", true);
        RenderQueue = RenderQueue.Transparent;
        PremultiplyAlpha = true;

    }
}