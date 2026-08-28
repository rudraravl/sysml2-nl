package NaturalGasDistributionSystem {
    import ScalarValues::*;

    // ===== Value Types =====
    value type Pressure :> Real;
    value type FlowRate :> Real;
    value type Volume :> Real;
    value type Temperature :> Real;
    value type Duration :> Real;

    attribute def PressureLimits {
        attribute lowWarning : Pressure;
        attribute highWarning : Pressure;
        attribute criticalHigh : Pressure;
        attribute criticalLow : Pressure;
    }

    // ===== Items =====
    item def NaturalGas {
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
        attribute temperature : Temperature;
        attribute heatingValue : Real;
        attribute methaneContent : Real;
        attribute density : Real;
    }

    item def ControlSignal {
        attribute signalType : String;
        attribute measuredPressure : Pressure;
        attribute timestamp : String;
    }

    item def AlarmEvent {
        attribute alarmType : String;
        attribute severity : String;
        attribute measuredPressure : Pressure;
        attribute location : String;
    }

    item def MaintenanceOrder {
        attribute orderType : String;
        attribute sectionId : String;
        attribute scheduledTime : Duration;
    }

    // ===== Port Definitions =====
    port def GasInPort {
        in gas : NaturalGas;
        attribute maxPressure : Pressure;
    }

    port def GasOutPort {
        out gas : NaturalGas;
        attribute nominalPressure : Pressure;
    }

    port def SignalInPort {
        in signal : ControlSignal;
    }

    port def SignalOutPort {
        out signal : ControlSignal;
    }

    port def AlarmOutPort {
        out alarm : AlarmEvent;
    }

    port def MaintenanceInPort {
        in order : MaintenanceOrder;
    }

    // ===== Action Definitions =====
    action def InitializeSystem;
    action def PerformSystemChecks {
        out checksPassed : Boolean;
        out regulatorStatus : Boolean;
        out monitorStatus : Boolean;
        out valveStatus : Boolean;
    }
    action def ConfirmReady;
    action def BeginNormalFlow;
    action def ContinuousMonitor;
    action def LogStateTransition {
        in fromState : String;
        in toState : String;
    }
    action def ActivatePeakMode;
    action def IncreasedFlow;
    action def RestoreNormalFlow;
    action def IsolateSection {
        in sectionId : String;
    }
    action def PerformMaintenance;
    action def Reactivate;
    action def ActivateSafetyProtocols;
    action def EmergencyResponse;
    action def PostEmergencyCheck;

    action def RegulatePressure {
        in inletGas : NaturalGas;
        out outletGas : NaturalGas;
        in setPoint : Pressure;
    }

    action def MeasurePressure {
        in gas : NaturalGas;
        out pressureReading : Pressure;
    }

    action def MeasureVolume {
        in gas : NaturalGas;
        out volumeReading : Volume;
    }

    action def VentExcessGas {
        in gas : NaturalGas;
        out ventedGas : NaturalGas;
    }

    action def CalculateFlowRate {
        in gas : NaturalGas;
        out flowRateReading : FlowRate;
    }

    action def CheckLeakIntegrity {
        out isLeakFree : Boolean;
    }

    // ===== Part Definitions =====

    part def HighPressureSupplyPoint {
        attribute supplyPressure : Pressure = 75.0;
        attribute maxFlowRate : FlowRate = 100000.0;
        attribute isSupplyActive : Boolean = false;
        attribute connectionDiameter : Real = 600.0;

        port gasOut : GasOutPort {
            :>> nominalPressure = 75.0;
            :>> maxPressure = 75.0;
        }
    }

    part def PressureRegulator {
        attribute setPoint : Pressure;
        attribute actualOutletPressure : Pressure;
        attribute regulationAccuracy : Real = 0.05;
        attribute isOpen : Boolean = true;
        attribute capacity : FlowRate;

        action regulate : RegulatePressure;
    }

    part def PressureMonitor {
        attribute lowWarningThreshold : Pressure = 3.5;
        attribute highWarningThreshold : Pressure = 4.5;
        attribute criticalHighThreshold : Pressure = 6.0;
        attribute criticalLowThreshold : Pressure = 2.0;
        attribute currentPressure : Pressure;
        attribute isWarningActive : Boolean = false;
        attribute isAlarmActive : Boolean = false;
        attribute isCriticalAlarm : Boolean = false;
        attribute samplingInterval : Duration = 1.0;

        port signalOut : SignalOutPort;
        port alarmOut : AlarmOutPort;

        action monitor : MeasurePressure;
        action checkLeak : CheckLeakIntegrity;

        action def evaluatePressure {
            in pressure : Pressure;
            out warningLevel : String;
            out alarmLevel : String;
        }
    }

    part def SafetyValve {
        attribute criticalSetPoint : Pressure = 6.0;
        attribute isOpen : Boolean = false;
        attribute ventRate : FlowRate = 50000.0;
        attribute resetPressure : Pressure = 5.0;
        attribute valveType : String = "Pressure Relief";

        port gasIn : GasInPort {
            :>> maxPressure = 6.0;
        }
        port ventOut : GasOutPort {
            :>> nominalPressure = 0.0;
        }

        action vent : VentExcessGas;

        action def openValve;
        action def closeValve;
    }

    part def PressureRegulationStation {
        attribute inletPressure : Pressure = 75.0;
        attribute outletPressure : Pressure = 4.0;
        attribute designFlowRate : FlowRate = 80000.0;
        attribute numberOfRegulators : Integer = 2;
        attribute stationId : String = "PRS-001";

        part primaryRegulator : PressureRegulator {
            :>> setPoint = 4.0;
            :>> capacity = 80000.0;
        }

        part backupRegulator : PressureRegulator {
            :>> setPoint = 4.0;
            :>> capacity = 80000.0;
            :>> isOpen = false;
        }

        part stationMonitor : PressureMonitor;
        part stationSafetyValve : SafetyValve;

        port gasIn : GasInPort {
            :>> maxPressure = 75.0;
        }
        port gasOut : GasOutPort {
            :>> nominalPressure = 4.0;
        }
        port controlOut : SignalOutPort;
        port alarmOut : AlarmOutPort;
        port maintenanceIn : MaintenanceInPort;
    }

    part def DistributionPipeline {
        attribute length : Real;
        attribute diameter : Real;
        attribute nominalPressure : Pressure = 4.0;
        attribute material : String;
        attribute isLeakFree : Boolean = true;
        attribute pipelineId : String;

        port gasIn : GasInPort;
        port gasOut : GasOutPort;
    }

    part def DistributionPipelineNetwork {
        attribute totalLength : Real = 500.0;
        attribute maxPressureRating : Pressure = 16.0;
        attribute operatingPressure : Pressure = 4.0;
        attribute networkId : String = "DN-North-001";

        part mainPipeline : DistributionPipeline {
            :>> length = 50.0;
            :>> diameter = 400.0;
            :>> material = "Steel";
            :>> pipelineId = "M-001";
            :>> nominalPressure = 4.0;
        }

        part residentialBranch : DistributionPipeline {
            :>> length = 30.0;
            :>> diameter = 150.0;
            :>> material = "HDPE";
            :>> pipelineId = "R-001";
            :>> nominalPressure = 4.0;
        }

        part commercialBranch : DistributionPipeline {
            :>> length = 25.0;
            :>> diameter = 200.0;
            :>> material = "Steel";
            :>> pipelineId = "C-001";
            :>> nominalPressure = 4.0;
        }

        part industrialBranch : DistributionPipeline {
            :>> length = 20.0;
            :>> diameter = 300.0;
            :>> material = "Steel";
            :>> pipelineId = "I-001";
            :>> nominalPressure = 4.0;
        }

        part networkMonitor : PressureMonitor;
        part networkSafetyValve : SafetyValve;

        port gasIn : GasInPort {
            :>> maxPressure = 4.0;
        }
        port residentialOut : GasOutPort {
            :>> nominalPressure = 4.0;
        }
        port commercialOut : GasOutPort {
            :>> nominalPressure = 4.0;
        }
        port industrialOut : GasOutPort {
            :>> nominalPressure = 4.0;
        }
        port alarmOut : AlarmOutPort;
    }

    part def VolumeMeter {
        attribute calibrationFactor : Real = 1.0;
        attribute totalVolume : Volume = 0.0;
        attribute accuracyClass : Real = 99.5;
        attribute meterId : String;

        action measure : MeasureVolume;

        action def calibrate {
            in calibrationGas : NaturalGas;
            out adjustedFactor : Real;
        }
    }

    part def MeteringStation {
        attribute stationType : String;
        attribute totalConsumption : Volume = 0.0;
        attribute finalOutletPressure : Pressure;
        attribute maxFlowRate : FlowRate;
        attribute stationId : String;

        part meter : VolumeMeter;
        part finalRegulator : PressureRegulator;

        port gasIn : GasInPort;
        port gasOut : GasOutPort;

        action measure : MeasureVolume;
        action calculateFlow : CalculateFlowRate;
    }

    part def ResidentialMeteringStation :> MeteringStation {
        :>> stationType = "Residential";
        :>> finalOutletPressure = 0.025;
        :>> maxFlowRate = 100.0;

        part meter : VolumeMeter {
            :>> accuracyClass = 99.5;
            :>> meterId = "RES-M-001";
        }

        part finalRegulator : PressureRegulator {
            :>> setPoint = 0.025;
            :>> capacity = 100.0;
        }

        :>> stationId = "RES-001";
    }

    part def CommercialMeteringStation :> MeteringStation {
        :>> stationType = "Commercial";
        :>> finalOutletPressure = 0.1;
        :>> maxFlowRate = 5000.0;

        part meter : VolumeMeter {
            :>> accuracyClass = 99.5;
            :>> meterId = "COM-M-001";
        }

        part finalRegulator : PressureRegulator {
            :>> setPoint = 0.1;
            :>> capacity = 5000.0;
        }

        :>> stationId = "COM-001";
    }

    part def IndustrialMeteringStation :> MeteringStation {
        :>> stationType = "Industrial";
        :>> finalOutletPressure = 4.0;
        :>> maxFlowRate = 50000.0;

        part meter : VolumeMeter {
            :>> accuracyClass = 99.5;
            :>> meterId = "IND-M-001";
        }

        part finalRegulator : PressureRegulator {
            :>> setPoint = 4.0;
            :>> capacity = 50000.0;
        }

        :>> stationId = "IND-001";
    }

    // ===== State Machine Definition =====
    state def SystemOperationState {
        attribute systemCheckComplete : Boolean = false;
        attribute allChecksPassed : Boolean = false;
        attribute demandExceedsThreshold : Boolean = false;
        attribute demandReturnsNormal : Boolean = false;
        attribute maintenanceScheduled : Boolean = false;
        attribute maintenanceComplete : Boolean = false;
        attribute pressureExceedsCritical : Boolean = false;
        attribute emergencyResolved : Boolean = false;
        attribute currentSystemPressure : Pressure;

        state startup {
            entry action initialize : InitializeSystem;
            do action performChecks : PerformSystemChecks;
            exit action confirmReady : ConfirmReady;
        }

        state normalOperation {
            entry action beginFlow : BeginNormalFlow;
            do action monitor : ContinuousMonitor;
            exit action logTransition : LogStateTransition;
        }

        state peakDemand {
            entry action activatePeak : ActivatePeakMode;
            do action increaseFlow : IncreasedFlow;
            exit action restore : RestoreNormalFlow;
        }

        state maintenance {
            entry action isolate : IsolateSection;
            do action performMaint : PerformMaintenance;
            exit action reactivate : Reactivate;
        }

        state emergency {
            entry action activateSafety : ActivateSafetyProtocols;
            do action respond : EmergencyResponse;
            exit action postCheck : PostEmergencyCheck;
        }

        transition from startup to normalOperation
            when systemCheckComplete and allChecksPassed;
        transition from normalOperation to peakDemand
            when demandExceedsThreshold;
        transition from peakDemand to normalOperation
            when demandReturnsNormal;
        transition from normalOperation to maintenance
            when maintenanceScheduled;
        transition from maintenance to normalOperation
            when maintenanceComplete;
        transition from startup to emergency
            when pressureExceedsCritical;
        transition from normalOperation to emergency
            when pressureExceedsCritical;
        transition from peakDemand to emergency
            when pressureExceedsCritical;
        transition from maintenance to emergency
            when pressureExceedsCritical;
        transition from emergency to startup
            when emergencyResolved;
    }

    // ===== Connection Definitions =====
    connection def GasFlowConnection {
        end source : GasOutPort;
        end target : GasInPort;
    }

    connection def SignalFlowConnection {
        end source : SignalOutPort;
        end target : SignalInPort;
    }

    // ===== Top-Level System =====
    part def NaturalGasDistributionSystem {
        attribute systemName : String = "Regional Gas Distribution System";
        attribute systemActive : Boolean = false;
        attribute systemId : String = "NGDS-Region-North";

        part supplyPoint : HighPressureSupplyPoint;

        part regulationStation : PressureRegulationStation;

        part pipelineNetwork : DistributionPipelineNetwork;

        part residentialStation : ResidentialMeteringStation;
        part commercialStation : CommercialMeteringStation;
        part industrialStation : IndustrialMeteringStation;

        state operationState : SystemOperationState;

        // Gas flow connections
        connection supplyToStation
            from supplyPoint.gasOut to regulationStation.gasIn;
        connection stationToNetwork
            from regulationStation.gasOut to pipelineNetwork.gasIn;
        connection networkToResidential
            from pipelineNetwork.residentialOut to residentialStation.gasIn;
        connection networkToCommercial
            from pipelineNetwork.commercialOut to commercialStation.gasIn;
        connection networkToIndustrial
            from pipelineNetwork.industrialOut to industrialStation.gasIn;

        // Internal connections within regulation station
        connection stationInternalMonitor
            from regulationStation.controlOut to regulationStation.stationMonitor.signalOut;
        connection stationInternalValve
            from regulationStation.gasOut to regulationStation.stationSafetyValve.gasIn;

        // Internal connections within pipeline network
        connection networkInternalMonitor
            from pipelineNetwork.gasIn to pipelineNetwork.networkMonitor.signalOut;
        connection networkInternalValve
            from pipelineNetwork.gasIn to pipelineNetwork.networkSafetyValve.gasIn;

        // Pipeline branches
        connection mainToResidentialBranch
            from pipelineNetwork.mainPipeline.gasOut to pipelineNetwork.residentialBranch.gasIn;
        connection mainToCommercialBranch
            from pipelineNetwork.mainPipeline.gasOut to pipelineNetwork.commercialBranch.gasIn;
        connection mainToIndustrialBranch
            from pipelineNetwork.mainPipeline.gasOut to pipelineNetwork.industrialBranch.gasIn;
    }

    // ===== Requirements =====

    requirement def PressureReductionRequirement {
        subject gasSystem : NaturalGasDistributionSystem;
        objective "Reduce high pressure from transmission level to safe distribution level";
        assume {
            gasSystem.supplyPoint.supplyPressure >= 50.0;
        }
        require {
            gasSystem.regulationStation.outletPressure == 4.0;
            gasSystem.regulationStation.primaryRegulator.setPoint == 4.0;
        }
    }

    requirement def OverpressureProtectionRequirement {
        subject gasSystem : NaturalGasDistributionSystem;
        objective "Automatically vent excess gas to prevent overpressure damage";
        require {
            gasSystem.regulationStation.stationSafetyValve.criticalSetPoint == 6.0;
            gasSystem.pipelineNetwork.networkSafetyValve.criticalSetPoint == 6.0;
        }
    }

    requirement def ContinuousMonitoringRequirement {
        subject gasSystem : NaturalGasDistributionSystem;
        objective "Continuously monitor pressure and issue warnings or alarms when limits are exceeded";
        require {
            gasSystem.regulationStation.stationMonitor.highWarningThreshold == 4.5;
            gasSystem.regulationStation.stationMonitor.lowWarningThreshold == 3.5;
            gasSystem.regulationStation.stationMonitor.criticalHighThreshold == 6.0;
            gasSystem.pipelineNetwork.networkMonitor.highWarningThreshold == 4.5;
            gasSystem.pipelineNetwork.networkMonitor.lowWarningThreshold == 3.5;
            gasSystem.pipelineNetwork.networkMonitor.criticalHighThreshold == 6.0;
        }
    }

    requirement def MeteringAccuracyRequirement {
        subject gasSystem : NaturalGasDistributionSystem;
        objective "Accurately measure gas volume consumed by each customer type";
        require {
            gasSystem.residentialStation.meter.accuracyClass >= 99.5;
            gasSystem.commercialStation.meter.accuracyClass >= 99.5;
            gasSystem.industrialStation.meter.accuracyClass >= 99.5;
        }
    }

    requirement def GasDeliveryRequirement {
        subject gasSystem : NaturalGasDistributionSystem;
        objective "Deliver gas at appropriate final pressures to all end-user categories";
        require {
            gasSystem.residentialStation.finalOutletPressure == 0.025;
            gasSystem.commercialStation.finalOutletPressure == 0.1;
            gasSystem.industrialStation.finalOutletPressure == 4.0;
        }
    }

    requirement def OperationalStatesRequirement {
        subject gasSystem : NaturalGasDistributionSystem;
        objective "Manage system through startup, normal operation, peak demand, maintenance, and emergency states";
        require {
            gasSystem.operationState.startup.entry;
            gasSystem.operationState.normalOperation.entry;
            gasSystem.operationState.peakDemand.entry;
            gasSystem.operationState.maintenance.entry;
            gasSystem.operationState.emergency.entry;
        }
    }

    requirement def SystemStartupRequirement {
        subject gasSystem : NaturalGasDistributionSystem;
        objective "Perform complete system verification before entering normal operation";
        assume {
            gasSystem.supplyPoint.supplyPressure >= 50.0;
        }
        require {
            gasSystem.operationState.systemCheckComplete == true;
            gasSystem.operationState.allChecksPassed == true;
        }
    }

    requirement def PeakDemandRequirement {
        subject gasSystem : NaturalGasDistributionSystem;
        objective "Increase flow capacity during periods of high consumption";
        require {
            gasSystem.operationState.peakDemand.increaseFlow;
            gasSystem.regulationStation.designFlowRate >= 80000.0;
        }
    }

    requirement def EmergencyResponseRequirement {
        subject gasSystem : NaturalGasDistributionSystem;
        objective "Activate safety protocols immediately upon critical overpressure detection";
        require {
            gasSystem.operationState.emergency.activateSafety;
            gasSystem.regulationStation.stationSafetyValve.ventRate >= 50000.0;
            gasSystem.pipelineNetwork.networkSafetyValve.ventRate >= 50000.0;
        }
    }

    requirement def DistributionIntegrityRequirement {
        subject gasSystem : NaturalGasDistributionSystem;
        objective "Maintain pipeline network integrity under all operating conditions";
        require {
            gasSystem.pipelineNetwork.maxPressureRating >= 16.0;
            gasSystem.pipelineNetwork.operatingPressure == 4.0;
            gasSystem.pipelineNetwork.mainPipeline.material == "Steel";
        }
    }

    requirement def BackupRegulatorRequirement {
        subject gasSystem : NaturalGasDistributionSystem;
        objective "Maintain redundancy in pressure regulation for reliability";
        require {
            gasSystem.regulationStation.numberOfRegulators >= 2;
            gasSystem.regulationStation.backupRegulator.setPoint == 4.0;
        }
    }

    requirement def TopLevelSystemRequirement {
        subject gasSystem : NaturalGasDistributionSystem;
        objective "Distribute natural gas safely and reliably from high-pressure transmission pipeline to residential, commercial, and industrial end users";
        assume {
            gasSystem.supplyPoint.supplyPressure >= 50.0;
            gasSystem.supplyPoint.maxFlowRate >= 80000.0;
        }
        require {
            gasSystem.regulationStation.outletPressure == 4.0;
            gasSystem.pipelineNetwork.operatingPressure == 4.0;
            gasSystem.regulationStation.stationSafetyValve.criticalSetPoint == 6.0;
            gasSystem.pipelineNetwork.networkSafetyValve.criticalSetPoint == 6.0;
            gasSystem.residentialStation.finalOutletPressure == 0.025;
            gasSystem.commercialStation.finalOutletPressure == 0.1;
            gasSystem.industrialStation.finalOutletPressure == 4.0;
            gasSystem.residentialStation.meter.accuracyClass >= 99.5;
            gasSystem.commercialStation.meter.accuracyClass >= 99.5;
            gasSystem.industrialStation.meter.accuracyClass >= 99.5;
            gasSystem.pipelineNetwork.maxPressureRating >= 16.0;
            gasSystem.regulationStation.numberOfRegulators >= 2;
        }
    }

    // ===== Requirement Satisfaction =====
    satisfaction satisfyTopLevelRequirement : TopLevelSystemRequirement by gasSystem : NaturalGasDistributionSystem;
    satisfaction satisfyPressureReduction : PressureReductionRequirement by gasSystem.regulationStation;
    satisfaction satisfyOverpressure : OverpressureProtectionRequirement by gasSystem.pipelineNetwork.networkSafetyValve;
    satisfaction satisfyMonitoring : ContinuousMonitoringRequirement by gasSystem.pipelineNetwork.networkMonitor;
    satisfaction satisfyMetering : MeteringAccuracyRequirement by gasSystem.residentialStation.meter;
    satisfaction satisfyDelivery : GasDeliveryRequirement by gasSystem.residentialStation;
    satisfaction satisfyStates : OperationalStatesRequirement by gasSystem.operationState;
}
