package UtilityFog {
    import ScalarValues::*;

    // ===== Units =====
    unit mm;
    unit N;
    unit mW;
    unit Mbps;
    unit MHz;
    unit mg;
    unit MPa;
    unit 'kg/m3';
    unit ms;
    unit s;
    unit percent;

    // ===== Value Types =====
    value type Length :> Real { unit mm; }
    value type Force :> Real { unit N; }
    value type Power :> Real { unit mW; }
    value type Bandwidth :> Real { unit Mbps; }
    value type Frequency :> Real { unit MHz; }
    value type Mass :> Real { unit mg; }
    value type Stress :> Real { unit MPa; }
    value type Density :> Real { unit 'kg/m3'; }
    value type Duration :> Real { unit ms; }
    value type Percentage :> Real { unit percent; }
    value type FogletCount :> Integer;

    // ===== Enumerations =====
    enum def ArmState { retracted; extended; grasped; locked; }
    enum def FogletStatus { standby; idle; active; failed; isolated; }
    enum def ClusterMode { dispersed; assembling; formed; maintaining; repairing; disassembling; }
    enum def LinkState { open; forming; connected; reinforced; broken; }
    enum def CommandType { assemble; disassemble; move; link; unlink; reinforce; isolate; reset; report; }

    // ===== Item Definitions =====
    item def Blueprint {
        attribute shapeId : String;
        attribute targetDensity : Density;
        attribute targetStrength : Stress;
        attribute geometryHash : String;
    }

    item def SensorReading {
        attribute position : Length[3];
        attribute detectedForce : Force;
        attribute neighborCount : FogletCount;
        attribute temperature : Real;
    }

    item def ControlCommand {
        attribute commandType : CommandType;
        attribute targetPosition : Length[3] optional;
        attribute priority : Integer;
        attribute sourceId : String;
    }

    item def HealthReport {
        attribute fogletId : String;
        attribute status : FogletStatus;
        attribute batteryLevel : Percentage;
        attribute armStates : ArmState[12];
    }

    item def StressReport {
        attribute fogletId : String;
        attribute measuredStress : Stress;
        attribute linkId : Integer;
    }

    // ===== Port Definitions =====
    port def MechanicalArmPort {
        attribute armId : Integer;
        out graspSignal : Boolean;
        in graspAck : Boolean;
        in transmittedForce : Force;
        out releaseSignal : Boolean;
    }

    port def CommPort {
        out tx : ControlCommand;
        in rx : ControlCommand;
        out healthOut : HealthReport;
        in healthIn : HealthReport;
        attribute bandwidth : Bandwidth;
    }

    // ===== Foglet Subcomponent Definitions =====
    part def Processor {
        attribute clockFreq : Frequency;
        attribute load : Percentage;
        in cmd : ControlCommand;
        out reading : SensorReading;

        action def ProcessCommand {
            in command : ControlCommand;
            out response : ControlCommand;
        }
    }

    part def PowerManagement {
        attribute storedEnergy : Power;
        attribute batteryLevel : Percentage;
        out powerOutput : Power;

        action def MonitorPower {
            out level : Percentage;
        }
    }

    part def SensorSuite {
        attribute samplingRate : Frequency;
        out reading : SensorReading;

        action def Sample {
            out reading : SensorReading;
        }
    }

    part def CommunicationModule {
        attribute bandwidth : Bandwidth;
        attribute range : Length;
        port commPort : CommPort;

        action def Transmit {
            in cmd : ControlCommand;
        }
        action def Receive {
            out cmd : ControlCommand;
        }
    }

    part def MechanicalArm {
        attribute armId : Integer;
        attribute state : ArmState := ArmState::retracted;
        attribute maxReach : Length;
        attribute maxForce : Force;
        port armPort : MechanicalArmPort;

        action def Extend {
            in target : Length;
            then Grasp;
        }
        action def Grasp {
            in neighborArm : MechanicalArmPort;
        }
        action def Lock {}
        action def Release {}
        action def Reinforce {
            in additionalForce : Force;
        }
    }

    // ===== Foglet Definition =====
    part def Foglet {
        attribute fogletId : String;
        attribute status : FogletStatus := FogletStatus::standby;
        attribute mass : Mass;
        attribute size : Length;

        part processor : Processor;
        part power : PowerManagement;
        part sensors : SensorSuite;
        part comm : CommunicationModule;
        part arms : MechanicalArm[12];

        port externalComm : CommPort;

        action def SenseAndReport {
            in reading : SensorReading;
            out report : HealthReport;
        }

        action def MoveTo {
            in target : Length[3];
        }

        action def LinkWithNeighbor {
            in armIndex : Integer;
            in neighbor : MechanicalArmPort;
        }

        action def SelfDiagnose {
            out status : FogletStatus;
        }

        state def FogletBehavior {
            initial; then Standby;

            state Standby {
                entry { status = FogletStatus::standby; }
            }
            state Idle {
                entry { status = FogletStatus::idle; }
            }
            state Assembling {
                entry { status = FogletStatus::active; }
            }
            state Linked {
                entry { status = FogletStatus::active; }
            }
            state Failed {
                entry { status = FogletStatus::failed; }
            }
            state Isolated {
                entry { status = FogletStatus::isolated; }
            }

            transition from Standby to Idle
                when externalComm.rx.commandType == CommandType::reset;
            transition from Idle to Assembling
                when externalComm.rx.commandType == CommandType::assemble;
            transition from Assembling to Linked
                when arms->select(a | a.state == ArmState::locked)->size() >= 3;
            transition from Linked to Failed
                when power.batteryLevel < 5;
            transition from Failed to Isolated
                when externalComm.rx.commandType == CommandType::isolate;
            transition from Isolated to Idle
                when externalComm.rx.commandType == CommandType::reset;
            transition from Linked to Idle
                when externalComm.rx.commandType == CommandType::disassemble;
        }
    }

    // ===== Connection Definitions =====
    connection def MechanicalLink {
        end armA : MechanicalArmPort;
        end armB : MechanicalArmPort;
        attribute state : LinkState := LinkState::open;
        attribute currentForce : Force;
    }

    connection def CommLink {
        end portA : CommPort;
        end portB : CommPort;
        attribute bandwidth : Bandwidth;
        attribute active : Boolean;
    }

    // ===== Foglet Cluster Definition =====
    part def FogletCluster {
        attribute clusterId : String;
        attribute mode : ClusterMode := ClusterMode::dispersed;
        attribute fogletCount : FogletCount;
        attribute targetDensity : Density;
        attribute targetStrength : Stress;

        part foglets : Foglet[*];
        part mechanicalLinks : MechanicalLink[*];
        part commLinks : CommLink[*];

        port clusterComm : CommPort;

        action def AssembleCluster {
            in blueprint : Blueprint;
            out assignments : ControlCommand[*];
        }

        action def MonitorIntegrity {
            in reports : HealthReport[*];
            in stressReports : StressReport[*];
            out reinforcementCmds : ControlCommand[*];
        }

        action def DetectFailures {
            in reports : HealthReport[*];
            out failedIds : String[*];
        }

        action def RepairStructure {
            in failedIds : String[*];
            out rerouteCmds : ControlCommand[*];
        }

        action def DisassembleCluster {
            out releaseCmds : ControlCommand[*];
        }

        state def ClusterBehavior {
            initial; then Dispersed;

            state Dispersed {
                entry { mode = ClusterMode::dispersed; }
            }
            state Assembling {
                entry { mode = ClusterMode::assembling; }
            }
            state Formed {
                entry { mode = ClusterMode::formed; }
            }
            state Maintaining {
                entry { mode = ClusterMode::maintaining; }
            }
            state Repairing {
                entry { mode = ClusterMode::repairing; }
            }
            state Disassembling {
                entry { mode = ClusterMode::disassembling; }
            }

            transition from Dispersed to Assembling
                when clusterComm.rx.commandType == CommandType::assemble;
            transition from Assembling to Formed
                when foglets->select(f | f.status == FogletStatus::active)->size() == fogletCount;
            transition from Formed to Maintaining
                when clusterComm.rx.commandType == CommandType::report;
            transition from Maintaining to Repairing
                when foglets->select(f | f.status == FogletStatus::failed)->size() > 0;
            transition from Repairing to Maintaining
                when foglets->select(f | f.status == FogletStatus::failed)->size() == 0;
            transition from Formed to Disassembling
                when clusterComm.rx.commandType == CommandType::disassemble;
            transition from Disassembling to Dispersed
                when foglets->select(f | f.status == FogletStatus::idle)->size() == fogletCount;
        }
    }

    // ===== Central Controller Definition =====
    part def CentralController {
        attribute controllerId : String;
        attribute targetDensity : Density;
        attribute targetStrength : Stress;
        attribute maxRepairTime : Duration;

        port swarmComm : CommPort;

        action def AnalyzeBlueprint {
            in blueprint : Blueprint;
            out shapeCommands : ControlCommand[*];
        }

        action def OrchestrateAssembly {
            in shapeCommands : ControlCommand[*];
            out assignments : ControlCommand[*];
        }

        action def MonitorStructuralIntegrity {
            in reports : HealthReport[*];
            in stressReports : StressReport[*];
            out reinforcementCmds : ControlCommand[*];
        }

        action def DetectAndIsolateFailures {
            in reports : HealthReport[*];
            out isolateCmds : ControlCommand[*];
            out rerouteCmds : ControlCommand[*];
        }

        action def CoordinateSelfHealing {
            in failedIds : String[*];
            out rerouteCmds : ControlCommand[*];
        }

        state def ControllerBehavior {
            initial; then Standby;

            state Standby;
            state Analyzing;
            state Orchestrating;
            state Monitoring;
            state Healing;

            transition from Standby to Analyzing
                when swarmComm.rx.commandType == CommandType::assemble;
            transition from Analyzing to Orchestrating;
            transition from Orchestrating to Monitoring;
            transition from Monitoring to Healing
                when swarmComm.healthIn.status == FogletStatus::failed;
            transition from Healing to Monitoring;
        }
    }

    // ===== Top-Level Utility Fog System =====
    part def UtilityFogSystem {
        attribute systemId : String;
        attribute totalFoglets : FogletCount;

        part controller : CentralController;
        part clusters : FogletCluster[*];

        connection controllerToClusters : CommLink
            connect controller.swarmComm to clusters.clusterComm;

        requirement def AssemblyTimeRequirement {
            subject system : UtilityFogSystem;
            attribute maxAssemblyTime : Duration = 60000;
            require { system.clusters.mode == ClusterMode::formed }
        }

        requirement def StructuralIntegrityRequirement {
            subject system : UtilityFogSystem;
            attribute maxDeformation : Length = 0.1;
            require { system.clusters.foglets->select(f | f.status == FogletStatus::active)->size() >= 1 }
        }

        requirement def SelfHealingRequirement {
            subject system : UtilityFogSystem;
            attribute maxRepairTime : Duration = 1000;
            require { system.clusters.foglets->select(f | f.status == FogletStatus::failed)->size() == 0 }
        }

        requirement def CommunicationRequirement {
            subject system : UtilityFogSystem;
            attribute minBandwidth : Bandwidth = 100;
            require { system.controller.swarmComm.bandwidth >= minBandwidth }
        }

        requirement def FogletArmRequirement {
            subject foglet : Foglet;
            attribute armCount : Integer = 12;
            require { foglet.arms->size() == 12 }
        }

        requirement def PowerEnduranceRequirement {
            subject foglet : Foglet;
            attribute minBatteryLevel : Percentage = 5;
            require { foglet.power.batteryLevel >= minBatteryLevel }
        }

        requirement def BlueprintFidelityRequirement {
            subject system : UtilityFogSystem;
            attribute densityTolerance : Density = 10;
            attribute strengthTolerance : Stress = 5;
            require { system.clusters.targetDensity == system.controller.targetDensity }
        }
    }
}
