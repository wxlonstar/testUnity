﻿using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SatelliteShapeBehavior : ShapeBehavior
{
    ShapeInstance focalShape;
    float frequency;
    Vector3 cosOffset, sinOffset;
    Vector3 previousPosition;

    public override ShapeBehaviorType BehaviorType
    {
        get
        {
            return ShapeBehaviorType.Satellite;
        }
    }

    public void Initialize(
        Shape shape, Shape focalShape, float radius, float frequency)
    {
        this.focalShape = focalShape;
        this.frequency = frequency;
        Vector3 orbitAxis = Random.onUnitSphere;
        do
        {
            cosOffset = Vector3.Cross(orbitAxis, Random.onUnitSphere).normalized;
        }
        while (cosOffset.sqrMagnitude < 0.1f);

        sinOffset = Vector3.Cross(cosOffset,orbitAxis);
        cosOffset *= radius;
        sinOffset *= radius;

        shape.AddBehavior<RotationShapeBehavior>().AngularVelocity =
                    -360f * frequency * shape.transform.InverseTransformDirection(orbitAxis);

        GameUpdate(shape);
        previousPosition = shape.transform.localPosition;
    }

    public override bool GameUpdate(Shape shape) {
        if (focalShape.isValid)
        {
            float t = 2f * Mathf.PI * frequency * shape.Age;
            previousPosition = shape.transform.localPosition;
            shape.transform.localPosition =
                focalShape.Shape.transform.localPosition +
                cosOffset * Mathf.Cos(t) + sinOffset * Mathf.Sin(t);

            return true;
        }
        else
        {
            shape.AddBehavior<MovementShapeBehavior>().Velocity = 
                (shape.transform.localPosition - previousPosition) / Time.deltaTime;
            return false;
        }

    }

    public override void Save(GameDataWriter writer) {
        writer.Write(focalShape); //write focalShape's index in Game's shapes List
        writer.Write(frequency);
        writer.Write(cosOffset);
        writer.Write(sinOffset);
        writer.Write(previousPosition);
    }

    public override void Load(GameDataReader reader)
    {
        focalShape = reader.ReadShapeInstance();
        frequency = reader.ReadFloat();
        cosOffset = reader.ReadVector3();
        sinOffset = reader.ReadVector3();
        previousPosition = reader.ReadVector3();
    }

    public override void Recycle()
    {
        ShapeBehaviorPool<SatelliteShapeBehavior>.Reclaim(this);
    }

    public override void ResolveShapeInstances()
    {
        focalShape.Resolve();
    }
}
