package EphemeralizationModel {
    private import ScalarValues::*;

    attribute def Mass_kg :> Real {
        doc /* Unit: kilogram. */
    }

    attribute def Volume_L :> Real {
        doc /* Unit: litre. */
    }

    attribute def Power_W :> Real {
        doc /* Unit: watt. */
    }

    attribute def Energy_kWh :> Real {
        doc /* Unit: kilowatt hour. */
    }

    attribute def DataRate_Mbps :> Real {
        doc /* Unit: megabit per second. */
    }

    attribute def Time_s :> Real {
        doc /* Unit: second. */
    }

    attribute def Temperature_C :> Real {
        doc /* Unit: degree Celsius. */
    }

    attribute def ServiceThroughput_tasksPerHour :> Real {
        doc /* Unit: delivered service tasks per hour. */
    }

    attribute def Ratio_1 :> Real {
        doc /* Unit: dimensionless ratio. */
    }

    item def ServiceIntent {
        attribute requestedThroughput : ServiceThroughput_tasksPerHour;
        attribute maximumResponseTime : Time_s;
        attribute qualityLevel : Ratio_1;
        attribute priority : Integer;
    }

    item def ResourceBudget {
        attribute availableMass : Mass_kg;
        attribute availableVolume : Volume_L;
        attribute availableEnergy : Energy_kWh;
        attribute peakPowerLimit : Power_W;
        attribute recoveryTarget : Ratio_1;
    }

    item def OptimizedServicePlan {
        attribute plannedThroughput : ServiceThroughput_tasksPerHour;
        attribute plannedMass : Mass_kg;
        attribute plannedVolume : Volume_L;
        attribute plannedEnergy : Energy_kWh;
        attribute plannedComputeRate : DataRate_Mbps;
        attribute expectedRecovery : Ratio_1;
    }

    item def ElectricalPowerFlow {
        attribute voltage : Real;
        attribute current : Real;
        attribute power : Power_W;
    }

    item def MaterialFeedstock {
        attribute mass : Mass_kg;
        attribute recyclableFraction : Ratio_1;
        attribute embodiedEnergy : Energy_kWh;
    }

    item def FabricatedMicrostructure {
        attribute mass : Mass_kg;
        attribute volume : Volume_L;
        attribute stiffnessRatio : Ratio_1;
        attribute reuseIndex : Ratio_1;
    }

    item def ServiceReport {
        attribute deliveredThroughput : ServiceThroughput_tasksPerHour;
        attribute responseTime : Time_s;
        attribute energyUsed : Energy_kWh;
        attribute materialRecovered : Ratio_1;
        attribute availability : Ratio_1;
    }

    item def Telemetry {
        attribute measuredMass : Mass_kg;
        attribute measuredPower : Power_W;
        attribute measuredTemperature : Temperature_C;
        attribute measuredThroughput : ServiceThroughput_tasksPerHour;
        attribute healthIndex : Ratio_1;
    }

    port def ServiceInterface {
        in item request : ServiceIntent;
        out item report : ServiceReport;
    }

    port def ResourceBudgetInPort {
        in item budget : ResourceBudget;
    }

    port def IntentOutPort {
        out item intent : ServiceIntent;
    }

    port def IntentInPort {
        in item intent : ServiceIntent;
    }

    port def PlanOutPort {
        out item plan : OptimizedServicePlan;
    }

    port def PlanInPort {
        in item plan : OptimizedServicePlan;
    }

    port def PowerInPort {
        in item power : ElectricalPowerFlow;
    }

    port def PowerOutPort {
        out item power : ElectricalPowerFlow;
    }

    port def MaterialInPort {
        in item material : MaterialFeedstock;
    }

    port def MaterialOutPort {
        out item material : MaterialFeedstock;
    }

    port def StructureInPort {
        in item structure : FabricatedMicrostructure;
    }

    port def StructureOutPort {
        out item structure : FabricatedMicrostructure;
    }

    port def TelemetryInPort {
        in item telemetry : Telemetry;
    }

    port def TelemetryOutPort {
        out item telemetry : Telemetry;
    }

    action def CaptureServiceIntent {
        in item request : ServiceIntent;
        out item normalizedIntent : ServiceIntent;
    }

    action def OptimizeResourcePlan {
        in item normalizedIntent : ServiceIntent;
        in item budget : ResourceBudget;
        in item feedback : Telemetry;
        out item plan : OptimizedServicePlan;
    }

    action def AllocateEnergy {
        in item plan : OptimizedServicePlan;
        in item budget : ResourceBudget;
        out item power : ElectricalPowerFlow;
    }

    action def FabricateMinimalStructure {
        in item plan : OptimizedServicePlan;
        in item feedstock : MaterialFeedstock;
        in item power : ElectricalPowerFlow;
        out item structure : FabricatedMicrostructure;
        out item fabricationTelemetry : Telemetry;
    }

    action def ExecutePrimaryService {
        in item request : ServiceIntent;
        in item structure : FabricatedMicrostructure;
        in item power : ElectricalPowerFlow;
        out item report : ServiceReport;
        out item serviceTelemetry : Telemetry;
    }

    action def RecoverAndRecycleResources {
        in item usedStructure : FabricatedMicrostructure;
        out item recoveredMaterial : MaterialFeedstock;
        out item recoveryTelemetry : Telemetry;
    }

    action def OperateEphemeralizedService {
        doc /* High-level primary function: convert a service intent into the smallest sufficient combination of material, energy, volume, and computation needed to deliver the requested service, then recover resources for reuse. */
        in item request : ServiceIntent;
        in item budget : ResourceBudget;
        in item feedstock : MaterialFeedstock;
        out item report : ServiceReport;
        out item recoveredMaterial : MaterialFeedstock;

        action capture : CaptureServiceIntent;
        action optimize : OptimizeResourcePlan;
        action allocate : AllocateEnergy;
        action fabricate : FabricateMinimalStructure;
        action execute : ExecutePrimaryService;
        action recover : RecoverAndRecycleResources;
    }

    part def IntentCaptureUnit {
        attribute mass : Mass_kg = 1.2;
        attribute averagePower : Power_W = 25.0;
        attribute latency : Time_s = 0.05;

        port service : ServiceInterface;
        port intentOut : IntentOutPort;

        perform action captureIntent : CaptureServiceIntent;
    }

    part def ResourceOptimizer {
        attribute mass : Mass_kg = 2.5;
        attribute averagePower : Power_W = 90.0;
        attribute computeRate : DataRate_Mbps = 1200.0;
        attribute optimizationEfficiency : Ratio_1 = 0.96;

        port intentIn : IntentInPort;
        port budgetIn : ResourceBudgetInPort;
        port telemetryIn : TelemetryInPort;
        port planOut : PlanOutPort;

        perform action optimizePlan : OptimizeResourcePlan;
    }

    part def EnergyManager {
        attribute mass : Mass_kg = 4.0;
        attribute storageCapacity : Energy_kWh = 5.0;
        attribute peakPower : Power_W = 1200.0;
        attribute conversionEfficiency : Ratio_1 = 0.94;

        port externalPowerIn : PowerInPort;
        port budgetIn : ResourceBudgetInPort;
        port planIn : PlanInPort;
        port powerOut : PowerOutPort;
        port telemetryOut : TelemetryOutPort;

        perform action allocateEnergy : AllocateEnergy;
    }

    part def LightweightFabricator {
        attribute mass : Mass_kg = 14.0;
        attribute buildVolume : Volume_L = 18.0;
        attribute averagePower : Power_W = 350.0;
        attribute materialUtilization : Ratio_1 = 0.97;

        port planIn : PlanInPort;
        port materialIn : MaterialInPort;
        port powerIn : PowerInPort;
        port structureOut : StructureOutPort;
        port telemetryOut : TelemetryOutPort;

        perform action fabricateStructure : FabricateMinimalStructure;
    }

    part def MorphingStructure {
        attribute mass : Mass_kg = 8.0;
        attribute deployedVolume : Volume_L = 55.0;
        attribute stowedVolume : Volume_L = 7.0;
        attribute stiffnessToMassRatio : Ratio_1 = 18.0;
        attribute reconfigurationTime : Time_s = 4.0;

        port structureIn : StructureInPort;
        port telemetryOut : TelemetryOutPort;
        port usedStructureOut : StructureOutPort;
    }

    part def ServiceExecutor {
        attribute mass : Mass_kg = 7.0;
        attribute averagePower : Power_W = 260.0;
        attribute nominalThroughput : ServiceThroughput_tasksPerHour = 1200.0;
        attribute nominalResponseTime : Time_s = 0.8;

        port intentIn : IntentInPort;
        port structureIn : StructureInPort;
        port powerIn : PowerInPort;
        port reportOut : ServiceInterface;
        port telemetryOut : TelemetryOutPort;

        perform action executeService : ExecutePrimaryService;
    }

    part def RecoveryModule {
        attribute mass : Mass_kg = 5.0;
        attribute averagePower : Power_W = 80.0;
        attribute recoveryYield : Ratio_1 = 0.93;
        attribute processingRate : Mass_kg = 3.0;

        port usedStructureIn : StructureInPort;
        port recoveredMaterialOut : MaterialOutPort;
        port telemetryOut : TelemetryOutPort;

        perform action recoverResources : RecoverAndRecycleResources;
    }

    part def DigitalTwinMonitor {
        attribute mass : Mass_kg = 0.8;
        attribute averagePower : Power_W = 35.0;
        attribute updateRate : DataRate_Mbps = 250.0;
        attribute predictionAccuracy : Ratio_1 = 0.92;

        port telemetryIn : TelemetryInPort;
        port planOut : PlanOutPort;
    }

    part def EphemeralizedServicePlatform {
        doc /* System based on Ephemeralization: it does more with less by dynamically minimizing committed material, energy, volume, and computation while maintaining useful service output. */
        doc /* Primary high-level function: deliver a requested service capability from a high-level intent using the least sufficient resources, then reclaim the temporary physical configuration. */

        attribute totalMass : Mass_kg = 42.5;
        attribute stowedVolume : Volume_L = 42.0;
        attribute deployedVolume : Volume_L = 95.0;
        attribute averagePower : Power_W = 760.0;
        attribute serviceThroughput : ServiceThroughput_tasksPerHour = 1200.0;
        attribute responseTime : Time_s = 0.8;
        attribute materialRecoveryRatio : Ratio_1 = 0.93;
        attribute materialUtilizationRatio : Ratio_1 = 0.97;
        attribute availability : Ratio_1 = 0.995;

        port service : ServiceInterface;
        port resourceBudget : ResourceBudgetInPort;
        port externalPower : PowerInPort;
        port feedstockIn : MaterialInPort;
        port recoveredMaterialOut : MaterialOutPort;
        port telemetryOut : TelemetryOutPort;

        part intentCapture : IntentCaptureUnit;
        part optimizer : ResourceOptimizer;
        part energyManager : EnergyManager;
        part fabricator : LightweightFabricator;
        part adaptiveStructure : MorphingStructure;
        part executor : ServiceExecutor;
        part recovery : RecoveryModule;
        part digitalTwin : DigitalTwinMonitor;

        connection serviceToIntentCapture connect service to intentCapture.service;
        connection requestIntentToOptimizer connect intentCapture.intentOut to optimizer.intentIn;
        connection requestIntentToExecutor connect intentCapture.intentOut to executor.intentIn;
        connection resourceBudgetToOptimizer connect resourceBudget to optimizer.budgetIn;
        connection resourceBudgetToEnergyManager connect resourceBudget to energyManager.budgetIn;
        connection externalPowerToEnergyManager connect externalPower to energyManager.externalPowerIn;
        connection optimizerPlanToEnergyManager connect optimizer.planOut to energyManager.planIn;
        connection optimizerPlanToFabricator connect optimizer.planOut to fabricator.planIn;
        connection digitalTwinPlanToFabricator connect digitalTwin.planOut to fabricator.planIn;
        connection feedstockToFabricator connect feedstockIn to fabricator.materialIn;
        connection energyToFabricator connect energyManager.powerOut to fabricator.powerIn;
        connection energyToExecutor connect energyManager.powerOut to executor.powerIn;
        connection fabricatedStructureToAdaptiveStructure connect fabricator.structureOut to adaptiveStructure.structureIn;
        connection adaptiveStructureToExecutor connect adaptiveStructure.usedStructureOut to executor.structureIn;
        connection adaptiveStructureToRecovery connect adaptiveStructure.usedStructureOut to recovery.usedStructureIn;
        connection recoveredMaterialExport connect recovery.recoveredMaterialOut to recoveredMaterialOut;
        connection fabricatorTelemetryToOptimizer connect fabricator.telemetryOut to optimizer.telemetryIn;
        connection energyTelemetryToDigitalTwin connect energyManager.telemetryOut to digitalTwin.telemetryIn;
        connection executorTelemetryToDigitalTwin connect executor.telemetryOut to digitalTwin.telemetryIn;
        connection recoveryTelemetryToDigitalTwin connect recovery.telemetryOut to digitalTwin.telemetryIn;
        connection systemTelemetryExport connect executor.telemetryOut to telemetryOut;
        connection reportToServiceInterface connect executor.reportOut to service;

        perform action operate : OperateEphemeralizedService;

        exhibit state lifecycle {
            state dormant;
            state acceptingIntent;
            state resourceAssessment;
            state ephemeralConfiguration;
            state serviceDelivery;
            state resourceRecovery;
            state degradedSafeMode;

            transition initialize first dormant then acceptingIntent;
            transition assessRequest first acceptingIntent then resourceAssessment;
            transition configureForMinimalResources first resourceAssessment then ephemeralConfiguration;
            transition deliverRequestedService first ephemeralConfiguration then serviceDelivery;
            transition reclaimTemporaryResources first serviceDelivery then resourceRecovery;
            transition readyForNextIntent first resourceRecovery then acceptingIntent;
            transition enterSafeMode first resourceAssessment then degradedSafeMode;
            transition restartFromSafeMode first degradedSafeMode then acceptingIntent;
        }
    }

    constraint def ResourceEfficiencyConstraint {
        in throughput : ServiceThroughput_tasksPerHour;
        in mass : Mass_kg;
        in power : Power_W;
        in recovery : Ratio_1;
        in utilization : Ratio_1;

        constraint {
            throughput >= 1000.0 and
            mass <= 50.0 and
            power <= 800.0 and
            recovery >= 0.90 and
            utilization >= 0.95
        }
    }

    constraint def AvailabilityConstraint {
        in availability : Ratio_1;
        in responseTime : Time_s;

        constraint {
            availability >= 0.99 and
            responseTime <= 1.0
        }
    }

    requirement def EphemeralizationPrimaryFunctionRequirement {
        doc /* The system shall deliver useful service output from a high-level intent while using minimal sufficient material, energy, volume, and computation, and shall recover most temporary material after service delivery. */
        subject platform : EphemeralizedServicePlatform;

        attribute minimumThroughput : ServiceThroughput_tasksPerHour = 1000.0;
        attribute maximumMass : Mass_kg = 50.0;
        attribute maximumAveragePower : Power_W = 800.0;
        attribute minimumRecovery : Ratio_1 = 0.90;
        attribute minimumMaterialUtilization : Ratio_1 = 0.95;

        require constraint {
            platform.serviceThroughput >= minimumThroughput and
            platform.totalMass <= maximumMass and
            platform.averagePower <= maximumAveragePower and
            platform.materialRecoveryRatio >= minimumRecovery and
            platform.materialUtilizationRatio >= minimumMaterialUtilization
        }
    }

    requirement def EphemeralizationResponsivenessRequirement {
        doc /* The system shall respond to a requested service intent quickly enough to preserve high-value operation. */
        subject platform : EphemeralizedServicePlatform;

        attribute maximumResponseTime : Time_s = 1.0;
        attribute minimumAvailability : Ratio_1 = 0.99;

        require constraint {
            platform.responseTime <= maximumResponseTime and
            platform.availability >= minimumAvailability
        }
    }

    requirement def ResourceCircularityRequirement {
        doc /* The system shall treat temporary physical configuration as recoverable resource rather than permanent committed mass. */
        subject platform : EphemeralizedServicePlatform;

        attribute minimumRecoveryRatio : Ratio_1 = 0.90;

        require constraint {
            platform.materialRecoveryRatio >= minimumRecoveryRatio
        }
    }

    part ephemeralizationSystem : EphemeralizedServicePlatform;

    requirement primaryFunction : EphemeralizationPrimaryFunctionRequirement {
        subject platform = ephemeralizationSystem;
    }

    requirement responsiveness : EphemeralizationResponsivenessRequirement {
        subject platform = ephemeralizationSystem;
    }

    requirement circularity : ResourceCircularityRequirement {
        subject platform = ephemeralizationSystem;
    }

    satisfy primaryFunction by ephemeralizationSystem;
    satisfy responsiveness by ephemeralizationSystem;
    satisfy circularity by ephemeralizationSystem;
}
