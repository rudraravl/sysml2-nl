package MTBF_Based_Primary_Function_Model {
    import ScalarValues::*;
    import SI::*;

    attribute def Hour :> Real;
    attribute def Volt :> Real;
    attribute def Ampere :> Real;
    attribute def Watt :> Real;
    attribute def Celsius :> Real;
    attribute def Probability :> Real;
    attribute def FailureRatePerHour :> Real;
    attribute def AvailabilityRatio :> Real;

    enum def HealthLevel {
        enum nominal;
        enum degraded;
        enum failed;
        enum maintenance;
    }

    enum def FaultSeverity {
        enum advisory;
        enum recoverable;
        enum critical;
    }

    item def ElectricalPower {
        attribute voltage : Volt;
        attribute current : Ampere;
        attribute power : Watt;
        attribute regulated : Boolean;
    }

    item def HealthTelemetry {
        attribute health : HealthLevel;
        attribute observedUptime : Hour;
        attribute predictedReliability : Probability;
        attribute remainingUsefulLife : Hour;
        attribute activeFaultCount : Integer;
    }

    item def FaultReport {
        attribute severity : FaultSeverity;
        attribute failedElementId : String;
        attribute timeSinceCommissioning : Hour;
        attribute estimatedRepairTime : Hour;
    }

    item def MaintenanceCommand {
        attribute resetRequested : Boolean;
        attribute isolateFailedUnit : Boolean;
        attribute replaceModuleId : String;
    }

    port def PowerInputPort {
        in item powerIn : ElectricalPower;
    }

    port def PowerOutputPort {
        out item powerOut : ElectricalPower;
    }

    port def TelemetryOutputPort {
        out item telemetryOut : HealthTelemetry;
        out item faultOut : FaultReport;
    }

    port def MaintenanceInputPort {
        in item commandIn : MaintenanceCommand;
    }

    constraint def ExponentialReliability {
        in missionTime : Hour;
        in meanTimeBetweenFailures : Hour;
        out reliability : Probability;

        constraint reliabilityEquation {
            reliability == exp(-missionTime / meanTimeBetweenFailures)
        }
    }

    constraint def ConstantFailureRate {
        in meanTimeBetweenFailures : Hour;
        out failureRate : FailureRatePerHour;

        constraint failureRateEquation {
            failureRate == 1.0 / meanTimeBetweenFailures
        }
    }

    constraint def SteadyStateAvailability {
        in meanTimeBetweenFailures : Hour;
        in meanTimeToRepair : Hour;
        out availability : AvailabilityRatio;

        constraint availabilityEquation {
            availability == meanTimeBetweenFailures / (meanTimeBetweenFailures + meanTimeToRepair)
        }
    }

    action def ConditionInputPower {
        in item unregulatedPower : ElectricalPower;
        out item regulatedPower : ElectricalPower;

        constraint regulatedVoltage {
            regulatedPower.voltage == 28.0
        }

        constraint regulatedFlag {
            regulatedPower.regulated == true
        }
    }

    action def EstimateReliability {
        in elapsedMissionTime : Hour;
        in mtbf : Hour;
        in mttr : Hour;
        out predictedReliability : Probability;
        out predictedAvailability : AvailabilityRatio;

        calc reliabilityCalc : ExponentialReliability {
            in missionTime = elapsedMissionTime;
            in meanTimeBetweenFailures = mtbf;
            out reliability = predictedReliability;
        }

        calc availabilityCalc : SteadyStateAvailability {
            in meanTimeBetweenFailures = mtbf;
            in meanTimeToRepair = mttr;
            out availability = predictedAvailability;
        }
    }

    action def DetectAndReportFault {
        in temperature : Celsius;
        in outputVoltage : Volt;
        in elapsedMissionTime : Hour;
        out item report : FaultReport;

        constraint criticalVoltageFault {
            outputVoltage < 24.0 implies report.severity == FaultSeverity::critical
        }

        constraint recoverableThermalFault {
            temperature > 85.0 implies report.severity == FaultSeverity::recoverable
        }

        constraint reportTime {
            report.timeSinceCommissioning == elapsedMissionTime
        }
    }

    state def ReliabilityControlledOperatingStates {
        state initializing;
        state operational;
        state degradedOperation;
        state failedSafe;
        state maintenanceRecovery;

        transition initial then initializing;

        transition initializing_to_operational
            first initializing
            then operational;

        transition operational_to_degraded
            first operational
            accept FaultReport
            if report.severity == FaultSeverity::recoverable
            then degradedOperation;

        transition operational_to_failedSafe
            first operational
            accept FaultReport
            if report.severity == FaultSeverity::critical
            then failedSafe;

        transition degraded_to_operational
            first degradedOperation
            accept MaintenanceCommand
            if commandIn.resetRequested == true
            then operational;

        transition degraded_to_failedSafe
            first degradedOperation
            accept FaultReport
            if report.severity == FaultSeverity::critical
            then failedSafe;

        transition failedSafe_to_maintenance
            first failedSafe
            accept MaintenanceCommand
            if commandIn.isolateFailedUnit == true
            then maintenanceRecovery;

        transition maintenance_to_initializing
            first maintenanceRecovery
            accept MaintenanceCommand
            if commandIn.replaceModuleId != ""
            then initializing;
    }

    part def PowerSourceUnit {
        attribute nominalVoltage : Volt = 28.0;
        attribute ratedPower : Watt = 1500.0;
        attribute mtbf : Hour = 120000.0;
        attribute mttr : Hour = 2.0;
        attribute health : HealthLevel = HealthLevel::nominal;

        port dcOut : PowerOutputPort;
    }

    part def PowerConditioningUnit {
        attribute outputVoltage : Volt = 28.0;
        attribute maxCurrent : Ampere = 40.0;
        attribute mtbf : Hour = 90000.0;
        attribute mttr : Hour = 1.5;
        attribute internalTemperature : Celsius;
        attribute health : HealthLevel = HealthLevel::nominal;

        port dcIn : PowerInputPort;
        port dcOut : PowerOutputPort;

        perform action conditionPower : ConditionInputPower;
    }

    part def LoadDistributionUnit {
        attribute branchCount : Integer = 4;
        attribute mtbf : Hour = 150000.0;
        attribute mttr : Hour = 1.0;
        attribute health : HealthLevel = HealthLevel::nominal;

        port input : PowerInputPort;
        port protectedOutput : PowerOutputPort;
    }

    part def ReliabilityMonitor {
        attribute missionElapsedTime : Hour;
        attribute systemMtbf : Hour;
        attribute systemMttr : Hour;
        attribute systemFailureRate : FailureRatePerHour;
        attribute predictedReliabilityForMission : Probability;
        attribute predictedAvailability : AvailabilityRatio;
        attribute health : HealthLevel = HealthLevel::nominal;

        port telemetry : TelemetryOutputPort;
        port maintenance : MaintenanceInputPort;

        perform action estimate : EstimateReliability;
        perform action detectFault : DetectAndReportFault;
        exhibit state reliabilityStates : ReliabilityControlledOperatingStates;
    }

    part def MissionLoad {
        attribute requiredVoltage : Volt = 28.0;
        attribute nominalPowerDemand : Watt = 800.0;
        attribute maximumPowerDemand : Watt = 1200.0;

        port powerInput : PowerInputPort;
    }

    part def MTBFManagedPowerSystem {
        attribute primaryFunction : String =
            "Provide continuous regulated electrical power to a mission load while estimating reliability from mean time between failures and reporting faults before loss of function.";

        attribute requiredMissionTime : Hour = 1000.0;
        attribute requiredMinimumReliability : Probability = 0.99;
        attribute requiredMinimumAvailability : AvailabilityRatio = 0.999;
        attribute allocatedSystemMtbf : Hour = 100000.0;
        attribute allocatedSystemMttr : Hour = 1.0;

        part source : PowerSourceUnit;
        part conditioner : PowerConditioningUnit;
        part distribution : LoadDistributionUnit;
        part monitor : ReliabilityMonitor;
        part load : MissionLoad;

        port externalMaintenance : MaintenanceInputPort;
        port externalTelemetry : TelemetryOutputPort;

        connect source.dcOut to conditioner.dcIn;
        connect conditioner.dcOut to distribution.input;
        connect distribution.protectedOutput to load.powerInput;
        connect externalMaintenance to monitor.maintenance;
        connect monitor.telemetry to externalTelemetry;

        constraint systemFailureRateConstraint : ConstantFailureRate {
            in meanTimeBetweenFailures = allocatedSystemMtbf;
            out failureRate = monitor.systemFailureRate;
        }

        constraint missionReliabilityConstraint : ExponentialReliability {
            in missionTime = requiredMissionTime;
            in meanTimeBetweenFailures = allocatedSystemMtbf;
            out reliability = monitor.predictedReliabilityForMission;
        }

        constraint availabilityConstraint : SteadyStateAvailability {
            in meanTimeBetweenFailures = allocatedSystemMtbf;
            in meanTimeToRepair = allocatedSystemMttr;
            out availability = monitor.predictedAvailability;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : MTBFManagedPowerSystem;

        require constraint primaryFunctionSatisfied {
            system.load.requiredVoltage == 28.0 and
            system.load.maximumPowerDemand <= 1200.0 and
            system.conditioner.outputVoltage == system.load.requiredVoltage
        }
    }

    requirement def MTBFRequirement {
        subject system : MTBFManagedPowerSystem;

        require constraint mtbfThreshold {
            system.allocatedSystemMtbf >= 100000.0
        }
    }

    requirement def MissionReliabilityRequirement {
        subject system : MTBFManagedPowerSystem;

        require constraint reliabilityThreshold {
            system.monitor.predictedReliabilityForMission >= system.requiredMinimumReliability
        }
    }

    requirement def AvailabilityRequirement {
        subject system : MTBFManagedPowerSystem;

        require constraint availabilityThreshold {
            system.monitor.predictedAvailability >= system.requiredMinimumAvailability
        }
    }

    requirement def FaultReportingRequirement {
        subject system : MTBFManagedPowerSystem;

        require constraint telemetryAvailable {
            system.monitor.health != HealthLevel::failed
        }
    }

    part operationalSystem : MTBFManagedPowerSystem;

    satisfy PrimaryFunctionRequirement by operationalSystem;
    satisfy MTBFRequirement by operationalSystem;
    satisfy MissionReliabilityRequirement by operationalSystem;
    satisfy AvailabilityRequirement by operationalSystem;
    satisfy FaultReportingRequirement by operationalSystem;
}