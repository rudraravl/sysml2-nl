package AdamsClaspModel {
    import ScalarValues::*;
    import SI::*;

    value def Force {
        unit 'N';
    }
    value def Length {
        unit 'mm';
    }
    value def Angle {
        unit 'deg';
    }
    value def Pressure {
        unit 'MPa';
    }
    value def Deflection : Length;
    value def Clearance : Length;

    enum def ToothSide {
        mesial;
        distal;
    }

    enum def ClaspState {
        uninserted;
        inserting;
        engaged;
        retained;
        removing;
    }

    item def StainlessSteelWire {
        attribute tensileStrength : Pressure = 1900 [MPa];
        attribute yieldStrength : Pressure = 1500 [MPa];
        attribute elasticModulus : Pressure = 193000 [MPa];
        attribute diameter : Length = 0.7 [mm];
    }

    part def AnchorTooth {
        attribute crownWidth : Length = 7.0 [mm];
        attribute crownHeight : Length = 6.0 [mm];
        attribute undercutDepth : Length = 0.3 [mm];
        attribute bulgeHeight : Length = 0.5 [mm];
        attribute occlusalClearance : Length = 1.0 [mm];
        port mesialUndercutPort :>> UndercutInterface;
        port distalUndercutPort :>> UndercutInterface;
        port occlusalSurfacePort :>> OcclusalInterface;
    }

    port def UndercutInterface {
        attribute location : ToothSide;
        out item contactForce : Force;
    }

    port def OcclusalInterface {
        attribute span : Length;
    }

    port def WireConnectionPort {
        in item wireSegment : StainlessSteelWire;
    }

    part def ArrowheadArm {
        attribute side : ToothSide;
        attribute armLength : Length = 12.0 [mm];
        attribute embeddedLength : Length = 4.0 [mm];
        attribute arrowheadWidth : Length = 2.0 [mm];
        attribute arrowheadHeight : Length = 1.5 [mm];
        attribute currentDeflection : Deflection = 0.0 [mm];
        attribute retentiveForce : Force = 1.5 [N];
        attribute maxDeflection : Deflection = 0.5 [mm];
        ref item wireMaterial : StainlessSteelWire;
        port bridgeConnectionPort :>> WireConnectionPort;
        port arrowheadTipPort :>> UndercutInterface;
        port embeddedPort :>> WireConnectionPort;

        action def deflect :>> Action {
            in appliedForce : Force;
            out resultingDeflection : Deflection;
        }
    }

    part def BridgeWire {
        attribute spanLength : Length = 7.0 [mm];
        attribute clearance : Clearance = 1.0 [mm];
        attribute wireDiameter : Length = 0.7 [mm];
        ref item wireMaterial : StainlessSteelWire;
        port mesialEndPort :>> WireConnectionPort;
        port distalEndPort :>> WireConnectionPort;
        port occlusalContactPort :>> OcclusalInterface;
    }

    part def AcrylicBase {
        attribute thickness : Length = 2.0 [mm];
        attribute width : Length = 40.0 [mm];
        attribute length : Length = 50.0 [mm];
        port embeddingPort :>> WireConnectionPort;
    }

    connection def WireJoint {
        end sender : WireConnectionPort;
        end receiver : WireConnectionPort;
    }

    connection def ToothContact {
        end claspTip : UndercutInterface;
        end toothUndercut : UndercutInterface;
    }

    part def AdamsClaspAssembly {
        attribute totalRetentiveForce : Force = 3.0 [N];
        attribute insertionForce : Force = 4.0 [N];
        attribute removalForce : Force = 4.5 [N];
        attribute currentState : ClaspState = ClaspState::uninserted;

        part mesialArm : ArrowheadArm {
            redefines side = ToothSide::mesial;
            redefines retentiveForce = 1.5 [N];
        }
        part distalArm : ArrowheadArm {
            redefines side = ToothSide::distal;
            redefines retentiveForce = 1.5 [N];
        }
        part bridge : BridgeWire;

        connection mesialJoint : WireJoint connect bridge.mesialEndPort to mesialArm.bridgeConnectionPort;
        connection distalJoint : WireJoint connect bridge.distalEndPort to distalArm.bridgeConnectionPort;

        port mesialTipPort :>> UndercutInterface;
        port distalTipPort :>> UndercutInterface;

        connection mesialTipLink connect mesialArm.arrowheadTipPort to mesialTipPort;
        connection distalTipLink connect distalArm.arrowheadTipPort to distalTipPort;

        exhibit ClaspLifecycle {
            state def ClaspLifecycle {
                state uninserted {
                    entry { currentState = ClaspState::uninserted; }
                    do { mesialArm.currentDeflection = 0.0 [mm]; distalArm.currentDeflection = 0.0 [mm]; }
                }
                state inserting {
                    entry { currentState = ClaspState::inserting; }
                    do { mesialArm.currentDeflection = mesialArm.maxDeflection; distalArm.currentDeflection = distalArm.maxDeflection; }
                }
                state engaged {
                    entry { currentState = ClaspState::engaged; }
                    do { mesialArm.currentDeflection = 0.0 [mm]; distalArm.currentDeflection = 0.0 [mm]; }
                }
                state retained {
                    entry { currentState = ClaspState::retained; }
                    do { totalRetentiveForce = mesialArm.retentiveForce + distalArm.retentiveForce; }
                }
                state removing {
                    entry { currentState = ClaspState::removing; }
                    do { mesialArm.currentDeflection = mesialArm.maxDeflection; distalArm.currentDeflection = distalArm.maxDeflection; }
                }

                transition uninserted to inserting when appliedInsertionForce > 0.0 [N];
                transition inserting to engaged when mesialArm.currentDeflection <= 0.1 [mm] and distalArm.currentDeflection <= 0.1 [mm];
                transition engaged to retained when totalRetentiveForce >= 2.0 [N];
                transition retained to removing when appliedRemovalForce > removalForce;
                transition removing to uninserted when mesialArm.currentDeflection >= mesialArm.maxDeflection and distalArm.currentDeflection >= distalArm.maxDeflection;
            }

            attribute appliedInsertionForce : Force = 0.0 [N];
            attribute appliedRemovalForce : Force = 0.0 [N];
        }
    }

    part def RemovableOrthodonticAppliance {
        attribute applianceName : String = "Hawley Retainer";
        part acrylicBase : AcrylicBase;
        part adamsClasp : AdamsClaspAssembly;
        part anchorTooth : AnchorTooth;

        connection mesialContact : ToothContact connect adamsClasp.mesialTipPort to anchorTooth.mesialUndercutPort;
        connection distalContact : ToothContact connect adamsClasp.distalTipPort to anchorTooth.distalUndercutPort;
        connection embeddingConnection : WireJoint connect adamsClasp.mesialArm.embeddedPort to acrylicBase.embeddingPort;
    }

    action def InsertionAction {
        in clasp : AdamsClaspAssembly;
        in tooth : AnchorTooth;
        out success : Boolean;
        attribute requiredForce : Force = 4.0 [N];

        start;
        then applyForceToClasp;
        action applyForceToClasp {
            out forceApplied : Force = requiredForce;
        }
        then deflectArmsOverBulge;
        action deflectArmsOverBulge {
            in bulgeHeight : Length = tooth.bulgeHeight;
            out armDeflection : Deflection;
        }
        then snapIntoUndercuts;
        action snapIntoUndercuts {
            in undercutDepth : Length = tooth.undercutDepth;
            out engaged : Boolean = true;
        }
        then success = true;
        done;
    }

    action def RemovalAction {
        in clasp : AdamsClaspAssembly;
        in tooth : AnchorTooth;
        out success : Boolean;
        attribute requiredForce : Force = 4.5 [N];

        start;
        then applyRemovalForce;
        action applyRemovalForce {
            out forceApplied : Force = requiredForce;
        }
        then flexArmsOutOfUndercuts;
        action flexArmsOutOfUndercuts {
            out armDeflection : Deflection;
        }
        then slideOverBulge;
        action slideOverBulge {
            out disengaged : Boolean = true;
        }
        then success = true;
        done;
    }

    requirement def RetentionForceRequirement {
        subject clasp : AdamsClaspAssembly;
        objective {
            doc /* The clasp shall provide sufficient continuous retentive force to resist dislodgement during normal activities. */
        }
        require constraint { clasp.totalRetentiveForce >= 2.0 [N] and clasp.totalRetentiveForce <= 5.0 [N] }
    }

    requirement def InsertionForceRequirement {
        subject clasp : AdamsClaspAssembly;
        objective {
            doc /* The force required to insert the appliance shall be manageable and comfortable for the patient. */
        }
        require constraint { clasp.insertionForce <= 5.0 [N] }
    }

    requirement def RemovalForceRequirement {
        subject clasp : AdamsClaspAssembly;
        objective {
            doc /* The force required to remove the appliance shall be manageable and comfortable for the patient. */
        }
        require constraint { clasp.removalForce <= 6.0 [N] }
    }

    requirement def OcclusalClearanceRequirement {
        subject bridge : BridgeWire;
        objective {
            doc /* The bridge wire shall maintain a slight clearance above the chewing surface of the tooth. */
        }
        require constraint { bridge.clearance >= 0.5 [mm] and bridge.clearance <= 1.5 [mm] }
    }

    requirement def WireMaterialRequirement {
        subject wire : StainlessSteelWire;
        objective {
            doc /* The clasp wire shall be made of stainless steel with adequate flexibility and strength. */
        }
        require constraint { wire.diameter >= 0.6 [mm] and wire.diameter <= 0.8 [mm] and wire.elasticModulus >= 180000 [MPa] }
    }

    requirement def ArmDeflectionRequirement {
        subject arm : ArrowheadArm;
        objective {
            doc /* Each arrowhead arm shall flex sufficiently to pass over the tooth bulge without permanent deformation. */
        }
        require constraint { arm.maxDeflection >= 0.4 [mm] and arm.maxDeflection <= 0.6 [mm] }
    }

    requirement def EmbedmentRequirement {
        subject clasp : AdamsClaspAssembly;
        subject base : AcrylicBase;
        objective {
            doc /* The wire arms shall be partially embedded into the acrylic base of the appliance. */
        }
        require constraint { clasp.mesialArm.embeddedLength >= 3.0 [mm] and clasp.distalArm.embeddedLength >= 3.0 [mm] }
    }

    requirement def DualArmRetentionRequirement {
        subject clasp : AdamsClaspAssembly;
        objective {
            doc /* The clasp shall consist of two arrowhead arms, one mesial and one distal, connected by a bridge wire. */
        }
        require constraint { clasp.mesialArm.side == ToothSide::mesial and clasp.distalArm.side == ToothSide::distal }
    }

    requirement group def AdamsClaspRequirements {
        require retentionForceReq : RetentionForceRequirement;
        require insertionForceReq : InsertionForceRequirement;
        require removalForceReq : RemovalForceRequirement;
        require occlusalClearanceReq : OcclusalClearanceRequirement;
        require wireMaterialReq : WireMaterialRequirement;
        require armDeflectionReq : ArmDeflectionRequirement;
        require embedmentReq : EmbedmentRequirement;
        require dualArmReq : DualArmRetentionRequirement;
    }

    part def AdamsClaspSystem :> RemovableOrthodonticAppliance {
        satisfy AdamsClaspRequirements by adamsClasp;
    }
}
