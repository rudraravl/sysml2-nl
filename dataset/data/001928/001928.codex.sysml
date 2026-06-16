package SpaceExplorationSystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Mass :> ISQ::mass {
        unit = SI::kilogram;
    }

    attribute def Distance :> ISQ::length {
        unit = SI::kilometre;
    }

    attribute def Velocity :> ISQ::speed {
        unit = SI::metrePerSecond;
    }

    attribute def Acceleration :> ISQ::acceleration {
        unit = SI::metrePerSecondSquared;
    }

    attribute def Force :> ISQ::force {
        unit = SI::newton;
    }

    attribute def Power :> ISQ::power {
        unit = SI::watt;
    }

    attribute def Energy :> ISQ::energy {
        unit = SI::joule;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def DataRate :> ISQ::frequency {
        unit = SI::hertz;
    }

    item def TelemetryPacket {
        attribute packetId : Integer;
        attribute timestamp : Real;
        attribute spacecraftPosition : Distance;
        attribute spacecraftVelocity : Velocity;
        attribute subsystemHealthCode : Integer;
        attribute sciencePayloadBytes : Integer;
    }

    item def CommandPacket {
        attribute commandId : Integer;
        attribute priority : Integer;
        attribute executionTime : Real;
        attribute targetSubsystemId : Integer;
    }

    item def Propellant {
        attribute remainingMass : Mass;
        attribute oxidizerRatio : Real;
        attribute storageTemperature : Temperature;
    }

    item def ElectricalEnergy {
        attribute availableEnergy : Energy;
        attribute busVoltage : Real;
    }

    item def ScienceSample {
        attribute sampleId : Integer;
        attribute mineralConfidence : Real;
        attribute imageResolution : Real;
        attribute radiationReading : Real;
    }

    item def ThermalLoad {
        attribute heatFlow : Power;
        attribute sourceTemperature : Temperature;
    }

    port def DataPort {
        out item telemetry : TelemetryPacket;
        in item command : CommandPacket;
    }

    port def PowerPort {
        out item suppliedPower : ElectricalEnergy;
        in item loadDemand : ElectricalEnergy;
    }

    port def PropellantPort {
        out item propellantFlow : Propellant;
    }

    port def ThermalPort {
        in item heatInput : ThermalLoad;
        out item rejectedHeat : ThermalLoad;
    }

    port def SciencePort {
        out item scienceData : ScienceSample;
        in item observationCommand : CommandPacket;
    }

    part def DeepSpaceExplorationSystem {
        doc
        /* Primary function: conduct autonomous deep-space exploration by launching a robotic spacecraft, navigating to a planetary target, collecting scientific observations, maintaining spacecraft health, and returning validated telemetry and science data to Earth. */

        attribute missionDuration : Real;
        attribute targetDistance : Distance;
        attribute cruiseVelocity : Velocity;
        attribute totalLaunchMass : Mass;
        attribute nominalPowerGeneration : Power;
        attribute minimumCommunicationRate : DataRate;

        port missionData : DataPort;
        port externalPowerInterface : PowerPort;

        part launchSegment : LaunchVehicle;
        part spacecraft : ExplorationSpacecraft;
        part groundSegment : GroundMissionControl;

        connect launchSegment.payloadMechanicalInterface to spacecraft.launchVehicleInterface;
        connect spacecraft.spaceToGroundLink to groundSegment.deepSpaceNetworkLink;
        connect groundSegment.missionCommandLink to spacecraft.commandAndTelemetryLink;
    }

    part def LaunchVehicle {
        attribute liftoffMass : Mass;
        attribute payloadCapacityToEscape : Mass;
        attribute maximumThrust : Force;
        attribute targetInjectionVelocity : Velocity;

        port payloadMechanicalInterface : DataPort;
        port propellantOutlet : PropellantPort;

        part firstStage : PropulsionStage {
            attribute stageDryMass = 26000 [SI::kilogram];
            attribute thrust = 7600000 [SI::newton];
        }

        part upperStage : PropulsionStage {
            attribute stageDryMass = 4800 [SI::kilogram];
            attribute thrust = 1100000 [SI::newton];
        }

        part flightComputer : GuidanceComputer;

        connect firstStage.stageTelemetry to flightComputer.guidanceData;
        connect upperStage.stageTelemetry to flightComputer.guidanceData;
    }

    part def PropulsionStage {
        attribute stageDryMass : Mass;
        attribute propellantMass : Mass;
        attribute thrust : Force;
        attribute specificImpulse : Real;

        port fuelOutlet : PropellantPort;
        port stageTelemetry : DataPort;

        part engineController : EngineController;
        part propellantTank : PropellantTank;

        connect propellantTank.tankOutlet to fuelOutlet;
        connect engineController.engineCommandPort to stageTelemetry;
    }

    part def PropellantTank {
        attribute capacity : Mass;
        attribute fillLevel : Mass;
        attribute tankPressure : Real;
        attribute tankTemperature : Temperature;

        port tankOutlet : PropellantPort;
        port thermalInterface : ThermalPort;
    }

    part def EngineController {
        attribute commandedThrottle : Real;
        attribute chamberPressure : Real;
        attribute shutdownThreshold : Real;

        port engineCommandPort : DataPort;
    }

    part def GuidanceComputer {
        attribute navigationError : Distance;
        attribute attitudeError : Real;
        attribute processorLoad : Real;

        port guidanceData : DataPort;
        port commandOutput : DataPort;
    }

    part def ExplorationSpacecraft {
        attribute dryMass : Mass;
        attribute propellantReserve : Mass;
        attribute maximumDeltaV : Velocity;
        attribute operationalTemperatureLow : Temperature;
        attribute operationalTemperatureHigh : Temperature;
        attribute onboardStorageCapacityBytes : Integer;

        port launchVehicleInterface : DataPort;
        port spaceToGroundLink : DataPort;
        port commandAndTelemetryLink : DataPort;

        part flightComputer : SpacecraftComputer;
        part electricPowerSystem : ElectricalPowerSubsystem;
        part propulsionSystem : SpacecraftPropulsionSubsystem;
        part attitudeControlSystem : AttitudeControlSubsystem;
        part thermalControlSystem : ThermalControlSubsystem;
        part communicationsSystem : CommunicationsSubsystem;
        part sciencePayload : SciencePayloadSubsystem;

        connect electricPowerSystem.primaryPowerBus to flightComputer.powerInput;
        connect electricPowerSystem.primaryPowerBus to communicationsSystem.powerInput;
        connect electricPowerSystem.primaryPowerBus to sciencePayload.powerInput;
        connect electricPowerSystem.primaryPowerBus to attitudeControlSystem.powerInput;
        connect electricPowerSystem.primaryPowerBus to thermalControlSystem.powerInput;

        connect propulsionSystem.propellantStatus to flightComputer.subsystemData;
        connect attitudeControlSystem.attitudeTelemetry to flightComputer.subsystemData;
        connect thermalControlSystem.thermalTelemetry to flightComputer.subsystemData;
        connect sciencePayload.scienceOutput to flightComputer.scienceInput;

        connect flightComputer.telemetryOutput to communicationsSystem.dataInput;
        connect communicationsSystem.radioLink to spaceToGroundLink;
        connect commandAndTelemetryLink to flightComputer.commandInput;
    }

    part def SpacecraftComputer {
        attribute processorRedundancyCount : Integer;
        attribute faultCounter : Integer;
        attribute autonomousModeEnabled : Boolean;
        attribute storedCommandCount : Integer;

        port powerInput : PowerPort;
        port commandInput : DataPort;
        port telemetryOutput : DataPort;
        port subsystemData : DataPort;
        port scienceInput : SciencePort;

        action performAutonomousMission {
            first startMission;
            then navigateCruise;
            then acquireScience;
            then transmitResults;
        }

        action startMission {
            out item initialTelemetry : TelemetryPacket;
        }

        action navigateCruise {
            in item navigationCommand : CommandPacket;
            out item cruiseTelemetry : TelemetryPacket;
        }

        action acquireScience {
            in item observationPlan : CommandPacket;
            out item collectedSample : ScienceSample;
        }

        action transmitResults {
            in item collectedSample : ScienceSample;
            out item downlinkTelemetry : TelemetryPacket;
        }

        state def MissionControlState {
            entry action initializeComputer;
            state SafeMode;
            state LaunchConfiguration;
            state Cruise;
            state TargetApproach;
            state ScienceOperations;
            state DataReturn;
            state MissionComplete;

            initial then LaunchConfiguration;

            transition LaunchConfiguration_to_Cruise
                first LaunchConfiguration
                then Cruise
                accept CommandPacket
                if autonomousModeEnabled == true;

            transition Cruise_to_TargetApproach
                first Cruise
                then TargetApproach
                if storedCommandCount > 0;

            transition TargetApproach_to_ScienceOperations
                first TargetApproach
                then ScienceOperations;

            transition ScienceOperations_to_DataReturn
                first ScienceOperations
                then DataReturn;

            transition DataReturn_to_MissionComplete
                first DataReturn
                then MissionComplete;

            transition Any_to_SafeMode
                first Cruise
                then SafeMode
                if faultCounter > 2;
        }
    }

    part def ElectricalPowerSubsystem {
        attribute solarArrayArea : Real;
        attribute batteryCapacity : Energy;
        attribute generatedPower : Power;
        attribute reserveEnergy : Energy;
        attribute minimumSafeEnergy : Energy;

        port primaryPowerBus : PowerPort;
        port powerTelemetry : DataPort;

        part solarArray : SolarArray;
        part battery : Battery;
        part powerConditioner : PowerConditioningUnit;

        connect solarArray.arrayOutput to powerConditioner.sourceInput;
        connect battery.batteryOutput to powerConditioner.storageInput;
        connect powerConditioner.regulatedOutput to primaryPowerBus;
    }

    part def SolarArray {
        attribute panelArea : Real;
        attribute conversionEfficiency : Real;
        attribute outputPower : Power;
        attribute degradationFactor : Real;

        port arrayOutput : PowerPort;
        port thermalInterface : ThermalPort;
    }

    part def Battery {
        attribute storedEnergy : Energy;
        attribute maximumEnergy : Energy;
        attribute chargeCycles : Integer;
        attribute batteryTemperature : Temperature;

        port batteryOutput : PowerPort;
        port thermalInterface : ThermalPort;
    }

    part def PowerConditioningUnit {
        attribute regulatedVoltage : Real;
        attribute conversionEfficiency : Real;
        attribute maximumLoad : Power;

        port sourceInput : PowerPort;
        port storageInput : PowerPort;
        port regulatedOutput : PowerPort;
    }

    part def SpacecraftPropulsionSubsystem {
        attribute totalPropellantMass : Mass;
        attribute remainingDeltaV : Velocity;
        attribute mainEngineThrust : Force;
        attribute maneuverAccuracy : Real;

        port propellantStatus : DataPort;
        port burnCommand : DataPort;

        part mainEngine : MainEngine;
        part reactionControlThrusters : ReactionControlThrusterSet;
        part propellantTank : PropellantTank;

        connect propellantTank.tankOutlet to mainEngine.enginePropellantInput;
        connect propellantTank.tankOutlet to reactionControlThrusters.thrusterPropellantInput;
    }

    part def MainEngine {
        attribute thrust : Force;
        attribute minimumImpulseBit : Real;
        attribute restartCount : Integer;

        port enginePropellantInput : PropellantPort;
        port engineTelemetry : DataPort;
    }

    part def ReactionControlThrusterSet {
        attribute thrusterCount : Integer;
        attribute singleThrusterForce : Force;
        attribute pulseDuration : Real;

        port thrusterPropellantInput : PropellantPort;
        port thrusterCommandPort : DataPort;
    }

    part def AttitudeControlSubsystem {
        attribute pointingAccuracy : Real;
        attribute angularRateLimit : Real;
        attribute starTrackerAvailability : Boolean;

        port powerInput : PowerPort;
        port attitudeTelemetry : DataPort;
        port attitudeCommand : DataPort;

        part starTracker : StarTracker;
        part inertialMeasurementUnit : InertialMeasurementUnit;
        part reactionWheels : ReactionWheelAssembly;

        connect starTracker.trackerData to attitudeTelemetry;
        connect inertialMeasurementUnit.imuData to attitudeTelemetry;
        connect reactionWheels.wheelStatus to attitudeTelemetry;
    }

    part def StarTracker {
        attribute fieldOfView : Real;
        attribute updateRate : Real;
        attribute attitudeKnowledgeError : Real;

        port trackerData : DataPort;
        port powerInput : PowerPort;
    }

    part def InertialMeasurementUnit {
        attribute gyroBias : Real;
        attribute accelerationNoise : Acceleration;
        attribute updateFrequency : Real;

        port imuData : DataPort;
        port powerInput : PowerPort;
    }

    part def ReactionWheelAssembly {
        attribute wheelCount : Integer;
        attribute maximumMomentum : Real;
        attribute wheelSpeedLimit : Real;

        port wheelStatus : DataPort;
        port powerInput : PowerPort;
    }

    part def ThermalControlSubsystem {
        attribute controlledTemperatureLow : Temperature;
        attribute controlledTemperatureHigh : Temperature;
        attribute radiatorArea : Real;
        attribute heaterPower : Power;

        port powerInput : PowerPort;
        port thermalTelemetry : DataPort;
        port equipmentThermalBus : ThermalPort;

        part radiator : Radiator;
        part heaterController : HeaterController;

        connect heaterController.heaterThermalOutput to equipmentThermalBus;
        connect equipmentThermalBus to radiator.radiatorInput;
    }

    part def Radiator {
        attribute emissivity : Real;
        attribute area : Real;
        attribute rejectedPower : Power;

        port radiatorInput : ThermalPort;
    }

    part def HeaterController {
        attribute commandedHeaterPower : Power;
        attribute thermostatSetPoint : Temperature;

        port heaterThermalOutput : ThermalPort;
        port heaterCommandPort : DataPort;
    }

    part def CommunicationsSubsystem {
        attribute transmitPower : Power;
        attribute antennaGain : Real;
        attribute downlinkRate : DataRate;
        attribute uplinkRate : DataRate;

        port powerInput : PowerPort;
        port dataInput : DataPort;
        port radioLink : DataPort;

        part highGainAntenna : HighGainAntenna;
        part transceiver : DeepSpaceTransceiver;

        connect dataInput to transceiver.basebandData;
        connect transceiver.rfPort to highGainAntenna.antennaPort;
        connect highGainAntenna.spaceLink to radioLink;
    }

    part def HighGainAntenna {
        attribute dishDiameter : Real;
        attribute pointingLoss : Real;
        attribute gain : Real;

        port antennaPort : DataPort;
        port spaceLink : DataPort;
    }

    part def DeepSpaceTransceiver {
        attribute carrierFrequency : Real;
        attribute transmitPower : Power;
        attribute receiverNoiseTemperature : Temperature;

        port basebandData : DataPort;
        port rfPort : DataPort;
        port powerInput : PowerPort;
    }

    part def SciencePayloadSubsystem {
        attribute instrumentCount : Integer;
        attribute dailyDataVolumeBytes : Integer;
        attribute payloadMass : Mass;
        attribute payloadPowerDemand : Power;

        port powerInput : PowerPort;
        port scienceOutput : SciencePort;
        port observationCommandPort : SciencePort;

        part camera : MultispectralCamera;
        part spectrometer : SurfaceSpectrometer;
        part radiationSensor : RadiationSensor;

        connect camera.imageData to scienceOutput;
        connect spectrometer.spectrumData to scienceOutput;
        connect radiationSensor.radiationData to scienceOutput;
    }

    part def MultispectralCamera {
        attribute apertureDiameter : Real;
        attribute spectralBandCount : Integer;
        attribute groundSampleDistance : Real;

        port imageData : SciencePort;
        port cameraCommand : SciencePort;
        port powerInput : PowerPort;
    }

    part def SurfaceSpectrometer {
        attribute wavelengthMinimum : Real;
        attribute wavelengthMaximum : Real;
        attribute spectralResolution : Real;

        port spectrumData : SciencePort;
        port spectrometerCommand : SciencePort;
        port powerInput : PowerPort;
    }

    part def RadiationSensor {
        attribute doseRateRange : Real;
        attribute measurementAccuracy : Real;

        port radiationData : SciencePort;
        port powerInput : PowerPort;
    }

    part def GroundMissionControl {
        attribute operatorCount : Integer;
        attribute planningCycleHours : Real;
        attribute archiveCapacityBytes : Integer;

        port deepSpaceNetworkLink : DataPort;
        port missionCommandLink : DataPort;

        part missionPlanningSystem : MissionPlanningSystem;
        part telemetryProcessingSystem : TelemetryProcessingSystem;
        part deepSpaceNetworkStation : DeepSpaceNetworkStation;

        connect deepSpaceNetworkLink to deepSpaceNetworkStation.antennaLink;
        connect deepSpaceNetworkStation.groundDataPort to telemetryProcessingSystem.rawTelemetryInput;
        connect missionPlanningSystem.commandOutput to missionCommandLink;
    }

    part def MissionPlanningSystem {
        attribute commandSequenceLength : Integer;
        attribute validatedPlanCount : Integer;

        port commandOutput : DataPort;
        port telemetryFeedback : DataPort;

        action generateObservationPlan {
            in item latestTelemetry : TelemetryPacket;
            out item commandSequence : CommandPacket;
        }
    }

    part def TelemetryProcessingSystem {
        attribute processedPacketsPerHour : Integer;
        attribute anomalyCount : Integer;
        attribute scienceProductsGenerated : Integer;

        port rawTelemetryInput : DataPort;
        port processedTelemetryOutput : DataPort;

        action validateTelemetry {
            in item rawPacket : TelemetryPacket;
            out item validatedPacket : TelemetryPacket;
        }
    }

    part def DeepSpaceNetworkStation {
        attribute antennaDiameter : Real;
        attribute receiverSensitivity : Real;
        attribute trackingAccuracy : Real;

        port antennaLink : DataPort;
        port groundDataPort : DataPort;
    }

    requirement def PrimaryMissionRequirement {
        doc
        /* The system shall perform autonomous robotic exploration of a selected deep-space target and return validated scientific data to Earth. */

        subject system : DeepSpaceExplorationSystem;

        require constraint {
            system.targetDistance >= 1000000 [SI::kilometre]
        }
    }

    requirement def ScienceReturnRequirement {
        doc
        /* The spacecraft shall collect and downlink science observations during the target operations phase. */

        subject payload : SciencePayloadSubsystem;
        subject communications : CommunicationsSubsystem;

        require constraint {
            payload.dailyDataVolumeBytes > 1000000 and communications.downlinkRate > 1 [SI::hertz]
        }
    }

    requirement def PowerSurvivalRequirement {
        doc
        /* The spacecraft shall maintain enough electrical energy to support flight computer, communications, attitude control, thermal control, and science payload operations. */

        subject power : ElectricalPowerSubsystem;

        require constraint {
            power.reserveEnergy > power.minimumSafeEnergy
        }
    }

    requirement def NavigationRequirement {
        doc
        /* The spacecraft shall maintain cruise navigation accuracy sufficient to approach the target and perform science operations. */

        subject computer : SpacecraftComputer;
        subject attitude : AttitudeControlSubsystem;

        require constraint {
            attitude.pointingAccuracy <= 0.05
        }
    }

    requirement def ThermalProtectionRequirement {
        doc
        /* The thermal control subsystem shall keep spacecraft equipment within the required operating temperature range throughout launch, cruise, and science operations. */

        subject thermal : ThermalControlSubsystem;

        require constraint {
            thermal.controlledTemperatureLow >= 240 [SI::kelvin] and thermal.controlledTemperatureHigh <= 320 [SI::kelvin]
        }
    }

    requirement def FaultResponseRequirement {
        doc
        /* The flight computer shall transition the spacecraft to safe mode when repeated subsystem faults are detected. */

        subject computer : SpacecraftComputer;

        require constraint {
            computer.faultCounter <= 2 or computer.autonomousModeEnabled == false
        }
    }

    satisfy PrimaryMissionRequirement by DeepSpaceExplorationSystem;
    satisfy ScienceReturnRequirement by SciencePayloadSubsystem;
    satisfy PowerSurvivalRequirement by ElectricalPowerSubsystem;
    satisfy NavigationRequirement by AttitudeControlSubsystem;
    satisfy ThermalProtectionRequirement by ThermalControlSubsystem;
    satisfy FaultResponseRequirement by SpacecraftComputer;
}