package AutomatedUrinalSystem {
    import ScalarValues::*;

    // ===== Value Types =====

    value def Distance :> Real {
        doc "Distance in meters (m)";
    }

    value def Duration :> Real {
        doc "Time duration in seconds (s)";
    }

    value def Volume :> Real {
        doc "Volume in liters (L)";
    }

    value def FlowRate :> Real {
        doc "Volumetric flow rate in liters per second (L/s)";
    }

    value def PressureValue :> Real {
        doc "Pressure in bar (bar)";
    }

    value def TemperatureValue :> Real {
        doc "Temperature in degrees Celsius (degC)";
    }

    value def Power :> Real {
        doc "Power consumption in watts (W)";
    }

    // ===== Enumerations =====

    enum def PresenceStatus {
        ABSENT;
        PRESENT;
    }

    enum def ValveCommand {
        CLOSE;
        OPEN;
    }

    // ===== Items =====

    item def FreshWater {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute purityGrade : String = "Potable";
    }

    item def WasteLiquid {
        attribute contaminationLevel : Real;
    }

    item def Wastewater :> WasteLiquid {
        doc "Mixture of waste and flush water";
        attribute dilutionRatio : Real;
    }

    item def SewerGas {
        doc "Unpleasant gases from the building sewer system";
        attribute odorIntensity : Real;
    }

    // ===== Port Definitions =====

    port def DetectionOutPort {
        out presence : PresenceStatus;
    }

    port def DetectionInPort {
        in presence : PresenceStatus;
    }

    port def CommandOutPort {
        out command : ValveCommand;
    }

    port def CommandInPort {
        in command : ValveCommand;
    }

    port def WaterFlowPort {
        flow of FreshWater;
    }

    port def WasteFlowPort {
        flow of Wastewater;
    }

    // ===== Part Definitions =====

    part def InfraredSensor {
        doc "Infrared proximity sensor for touchless user detection";
        attribute maxRange : Distance = 0.6;
        attribute mountingHeight : Distance = 1.2;
        attribute powerConsumption : Power = 0.5;
        attribute detected : Boolean = false;
        port detectionOut : DetectionOutPort;

        state detectionLogic {
            initial Idle;
            state Idle {
                doc "No user detected — sensor continuously scans";
                entry { detectionOut.presence = PresenceStatus::ABSENT; }
                do { detected = readInfraredReflection(); }
                transition Idle -> UserPresent
                    when detected == true;
            }
            state UserPresent {
                doc "User standing in front of urinal";
                entry { detectionOut.presence = PresenceStatus::PRESENT; }
                do { detected = readInfraredReflection(); }
                transition UserPresent -> Idle
                    when detected == false;
            }
        }

        action def readInfraredReflection :> Boolean {
            doc "Reads IR sensor and returns true if a warm body is within range";
        }
    }

    part def FlushController {
        doc "Electronic controller acting as the system brain";
        attribute flushDelay : Duration = 1.5;
        attribute flushDuration : Duration = 3.0;
        attribute flushVolume : Volume = 1.0;
        attribute supplyVoltage : Real = 5.0;
        port sensorInput : DetectionInPort;
        port valveOutput : CommandOutPort;

        state controllerLogic {
            initial Ready;
            state Ready {
                doc "System idle, awaiting next user";
                entry { valveOutput.command = ValveCommand::CLOSE; }
                transition Ready -> Occupied
                    when sensorInput.presence == PresenceStatus::PRESENT;
            }
            state Occupied {
                doc "User present at urinal";
                transition Occupied -> Waiting
                    when sensorInput.presence == PresenceStatus::ABSENT;
            }
            state Waiting {
                doc "User departed — waiting preset delay before flushing";
                transition Waiting -> Flushing
                    after flushDelay;
            }
            state Flushing {
                doc "Flush cycle in progress — valve open";
                entry { valveOutput.command = ValveCommand::OPEN; }
                exit { valveOutput.command = ValveCommand::CLOSE; }
                transition Flushing -> Ready
                    after flushDuration;
            }
        }
    }

    part def SolenoidValve {
        doc "Electrically actuated valve that releases measured fresh water";
        attribute nominalFlowRate : FlowRate = 0.35;
        attribute operatingPressure : PressureValue = 3.0;
        attribute responseTime : Duration = 0.1;
        port commandInput : CommandInPort;
        port waterInlet : WaterFlowPort;
        port waterOutlet : WaterFlowPort;

        state valveLogic {
            initial Closed;
            state Closed {
                doc "Valve closed — no water flow";
                entry { /* valve physically closed */ }
                transition Closed -> Open
                    when commandInput.command == ValveCommand::OPEN;
            }
            state Open {
                doc "Valve open — fresh water flowing to bowl";
                entry { /* valve physically open */ }
                transition Open -> Closed
                    when commandInput.command == ValveCommand::CLOSE;
            }
        }
    }

    part def CeramicBowl {
        doc "Main ceramic fixture for collecting and rinsing liquid waste";
        attribute bowlCapacity : Volume = 2.0;
        attribute surfaceFinish : String = "Glazed ceramic";
        attribute rimHeight : Distance = 0.65;
        port rinseInlet : WaterFlowPort;
        port wasteOutlet : WasteFlowPort;

        action def Rinse {
            doc "Fresh water rinses the bowl surface, carrying waste to the outlet";
            in incomingWater : FreshWater;
            out outgoingWaste : Wastewater;
        }
    }

    part def PTrap {
        doc "Curved pipe section holding a water seal to prevent sewer gas backup";
        attribute sealVolume : Volume = 0.3;
        attribute trapDiameter : Distance = 0.05;
        attribute material : String = "PVC";
        attribute sealMaintained : Boolean = true;
        port wasteInlet : WasteFlowPort;
        port wasteOutlet : WasteFlowPort;

        invariant sealIntegrity {
            sealVolume >= 0.3;
            sealMaintained == true;
        }
    }

    part def DrainPipe {
        doc "Main drain pipe carrying wastewater to the building sewage system";
        attribute diameter : Distance = 0.1;
        attribute length : Distance = 5.0;
        attribute slope : Real = 0.02;
        port wasteInlet : WasteFlowPort;
        port wasteOutlet : WasteFlowPort;
    }

    part def FreshWaterSupply {
        doc "Building potable water supply connection";
        attribute supplyPressure : PressureValue = 3.0;
        attribute supplyTemperature : TemperatureValue = 15.0;
        port supplyOutlet : WaterFlowPort;
    }

    // ===== System Assembly =====

    part def TouchlessUrinalSystem {
        doc "Automated, touchless urinal system for hygienic liquid waste disposal in public or commercial restrooms";

        part sensor : InfraredSensor;
        part controller : FlushController;
        part solenoidValve : SolenoidValve;
        part bowl : CeramicBowl;
        part ptrap : PTrap;
        part drain : DrainPipe;
        part waterSupply : FreshWaterSupply;

        // Signal connections
        connect sensor.detectionOut to controller.sensorInput;
        connect controller.valveOutput to solenoidValve.commandInput;

        // Water flow connections
        connect waterSupply.supplyOutlet to solenoidValve.waterInlet;
        connect solenoidValve.waterOutlet to bowl.rinseInlet;

        // Wastewater flow connections
        connect bowl.wasteOutlet to ptrap.wasteInlet;
        connect ptrap.wasteOutlet to drain.wasteInlet;
    }

    // ===== Top-level System Instance =====

    part urinalSystem : TouchlessUrinalSystem;

    // ===== Requirements =====

    requirement def HandsFreeOperation {
        doc "The system shall provide hands-free, touchless operation to improve sanitation in public or commercial restrooms.";
    }

    requirement def WaterConservation {
        doc "The system shall conserve water by using a controlled, automated flush cycle.";
        attribute maxFlushVolume : Volume = 1.5;
    }

    requirement def UserDetection {
        doc "An infrared sensor mounted on the unit shall detect when a person is standing in front of the urinal.";
        attribute detectionRange : Distance = 0.6;
        attribute mountingHeight : Distance = 1.2;
    }

    requirement def DepartureSignaling {
        doc "Once the person leaves, the sensor shall signal their departure to the controller.";
    }

    requirement def PresetFlushDelay {
        doc "The controller shall wait for a brief, preset delay after user departure before initiating the flush.";
        attribute delayDuration : Duration = 1.5;
    }

    requirement def ValveActuation {
        doc "The controller shall send an electrical command to a solenoid valve to open and release water.";
    }

    requirement def MeasuredWaterRelease {
        doc "The solenoid valve shall open to release a measured amount of fresh water into the main ceramic fixture bowl.";
        attribute flushVolume : Volume = 1.0;
        attribute flushDuration : Duration = 3.0;
        attribute flowRate : FlowRate = 0.35;
    }

    requirement def BowlRinsing {
        doc "The fresh water shall rinse the bowl, carrying waste down the drain.";
    }

    requirement def SewerGasPrevention {
        doc "The P-trap shall hold a small amount of water to create a seal preventing sewer gases from backing up into the restroom.";
        attribute minSealVolume : Volume = 0.3;
    }

    requirement def WastewaterDrainage {
        doc "Wastewater shall flow from the bowl through the P-trap into the main drain pipe and away into the building sewage system.";
    }

    requirement def CycleCompletion {
        doc "After a fixed duration, the controller shall close the solenoid valve, stopping the water flow and completing the cycle, leaving the system ready for the next user.";
        attribute flushDuration : Duration = 3.0;
    }

    // ===== Requirement Usages =====

    requirement handsFreeReq : HandsFreeOperation;
    requirement conservationReq : WaterConservation;
    requirement detectionReq : UserDetection;
    requirement departureReq : DepartureSignaling;
    requirement delayReq : PresetFlushDelay;
    requirement actuationReq : ValveActuation;
    requirement releaseReq : MeasuredWaterRelease;
    requirement rinsingReq : BowlRinsing;
    requirement sealReq : SewerGasPrevention;
    requirement drainageReq : WastewaterDrainage;
    requirement completionReq : CycleCompletion;

    // ===== Satisfaction =====

    satisfy handsFreeReq by urinalSystem;
    satisfy conservationReq by urinalSystem;
    satisfy detectionReq by urinalSystem.sensor;
    satisfy departureReq by urinalSystem.sensor;
    satisfy delayReq by urinalSystem.controller;
    satisfy actuationReq by urinalSystem.controller;
    satisfy releaseReq by urinalSystem.solenoidValve;
    satisfy rinsingReq by urinalSystem.bowl;
    satisfy sealReq by urinalSystem.ptrap;
    satisfy drainageReq by urinalSystem.drain;
    satisfy completionReq by urinalSystem.controller;
}
