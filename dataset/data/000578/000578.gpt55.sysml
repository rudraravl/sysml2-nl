package CrutchMobilitySupportModel {
    import ScalarValues::*;
    import SI::*;

    value def LengthValue :> Real {
        attribute unitSymbol: String = "m";
    }

    value def MassValue :> Real {
        attribute unitSymbol: String = "kg";
    }

    value def ForceValue :> Real {
        attribute unitSymbol: String = "N";
    }

    value def AngleValue :> Real {
        attribute unitSymbol: String = "deg";
    }

    value def TimeValue :> Real {
        attribute unitSymbol: String = "s";
    }

    value def StiffnessValue :> Real {
        attribute unitSymbol: String = "N/m";
    }

    value def CoefficientValue :> Real {
        attribute unitSymbol: String = "1";
    }

    value def LoadFractionValue :> Real {
        attribute unitSymbol: String = "1";
    }

    item def BodyLoad {
        attribute verticalForce: ForceValue;
        attribute lateralForce: ForceValue;
        attribute foreAftForce: ForceValue;
        attribute appliedAtHeight: LengthValue;
    }

    item def SupportReaction {
        attribute upwardForce: ForceValue;
        attribute lateralStabilizingForce: ForceValue;
        attribute foreAftStabilizingForce: ForceValue;
        attribute comfortPressure: ForceValue;
    }

    item def GroundReaction {
        attribute normalForce: ForceValue;
        attribute frictionForce: ForceValue;
        attribute contactPatchDiameter: LengthValue;
    }

    item def SurfaceCondition {
        attribute surfaceSlope: AngleValue;
        attribute staticFrictionCoefficient: CoefficientValue;
        attribute wet: Boolean;
        attribute deformable: Boolean;
    }

    item def HeightSetting {
        attribute totalCrutchLength: LengthValue;
        attribute handleHeight: LengthValue;
        attribute cuffHeight: LengthValue;
        attribute detentIndex: Integer;
    }

    item def LockStatus {
        attribute locked: Boolean;
        attribute pinEngaged: Boolean;
        attribute clampClosed: Boolean;
    }

    item def GaitIntent {
        attribute intendedStepLength: LengthValue;
        attribute cadencePeriod: TimeValue;
        attribute desiredLoadShare: LoadFractionValue;
    }

    item def GripCommand {
        attribute handPresent: Boolean;
        attribute gripForce: ForceValue;
        attribute wristNeutral: Boolean;
    }

    port def UserInterfacePort {
        in item userLoad: BodyLoad;
        in item grip: GripCommand;
        in item gaitIntent: GaitIntent;
        out item support: SupportReaction;
    }

    port def StructuralLoadPort {
        in item incomingLoad: BodyLoad;
        out item outgoingReaction: SupportReaction;
    }

    port def GroundContactPort {
        in item surface: SurfaceCondition;
        out item groundReaction: GroundReaction;
    }

    port def AdjustmentPort {
        in item requestedHeight: HeightSetting;
        out item status: LockStatus;
    }

    port def CuffPort {
        in item forearmLoad: BodyLoad;
        out item forearmReaction: SupportReaction;
    }

    port def HandlePort {
        in item handLoad: BodyLoad;
        in item grip: GripCommand;
        out item handReaction: SupportReaction;
    }

    part def ForearmCuff {
        attribute innerDiameter: LengthValue = 0.085;
        attribute openingWidth: LengthValue = 0.045;
        attribute cuffHeightAboveHandle: LengthValue = 0.230;
        attribute paddingThickness: LengthValue = 0.008;
        attribute allowableForearmLoad: ForceValue = 350.0;
        port userSide: CuffPort;
        port frameSide: StructuralLoadPort;
    }

    part def ErgonomicHandGrip {
        attribute gripLength: LengthValue = 0.125;
        attribute gripDiameter: LengthValue = 0.035;
        attribute gripAngle: AngleValue = 12.0;
        attribute allowableHandLoad: ForceValue = 800.0;
        attribute surfaceFrictionCoefficient: CoefficientValue = 0.80;
        port userSide: HandlePort;
        port frameSide: StructuralLoadPort;
    }

    part def UpperTube {
        attribute outerDiameter: LengthValue = 0.022;
        attribute wallThickness: LengthValue = 0.002;
        attribute length: LengthValue = 0.460;
        attribute materialYieldLoad: ForceValue = 2300.0;
        port upperEnd: StructuralLoadPort;
        port lowerEnd: StructuralLoadPort;
    }

    part def LowerTube {
        attribute outerDiameter: LengthValue = 0.019;
        attribute wallThickness: LengthValue = 0.002;
        attribute adjustableLength: LengthValue = 0.410;
        attribute minimumExposedLength: LengthValue = 0.290;
        attribute maximumExposedLength: LengthValue = 0.520;
        attribute materialYieldLoad: ForceValue = 2100.0;
        port upperEnd: StructuralLoadPort;
        port lowerEnd: StructuralLoadPort;
    }

    part def HeightAdjustmentMechanism {
        attribute detentSpacing: LengthValue = 0.025;
        attribute numberOfDetents: Integer = 10;
        attribute lockShearCapacity: ForceValue = 1600.0;
        attribute adjustmentTime: TimeValue = 8.0;
        port adjust: AdjustmentPort;
        port upperTubeSide: StructuralLoadPort;
        port lowerTubeSide: StructuralLoadPort;
    }

    part def ShockAbsorbingInsert {
        attribute travel: LengthValue = 0.018;
        attribute nominalStiffness: StiffnessValue = 36000.0;
        attribute dampingResponseTime: TimeValue = 0.12;
        attribute maximumCompressionForce: ForceValue = 900.0;
        port upperSide: StructuralLoadPort;
        port lowerSide: StructuralLoadPort;
    }

    part def RubberTip {
        attribute outerDiameter: LengthValue = 0.050;
        attribute contactPatchDiameter: LengthValue = 0.042;
        attribute treadDepth: LengthValue = 0.004;
        attribute staticFrictionCoefficientDry: CoefficientValue = 0.90;
        attribute staticFrictionCoefficientWet: CoefficientValue = 0.55;
        attribute replacementWearLimit: LengthValue = 0.002;
        port shaftSide: StructuralLoadPort;
        port groundSide: GroundContactPort;
    }

    connection def RigidStructuralConnection {
        end a: StructuralLoadPort;
        end b: StructuralLoadPort;
    }

    connection def UserLoadConnection {
        end userPort: UserInterfacePort;
        end crutchPort: UserInterfacePort;
    }

    action def AcceptUserLoad {
        in item userLoad: BodyLoad;
        in item gripCommand: GripCommand;
        out item distributedHandLoad: BodyLoad;
        out item distributedForearmLoad: BodyLoad;
    }

    action def AdjustCrutchHeight {
        in item desiredHeight: HeightSetting;
        out item lockStatus: LockStatus;
    }

    action def TransmitLoadThroughFrame {
        in item handLoad: BodyLoad;
        in item forearmLoad: BodyLoad;
        out item axialTubeLoad: BodyLoad;
    }

    action def MaintainTipTraction {
        in item axialLoad: BodyLoad;
        in item surface: SurfaceCondition;
        out item groundReaction: GroundReaction;
    }

    action def ReturnSupportToUser {
        in item groundReaction: GroundReaction;
        out item supportReaction: SupportReaction;
    }

    action def ProvideAmbulatorySupport {
        in item appliedUserLoad: BodyLoad;
        in item gripCommand: GripCommand;
        in item gaitIntent: GaitIntent;
        in item walkingSurface: SurfaceCondition;
        in item selectedHeight: HeightSetting;
        out item supportToUser: SupportReaction;
        out item reactionAtGround: GroundReaction;

        action adjustHeight: AdjustCrutchHeight;
        action acceptLoad: AcceptUserLoad;
        action transmitLoad: TransmitLoadThroughFrame;
        action maintainTraction: MaintainTipTraction;
        action returnSupport: ReturnSupportToUser;

        flow selectedHeight to adjustHeight.desiredHeight;
        flow appliedUserLoad to acceptLoad.userLoad;
        flow gripCommand to acceptLoad.gripCommand;
        flow acceptLoad.distributedHandLoad to transmitLoad.handLoad;
        flow acceptLoad.distributedForearmLoad to transmitLoad.forearmLoad;
        flow transmitLoad.axialTubeLoad to maintainTraction.axialLoad;
        flow walkingSurface to maintainTraction.surface;
        flow maintainTraction.groundReaction to returnSupport.groundReaction;
        flow maintainTraction.groundReaction to reactionAtGround;
        flow returnSupport.supportReaction to supportToUser;

        succession adjustHeight then acceptLoad;
        succession acceptLoad then transmitLoad;
        succession transmitLoad then maintainTraction;
        succession maintainTraction then returnSupport;
    }

    state def CrutchUseStateMachine {
        state Stowed;
        state HeightAdjustment;
        state ReadyForUse;
        state SwingPhase;
        state LoadedSupportPhase;
        state SlipRisk;
        state MaintenanceRequired;

        transition initial then Stowed;
        transition Stowed then HeightAdjustment accept requestedAdjustment;
        transition HeightAdjustment then ReadyForUse accept lockEngaged;
        transition ReadyForUse then SwingPhase accept crutchLifted;
        transition SwingPhase then LoadedSupportPhase accept tipContactsGround;
        transition LoadedSupportPhase then SwingPhase accept bodyLoadRemoved;
        transition LoadedSupportPhase then SlipRisk accept insufficientFriction;
        transition SlipRisk then LoadedSupportPhase accept tractionRestored;
        transition LoadedSupportPhase then MaintenanceRequired accept tipWearBelowLimit;
        transition MaintenanceRequired then ReadyForUse accept tipReplaced;
        transition ReadyForUse then Stowed accept userStoresCrutch;
    }

    constraint def StaticSupportBalance {
        in userVerticalLoad: ForceValue;
        in crutchWeight: ForceValue;
        in groundNormalReaction: ForceValue;
        assert groundNormalReaction >= userVerticalLoad + crutchWeight;
    }

    constraint def TipTractionAdequacy {
        in normalForce: ForceValue;
        in frictionCoefficient: CoefficientValue;
        in lateralForce: ForceValue;
        assert normalForce * frictionCoefficient >= lateralForce;
    }

    constraint def HeightFitRange {
        in requestedLength: LengthValue;
        in minimumLength: LengthValue;
        in maximumLength: LengthValue;
        assert requestedLength >= minimumLength and requestedLength <= maximumLength;
    }

    part def AdjustableForearmCrutch {
        attribute primaryFunction: String = "Provide ambulatory support by transferring a controlled portion of the user's body load from the hand and forearm through a rigid adjustable frame to the ground, improving stability and enabling walking.";
        attribute totalMass: MassValue = 0.90;
        attribute ratedVerticalLoad: ForceValue = 1200.0;
        attribute recommendedUserMassLimit: MassValue = 120.0;
        attribute minimumOverallLength: LengthValue = 0.760;
        attribute maximumOverallLength: LengthValue = 1.010;
        attribute nominalOverallLength: LengthValue = 0.910;
        attribute nominalLoadShare: LoadFractionValue = 0.35;
        attribute allowableTipSlope: AngleValue = 8.0;

        port userInterface: UserInterfacePort;
        port groundInterface: GroundContactPort;
        port adjustmentInterface: AdjustmentPort;

        part cuff: ForearmCuff;
        part handle: ErgonomicHandGrip;
        part upperTube: UpperTube;
        part lowerTube: LowerTube;
        part heightLock: HeightAdjustmentMechanism;
        part absorber: ShockAbsorbingInsert;
        part tip: RubberTip;

        connection cuffToUpperTube: RigidStructuralConnection connect cuff.frameSide to upperTube.upperEnd;
        connection handleToUpperTube: RigidStructuralConnection connect handle.frameSide to upperTube.upperEnd;
        connection upperToHeightLock: RigidStructuralConnection connect upperTube.lowerEnd to heightLock.upperTubeSide;
        connection heightLockToLower: RigidStructuralConnection connect heightLock.lowerTubeSide to lowerTube.upperEnd;
        connection lowerToAbsorber: RigidStructuralConnection connect lowerTube.lowerEnd to absorber.upperSide;
        connection absorberToTip: RigidStructuralConnection connect absorber.lowerSide to tip.shaftSide;

        connect userInterface to handle.userSide;
        connect userInterface to cuff.userSide;
        connect groundInterface to tip.groundSide;
        connect adjustmentInterface to heightLock.adjust;

        perform action supportFunction: ProvideAmbulatorySupport;
        exhibit state useState: CrutchUseStateMachine;

        constraint fitRange: HeightFitRange {
            in requestedLength = nominalOverallLength;
            in minimumLength = minimumOverallLength;
            in maximumLength = maximumOverallLength;
        }
    }

    part def User {
        attribute bodyMass: MassValue = 82.0;
        attribute preferredLoadShare: LoadFractionValue = 0.30;
        port mobilityAidInterface: UserInterfacePort;
    }

    part def WalkingSurface {
        attribute slope: AngleValue = 2.0;
        attribute dryFrictionCoefficient: CoefficientValue = 0.75;
        attribute wetFrictionCoefficient: CoefficientValue = 0.45;
        port contact: GroundContactPort;
    }

    part def CrutchMobilitySupportSystem {
        attribute missionStatement: String = "A crutch-based mobility support system assists a user during ambulation by accepting body load at ergonomic interfaces, transmitting that load through an adjustable structural member, and producing a stable reaction at the ground.";

        part user: User;
        part crutch: AdjustableForearmCrutch;
        part floor: WalkingSurface;

        connection userToCrutch: UserLoadConnection connect user.mobilityAidInterface to crutch.userInterface;
        connect crutch.groundInterface to floor.contact;
    }

    requirement def PrimaryFunctionRequirement {
        subject crutch: AdjustableForearmCrutch;
        require constraint {
            crutch.ratedVerticalLoad >= 1200.0 and
            crutch.nominalLoadShare >= 0.25 and
            crutch.nominalLoadShare <= 0.50
        }
    }

    requirement def AdjustableHeightRequirement {
        subject crutch: AdjustableForearmCrutch;
        require constraint {
            crutch.minimumOverallLength <= 0.760 and
            crutch.maximumOverallLength >= 1.000
        }
    }

    requirement def LowMassRequirement {
        subject crutch: AdjustableForearmCrutch;
        require constraint {
            crutch.totalMass <= 1.20
        }
    }

    requirement def SlipResistanceRequirement {
        subject tip: RubberTip;
        require constraint {
            tip.staticFrictionCoefficientDry >= 0.75 and
            tip.staticFrictionCoefficientWet >= 0.45
        }
    }

    requirement def StructuralLoadRequirement {
        subject crutch: AdjustableForearmCrutch;
        require constraint {
            crutch.ratedVerticalLoad <= crutch.upperTube.materialYieldLoad and
            crutch.ratedVerticalLoad <= crutch.lowerTube.materialYieldLoad and
            crutch.ratedVerticalLoad <= crutch.heightLock.lockShearCapacity
        }
    }

    requirement def UserComfortRequirement {
        subject crutch: AdjustableForearmCrutch;
        require constraint {
            crutch.handle.gripDiameter >= 0.030 and
            crutch.handle.gripDiameter <= 0.040 and
            crutch.cuff.paddingThickness >= 0.006
        }
    }

    part crutchSupportSystem: CrutchMobilitySupportSystem {
        :>> user.bodyMass = 82.0;
        :>> user.preferredLoadShare = 0.30;
        :>> crutch.nominalOverallLength = 0.910;
        :>> crutch.nominalLoadShare = 0.35;
        :>> floor.slope = 2.0;
        :>> floor.dryFrictionCoefficient = 0.75;
    }

    satisfy PrimaryFunctionRequirement by crutchSupportSystem.crutch.supportFunction;
    satisfy AdjustableHeightRequirement by crutchSupportSystem.crutch.heightLock;
    satisfy LowMassRequirement by crutchSupportSystem.crutch;
    satisfy SlipResistanceRequirement by crutchSupportSystem.crutch.tip;
    satisfy StructuralLoadRequirement by crutchSupportSystem.crutch.upperTube;
    satisfy StructuralLoadRequirement by crutchSupportSystem.crutch.lowerTube;
    satisfy StructuralLoadRequirement by crutchSupportSystem.crutch.heightLock;
    satisfy UserComfortRequirement by crutchSupportSystem.crutch.handle;
    satisfy UserComfortRequirement by crutchSupportSystem.crutch.cuff;
}
