package IndoorAirQualitySystem {
    import ISQ::*;
    import ScalarValues::*;

    doc /* Comprehensive Indoor Air Quality System for building environment management. */

    // ===== Units =====
    unit ppm;
    unit ppb;
    unit ug_per_m3;
    unit percent;
    unit degC;

    // ===== Enumerations =====
    enum def AlertSeverity { info; low; medium; high; critical; }
    enum def AlertType { sensorFault; filterReplacement; highPollutant; controlFailure; communicationError; }
    enum def SystemMode { idleMonitoring; activeVentilating; activePurifying; humidityControl; failsafe; }
    enum def HumidityMode { off; humidifying; dehumidifying; }
    enum def FanMode { off; low; medium; high; maximum; }
    enum def PurifierMode { standby; low; medium; high; filterReplacementNeeded; }
    enum def DisplayStatus { good; moderate; unhealthy; hazardous; }

    // ===== Value Types =====
    value type CO2Concentration :> Real { unit ppm; }
    value type VOCConcentration :> Real { unit ppb; }
    value type PM25Concentration :> Real { unit ug_per_m3; }
    value type RelativeHumidity :> Real { unit percent; }
    value type TemperatureValue :> Real { unit degC; }
    value type AirQualityIndexValue :> Real { unit percent; }
    value type FanSpeedValue :> Real { unit percent; }
    value type PurificationIntensityValue :> Real { unit percent; }
    value type HumidityLevelValue :> Real { unit percent; }
    value type FilterLifePercentage :> Real { unit percent; }
    value type OperatingHoursValue :> Real;

    // ===== Constraint Definitions =====
    constraint def ValidCO2Range {
        in co2 : CO2Concentration;
        co2 >= 300 [ppm] && co2 <= 5000 [ppm];
    }

    constraint def ValidHumidityRange {
        in humidity : RelativeHumidity;
        humidity >= 0 [percent] && humidity <= 100 [percent];
    }

    constraint def ValidTemperatureRange {
        in temp : TemperatureValue;
        temp >= -20 [degC] && temp <= 50 [degC];
    }

    constraint def ValidAQIRange {
        in aqi : AirQualityIndexValue;
        aqi >= 0 [percent] && aqi <= 100 [percent];
    }

    constraint def ValidFanSpeedRange {
        in speed : FanSpeedValue;
        speed >= 0 [percent] && speed <= 100 [percent];
    }

    // ===== Item Definitions =====
    item def AirSample {
        attribute co2 : CO2Concentration := 400 [ppm];
        attribute voc : VOCConcentration := 0 [ppb];
        attribute pm25 : PM25Concentration := 0 [ug_per_m3];
        attribute humidity : RelativeHumidity := 50 [percent];
        attribute temperature : TemperatureValue := 22 [degC];
        attribute sensorId : String;
        attribute valid : Boolean := true;
    }

    item def ControlCommand {
        attribute targetFanSpeed : FanSpeedValue := 0 [percent];
        attribute targetPurificationIntensity : PurificationIntensityValue := 0 [percent];
        attribute targetHumidityLevel : HumidityLevelValue := 50 [percent];
        attribute activateHumidityRegulator : Boolean := false;
        attribute activateFan : Boolean := false;
        attribute activatePurifier : Boolean := false;
        attribute failsafeMode : Boolean := false;
    }

    item def AlertMessage {
        attribute alertType : AlertType;
        attribute severity : AlertSeverity;
        attribute description : String;
        attribute componentId : String;
    }

    item def FilterStatus {
        attribute filterLifeRemaining : FilterLifePercentage := 100 [percent];
        attribute needsReplacement : Boolean := false;
        attribute operatingHours : OperatingHoursValue := 0;
        attribute purifierId : String;
    }

    item def AirQualityStatus {
        attribute aqi : AirQualityIndexValue := 0 [percent];
        attribute statusLabel : DisplayStatus := good;
        attribute co2 : CO2Concentration := 400 [ppm];
        attribute voc : VOCConcentration := 0 [ppb];
        attribute pm25 : PM25Concentration := 0 [ug_per_m3];
        attribute humidity : RelativeHumidity := 50 [percent];
        attribute temperature : TemperatureValue := 22 [degC];
        attribute currentMode : SystemMode := idleMonitoring;
    }

    // ===== Port Definitions =====
    port def SensorDataOut {
        out airSample : AirSample;
    }

    port def SensorDataIn {
        in airSample : AirSample;
    }

    port def CommandOut {
        out command : ControlCommand;
    }

    port def CommandIn {
        in command : ControlCommand;
    }

    port def AlertOut {
        out alert : AlertMessage;
    }

    port def AlertIn {
        in alert : AlertMessage;
    }

    port def StatusOut {
        out status : AirQualityStatus;
    }

    port def StatusIn {
        in status : AirQualityStatus;
    }

    port def FilterStatusOut {
        out filterStatus : FilterStatus;
    }

    port def FilterStatusIn {
        in filterStatus : FilterStatus;
    }

    // ===== Attribute Definitions =====
    attribute def AirQualityThresholds {
        attribute co2Threshold : CO2Concentration := 1000 [ppm];
        attribute vocThreshold : VOCConcentration := 500 [ppb];
        attribute pm25Threshold : PM25Concentration := 35 [ug_per_m3];
        attribute humidityMin : RelativeHumidity := 30 [percent];
        attribute humidityMax : RelativeHumidity := 60 [percent];
        attribute temperatureMin : TemperatureValue := 18 [degC];
        attribute temperatureMax : TemperatureValue := 26 [degC];
        attribute co2Critical : CO2Concentration := 2000 [ppm];
        attribute pm25Critical : PM25Concentration := 75 [ug_per_m3];
        attribute vocCritical : VOCConcentration := 1500 [ppb];
    }

    // ===== Action Definitions =====
    action def AggregateSensorReadings {
        in s1 : AirSample;
        in s2 : AirSample;
        in s3 : AirSample;
        out avgCO2 : CO2Concentration;
        out avgVOC : VOCConcentration;
        out avgPM25 : PM25Concentration;
        out avgHumidity : RelativeHumidity;
        out avgTemperature : TemperatureValue;
        out activeSensorCount : Integer;
        doc /* Averages readings from three sensor units, handling redundancy and excluding invalid sensors. */
    }

    action def CalculateAQI {
        in co2 : CO2Concentration;
        in voc : VOCConcentration;
        in pm25 : PM25Concentration;
        in humidity : RelativeHumidity;
        in temperature : TemperatureValue;
        in thresholds : AirQualityThresholds;
        out aqi : AirQualityIndexValue;
        out statusLabel : DisplayStatus;
        doc /* Calculates overall Air Quality Index from normalized parameter deviations relative to thresholds. */
    }

    action def DetermineControlResponse {
        in aqi : AirQualityIndexValue;
        in co2 : CO2Concentration;
        in voc : VOCConcentration;
        in pm25 : PM25Concentration;
        in humidity : RelativeHumidity;
        in thresholds : AirQualityThresholds;
        out command : ControlCommand;
        doc /* Determines adaptive control response scaling fan speed and purification intensity based on severity. */
    }

    action def CheckFilterStatus {
        in filterStatus : FilterStatus;
        out needsAlert : Boolean;
        out alert : AlertMessage;
        doc /* Checks filter life remaining and generates maintenance alert when below threshold. */
    }

    action def GenerateMaintenanceAlert {
        in componentId : String;
        in alertType : AlertType;
        in severity : AlertSeverity;
        in description : String;
        out alert : AlertMessage;
        doc /* Generates a maintenance alert message for the specified component. */
    }

    action def EvaluateFailsafe {
        in sensorCount : Integer;
        in controllerHealth : Boolean;
        out controlFailure : Boolean;
        doc /* Evaluates whether failsafe mode should be triggered based on sensor availability and controller health. */
    }

    // ===== Part Definitions =====

    part def MultiSensorUnit {
        port sensorOut : SensorDataOut;

        attribute sensorId : String;
        attribute measuredCO2 : CO2Concentration := 400 [ppm];
        attribute measuredVOC : VOCConcentration := 0 [ppb];
        attribute measuredPM25 : PM25Concentration := 0 [ug_per_m3];
        attribute measuredHumidity : RelativeHumidity := 50 [percent];
        attribute measuredTemperature : TemperatureValue := 22 [degC];
        attribute isOperational : Boolean := true;
        attribute calibrationDue : Boolean := false;
        attribute readingValid : Boolean := true;

        doc /* Integrated multi-sensor unit measuring CO2, VOCs, PM2.5, relative humidity, and temperature. */

        constraint validCO2 : ValidCO2Range { in co2 = measuredCO2; }
        constraint validHumidity : ValidHumidityRange { in humidity = measuredHumidity; }
        constraint validTemp : ValidTemperatureRange { in temp = measuredTemperature; }

        exhibit state SensorOperation {
            state Operational {
                doc /* Sensor is operational and providing valid readings. */
                entry;
            }

            state Faulted {
                doc /* Sensor has detected a fault and is not providing valid readings. */
                entry;
            }

            state CalibrationMode {
                doc /* Sensor is undergoing calibration. */
                entry;
            }

            transition Operational to Faulted when !isOperational;
            transition Faulted to Operational when isOperational;
            transition Operational to CalibrationMode when calibrationDue;
            transition CalibrationMode to Operational when !calibrationDue;
        }
    }

    part def ControlProcessor {
        port sensorIn1 : SensorDataIn;
        port sensorIn2 : SensorDataIn;
        port sensorIn3 : SensorDataIn;
        port fanCommandOut : CommandOut;
        port purifierCommandOut : CommandOut;
        port humidityRegulatorCommandOut : CommandOut;
        port uiStatusOut : StatusOut;
        port alertOut : AlertOut;
        port filterStatusIn : FilterStatusIn;

        attribute thresholds : AirQualityThresholds;
        attribute currentAQI : AirQualityIndexValue := 0 [percent];
        attribute currentStatus : AirQualityStatus;
        attribute controlFailure : Boolean := false;
        attribute filterStatus : FilterStatus;
        attribute currentMode : SystemMode := idleMonitoring;
        attribute controllerHealth : Boolean := true;

        attribute avgCO2 : CO2Concentration := 400 [ppm];
        attribute avgVOC : VOCConcentration := 0 [ppb];
        attribute avgPM25 : PM25Concentration := 0 [ug_per_m3];
        attribute avgHumidity : RelativeHumidity := 50 [percent];
        attribute avgTemperature : TemperatureValue := 22 [degC];
        attribute activeSensorCount : Integer := 3;

        action aggregateReadings : AggregateSensorReadings;
        action calculateAQI : CalculateAQI;
        action determineResponse : DetermineControlResponse;
        action checkFilter : CheckFilterStatus;
        action generateAlert : GenerateMaintenanceAlert;
        action evaluateFailsafe : EvaluateFailsafe;

        doc /* Central control processor that acts as the system brain, receiving sensor data and commanding actuators. */

        constraint validAQI : ValidAQIRange { in aqi = currentAQI; }

        exhibit state OperatingModes {
            state IdleMonitoring {
                doc /* Air quality is within acceptable ranges; system monitors passively. */
                entry;
            }

            state ActiveVentilating {
                doc /* CO2 or PM2.5 exceeds thresholds; ventilation fan activated at adaptive speed. */
                entry;
            }

            state ActivePurifying {
                doc /* VOCs or PM2.5 exceed thresholds; air purifier activated at adaptive intensity. */
                entry;
            }

            state HumidityControl {
                doc /* Humidity outside optimal range; humidity regulator engaged. */
                entry;
            }

            state FailsafeMode {
                doc /* Control failure detected; maximum ventilation engaged as failsafe. */
                entry;
            }

            transition IdleMonitoring to ActiveVentilating
                when avgCO2 > thresholds.co2Threshold || avgPM25 > thresholds.pm25Threshold;

            transition IdleMonitoring to ActivePurifying
                when avgVOC > thresholds.vocThreshold || avgPM25 > thresholds.pm25Threshold;

            transition IdleMonitoring to HumidityControl
                when avgHumidity < thresholds.humidityMin || avgHumidity > thresholds.humidityMax;

            transition ActiveVentilating to IdleMonitoring
                when avgCO2 <= thresholds.co2Threshold && avgPM25 <= thresholds.pm25Threshold;

            transition ActiveVentilating to ActivePurifying
                when avgVOC > thresholds.vocThreshold;

            transition ActivePurifying to IdleMonitoring
                when avgVOC <= thresholds.vocThreshold && avgPM25 <= thresholds.pm25Threshold;

            transition ActivePurifying to ActiveVentilating
                when avgCO2 > thresholds.co2Threshold;

            transition HumidityControl to IdleMonitoring
                when avgHumidity >= thresholds.humidityMin && avgHumidity <= thresholds.humidityMax;

            transition IdleMonitoring to FailsafeMode when controlFailure;
            transition ActiveVentilating to FailsafeMode when controlFailure;
            transition ActivePurifying to FailsafeMode when controlFailure;
            transition HumidityControl to FailsafeMode when controlFailure;

            transition FailsafeMode to IdleMonitoring when !controlFailure;
        }
    }

    part def VentilationFan {
        port commandIn : CommandIn;

        attribute currentSpeed : FanSpeedValue := 0 [percent];
        attribute maxSpeed : FanSpeedValue := 100 [percent];
        attribute isOperational : Boolean := true;
        attribute currentMode : FanMode := off;

        doc /* Variable-speed ventilation fan for increasing fresh air flow. */

        constraint validSpeed : ValidFanSpeedRange { in speed = currentSpeed; }

        exhibit state FanOperation {
            state Off {
                doc /* Fan is off. */
                entry;
            }

            state LowSpeed {
                doc /* Fan running at low speed (25%). */
                entry;
            }

            state MediumSpeed {
                doc /* Fan running at medium speed (50%). */
                entry;
            }

            state HighSpeed {
                doc /* Fan running at high speed (75%). */
                entry;
            }

            state MaxSpeed {
                doc /* Fan running at maximum speed (100%). */
                entry;
            }

            transition Off to LowSpeed
                when commandIn.command.activateFan && commandIn.command.targetFanSpeed > 0 [percent] && commandIn.command.targetFanSpeed <= 25 [percent];

            transition Off to MediumSpeed
                when commandIn.command.activateFan && commandIn.command.targetFanSpeed > 25 [percent] && commandIn.command.targetFanSpeed <= 50 [percent];

            transition Off to HighSpeed
                when commandIn.command.activateFan && commandIn.command.targetFanSpeed > 50 [percent] && commandIn.command.targetFanSpeed <= 75 [percent];

            transition Off to MaxSpeed
                when commandIn.command.activateFan && commandIn.command.targetFanSpeed > 75 [percent];

            transition Off to MaxSpeed
                when commandIn.command.failsafeMode;

            transition LowSpeed to MediumSpeed
                when commandIn.command.targetFanSpeed > 25 [percent];

            transition MediumSpeed to HighSpeed
                when commandIn.command.targetFanSpeed > 50 [percent];

            transition HighSpeed to MaxSpeed
                when commandIn.command.targetFanSpeed > 75 [percent];

            transition LowSpeed to Off
                when !commandIn.command.activateFan;

            transition MediumSpeed to LowSpeed
                when commandIn.command.targetFanSpeed <= 25 [percent];

            transition HighSpeed to MediumSpeed
                when commandIn.command.targetFanSpeed <= 50 [percent];

            transition MaxSpeed to HighSpeed
                when commandIn.command.targetFanSpeed <= 75 [percent] && !commandIn.command.failsafeMode;
        }
    }

    part def AirPurifier {
        port commandIn : CommandIn;
        port filterStatusOut : FilterStatusOut;

        attribute currentIntensity : PurificationIntensityValue := 0 [percent];
        attribute filterStatus : FilterStatus;
        attribute isOperational : Boolean := true;
        attribute currentMode : PurifierMode := standby;
        attribute purifierId : String;
        attribute filterReplacementThreshold : FilterLifePercentage := 20 [percent];

        doc /* Air purifier with HEPA filter for particulate and VOC removal. */

        exhibit state PurifierOperation {
            state Standby {
                doc /* Purifier is in standby mode. */
                entry;
            }

            state LowPurification {
                doc /* Purifier running at low intensity (33%). */
                entry;
            }

            state MediumPurification {
                doc /* Purifier running at medium intensity (66%). */
                entry;
            }

            state HighPurification {
                doc /* Purifier running at high intensity (100%). */
                entry;
            }

            state FilterReplacementNeeded {
                doc /* Filter life exhausted; replacement required. */
                entry;
            }

            transition Standby to LowPurification
                when commandIn.command.activatePurifier && commandIn.command.targetPurificationIntensity > 0 [percent] && commandIn.command.targetPurificationIntensity <= 33 [percent];

            transition Standby to MediumPurification
                when commandIn.command.activatePurifier && commandIn.command.targetPurificationIntensity > 33 [percent] && commandIn.command.targetPurificationIntensity <= 66 [percent];

            transition Standby to HighPurification
                when commandIn.command.activatePurifier && commandIn.command.targetPurificationIntensity > 66 [percent];

            transition LowPurification to MediumPurification
                when commandIn.command.targetPurificationIntensity > 33 [percent];

            transition MediumPurification to HighPurification
                when commandIn.command.targetPurificationIntensity > 66 [percent];

            transition HighPurification to MediumPurification
                when commandIn.command.targetPurificationIntensity <= 66 [percent];

            transition MediumPurification to LowPurification
                when commandIn.command.targetPurificationIntensity <= 33 [percent];

            transition LowPurification to Standby
                when !commandIn.command.activatePurifier;

            transition MediumPurification to Standby
                when !commandIn.command.activatePurifier;

            transition HighPurification to Standby
                when !commandIn.command.activatePurifier;

            transition Standby to FilterReplacementNeeded
                when filterStatus.needsReplacement;

            transition LowPurification to FilterReplacementNeeded
                when filterStatus.needsReplacement;

            transition MediumPurification to FilterReplacementNeeded
                when filterStatus.needsReplacement;

            transition HighPurification to FilterReplacementNeeded
                when filterStatus.needsReplacement;

            transition FilterReplacementNeeded to Standby
                when !filterStatus.needsReplacement;
        }
    }

    part def HumidityRegulator {
        port commandIn : CommandIn;

        attribute currentLevel : HumidityLevelValue := 50 [percent];
        attribute currentMode : HumidityMode := off;
        attribute isOperational : Boolean := true;

        doc /* Humidity regulator to maintain optimal moisture levels by humidifying or dehumidifying. */

        constraint validHumidityLevel : ValidHumidityRange { in humidity = currentLevel; }

        exhibit state HumidityOperation {
            state Inactive {
                doc /* Humidity regulator is inactive. */
                entry;
            }

            state Humidifying {
                doc /* Adding moisture to increase humidity toward target. */
                entry;
            }

            state Dehumidifying {
                doc /* Removing moisture to decrease humidity toward target. */
                entry;
            }

            transition Inactive to Humidifying
                when commandIn.command.activateHumidityRegulator && commandIn.command.targetHumidityLevel > currentLevel;

            transition Inactive to Dehumidifying
                when commandIn.command.activateHumidityRegulator && commandIn.command.targetHumidityLevel < currentLevel;

            transition Humidifying to Inactive
                when currentLevel >= commandIn.command.targetHumidityLevel;

            transition Dehumidifying to Inactive
                when currentLevel <= commandIn.command.targetHumidityLevel;
        }
    }

    part def UserInterface {
        port statusIn : StatusIn;
        port alertIn : AlertIn;

        attribute displayedAQI : AirQualityIndexValue := 0 [percent];
        attribute displayedStatus : DisplayStatus := good;
        attribute displayedCO2 : CO2Concentration := 400 [ppm];
        attribute displayedVOC : VOCConcentration := 0 [ppb];
        attribute displayedPM25 : PM25Concentration := 0 [ug_per_m3];
        attribute displayedHumidity : RelativeHumidity := 50 [percent];
        attribute displayedTemperature : TemperatureValue := 22 [degC];
        attribute displayedMode : SystemMode := idleMonitoring;
        attribute activeAlerts : AlertMessage[0..*];

        doc /* User interface displaying current air quality status, index, and alerts to occupants. */

        exhibit state UIDisplay {
            state DisplayGood {
                doc /* AQI 0-50: Air quality is good. */
                entry;
            }

            state DisplayModerate {
                doc /* AQI 51-100: Air quality is moderate. */
                entry;
            }

            state DisplayUnhealthy {
                doc /* AQI 101-150: Air quality is unhealthy for sensitive groups. */
                entry;
            }

            state DisplayHazardous {
                doc /* AQI above 150: Air quality is hazardous. */
                entry;
            }

            transition DisplayGood to DisplayModerate
                when statusIn.status.aqi > 50 [percent] && statusIn.status.aqi <= 100 [percent];

            transition DisplayModerate to DisplayGood
                when statusIn.status.aqi <= 50 [percent];

            transition DisplayModerate to DisplayUnhealthy
                when statusIn.status.aqi > 100 [percent] && statusIn.status.aqi <= 150 [percent];

            transition DisplayUnhealthy to DisplayModerate
                when statusIn.status.aqi <= 100 [percent];

            transition DisplayUnhealthy to DisplayHazardous
                when statusIn.status.aqi > 150 [percent];

            transition DisplayHazardous to DisplayUnhealthy
                when statusIn.status.aqi <= 150 [percent];
        }
    }

    // ===== Requirement Definitions =====

    requirement def AirQualityMonitoringReq {
        doc /* The system shall continuously monitor CO2, VOCs, PM2.5, relative humidity, and temperature. */
    }

    requirement def MultiSensorReq {
        doc /* The system shall include three multi-sensor units placed throughout the monitored space. */
    }

    requirement def AQICalculationReq {
        doc /* The controller shall calculate an overall Air Quality Index from aggregated sensor readings. */
    }

    requirement def AdaptiveResponseReq {
        doc /* The system shall adaptively scale fan speed and purification intensity based on the severity of air quality degradation. */
    }

    requirement def ThresholdResponseReq {
        doc /* If any parameter exceeds predefined healthy thresholds, the system shall automatically activate ventilation, purification, or humidity regulation. */
    }

    requirement def OperatingModesReq {
        doc /* The system shall operate in idle monitoring, active ventilating, active purifying, humidity control, and failsafe modes. */
    }

    requirement def FailsafeReq {
        doc /* In case of control failure, the system shall default to maximum ventilation as a failsafe mechanism. */
    }

    requirement def SensorRedundancyReq {
        doc /* The system shall feature sensor redundancy across three sensor units for measurement reliability. */
    }

    requirement def MaintenanceAlertReq {
        doc /* The system shall track component status and issue alerts when maintenance such as filter replacement is required. */
    }

    requirement def UserInterfaceReq {
        doc /* The user interface shall display the current air quality status and index to occupants. */
    }

    // ===== Top-level System =====

    part def IAQSystem {
        doc /* Comprehensive Indoor Air Quality System that automatically monitors and maintains healthy building environment. */

        // Requirement usages
        requirement airQualityMonitoringReq : AirQualityMonitoringReq;
        requirement multiSensorReq : MultiSensorReq;
        requirement aqiCalculationReq : AQICalculationReq;
        requirement adaptiveResponseReq : AdaptiveResponseReq;
        requirement thresholdResponseReq : ThresholdResponseReq;
        requirement operatingModesReq : OperatingModesReq;
        requirement failsafeReq : FailsafeReq;
        requirement sensorRedundancyReq : SensorRedundancyReq;
        requirement maintenanceAlertReq : MaintenanceAlertReq;
        requirement userInterfaceReq : UserInterfaceReq;

        // Parts
        part controller : ControlProcessor {
            attribute thresholds : AirQualityThresholds;
        }

        part sensorUnit1 : MultiSensorUnit {
            attribute sensorId : String := "SENSOR_01";
        }

        part sensorUnit2 : MultiSensorUnit {
            attribute sensorId : String := "SENSOR_02";
        }

        part sensorUnit3 : MultiSensorUnit {
            attribute sensorId : String := "SENSOR_03";
        }

        part ventilationFan : VentilationFan;

        part airPurifier : AirPurifier {
            attribute purifierId : String := "PURIFIER_01";
            attribute filterStatus : FilterStatus := FilterStatus {
                filterLifeRemaining = 100 [percent],
                needsReplacement = false,
                operatingHours = 0,
                purifierId = "PURIFIER_01"
            };
        }

        part humidityRegulator : HumidityRegulator;

        part userInterface : UserInterface;

        // Connections — sensor data to controller
        connect sensorUnit1.sensorOut to controller.sensorIn1;
        connect sensorUnit2.sensorOut to controller.sensorIn2;
        connect sensorUnit3.sensorOut to controller.sensorIn3;

        // Connections — controller commands to actuators
        connect controller.fanCommandOut to ventilationFan.commandIn;
        connect controller.purifierCommandOut to airPurifier.commandIn;
        connect controller.humidityRegulatorCommandOut to humidityRegulator.commandIn;

        // Connections — status and alerts to user interface
        connect controller.uiStatusOut to userInterface.statusIn;
        connect controller.alertOut to userInterface.alertIn;

        // Connections — filter status feedback to controller
        connect airPurifier.filterStatusOut to controller.filterStatusIn;

        // Requirement satisfactions
        satisfy airQualityMonitoringReq by controller;
        satisfy multiSensorReq by sensorUnit1;
        satisfy multiSensorReq by sensorUnit2;
        satisfy multiSensorReq by sensorUnit3;
        satisfy aqiCalculationReq by controller;
        satisfy adaptiveResponseReq by controller;
        satisfy adaptiveResponseReq by ventilationFan;
        satisfy adaptiveResponseReq by airPurifier;
        satisfy thresholdResponseReq by controller;
        satisfy operatingModesReq by controller;
        satisfy failsafeReq by controller;
        satisfy failsafeReq by ventilationFan;
        satisfy sensorRedundancyReq by sensorUnit1;
        satisfy sensorRedundancyReq by sensorUnit2;
        satisfy sensorRedundancyReq by sensorUnit3;
        satisfy maintenanceAlertReq by controller;
        satisfy maintenanceAlertReq by airPurifier;
        satisfy userInterfaceReq by userInterface;
    }
}
