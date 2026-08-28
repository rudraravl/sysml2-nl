package AutonomousDockingSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Units ----
    unit m;
    unit deg;
    unit 'm/s';
    unit N;
    unit Pa;
    unit Hz;

    // ---- Value types ----
    value def Distance :> Real { unit m; }
    value def LateralOffset :> Real { unit m; }
    value def Angle :> Real { unit deg; }
    value def RelativeVelocity :> Real { unit 'm/s'; }
    value def Force :> Real { unit N; }
    value def Pressure :> Real { unit Pa; }
    value def Diameter :> Real { unit m; }
    value def Frequency :> Real { unit Hz; }

    // ---- Item definitions ----
    item def AlignmentData {
        attribute distance : Distance;
        attribute lateralOffset : LateralOffset;
        attribute pitchAngle : Angle;
        attribute yawAngle : Angle;
        attribute rollAngle : Angle;
        attribute relativeVelocity : RelativeVelocity;
    }

    item def DockingCommand {
        attribute commandType : String;
        attribute timestamp : Real;
    }

    item def CaptureStatus {
        attribute latchesExtended : Boolean;
        attribute latchesLocked : Boolean;
        attribute latchCountEngaged : Integer;
    }

    item def SealStatus {
        attribute sealed : Boolean;
        attribute internalPressure : Pressure;
        attribute leakRate : Real;
    }

    item def MechanicalLink {
        attribute engaged : Boolean;
        attribute loadCapacity : Force;
        attribute rigid : Boolean;
    }

    item def SealLink {
        attribute sealed : Boolean;
        attribute sealMaterial : String;
    }

    item def StructuralLoad {
        attribute axialLoad : Force;
        attribute lateralLoad : Force;
    }

    item def AbortSignal {
        attribute reason : String;
        attribute severity : Integer;
    }

    // ---- Interfaces ----
    interface def SensorInterface {
        end sensor : ActiveDockingMechanism::sensorPort;
        end target : PassiveDockingAdapter::targetPort;
        item alignmentData : AlignmentData;
    }

    interface def MechanicalInterface {
        end activeRing : ActiveDockingMechanism::ringPort;
        end passiveRing : PassiveDockingAdapter::ringPort;
        item mechanicalLink : MechanicalLink;
    }

    interface def SealInterface {
        end activeSeal : ActiveDockingMechanism::sealPort;
        end passiveSeal : PassiveDockingAdapter::sealPort;
        item sealLink : SealLink;
    }

    interface def SpacecraftMountInterface {
        end mechanism : ActiveDockingMechanism::spacecraftInterfacePort;
        end spacecraftBus : SpacecraftBus::dockingMountPort;
        item structuralLoad : StructuralLoad;
    }

    // ---- Spacecraft bus (context) ----
    part def SpacecraftBus {
        port dockingMountPort : StructuralLoad;
        attribute name : String;
    }

    // ---- Passive Docking Adapter ----
    part def PassiveDockingAdapter {
        attribute ringDiameter : Diameter = 1.2 [m];
        attribute sealMaterial : String = "silicone elastomer";

        port targetPort : in AlignmentData;
        port ringPort : in MechanicalLink;
        port sealPort : in SealLink;

        part dockingRing {
            attribute diameter : Diameter = 1.2 [m];
            attribute material : String = "aluminum-lithium alloy";
        }

        part guidePetals {
            attribute count : Integer = 6;
            attribute material : String = "titanium alloy";
            attribute funnelAngle : Angle = 15.0 [deg];
        }

        part matingSeal {
            attribute material : String = "silicone elastomer";
            attribute ratedPressure : Pressure = 101325 [Pa];
        }

        part structuralRing {
            attribute maxLoad : Force = 200000 [N];
        }
    }

    // ---- Active Docking Mechanism ----
    part def ActiveDockingMechanism {
        attribute ringDiameter : Diameter = 1.2 [m];
        attribute latchCount : Integer = 16;
        attribute sealMaterial : String = "silicone elastomer";

        port sensorPort : out AlignmentData;
        port ringPort : out MechanicalLink;
        port sealPort : out SealLink;
        port spacecraftInterfacePort : out StructuralLoad;
        port commandPort : in DockingCommand;
        port abortPort : in AbortSignal;

        // Tolerances
        attribute maxCaptureDistance : Distance = 0.05 [m];
        attribute maxCaptureAngle : Angle = 1.0 [deg];
        attribute maxCaptureVelocity : RelativeVelocity = 0.01 ['m/s'];

        // Status flags
        attribute aligned : Boolean = false;
        attribute withinTolerance : Boolean = false;
        attribute softCaptured : Boolean = false;
        attribute hardCaptured : Boolean = false;
        attribute sealed : Boolean = false;
        attribute verified : Boolean = false;
        attribute aborted : Boolean = false;

        part laserRangefinder {
            attribute measurementRate : Frequency = 10 [Hz];
            attribute rangeMax : Distance = 1000.0 [m];
            attribute rangeMin : Distance = 0.1 [m];
            attribute angularAccuracy : Angle = 0.05 [deg];
            port dataOut : out AlignmentData;
        }

        part dockingRing {
            attribute diameter : Diameter = 1.2 [m];
            attribute material : String = "aluminum-lithium alloy";
        }

        part captureLatches[16] {
            attribute id : Integer;
            attribute extended : Boolean = false;
            attribute locked : Boolean = false;
            attribute maxLoad : Force = 50000 [N];
            attribute actuationTime : Real = 0.5;
        }

        part pressureSeal {
            attribute material : String = "silicone elastomer";
            attribute activated : Boolean = false;
            attribute ratedPressure : Pressure = 101325 [Pa];
        }

        part structuralInterface {
            attribute maxAxialLoad : Force = 200000 [N];
            attribute maxLateralLoad : Force = 50000 [N];
            attribute dampingCoefficient : Real = 0.3;
        }

        part retractionActuator {
            attribute stroke : Distance = 0.3 [m];
            attribute maxForce : Force = 100000 [N];
            attribute retracted : Boolean = false;
        }

        // ---- Docking state machine ----
        state machine dockingStateMachine {
            state Standby {
                entry { aligned = false; withinTolerance = false; softCaptured = false; hardCaptured = false; sealed = false; verified = false; }
            }
            state Sensing;
            state Maneuvering;
            state ReadyForCapture;
            state SoftCapture;
            state HardCapture;
            state Sealing;
            state Verifying;
            state Docked;
            state Aborting;
            state Disengaged;

            transition t_standby_to_sensing
                from Standby to Sensing
                accept DockingCommand;

            transition t_sensing_to_maneuvering
                from Sensing to Maneuvering
                when (!aligned);

            transition t_sensing_to_ready
                from Sensing to ReadyForCapture
                when (aligned and withinTolerance);

            transition t_maneuvering_to_ready
                from Maneuvering to ReadyForCapture
                when (withinTolerance);

            transition t_maneuvering_to_sensing
                from Maneuvering to Sensing
                when (!withinTolerance);

            transition t_ready_to_soft
                from ReadyForCapture to SoftCapture
                accept DockingCommand
                when (commandType == "capture");

            transition t_soft_to_hard
                from SoftCapture to HardCapture
                when (softCaptured);

            transition t_hard_to_sealing
                from HardCapture to HardCapture
                when (hardCaptured)
                then to Sealing;

            transition t_sealing_to_verifying
                from Sealing to Verifying
                when (sealed);

            transition t_verifying_to_docked
                from Verifying to Docked
                when (verified);

            transition t_abort_any
                from {Sensing, Maneuvering, ReadyForCapture, SoftCapture, HardCapture, Sealing, Verifying}
                to Aborting
                accept AbortSignal
                when (reason == "alignmentLost" or reason == "verificationFailed");

            transition t_aborting_to_disengaged
                from Aborting to Disengaged
                when (softCaptured == false and hardCaptured == false);

            transition t_disengaged_to_standby
                from Disengaged to Standby
                accept DockingCommand
                when (commandType == "reset");
        }

        // ---- Docking action sequence ----
        action performDockingSequence {
            in command : DockingCommand;
            in alignment : AlignmentData;
            out finalStatus : String;

            action measureAlignment {
                in data : AlignmentData;
                out alignedResult : Boolean;
                out toleranceResult : Boolean;
            }

            action correctiveManeuver {
                in data : AlignmentData;
                out maneuverComplete : Boolean;
            }

            action engageCaptureLatches {
                out captureStatus : CaptureStatus;
            }

            action retractToHardCapture {
                in captureStatus : CaptureStatus;
                out hardCaptureAchieved : Boolean;
            }

            action activatePressureSeal {
                out sealStatus : SealStatus;
            }

            action verifyConnection {
                in sealStatus : SealStatus;
                out verificationResult : Boolean;
            }

            action abortSequence {
                in abortSignal : AbortSignal;
                out disengaged : Boolean;
            }

            // Control flow
            flow from measureAlignment.alignedResult to correctiveManeuver.maneuverComplete;
            flow from engageCaptureLatches.captureStatus to retractToHardCapture.captureStatus;
            flow from retractToHardCapture.hardCaptureAchieved to activatePressureSeal.sealStatus;
            flow from activatePressureSeal.sealStatus to verifyConnection.sealStatus;
        }
    }

    // ---- Docking System (top-level) ----
    part def DockingSystem {
        attribute systemName : String = "Autonomous Docking System";

        part activeMechanism : ActiveDockingMechanism {
            redefines latchCount = 16;
        }

        part passiveAdapter : PassiveDockingAdapter;

        part activeSpacecraft : SpacecraftBus {
            attribute name = "Chaser Spacecraft";
        }

        part passiveSpacecraft : SpacecraftBus {
            attribute name = "Target Spacecraft";
        }

        connection sensorLink : SensorInterface
            connect activeMechanism.sensorPort to passiveAdapter.targetPort;

        connection mechanicalLink : MechanicalInterface
            connect activeMechanism.ringPort to passiveAdapter.ringPort;

        connection sealLink : SealInterface
            connect activeMechanism.sealPort to passiveAdapter.sealPort;

        connection activeMount : SpacecraftMountInterface
            connect activeMechanism.spacecraftInterfacePort to activeSpacecraft.dockingMountPort;

        connection passiveMount : SpacecraftMountInterface
            connect passiveAdapter.structuralRing to passiveSpacecraft.dockingMountPort;
    }

    // ---- Requirements ----
    requirement def DockingRequirement {
        subject dockingSystem : DockingSystem;
        doc /* Base requirement for the autonomous docking system. */
    }

    requirement SecureRigidConnection :> DockingRequirement {
        doc /* The system shall create a secure, rigid mechanical connection between the two modules. */
        require { dockingSystem.activeMechanism.hardCaptured == true; }
        require { dockingSystem.activeMechanism.captureLatches.locked == true; }
    }

    requirement PressurizedPassageway :> DockingRequirement {
        doc /* The system shall create an airtight, pressurized passageway allowing transfer of crew or resources. */
        require { dockingSystem.activeMechanism.sealed == true; }
        require { dockingSystem.activeMechanism.verified == true; }
        require { dockingSystem.activeMechanism.pressureSeal.ratedPressure >= 101325 [Pa]; }
    }

    requirement AlignmentMeasurement :> DockingRequirement {
        doc /* The active mechanism shall use laser rangefinders to measure distance, angle, and velocity relative to the passive target. */
        require { dockingSystem.activeMechanism.laserRangefinder.measurementRate >= 10 [Hz]; }
        require { dockingSystem.activeMechanism.laserRangefinder.angularAccuracy <= 0.05 [deg]; }
    }

    requirement AlignmentTolerance :> DockingRequirement {
        doc /* The active mechanism shall achieve alignment within specified tolerances before initiating capture. */
        require { dockingSystem.activeMechanism.maxCaptureDistance <= 0.05 [m]; }
        require { dockingSystem.activeMechanism.maxCaptureAngle <= 1.0 [deg]; }
        require { dockingSystem.activeMechanism.maxCaptureVelocity <= 0.01 ['m/s']; }
    }

    requirement CaptureLatchSpecification :> DockingRequirement {
        doc /* The active mechanism shall feature a 1.2-meter diameter docking ring and 16 mechanical capture latches. */
        require { dockingSystem.activeMechanism.ringDiameter == 1.2 [m]; }
        require { dockingSystem.activeMechanism.latchCount == 16; }
        require { dockingSystem.passiveAdapter.ringDiameter == 1.2 [m]; }
    }

    requirement PressureSealSpecification :> DockingRequirement {
        doc /* The active mechanism shall activate a silicone elastomer pressure seal upon hard capture. */
        require { dockingSystem.activeMechanism.pressureSeal.material == "silicone elastomer"; }
        require { dockingSystem.passiveAdapter.matingSeal.material == "silicone elastomer"; }
    }

    requirement GuidePetalsSpecification :> DockingRequirement {
        doc /* The passive adapter shall feature guide petals to funnel the active mechanism during final approach. */
        require { dockingSystem.passiveAdapter.guidePetals.count >= 4; }
        require { dockingSystem.passiveAdapter.guidePetals.funnelAngle <= 20.0 [deg]; }
    }

    requirement StructuralInterfaceStrength :> DockingRequirement {
        doc /* The active unit shall be mounted via a structural interface capable of withstanding significant loads. */
        require { dockingSystem.activeMechanism.structuralInterface.maxAxialLoad >= 200000 [N]; }
        require { dockingSystem.activeMechanism.structuralInterface.maxLateralLoad >= 50000 [N]; }
    }

    requirement SoftCaptureSequence :> DockingRequirement {
        doc /* Upon command, the capture latches shall engage to create a soft capture mechanical link. */
        require { dockingSystem.activeMechanism.softCaptured == true; }
    }

    requirement HardCaptureSequence :> DockingRequirement {
        doc /* Following soft capture, the system shall pull the modules together to achieve hard capture. */
        require { dockingSystem.activeMechanism.hardCaptured == true; }
        require { dockingSystem.activeMechanism.retractionActuator.retracted == true; }
    }

    requirement ConnectionVerification :> DockingRequirement {
        doc /* The system shall verify that the connection is secure and airtight after sealing. */
        require { dockingSystem.activeMechanism.verified == true; }
    }

    requirement AbortAndDisengage :> DockingRequirement {
        doc /* The system shall abort the sequence and safely disengage if alignment is lost or verification fails at any point. */
        require { dockingSystem.activeMechanism.aborted == true; }
        require { dockingSystem.activeMechanism.captureLatches.extended == false; }
    }

    requirement DockingSequenceOrder :> DockingRequirement {
        doc /* The docking process shall follow the sequence: sense, maneuver, soft capture, hard capture, seal, verify. */
        require { dockingSystem.activeMechanism.dockingStateMachine.Docked.isTerminal; }
    }
}
