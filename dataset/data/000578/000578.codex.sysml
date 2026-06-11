package CrutchAssistSystemModel {

    import ScalarValues::*;
    import ISQ::*;

    attribute def LengthValue :> length;
    attribute def MassValue :> mass;
    attribute def ForceValue :> force;
    attribute def AngleValue :> planeAngle;
    attribute def TimeValue :> time;
    attribute def RatioValue :> real;

    enum def GroundSurfaceKind {
        enum levelFloor;
        enum ramp;
        enum stairTread;
        enum wetFloor;
        enum unevenOutdoorSurface;
    }

    enum def CrutchUseMode {
        enum stored;
        enum fitted;
        enum weightBearing;
        enum swingThrough;
        enum repositioning;
    }

    item def UserBodyLoad {
        attribute verticalForce : ForceValue;
        attribute lateralForce : ForceValue;
        attribute appliedAtHeight : LengthValue;
    }

    item def HandGripForce {
        attribute compressiveForce : ForceValue;
        attribute shearForce : ForceValue;
    }

    item def GroundReaction {
        attribute normalForce : ForceValue;
        attribute frictionForce : ForceValue;
        attribute surfaceKind : GroundSurfaceKind;
    }

    item def HeightAdjustmentCommand {
        attribute requestedLength : LengthValue;
    }

    item def StabilityStatus {
        attribute slipMargin : RatioValue;
        attribute tipContactConfirmed : Boolean;
        attribute loadWithinLimit : Boolean;
    }

    port def UnderarmSupportPort {
        in item bodyLoad : UserBodyLoad;
    }

    port def HandSupportPort {
        in item gripForce : HandGripForce;
    }

    port def GroundContactPort {
        out item reaction : GroundReaction;
    }

    port def AdjustmentPort {
        in item heightCommand : HeightAdjustmentCommand;
        out item adjustedLength : LengthValue;
    }

    port def StatusPort {
        out item status : StabilityStatus;
    }

    part def AxillaryPad {
        attribute width : LengthValue = 0.18 [m];
        attribute depth : LengthValue = 0.055 [m];
        attribute cushionThickness : LengthValue = 0.025 [m];
        attribute maximumComfortLoad : ForceValue = 350 [N];

        port userInterface : UnderarmSupportPort;
    }

    part def HandGrip {
        attribute diameter : LengthValue = 0.032 [m];
        attribute gripLength : LengthValue = 0.125 [m];
        attribute nominalHeightFromTip : LengthValue = 0.76 [m];
        attribute maximumGripLoad : ForceValue = 500 [N];

        port handInterface : HandSupportPort;
    }

    part def MainTube {
        attribute outerDiameter : LengthValue = 0.022 [m];
        attribute wallThickness : LengthValue = 0.0018 [m];
        attribute minimumLength : LengthValue = 0.95 [m];
        attribute maximumLength : LengthValue = 1.35 [m];
        attribute allowableAxialLoad : ForceValue = 1200 [N];
    }

    part def LowerTube {
        attribute outerDiameter : LengthValue = 0.019 [m];
        attribute wallThickness : LengthValue = 0.0016 [m];
        attribute exposedLength : LengthValue = 0.42 [m];
        attribute allowableAxialLoad : ForceValue = 1000 [N];
    }

    part def HeightAdjustmentMechanism {
        attribute holeSpacing : LengthValue = 0.025 [m];
        attribute locked : Boolean = true;
        attribute selectedLength : LengthValue = 1.15 [m];
        attribute minimumUserHeight : LengthValue = 1.45 [m];
        attribute maximumUserHeight : LengthValue = 1.95 [m];

        port adjust : AdjustmentPort;
    }

    part def RubberTip {
        attribute contactDiameter : LengthValue = 0.045 [m];
        attribute treadDepth : LengthValue = 0.006 [m];
        attribute staticFrictionCoefficient : RatioValue = 0.75;
        attribute wearLimitDepth : LengthValue = 0.002 [m];

        port floorInterface : GroundContactPort;
    }

    part def LoadPath {
        attribute currentAxialLoad : ForceValue;
        attribute currentBendingLoad : ForceValue;
        attribute loadSafetyFactor : RatioValue;
    }

    action def TransferWeight {
        in item loadFromUser : UserBodyLoad;
        in item gripInput : HandGripForce;
        out item reactionAtFloor : GroundReaction;

        first start;
        then receiveUserLoad;
        then combineUnderarmAndHandForces;
        then transmitLoadThroughFrame;
        then generateGroundReaction;
        then done;
    }

    action def AdjustHeight {
        in item command : HeightAdjustmentCommand;
        out item finalLength : LengthValue;

        first unlockPin;
        then slideLowerTube;
        then alignNearestAdjustmentHole;
        then lockPin;
        then verifyLockEngagement;
        then done;
    }

    action def CheckStability {
        in item floorReaction : GroundReaction;
        out item stability : StabilityStatus;

        first senseTipContact;
        then calculateSlipMargin;
        then compareLoadToLimit;
        then reportStatus;
        then done;
    }

    state def CrutchOperationalStates {
        state Stored;
        state Fitted;
        state PositionedForSupport;
        state BearingWeight;
        state SwingingForward;
        state AdjustingHeight;
        state UnsafeContact;

        transition first Stored then Fitted;
        transition Fitted then AdjustingHeight accept HeightAdjustmentCommand;
        transition AdjustingHeight then Fitted;
        transition Fitted then PositionedForSupport;
        transition PositionedForSupport then BearingWeight;
        transition BearingWeight then SwingingForward;
        transition SwingingForward then PositionedForSupport;
        transition BearingWeight then UnsafeContact if not tipContactConfirmed;
        transition UnsafeContact then PositionedForSupport if tipContactConfirmed;
    }

    part def Crutch {
        attribute totalMass : MassValue = 0.85 [kg];
        attribute overallLength : LengthValue = 1.15 [m];
        attribute ratedUserLoad : ForceValue = 900 [N];
        attribute nominalCrutchAngleFromVertical : AngleValue = 12 [deg];
        attribute primaryFunction : String = "Provide external upper-body support that transfers part of a user's body load through a hand grip, underarm pad, structural frame, and ground tip to improve stability and assist ambulation.";

        part axillaryPad : AxillaryPad;
        part handGrip : HandGrip;
        part mainTube : MainTube;
        part lowerTube : LowerTube;
        part adjustmentMechanism : HeightAdjustmentMechanism;
        part rubberTip : RubberTip;
        part loadPath : LoadPath;

        port underarmPort : UnderarmSupportPort;
        port handPort : HandSupportPort;
        port groundPort : GroundContactPort;
        port adjustmentPort : AdjustmentPort;
        port statusPort : StatusPort;

        perform action transferWeight : TransferWeight;
        perform action adjustHeight : AdjustHeight;
        perform action checkStability : CheckStability;

        exhibit state operationalBehavior : CrutchOperationalStates;

        connect underarmPort to axillaryPad.userInterface;
        connect handPort to handGrip.handInterface;
        connect adjustmentPort to adjustmentMechanism.adjust;
        connect groundPort to rubberTip.floorInterface;

        bind overallLength = adjustmentMechanism.selectedLength;
    }

    part def User {
        attribute bodyMass : MassValue = 82 [kg];
        attribute assistedLoadFraction : RatioValue = 0.35;

        port supportedBody : UnderarmSupportPort;
        port supportingHand : HandSupportPort;
    }

    part def WalkingSurface {
        attribute surfaceKind : GroundSurfaceKind = GroundSurfaceKind::levelFloor;
        attribute availableFrictionCoefficient : RatioValue = 0.80;

        port contact : GroundContactPort;
    }

    part crutchBasedMobilityAid {
        part user : User;
        part leftCrutch : Crutch;
        part walkingSurface : WalkingSurface;

        connect user.supportedBody to leftCrutch.underarmPort;
        connect user.supportingHand to leftCrutch.handPort;
        connect leftCrutch.groundPort to walkingSurface.contact;
    }

    requirement def SupportBodyLoadRequirement {
        subject crutch : Crutch;
        require constraint {
            crutch.ratedUserLoad >= 900 [N]
        }
    }

    requirement def AdjustableHeightRequirement {
        subject crutch : Crutch;
        require constraint {
            crutch.adjustmentMechanism.selectedLength >= crutch.mainTube.minimumLength and
            crutch.adjustmentMechanism.selectedLength <= crutch.mainTube.maximumLength
        }
    }

    requirement def SlipResistanceRequirement {
        subject crutch : Crutch;
        require constraint {
            crutch.rubberTip.staticFrictionCoefficient >= 0.70
        }
    }

    requirement def ComfortLoadRequirement {
        subject crutch : Crutch;
        require constraint {
            crutch.axillaryPad.maximumComfortLoad >= 300 [N]
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject crutch : Crutch;
        require constraint {
            crutch.primaryFunction == "Provide external upper-body support that transfers part of a user's body load through a hand grip, underarm pad, structural frame, and ground tip to improve stability and assist ambulation."
        }
    }

    satisfy SupportBodyLoadRequirement by crutchBasedMobilityAid.leftCrutch;
    satisfy AdjustableHeightRequirement by crutchBasedMobilityAid.leftCrutch;
    satisfy SlipResistanceRequirement by crutchBasedMobilityAid.leftCrutch;
    satisfy ComfortLoadRequirement by crutchBasedMobilityAid.leftCrutch;
    satisfy PrimaryFunctionRequirement by crutchBasedMobilityAid.leftCrutch;
}