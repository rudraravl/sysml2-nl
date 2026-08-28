package AutonomousIntelligenceSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----
    attribute def DistanceKm :> Real { 
        attribute unit : String = "km"; 
    }
    attribute def PowerWatt :> Real { 
        attribute unit : String = "W"; 
    }
    attribute def ConfidencePercent :> Real { 
        attribute unit : String = "%"; 
    }
    attribute def DataRateMbps :> Real { 
        attribute unit : String = "Mb/s"; 
    }
    attribute def VoltageVolt :> Real { 
        attribute unit : String = "V"; 
    }
    attribute def CurrentAmp :> Real { 
        attribute unit : String = "A"; 
    }

    // ---- Technology maturity ----
    enum def TechnologyReadinessLevel {
        concept = 1,
        prototypeDemonstration = 6,
        operationalDemonstration = 7,
        complete = 9,
    }

    // ---- Items ----
    item def RawData {
        attribute timestamp : String;
        attribute payloadSize : Integer;
        attribute integrityChecksum : Integer;
    }

    item def IntelligenceReport {
        attribute summary : String;
        attribute confidence : ConfidencePercent;
        attribute generatedAt : String;
    }

    item def Command {
        attribute commandId : String;
        attribute target : String;
        attribute priority : Integer;
    }

    // ---- Ports ----
    port def DataOutPort {
        out raw : RawData;
    }
    port def DataInPort {
        in raw : RawData;
    }
    port def IntelligenceOutPort {
        out report : IntelligenceReport;
    }
    port def IntelligenceInPort {
        in report : IntelligenceReport;
    }
    port def CommandInPort {
        in cmd : Command;
    }
    port def CommandOutPort {
        out cmd : Command;
    }
    port def PowerPort {
        out voltage : VoltageVolt;
        out current : CurrentAmp;
    }

    // ---- Sensor Module ----
    part def SensorModule {
        attribute trl : TechnologyReadinessLevel = TechnologyReadinessLevel::complete;
        attribute resolution : Real = 4096;
        attribute acquisitionTime : Real = 0.5;

        port dataOut : DataOutPort;
        port commandIn : CommandInPort;
        port powerIn : PowerPort;

        attribute dataReady : Boolean = false;
        attribute maintenanceRequested : Boolean = false;
        attribute maintenanceComplete : Boolean = false;
        attribute initialized : Boolean = false;

        state def SensorStates {
            entry; then Off;
            state Off;
            state Initializing;
            state Idle;
            state Acquiring;
            state Transmitting;
            state Maintenance;

            transition off_to_init
                first Off then Initializing
                when powerIn.voltage > 0;
            transition init_to_idle
                first Initializing then Idle
                when initialized;
            transition idle_to_acq
                first Idle then Acquiring
                when commandIn.cmd.target == "acquire";
            transition acq_to_tx
                first Acquiring then Transmitting
                when dataReady;
            transition tx_to_idle
                first Transmitting then Idle
                when dataReady == false;
            transition idle_to_maint
                first Idle then Maintenance
                when maintenanceRequested;
            transition maint_to_idle
                first Maintenance then Idle
                when maintenanceComplete;
        }

        state machine sensorBehavior :>> SensorStates;

        action acquireData {
            in cmd : Command;
            out raw : RawData;
        }

        action transmitData {
            in raw : RawData;
            out dataOut.raw;
        }
    }

    // ---- AI Processing Core ----
    part def AIProcessingCore {
        attribute trl : TechnologyReadinessLevel = TechnologyReadinessLevel::prototypeDemonstration;
        attribute algorithmVersion : String = "NeuralNet-v2.3";
        attribute minConfidence : ConfidencePercent = 70;

        port dataIn : DataInPort;
        port intelOut : IntelligenceOutPort;
        port powerIn : PowerPort;

        attribute dataValid : Boolean = false;
        attribute patternsFound : Boolean = false;
        attribute reportReady : Boolean = false;

        state def AIStates {
            entry; then Standby;
            state Standby;
            state Validating;
            state Analyzing;
            state Generating;

            transition standby_to_val
                first Standby then Validating
                when dataIn.raw != null;
            transition val_to_anal
                first Validating then Analyzing
                when dataValid;
            transition anal_to_gen
                first Analyzing then Generating
                when patternsFound;
            transition gen_to_standby
                first Generating then Standby
                when reportReady;
        }

        state machine aiBehavior :>> AIStates;

        action processData {
            in raw : RawData;
            out report : IntelligenceReport;
        }

        action validateData {
            in raw : RawData;
            out valid : Boolean;
        }

        action analyzePatterns {
            in raw : RawData;
            out patterns : Boolean;
        }

        action generateReport {
            in patterns : Boolean;
            out report : IntelligenceReport;
        }
    }

    // ---- Communication Subsystem ----
    part def CommunicationSubsystem {
        attribute trl : TechnologyReadinessLevel = TechnologyReadinessLevel::operationalDemonstration;
        attribute maxRange : DistanceKm = 50;
        attribute dataRate : DataRateMbps = 10;
        attribute transmissionComplete : Boolean = false;
        attribute commandReceived : Boolean = false;
        attribute commandProcessed : Boolean = false;

        port intelIn : IntelligenceInPort;
        port externalCommandIn : CommandInPort;
        port commandOut : CommandOutPort;
        port powerIn : PowerPort;

        state def CommStates {
            entry; then Standby;
            state Standby;
            state Transmitting;
            state Receiving;

            transition standby_to_tx
                first Standby then Transmitting
                when intelIn.report != null;
            transition tx_to_standby
                first Transmitting then Standby
                when transmissionComplete;
            transition standby_to_rx
                first Standby then Receiving
                when commandReceived;
            transition rx_to_standby
                first Receiving then Standby
                when commandProcessed;
        }

        state machine commBehavior :>> CommStates;

        action transmitIntelligence {
            in report : IntelligenceReport;
        }

        action receiveCommand {
            out cmd : Command;
        }
    }

    // ---- Power Management Unit ----
    part def PowerManagementUnit {
        attribute trl : TechnologyReadinessLevel = TechnologyReadinessLevel::complete;
        attribute totalCapacity : PowerWatt = 1000;
        attribute safetyMargin : Real = 0.8;
        attribute maxLoad : PowerWatt = totalCapacity * safetyMargin;
        attribute currentLoad : PowerWatt = 0;
        attribute activated : Boolean = false;
        attribute faultDetected : Boolean = false;

        port powerOutSensor : PowerPort;
        port powerOutAI : PowerPort;
        port powerOutComm : PowerPort;

        state def PowerStates {
            entry; then Off;
            state Off;
            state Distributing;
            state LowPower;
            state Fault;

            transition off_to_dist
                first Off then Distributing
                when activated;
            transition dist_to_low
                first Distributing then LowPower
                when currentLoad > maxLoad * 0.9;
            transition low_to_dist
                first LowPower then Distributing
                when currentLoad < maxLoad * 0.7;
            transition dist_to_fault
                first Distributing then Fault
                when faultDetected;
            transition fault_to_off
                first Fault then Off
                when activated == false;
        }

        state machine powerBehavior :>> PowerStates;

        action distributePower {
            out v1 : VoltageVolt;
            out v2 : VoltageVolt;
            out v3 : VoltageVolt;
        }
    }

    // ---- Top-level Autonomous Intelligence System ----
    part def AutonomousIntelligenceSystem {
        attribute trl : TechnologyReadinessLevel = TechnologyReadinessLevel::prototypeDemonstration;
        attribute systemName : String = "AIS-1";

        port externalCommandIn : CommandInPort;
        port externalIntelOut : IntelligenceOutPort;

        part sensor : SensorModule;
        part aiCore : AIProcessingCore;
        part comm : CommunicationSubsystem;
        part pmu : PowerManagementUnit;

        // Data and intelligence flow
        connection sensorToAI : DataOutPort to DataInPort {
            from sensor.dataOut to aiCore.dataIn;
        }
        connection aiToComm : IntelligenceOutPort to IntelligenceInPort {
            from aiCore.intelOut to comm.intelIn;
        }
        connection commToSensor : CommandOutPort to CommandInPort {
            from comm.commandOut to sensor.commandIn;
        }

        // External interfaces
        connection extCmdToComm : CommandInPort to CommandInPort {
            from externalCommandIn to comm.externalCommandIn;
        }
        connection commIntelToExt : IntelligenceInPort to IntelligenceOutPort {
            from comm.intelIn to externalIntelOut;
        }

        // Power distribution
        connection powerToSensor : PowerPort to PowerPort {
            from pmu.powerOutSensor to sensor.powerIn;
        }
        connection powerToAI : PowerPort to PowerPort {
            from pmu.powerOutAI to aiCore.powerIn;
        }
        connection powerToComm : PowerPort to PowerPort {
            from pmu.powerOutComm to comm.powerIn;
        }

        // Mission-level autonomous loop
        attribute commandReceived : Boolean = false;
        attribute dataAcquired : Boolean = false;
        attribute intelligenceGenerated : Boolean = false;
        attribute transmissionComplete : Boolean = false;

        state def MissionStates {
            entry; then Idle;
            state Idle;
            state AcquirePhase;
            state ProcessPhase;
            state TransmitPhase;

            transition idle_to_acq
                first Idle then AcquirePhase
                when commandReceived;
            transition acq_to_proc
                first AcquirePhase then ProcessPhase
                when dataAcquired;
            transition proc_to_tx
                first ProcessPhase then TransmitPhase
                when intelligenceGenerated;
            transition tx_to_idle
                first TransmitPhase then Idle
                when transmissionComplete;
        }

        state machine missionBehavior :>> MissionStates;

        action executeMissionLoop {
            in cmd : Command;
            out report : IntelligenceReport;
        }
    }

    // ---- Requirements ----
    requirement def PowerSafetyRequirement {
        subject pmu : PowerManagementUnit;
        objective {
            pmu.currentLoad < pmu.maxLoad
        }
    }

    requirement def CommunicationRangeRequirement {
        subject comm : CommunicationSubsystem;
        objective {
            comm.maxRange >= 50
        }
    }

    requirement def AutonomousLoopRequirement {
        subject sys : AutonomousIntelligenceSystem;
        objective {
            sys.missionBehavior continuously executes
            AcquirePhase then ProcessPhase then TransmitPhase
        }
    }

    requirement def IntelligenceConfidenceRequirement {
        subject report : IntelligenceReport;
        objective {
            report.confidence >= 70
        }
    }

    requirement def SensorReliabilityRequirement {
        subject sensor : SensorModule;
        objective {
            sensor.trl == TechnologyReadinessLevel::complete
        }
    }

    requirement def AIMaturityRequirement {
        subject ai : AIProcessingCore;
        objective {
            ai.trl == TechnologyReadinessLevel::prototypeDemonstration
        }
    }

    requirement def CommMaturityRequirement {
        subject comm : CommunicationSubsystem;
        objective {
            comm.trl == TechnologyReadinessLevel::operationalDemonstration
        }
    }

    // ---- Requirement satisfaction ----
    part def SystemVerification {
        part ais : AutonomousIntelligenceSystem;
        satisfy PowerSafetyRequirement by ais.pmu;
        satisfy CommunicationRangeRequirement by ais.comm;
        satisfy AutonomousLoopRequirement by ais;
        satisfy IntelligenceConfidenceRequirement by ais.aiCore.intelOut.report;
        satisfy SensorReliabilityRequirement by ais.sensor;
        satisfy AIMaturityRequirement by ais.aiCore;
        satisfy CommMaturityRequirement by ais.comm;
    }
}
