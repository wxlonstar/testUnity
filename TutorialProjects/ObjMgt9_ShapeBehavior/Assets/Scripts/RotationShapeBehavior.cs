﻿using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public sealed class RotationShapeBehavior : ShapeBehavior
{
    public Vector3 AngularVelocity { get; set; }

    public override ShapeBehaviorType BehaviorType
    {
        get
        {
            return ShapeBehaviorType.Rotation;
        }
    }


    public override void GameUpdate(Shape shape)
    {
        shape.transform.Rotate(AngularVelocity * Time.deltaTime);
    }

    public override void Save(GameDataWriter writer)
    {
        writer.Write(AngularVelocity);
    }

    public override void Load(GameDataReader reader)
    {
        AngularVelocity = reader.ReadVector3();
    }

    public override void Recycle()
    {
        //ShapeBehaviorPool is a static class so do not need to instantiate
        ShapeBehaviorPool<RotationShapeBehavior>.Reclaim(this);
    }
}
