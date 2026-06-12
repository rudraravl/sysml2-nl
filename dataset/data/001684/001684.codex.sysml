package SmartLabSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percentage : Real {
        doc /* Unitless percentage in the range 0..100. */
    }

    attribute def PartsPerMillion : Real;
    attribute def Lux : Real;
    attribute def Decibel : Real;
    attribute def AirChangesPerHour : Real;
    attribute def WattHour : Real;
    attribute def Celsius : Real;
    attribute def Milliliter : Real;
    attribute def Gram : Real;

    item def AirSample {
        attribute carbonDioxide : PartsPerMillion;
        attribute volatileOrganicCompounds : PartsPerMillion;
        attribute particulateMatterPM25 : PartsPerMillion;
        attribute temperature : Celsius;
        attribute humidity : Percentage;
    }

    item def LabOccupancy {
        attribute occupied : Boolean;
        attribute personCount : Integer;
        attribute authorizedPersonCount : Integer;
    }

    item def ExperimentProfile {
        attribute experimentId : String;
        attribute targetTemperature : Celsius;
        attribute targetHumidity : Percentage;
        attribute targetIlluminance : Lux;
        attribute minimumAirChangeRate : AirChangesPerHour;
        attribute hazardousMaterialUsed : Boolean;
        attribute maximumNoiseLevel : Decibel;
    }

    item def SensorReading {
        attribute readingId : String;
        attribute measuredAtSeconds : Real;
        attribute qualityValid : Boolean;
    }

    item def TemperatureReading specializes SensorReading {
        attribute value : Celsius;
    }

    item def HumidityReading specializes SensorReading {
        attribute value : Percentage;
    }

    item def LightReading specializes SensorReading {
        attribute value : Lux;
    }

    item def EnergyReading specializes SensorReading {
        attribute value : WattHour;
    }

    item def DoorEvent {
        attribute doorId : String;
        attribute opened : Boolean;
        attribute authenticated : Boolean;
        attribute eventTimeSeconds : Real;
    }

    item def SafetyAlarm {
        attribute alarmId : String;
        attribute severity : Integer;
        attribute alarmText : String;
        attribute active : Boolean;
    }

    item def ControlCommand {
        attribute commandId : String;
        attribute issuedAtSeconds : Real;
        attribute priority : Integer;
    }

    item def HvacCommand specializes ControlCommand {
        attribute requestedTemperature : Celsius;
        attribute requestedHumidity : Percentage;
        attribute requestedAirChangeRate : AirChangesPerHour;
    }

    item def LightingCommand specializes ControlCommand {
        attribute requestedIlluminance : Lux;
        attribute requestedPowerLevel : Percentage;
    }

    item def AccessDecision specializes ControlCommand {
        attribute accessGranted : Boolean;
        attribute reason : String;
    }

    item def InventoryTransaction {
        attribute materialId : String;
        attribute materialName : String;
        attribute deltaMass : Gram;
        attribute deltaVolume : Milliliter;
        attribute hazardous : Boolean;
        attribute operatorId : String;
    }

    item def LabStatusReport {
        attribute reportId : String;
        attribute summary : String;
        attribute safeForOccupancy : Boolean;
        attribute energyConsumedToday : WattHour;
        attribute activeAlarmCount : Integer;
    }

    port def PowerPort {
        in item suppliedEnergy : EnergyReading;
    }

    port def DataInPort {
        in item reading : SensorReading;
    }

    port def DataOutPort {
        out item reading : SensorReading;
    }

    port def CommandInPort {
        in item command : ControlCommand;
    }

    port def CommandOutPort {
        out item command : ControlCommand;
    }

    port def AlarmOutPort {
        out item alarm : SafetyAlarm;
    }

    port def AlarmInPort {
        in item alarm : SafetyAlarm;
    }

    port def OccupancyOutPort {
        out item occupancy : LabOccupancy;
    }

    port def OccupancyInPort {
        in item occupancy : LabOccupancy;
    }

    port def ProfileInPort {
        in item profile : ExperimentProfile;
    }

    port def ProfileOutPort {
        out item profile : ExperimentProfile;
    }

    part def EnvironmentalSensor {
        attribute samplePeriodSeconds : Real = 5.0;
        attribute calibrated : Boolean = true;

        port power : PowerPort;
        port dataOut : DataOutPort;

        action senseEnvironment {
            out item temperature : TemperatureReading;
            out item humidity : HumidityReading;
            out item air : AirSample;
        }
    }

    part def LightingSensor {
        attribute samplePeriodSeconds : Real = 3.0;
        attribute measurementRange : Lux = 100000.0;

        port power : PowerPort;
        port dataOut : DataOutPort;

        action measureIlluminance {
            out item illuminance : LightReading;
        }
    }

    part def OccupancySensor {
        attribute detectionConfidence : Percentage = 98.0;

        port power : PowerPort;
        port occupancyOut : OccupancyOutPort;

        action detectPresence {
            out item occupancy : LabOccupancy;
        }
    }

    part def SmartDoorController {
        attribute doorLocked : Boolean = true;
        attribute failSecure : Boolean = true;

        port power : PowerPort;
        port occupancyOut : OccupancyOutPort;
        port commandIn : CommandInPort;
        port alarmOut : AlarmOutPort;

        action authenticateEntry {
            in item event : DoorEvent;
            out item decision : AccessDecision;
        }

        state def DoorSecurityState {
            state locked;
            state unlocked;
            state forcedOpen;
            state emergencyReleased;

            entry action initializeLock;
            initial then locked;

            transition locked_to_unlocked
                first locked
                accept AccessDecision
                if accessGranted
                then unlocked;

            transition unlocked_to_locked
                first unlocked
                accept DoorEvent
                if not opened
                then locked;

            transition locked_to_forcedOpen
                first locked
                accept DoorEvent
                if opened and not authenticated
                then forcedOpen;

            transition forcedOpen_to_locked
                first forcedOpen
                accept AccessDecision
                if accessGranted
                then locked;

            transition locked_to_emergencyReleased
                first locked
                accept SafetyAlarm
                if active and severity >= 4
                then emergencyReleased;
        }
    }

    part def HvacUnit {
        attribute currentTemperatureSetpoint : Celsius = 22.0;
        attribute currentHumiditySetpoint : Percentage = 45.0;
        attribute currentAirChangeRate : AirChangesPerHour = 6.0;
        attribute maximumAirChangeRate : AirChangesPerHour = 20.0;

        port power : PowerPort;
        port commandIn : CommandInPort;
        port dataOut : DataOutPort;

        action regulateClimate {
            in item command : HvacCommand;
            in item airSample : AirSample;
            out item energyUse : EnergyReading;
        }

        state def HvacOperatingState {
            state standby;
            state heating;
            state cooling;
            state ventilating;
            state dehumidifying;
            state emergencyPurge;

            initial then standby;

            transition standby_to_heating
                first standby
                accept HvacCommand
                if requestedTemperature > currentTemperatureSetpoint
                then heating;

            transition standby_to_cooling
                first standby
                accept HvacCommand
                if requestedTemperature < currentTemperatureSetpoint
                then cooling;

            transition standby_to_ventilating
                first standby
                accept HvacCommand
                if requestedAirChangeRate > currentAirChangeRate
                then ventilating;

            transition any_to_emergencyPurge
                first standby
                accept SafetyAlarm
                if active and severity >= 5
                then emergencyPurge;

            transition emergencyPurge_to_standby
                first emergencyPurge
                accept SafetyAlarm
                if not active
                then standby;
        }
    }

    part def AdaptiveLightingSystem {
        attribute currentIlluminanceSetpoint : Lux = 500.0;
        attribute currentPowerLevel : Percentage = 60.0;
        attribute maximumPowerWatts : Real = 1200.0;

        port power : PowerPort;
        port commandIn : CommandInPort;
        port dataOut : DataOutPort;

        action adjustLighting {
            in item command : LightingCommand;
            in item occupancy : LabOccupancy;
            out item energyUse : EnergyReading;
        }

        state def LightingState {
            state off;
            state taskMode;
            state energySavingMode;
            state emergencyMode;

            initial then energySavingMode;

            transition energySaving_to_task
                first energySavingMode
                accept LabOccupancy
                if occupied
                then taskMode;

            transition task_to_energySaving
                first taskMode
                accept LabOccupancy
                if not occupied
                then energySavingMode;

            transition any_to_emergency
                first taskMode
                accept SafetyAlarm
                if active and severity >= 4
                then emergencyMode;

            transition emergency_to_energySaving
                first emergencyMode
                accept SafetyAlarm
                if not active
                then energySavingMode;
        }
    }

    part def InventoryManager {
        attribute controlledSubstanceCount : Integer = 0;
        attribute hazardousMaterialCount : Integer = 0;

        port commandIn : CommandInPort;
        port alarmOut : AlarmOutPort;

        action recordTransaction {
            in item transaction : InventoryTransaction;
            out item alarm : SafetyAlarm;
        }

        action reconcileInventory {
            out attribute discrepancyDetected : Boolean;
        }
    }

    part def ExperimentScheduler {
        attribute activeExperimentId : String = "none";
        attribute scheduleHorizonHours : Real = 168.0;

        port profileOut : ProfileOutPort;
        port alarmIn : AlarmInPort;

        action publishExperimentProfile {
            out item profile : ExperimentProfile;
        }

        action suspendExperiment {
            in item alarm : SafetyAlarm;
        }
    }

    part def SafetySupervisor {
        attribute maximumAllowedCO2 : PartsPerMillion = 1000.0;
        attribute maximumAllowedVOC : PartsPerMillion = 5.0;
        attribute maximumAllowedPM25 : PartsPerMillion = 35.0;
        attribute maximumAllowedTemperature : Celsius = 30.0;
        attribute minimumAllowedTemperature : Celsius = 16.0;

        port sensorIn : DataInPort;
        port occupancyIn : OccupancyInPort;
        port alarmOut : AlarmOutPort;

        action evaluateSafety {
            in item air : AirSample;
            in item occupancy : LabOccupancy;
            out item alarm : SafetyAlarm;
        }

        state def SafetyState {
            state normal;
            state advisory;
            state warning;
            state emergency;

            initial then normal;

            transition normal_to_advisory
                first normal
                accept AirSample
                if carbonDioxide > 800.0
                then advisory;

            transition advisory_to_warning
                first advisory
                accept AirSample
                if carbonDioxide > maximumAllowedCO2 or volatileOrganicCompounds > maximumAllowedVOC
                then warning;

            transition warning_to_emergency
                first warning
                accept AirSample
                if particulateMatterPM25 > maximumAllowedPM25 or temperature > maximumAllowedTemperature
                then emergency;

            transition emergency_to_normal
                first emergency
                accept AirSample
                if carbonDioxide <= 800.0 and volatileOrganicCompounds <= 1.0 and temperature <= 25.0
                then normal;
        }
    }

    part def SmartLabOrchestrator {
        attribute controlCycleSeconds : Real = 10.0;
        attribute optimizationEnabled : Boolean = true;
        attribute latestStatusSafe : Boolean = true;

        port sensorIn : DataInPort;
        port occupancyIn : OccupancyInPort;
        port profileIn : ProfileInPort;
        port alarmIn : AlarmInPort;
        port hvacCommandOut : CommandOutPort;
        port lightingCommandOut : CommandOutPort;
        port accessCommandOut : CommandOutPort;

        action optimizeLabEnvironment {
            in item profile : ExperimentProfile;
            in item occupancy : LabOccupancy;
            in item air : AirSample;
            out item hvacCommand : HvacCommand;
            out item lightingCommand : LightingCommand;
        }

        action generateStatusReport {
            in item alarm : SafetyAlarm;
            in item energy : EnergyReading;
            out item report : LabStatusReport;
        }

        state def OrchestratorState {
            state idle;
            state preparingExperiment;
            state monitoringExperiment;
            state optimizing;
            state safetyOverride;

            initial then idle;

            transition idle_to_preparing
                first idle
                accept ExperimentProfile
                then preparingExperiment;

            transition preparing_to_monitoring
                first preparingExperiment
                accept LabOccupancy
                if occupied
                then monitoringExperiment;

            transition monitoring_to_optimizing
                first monitoringExperiment
                accept SensorReading
                if qualityValid
                then optimizing;

            transition optimizing_to_monitoring
                first optimizing
                accept ControlCommand
                then monitoringExperiment;

            transition any_to_safetyOverride
                first monitoringExperiment
                accept SafetyAlarm
                if active and severity >= 4
                then safetyOverride;

            transition safetyOverride_to_idle
                first safetyOverride
                accept SafetyAlarm
                if not active
                then idle;
        }
    }

    part def EnergyMeter {
        attribute measurementIntervalSeconds : Real = 60.0;
        attribute accumulatedDailyEnergy : WattHour = 0.0;

        port power : PowerPort;
        port dataOut : DataOutPort;

        action measureEnergy {
            out item energy : EnergyReading;
        }
    }

    part def SmartLab {
        doc /* Primary high-level function: a SmartLab autonomously prepares, monitors, and controls a laboratory environment so experiments can run safely, efficiently, and repeatably with adaptive climate, lighting, access, inventory, energy, and safety supervision. */

        attribute labIdentifier : String = "SL-01";
        attribute nominalAreaSquareMeters : Real = 85.0;
        attribute targetAvailability : Percentage = 99.5;

        port facilityPower : PowerPort;
        port statusAlarm : AlarmOutPort;

        part environmentalSensor : EnvironmentalSensor;
        part lightingSensor : LightingSensor;
        part occupancySensor : OccupancySensor;
        part doorController : SmartDoorController;
        part hvac : HvacUnit;
        part lighting : AdaptiveLightingSystem;
        part inventory : InventoryManager;
        part scheduler : ExperimentScheduler;
        part supervisor : SafetySupervisor;
        part orchestrator : SmartLabOrchestrator;
        part energyMeter : EnergyMeter;

        connect facilityPower to environmentalSensor.power;
        connect facilityPower to lightingSensor.power;
        connect facilityPower to occupancySensor.power;
        connect facilityPower to doorController.power;
        connect facilityPower to hvac.power;
        connect facilityPower to lighting.power;
        connect facilityPower to energyMeter.power;

        connect environmentalSensor.dataOut to orchestrator.sensorIn;
        connect environmentalSensor.dataOut to supervisor.sensorIn;
        connect lightingSensor.dataOut to orchestrator.sensorIn;
        connect energyMeter.dataOut to orchestrator.sensorIn;

        connect occupancySensor.occupancyOut to orchestrator.occupancyIn;
        connect occupancySensor.occupancyOut to supervisor.occupancyIn;
        connect doorController.occupancyOut to orchestrator.occupancyIn;

        connect scheduler.profileOut to orchestrator.profileIn;

        connect supervisor.alarmOut to orchestrator.alarmIn;
        connect supervisor.alarmOut to scheduler.alarmIn;
        connect supervisor.alarmOut to statusAlarm;
        connect inventory.alarmOut to orchestrator.alarmIn;
        connect inventory.alarmOut to statusAlarm;
        connect doorController.alarmOut to orchestrator.alarmIn;
        connect doorController.alarmOut to statusAlarm;

        connect orchestrator.hvacCommandOut to hvac.commandIn;
        connect orchestrator.lightingCommandOut to lighting.commandIn;
        connect orchestrator.accessCommandOut to doorController.commandIn;
    }

    action def RunSmartLabMission {
        in item experimentProfile : ExperimentProfile;
        in item initialOccupancy : LabOccupancy;
        out item finalReport : LabStatusReport;

        first start;

        action loadProfile {
            in item experimentProfile;
        }

        action prepareEnvironment {
            in item experimentProfile;
            out item hvacCommand : HvacCommand;
            out item lightingCommand : LightingCommand;
        }

        action authorizeAccess {
            in item initialOccupancy;
            out item accessDecision : AccessDecision;
        }

        action monitorContinuously {
            out item airSample : AirSample;
            out item alarm : SafetyAlarm;
        }

        action optimizeResources {
            in item airSample;
            in item experimentProfile;
        }

        action reportStatus {
            in item alarm;
            out item finalReport;
        }

        then loadProfile;
        then prepareEnvironment;
        then authorizeAccess;
        then monitorContinuously;
        then optimizeResources;
        then reportStatus;
        then done;
    }

    requirement def SmartLabPrimaryFunction {
        doc /* The SmartLab shall autonomously maintain laboratory environmental, safety, access, energy, and inventory conditions needed to support scheduled experiments. */
    }

    requirement def ClimateControlRequirement {
        doc /* The SmartLab shall maintain temperature within plus or minus 1.0 Celsius of the active experiment target while occupied. */
        attribute tolerance : Celsius = 1.0;
    }

    requirement def HumidityControlRequirement {
        doc /* The SmartLab shall maintain relative humidity within plus or minus 5 percent of the active experiment target unless safety purge mode is active. */
        attribute tolerance : Percentage = 5.0;
    }

    requirement def LightingRequirement {
        doc /* The SmartLab shall provide adaptive task lighting from 300 lux to 1000 lux based on occupancy and experiment profile. */
        attribute minimumTaskIlluminance : Lux = 300.0;
        attribute maximumTaskIlluminance : Lux = 1000.0;
    }

    requirement def SafetyAirRequirement {
        doc /* The SmartLab shall raise an alarm and increase ventilation when carbon dioxide exceeds 1000 ppm, volatile organic compounds exceed 5 ppm, or PM2.5 exceeds 35 ppm. */
        attribute carbonDioxideLimit : PartsPerMillion = 1000.0;
        attribute vocLimit : PartsPerMillion = 5.0;
        attribute pm25Limit : PartsPerMillion = 35.0;
    }

    requirement def AccessControlRequirement {
        doc /* The SmartLab shall permit entry only to authenticated personnel and shall generate a forced-entry alarm when a locked door is opened without authentication. */
    }

    requirement def InventoryTraceabilityRequirement {
        doc /* The SmartLab shall record every hazardous material inventory transaction with material identity, operator identity, quantity change, and hazard classification. */
    }

    requirement def EnergyEfficiencyRequirement {
        doc /* The SmartLab shall reduce lighting and ventilation demand when unoccupied while preserving safety limits and experiment constraints. */
        attribute unoccupiedLightingPowerLimit : Percentage = 20.0;
        attribute minimumUnoccupiedAirChangeRate : AirChangesPerHour = 3.0;
    }

    requirement def EmergencyResponseRequirement {
        doc /* The SmartLab shall enter emergency purge and emergency lighting modes when a severity 5 alarm is active. */
        attribute emergencyAlarmSeverity : Integer = 5;
    }

    requirement def AvailabilityRequirement {
        doc /* The SmartLab shall achieve at least 99.5 percent operational availability for monitoring and safety functions. */
        attribute requiredAvailability : Percentage = 99.5;
    }

    satisfy SmartLab by SmartLabPrimaryFunction;
    satisfy SmartLab::hvac by ClimateControlRequirement;
    satisfy SmartLab::hvac by HumidityControlRequirement;
    satisfy SmartLab::lighting by LightingRequirement;
    satisfy SmartLab::supervisor by SafetyAirRequirement;
    satisfy SmartLab::doorController by AccessControlRequirement;
    satisfy SmartLab::inventory by InventoryTraceabilityRequirement;
    satisfy SmartLab::orchestrator by EnergyEfficiencyRequirement;
    satisfy SmartLab::hvac by EmergencyResponseRequirement;
    satisfy SmartLab::lighting by EmergencyResponseRequirement;
    satisfy SmartLab::environmentalSensor by AvailabilityRequirement;
    satisfy SmartLab::supervisor by AvailabilityRequirement;

    requirement def SmartLabVerificationRequirement {
        doc /* Verification shall demonstrate closed-loop environment control, authenticated access handling, hazardous inventory traceability, energy reduction during vacancy, and emergency response under alarm injection. */
    }

    verification case def VerifyClimateStability {
        subject smartLab : SmartLab;
        objective ClimateControlRequirement;
    }

    verification case def VerifySafetyAlarmResponse {
        subject smartLab : SmartLab;
        objective SafetyAirRequirement;
        objective EmergencyResponseRequirement;
    }

    verification case def VerifyAccessControl {
        subject smartLab : SmartLab;
        objective AccessControlRequirement;
    }

    verification case def VerifyInventoryTraceability {
        subject smartLab : SmartLab;
        objective InventoryTraceabilityRequirement;
    }

    verification case def VerifyEnergyEfficiency {
        subject smartLab : SmartLab;
        objective EnergyEfficiencyRequirement;
    }

}