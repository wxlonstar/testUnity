﻿using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

[CustomPropertyDrawer(typeof(FloatRangeSliderAttribute))]
public class FloatRangeSliderDrawer : PropertyDrawer
{
    public override void OnGUI(
        Rect position, SerializedProperty property, GUIContent label
    )
    {
        int originalIndentLevel = EditorGUI.indentLevel;

        EditorGUI.BeginProperty(position, label, property);

        position = EditorGUI.PrefixLabel(position, 
            GUIUtility.GetControlID(FocusType.Passive), label);
        EditorGUI.indentLevel = 0;

        SerializedProperty minProperty = property.FindPropertyRelative("min");
        SerializedProperty maxProperty = property.FindPropertyRelative("max");
        float minValue = minProperty.floatValue;
        float maxValue = maxProperty.floatValue;

        //'minValue' position
        float fieldWidth = position.width / 4f - 4f;
        float sliderWidth = position.width / 2f;
        position.width = fieldWidth;

        minValue = EditorGUI.FloatField(position, minValue);

        //'slider' position
        position.x += fieldWidth + 4f;
        position.width = sliderWidth;

        FloatRangeSliderAttribute limit = attribute as FloatRangeSliderAttribute;
        EditorGUI.MinMaxSlider(
            position, ref minValue, ref maxValue, limit.Min, limit.Max);

        //'maxValue' position
        position.x += sliderWidth + 4f;
        position.width = fieldWidth;

        maxValue = EditorGUI.FloatField(position, maxValue);

        if (minValue < limit.Min)
        {
            minValue = limit.Min;
        }
        else if (minValue > limit.Max)
        {
            minValue = limit.Max;
        }
        if (maxValue < minValue)
        {
            maxValue = minValue;
        }
        else if (maxValue > limit.Max)
        {
            maxValue = limit.Max;
        }
        minProperty.floatValue = minValue;
        maxProperty.floatValue = maxValue;
        EditorGUI.EndProperty();

        EditorGUI.indentLevel = originalIndentLevel;

    }
}
