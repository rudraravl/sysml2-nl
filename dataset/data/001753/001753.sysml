package 'Biomimetic Gecko Adhesion System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    doc /*
        This model describes a biomimetic adhesion system inspired by gecko feet,
        which enables reversible attachment to various surfaces without adhesives.
        The system uses van der Waals forces through micro-structured contact surfaces
        to achieve controllable grip and release, mimicking the gecko's ability to
        climb smooth vertical surfaces and even cling to ceilings.
    */

    attribute def AdhesionForce :> ForceValue;
    attribute def ContactArea :> AreaValue;
    attribute def ShearAngle :> AngleValue;
    attribute def SurfaceRoughness :> LengthValue;
    attribute def GripState :> String;

    item def Surface {
        attribute roughness :> SurfaceRoughness;
        attribute material : String;
        attribute orientation :> AngleValue;
    }

    item def Load {
        attribute mass :> MassValue;
        attribute appliedForce :> ForceValue;
    }

    port def MechanicalContactPort {
        in attribute normalForce :> ForceValue;
        in attribute shearForce :> ForceValue;
        out attribute adhesionForce :> AdhesionForce;
        out attribute contactState :> GripState;
    }

    port def ActuationPort {
        in attribute angleCommand :> AngleValue;
        in attribute engageCommand : Boolean;
        out attribute currentAngle :> AngleValue;
    }

    port def LoadPort {
        in item supportedLoad : Load;
        out attribute reactionForce :> ForceValue;
    }

    attribute def SetaeDensity :> Real {
        doc /* Number of setae (micro-hairs) per unit area. */
    }

    part def MicroSeta {
        attribute length :> LengthValue;
        attribute diameter :> LengthValue;
        attribute stiffness :> Real;
        attribute tipArea :> AreaValue;

        perform action generateAdhesion {
            in surfaceContact : Boolean;
            in normalLoad :> ForceValue;
            out adhesiveForce :> ForceValue;
        }
    }

    part def SetaeArray {
        attribute arrayArea :> ContactArea;
        attribute setaeDensity :> SetaeDensity;
        attribute totalSetae : Integer;

        part individualSetae : MicroSeta[10000..1000000];

        port mechanicalInterface : MechanicalContactPort;

        perform action collectiveAdhesion {
            in surfaceType : Surface;
            in appliedLoad :> ForceValue;
            out totalAdhesion :> AdhesionForce;
        }
    }

    part def FlexibleLamella {
        attribute lamellaWidth :> LengthValue;
        attribute lamellaThickness :> LengthValue;
        attribute flexibility :> Real;

        part setaeLayer : SetaeArray;

        perform action conformToSurface {
            in surfaceProfile : Surface;
            out contactQuality :> Real;
        }
    }

    part def GeckoToe {
        attribute toeLength :> LengthValue;
        attribute numberOfLamellae : Integer;

        part lamellae : FlexibleLamella[5..20];

        port contact : MechanicalContactPort;

        perform action distributeLoad {
            in totalLoad :> ForceValue;
            out lamellarLoads :> ForceValue[*];
        }
    }

    part def AngleController {
        attribute currentPeelAngle :> ShearAngle;
        attribute targetPeelAngle :> ShearAngle;

        port actuationControl : ActuationPort;

        perform action adjustAngle {
            in desiredAngle :> AngleValue;
            in currentAngle :> AngleValue;
            out controlSignal :> AngleValue;
        }
    }

    part def AdhesivePad {
        attribute padArea :> AreaValue;
        attribute maxAdhesionCapacity :> AdhesionForce;
        attribute currentAdhesion :> AdhesionForce;

        part toes : GeckoToe[4..6];
        part angleControl : AngleController;

        port surfaceContact : MechanicalContactPort;
        port actuation : ActuationPort;
        port loadSupport : LoadPort;

        connection angleToToes connect angleControl.actuationControl to actuation;
        connection toesToSurface connect toes.contact to surfaceContact;

        perform action engageGrip {
            in targetSurface : Surface;
            out achievedAdhesion :> AdhesionForce;
        }

        perform action releaseGrip {
            in peelAngle :> ShearAngle;
            out releasedState : Boolean;
        }
    }

    attribute def ApproachCommand :> String;
    attribute def SurfaceDetected :> Boolean;
    attribute def ReleaseCommand :> String;
    attribute def AdhesionBroken :> Boolean;

    state def AdhesionSystemState {
        entry action initializeSystem;

        state detached {
            entry action resetSetae;
        }

        state approaching {
            do action alignWithSurface;
        }

        state engaging {
            entry action increaseNormalForce;
            do action maximizeContact;
        }

        state adhered {
            do action maintainGrip;
            do action monitorLoad;
        }

        state releasing {
            entry action initiateRelease;
            do action applyPeelAngle;
        }

        state overloaded {
            do action emergencyRelease;
        }

        transition detached_to_approaching
            first detached
            accept approachCommand : ApproachCommand
            then approaching;

        transition approaching_to_engaging
            first approaching
            accept surfaceDetected : SurfaceDetected
            then engaging;

        transition engaging_to_adhered
            first engaging
            accept adhesionEstablished : AdhesionForce
            if adhesionEstablished > 10.0 [N]
            then adhered;

        transition adhered_to_releasing
            first adhered
            accept releaseCommand : ReleaseCommand
            then releasing;

        transition releasing_to_detached
            first releasing
            accept adhesionBroken : AdhesionBroken
            then detached;

        transition adhered_to_overloaded
            first adhered
            accept excessiveLoad : ForceValue
            if excessiveLoad > 100.0 [N]
            then overloaded;

        transition overloaded_to_releasing
            first overloaded
            accept after 0.5 [s]
            then releasing;
    }

    action def CalculateAdhesion {
        in contactArea :> AreaValue;
        in setaeDensity :> SetaeDensity;
        in surfaceRoughness :> SurfaceRoughness;
        out adhesionForce :> AdhesionForce;
    }

    action def ModulatePeelAngle {
        in desiredState : GripState;
        in currentAngle :> ShearAngle;
        out targetAngle :> ShearAngle;
    }

    action def MonitorLoadCapacity {
        in appliedLoad :> ForceValue;
        in maxCapacity :> AdhesionForce;
        out safetyMargin :> Real;
        out overloadWarning : Boolean;
    }

    action def PerformAdhesionCycle {
        in targetSurface : Surface;
        in payloadMass :> MassValue;
        out cycleSuccess : Boolean;
        out finalAdhesion :> AdhesionForce;

        first start;

        then action detectSurface {
            in surface = targetSurface;
            out surfaceCharacteristics : Surface;
        }

        then action calculateRequiredAdhesion : CalculateAdhesion {
            in contactArea = 0.01 [m^2];
            in setaeDensity = 14000.0;
            in surfaceRoughness = detectSurface.surfaceCharacteristics.roughness;
            out adhesionForce;
        }

        then decide;
            if calculateRequiredAdhesion.adhesionForce > payloadMass * 9.81 [m/s^2] then proceedToEngage;
            if calculateRequiredAdhesion.adhesionForce <= payloadMass * 9.81 [m/s^2] then abortCycle;

        action proceedToEngage {
            then action alignPad {
                in surface = targetSurface;
                out alignmentAngle :> AngleValue;
            }

            then action engageSetae {
                in angle = alignPad.alignmentAngle;
                out engaged : Boolean;
            }

            then action applyLoad {
                in mass = payloadMass;
                out loadForce :> ForceValue;
            }

            then action monitorStability : MonitorLoadCapacity {
                in appliedLoad = applyLoad.loadForce;
                in maxCapacity = calculateRequiredAdhesion.adhesionForce;
                out safetyMargin;
                out overloadWarning;
            }

            then decide;
                if monitorStability.safetyMargin > 0.2 then holdPosition;
                if monitorStability.safetyMargin <= 0.2 then reinforceGrip;

            action holdPosition {
                then action maintainContact {
                    in duration :> TimeValue;
                    out stable : Boolean;
                }
                then assign cycleSuccess := true;
                then assign finalAdhesion := calculateRequiredAdhesion.adhesionForce;
            }

            action reinforceGrip {
                then action increaseContactArea {
                    in currentArea :> AreaValue;
                    out newArea :> AreaValue;
                }
                then holdPosition;
            }
        }

        action abortCycle {
            then assign cycleSuccess := false;
            then assign finalAdhesion := 0.0 [N];
        }

        then done;
    }

    action def ReleaseSequence {
        in currentAdhesion :> AdhesionForce;
        out releaseComplete : Boolean;

        first start;

        then action calculatePeelAngle : ModulatePeelAngle {
            in desiredState = "release";
            in currentAngle = 0.0 ['°'];
            out targetAngle;
        }

        then action applyPeel {
            in peelAngle = calculatePeelAngle.targetAngle;
            out peelForce :> ForceValue;
        }

        then action reduceNormalForce {
            in currentForce :> ForceValue;
            out reducedForce :> ForceValue;
        }

        then action verifyDetachment {
            in residualAdhesion :> AdhesionForce;
            out detached : Boolean;
        }

        then assign releaseComplete := verifyDetachment.detached;

        then done;
    }

    part def GeckoGripperSystem {
        doc /*
            Biomimetic adhesion system based on gecko toe pad structure.
            Uses hierarchical micro-structured surfaces with millions of setae
            to achieve dry, reversible adhesion through van der Waals forces.
            Primary function: Enable controllable attachment and detachment
            on various surfaces for climbing robots and manipulation systems.
        */

        attribute operatingLoad :> MassValue;
        attribute maxSupportedLoad :> MassValue;
        attribute adhesionEfficiency :> Real;
        attribute cycleCount : Integer;

        part adhesivePads : AdhesivePad[2..4] {
            attribute :>> padArea = 0.0025 [m^2];
            attribute :>> maxAdhesionCapacity = 50.0 [N];
        }

        part loadDistributor {
            perform action balanceLoad {
                in totalLoad :> ForceValue;
                out padLoads :> ForceValue[*];
            }
        }

        part controlSystem : AngleController {
            attribute :>> currentPeelAngle = 0.0 ['°'];
            attribute :>> targetPeelAngle = 30.0 ['°'];
        }

        connection padControl [2..4] connect controlSystem.actuationControl to adhesivePads.actuation;

        perform action gripCycle : PerformAdhesionCycle[*] ordered {
            in attribute :>> targetSurface;
            in attribute :>> payloadMass = operatingLoad;
            out attribute :>> cycleSuccess;
            out attribute :>> finalAdhesion;
        }

        perform action releaseAction : ReleaseSequence[*] ordered {
            in attribute :>> currentAdhesion;
            out attribute :>> releaseComplete;
        }

        exhibit state systemState : AdhesionSystemState;
    }

    part geckoGripper : GeckoGripperSystem {
        attribute :>> operatingLoad = 5.0 [kg];
        attribute :>> maxSupportedLoad = 10.0 [kg];
        attribute :>> adhesionEfficiency = 0.85;
        attribute :>> cycleCount = 0;
    }

    requirement def PrimaryFunctionRequirement {
        doc /*
            The gecko-inspired adhesion system shall provide reversible,
            controllable attachment to surfaces using dry adhesion mechanisms.
        */

        subject system : GeckoGripperSystem;

        require constraint reversibleAdhesion {
            doc /* System shall attach and detach without leaving residue. */
            system.adhesionEfficiency >= 0.80
        }

        require constraint loadCapacity {
            doc /* System shall support minimum payload mass. */
            system.maxSupportedLoad >= 5.0 [kg]
        }
    }

    requirement def PerformanceRequirement {
        doc /*
            System shall achieve gecko-like adhesion performance metrics.
        */

        subject system : GeckoGripperSystem;

        require constraint adhesionStrength {
            doc /* Adhesion force per unit area shall match biological performance. */
            system.adhesivePads.maxAdhesionCapacity / system.adhesivePads.padArea >= 10000.0 [N/m^2]
        }

        require constraint cycleDurability {
            doc /* System shall maintain performance over repeated cycles. */
            system.cycleCount <= 100000
        }
    }

    requirement def SafetyRequirement {
        doc /*
            System shall operate safely under all load conditions.
        */

        subject system : GeckoGripperSystem;

        require constraint overloadProtection {
            doc /* System shall release before structural failure. */
            system.operatingLoad <= 0.8 * system.maxSupportedLoad
        }
    }

    requirement systemFunctionRequirement : PrimaryFunctionRequirement {
        subject geckoGripper;

        assume constraint smoothSurface {
            doc /* System operates on surfaces with roughness less than setae tip size. */
            true
        }

        require reversibleAdhesion;
        require loadCapacity;
    }

    requirement systemPerformance : PerformanceRequirement {
        subject geckoGripper;

        require adhesionStrength;
        require cycleDurability;
    }

    requirement systemSafety : SafetyRequirement {
        subject geckoGripper;

        require overloadProtection;
    }
}
