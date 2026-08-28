package AdjustableUnderarmCrutchModel {

    private import ScalarValues::*;
    private import ISQ::*;

    public import Definitions::*;

    package Definitions {

        private import ScalarValues::*;
        private import ISQ::*;

        attribute def LengthValue :> Real;
        attribute def MassValue :> Real;
        attribute def ForceValue :> Real;
        attribute def PressureValue :> Real;
        attribute def Dimensionless :> Real;

        attribute def StructuralMaterial {
            attribute name : String;
            attribute tensileStrength : PressureValue;
            attribute youngModulus : PressureValue;
        }

        attribute aluminumAlloy : StructuralMaterial {
            attribute name = "Aluminum Alloy 6061";
            attribute tensileStrength = 300000000.0;
            attribute youngModulus = 69000000000.0;
        }

        attribute polymerFoam : StructuralMaterial {
            attribute name = "Closed-cell Polymer Foam";
            attribute tensileStrength = 10000000.0;
            attribute youngModulus = 5000000.0;
        }

        attribute rubberCompound : StructuralMaterial {
            attribute name = "High-Friction Rubber Compound";
            attribute tensileStrength = 10000000.0;
            attribute youngModulus = 5000000.0;
        }

        port def MechanicalPort {
            attribute axialLoad : ForceValue;
        }

        port def UserInterfacePort {
            attribute appliedLoad : ForceValue;
        }

        port def GroundContactPort {
            attribute normalForce : ForceValue;
            attribute frictionCoefficient : Dimensionless;
        }

        action def AdjustHeight {
            in targetLength : LengthValue;
            out achievedLength : LengthValue;
            out locked : Boolean;
        }

        action def LockPin {
            in position : Integer;
            out engaged : Boolean;
        }

        action def BearLoad {
            in appliedLoad : ForceValue;
            out supportedLoad : ForceValue;
        }

        action def ReleaseLoad {
            out supportedLoad : ForceValue;
        }

        action def InspectCrutch {
            out serviceNeeded : Boolean;
        }

        state def CrutchOperationalStates;

        attribute def ConfigureEvent;
        attribute def HeightSetEvent;
        attribute def StartUseEvent;
        attribute def StopUseEvent;
        attribute def StoreEvent;
        attribute def InspectEvent;
        attribute def ReturnToServiceEvent;
        attribute def WeightAppliedEvent;
        attribute def WeightReleasedEvent;

        part def HeightLockMechanism {
            attribute pinPositions : Integer = 10;
            attribute currentPinPosition : Integer = 5;
            attribute lockEngaged : Boolean = true;
            port shaftInterface : MechanicalPort;
        }

        part def TelescopicShaft {
            attribute material : StructuralMaterial = aluminumAlloy;
            attribute minLength : LengthValue = 0.8;
            attribute maxLength : LengthValue = 1.4;
            attribute currentLength : LengthValue = 1.1;
            attribute tubeDiameter : LengthValue = 0.03;

            part upperTube {
                attribute outerDiameter : LengthValue = 0.03;
                port topEnd : MechanicalPort;
                port bottomEnd : MechanicalPort;
                port gripMount : MechanicalPort;
            }

            part lowerTube {
                attribute outerDiameter : LengthValue = 0.025;
                port topEnd : MechanicalPort;
                port bottomEnd : MechanicalPort;
            }

            part lock : HeightLockMechanism;

            port topEnd : MechanicalPort;
            port gripMount : MechanicalPort;
            port bottomEnd : MechanicalPort;

            connect topEnd to upperTube.topEnd;
            connect upperTube.bottomEnd to lowerTube.topEnd;
            connect lock.shaftInterface to upperTube.bottomEnd;
            connect gripMount to upperTube.gripMount;
            connect bottomEnd to lowerTube.bottomEnd;
        }

        part def UnderarmCuff {
            attribute paddingThickness : LengthValue = 0.03;
            attribute cuffWidth : LengthValue = 0.12;
            attribute paddingMaterial : StructuralMaterial = polymerFoam;
            port shaftInterface : MechanicalPort;
            port userInterface : UserInterfacePort;
        }

        part def HandGrip {
            attribute gripDiameter : LengthValue = 0.035;
            attribute gripLength : LengthValue = 0.12;
            attribute material : StructuralMaterial = polymerFoam;
            port shaftInterface : MechanicalPort;
            port userInterface : UserInterfacePort;
        }

        part def RubberFootTip {
            attribute treadPattern : String = "High-friction tread";
            attribute frictionCoefficient : Dimensionless = 0.9;
            attribute tipDiameter : LengthValue = 0.04;
            attribute material : StructuralMaterial = rubberCompound;
            port shaftInterface : MechanicalPort;
            port groundInterface : GroundContactPort;
        }

        part def UnderarmCrutch {
            attribute totalMass : MassValue = 1.2;
            attribute maxLoad : ForceValue = 1500.0;
            attribute minHeight : LengthValue = 1.0;
            attribute maxHeight : LengthValue = 1.5;
            attribute currentHeight : LengthValue = 1.3;
            attribute yieldStrength : ForceValue = 3000.0;

            part shaft : TelescopicShaft;
            part cuff : UnderarmCuff;
            part grip : HandGrip;
            part footTip : RubberFootTip;

            port userLoadPort : UserInterfacePort;
            port groundPort : GroundContactPort;

            connect cuff.shaftInterface to shaft.topEnd;
            connect grip.shaftInterface to shaft.gripMount;
            connect footTip.shaftInterface to shaft.bottomEnd;
            connect userLoadPort to cuff.userInterface;
            connect userLoadPort to grip.userInterface;
            connect groundPort to footTip.groundInterface;
        }

        part def User {
            attribute bodyMass : MassValue;
            attribute height : LengthValue;
            attribute impairmentType : String;
            port crutchInterface : UserInterfacePort;
        }

        part def WalkingSystem {
            part user : User;
            part crutch : UnderarmCrutch;
            connect user.crutchInterface to crutch.userLoadPort;
        }

        use case def ConfigureHeightUseCase {
            subject crutch : UnderarmCrutch;
            actor user : User;
            objective {
                /* Adjust crutch height to user stature */
            }
        }

        use case def WalkWithCrutchUseCase {
            subject crutch : UnderarmCrutch;
            actor user : User;
            objective {
                /* Provide stable support during walking */
            }
        }

        use case def UseCrutch {
            subject crutch : UnderarmCrutch;
            actor user : User;
            objective {
                /* Provide mobility assistance for user */
            }
            include use case configureHeight : ConfigureHeightUseCase {
                subject = crutch;
                actor user = UseCrutch::user;
            }
            include use case walkWithCrutch : WalkWithCrutchUseCase {
                subject = crutch;
                actor user = UseCrutch::user;
            }
        }
    }

    package Requirements {

        private import Definitions::*;

        requirement def LoadCapacityRequirement {
            subject crutch : UnderarmCrutch;
            attribute requiredMaxLoad : ForceValue = 1500.0;
            require constraint { crutch.maxLoad >= requiredMaxLoad }
        }

        requirement def StructuralIntegrityRequirement {
            subject crutch : UnderarmCrutch;
            attribute safetyFactor : Real = 2.0;
            require constraint { crutch.yieldStrength >= crutch.maxLoad * safetyFactor }
        }

        requirement def WeightRequirement {
            subject crutch : UnderarmCrutch;
            attribute maxMass : MassValue = 2.0;
            require constraint { crutch.totalMass <= maxMass }
        }

        requirement def AdjustabilityRequirement {
            subject crutch : UnderarmCrutch;
            attribute minAdjustmentRange : LengthValue = 0.5;
            attribute minPinPositions : Integer = 8;
            require constraint { (crutch.shaft.maxLength - crutch.shaft.minLength) >= minAdjustmentRange }
            require constraint { crutch.shaft.lock.pinPositions >= minPinPositions }
        }

        requirement def TractionRequirement {
            subject crutch : UnderarmCrutch;
            attribute minFrictionCoefficient : Real = 0.8;
            require constraint { crutch.footTip.frictionCoefficient >= minFrictionCoefficient }
        }

        requirement def ComfortRequirement {
            subject crutch : UnderarmCrutch;
            attribute minPaddingThickness : LengthValue = 0.02;
            attribute minGripDiameter : LengthValue = 0.025;
            attribute maxGripDiameter : LengthValue = 0.04;
            require constraint { crutch.cuff.paddingThickness >= minPaddingThickness }
            require constraint { crutch.grip.gripDiameter >= minGripDiameter }
            require constraint { crutch.grip.gripDiameter <= maxGripDiameter }
        }

        requirement CrutchSystemRequirements {
            public import LoadCapacityRequirement;
            public import StructuralIntegrityRequirement;
            public import WeightRequirement;
            public import AdjustabilityRequirement;
            public import TractionRequirement;
            public import ComfortRequirement;
        }
    }

    package Usages {

        private import Definitions::*;
        private import Requirements::*;

        requirement loadCapReq : LoadCapacityRequirement;
        requirement structIntegReq : StructuralIntegrityRequirement;
        requirement weightReq : WeightRequirement;
        requirement adjustReq : AdjustabilityRequirement;
        requirement tractionReq : TractionRequirement;
        requirement comfortReq : ComfortRequirement;

        part crutch : UnderarmCrutch {

            action adjustHeight : AdjustHeight;
            action lockPin : LockPin;
            action bearLoad : BearLoad;
            action releaseLoad : ReleaseLoad;
            action inspectCrutch : InspectCrutch;

            state operationalStates : CrutchOperationalStates {
                entry; then storage;

                state storage;

                accept ConfigureEvent
                    do adjustHeight
                    then configuring;

                state configuring {
                    entry adjustHeight;
                    exit lockPin;
                }

                accept HeightSetEvent
                    then ready;

                state ready;

                accept StartUseEvent
                    then active;
                accept StoreEvent
                    then storage;
                accept InspectEvent
                    then maintenance;

                state active {
                    entry; then stance;
                    do bearLoad;
                    exit releaseLoad;

                    state stance;
                    accept WeightReleasedEvent
                        then swing;

                    state swing;
                    accept WeightAppliedEvent
                        then stance;
                }
                accept StopUseEvent
                    then ready;

                state maintenance {
                    entry inspectCrutch;
                }
                accept ReturnToServiceEvent
                    then ready;
            }

            satisfy loadCapReq;
            satisfy structIntegReq;
            satisfy weightReq;
            satisfy adjustReq;
            satisfy tractionReq;
            satisfy comfortReq;
        }

        part walkingSystem : WalkingSystem;

        use case useCrutch : UseCrutch;
    }
}
