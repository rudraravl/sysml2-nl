package SmartLabsSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TemperatureReading :> Real {
        attribute timestamp : Real;
        attribute sensorId : String;
        attribute accuracy : Real;
    }
    
    attribute def HumidityReading :> Real {
        attribute timestamp : Real;
        attribute sensorId : String;
        attribute percentValue : Real;
    }
    
    attribute def AirQualityReading {
        attribute co2Level : Real;
        attribute vocLevel : Real;
        attribute particulateMatter : Real;
        attribute timestamp : Real;
        attribute sensorId : String;
    }
    
    attribute def PressureReading :> Real {
        attribute timestamp : Real;
        attribute sensorId : String;
    }
    
    attribute def EnvironmentalConditions {
        attribute temperature : TemperatureReading;
        attribute humidity : HumidityReading;
        attribute airQuality : AirQualityReading;
        attribute pressure : PressureReading;
    }
    
    attribute def ControlSetpoint {
        attribute targetTemperature : Real;
        attribute targetHumidity : Real;
        attribute targetPressure : Real;
        attribute ventilationRate : Real;
        attribute timestamp : Real;
    }
    
    item def SensorData;
    item def ControlSignal;
    item def AlertMessage;
    item def ExperimentProtocol;
    item def SampleData;
    item def StartCommand;
    item def EmergencyResolved;
    item def ExperimentComplete;
    
    port def EnvironmentalSensorPort {
        out item sensorData : SensorData;
    }
    
    port def ControlActuatorPort {
        in item controlSignal : ControlSignal;
    }
    
    port def DataProcessingPort {
        in item rawData : SensorData;
        out item processedData : ControlSignal;
    }
    
    port def UserInterfacePort {
        in item statusData : SensorData;
        out item userCommand : ControlSignal;
        out item notification : AlertMessage;
    }
    
    port def ExperimentPort {
        in item protocol : ExperimentProtocol;
        out item results : SampleData;
    }
    
    part def TemperatureSensor {
        port sensorPort : EnvironmentalSensorPort;
        attribute currentReading : TemperatureReading;
        attribute calibrationOffset : Real = 0.0;
        attribute minRange : Real = 253.15;
        attribute maxRange : Real = 373.15;
        
        action measureTemperature {
            out reading : TemperatureReading;
        }
    }
    
    part def HumiditySensor {
        port sensorPort : EnvironmentalSensorPort;
        attribute currentReading : HumidityReading;
        attribute calibrationFactor : Real = 1.0;
        attribute minRange : Real = 0.0;
        attribute maxRange : Real = 100.0;
        
        action measureHumidity {
            out reading : HumidityReading;
        }
    }
    
    part def AirQualitySensor {
        port sensorPort : EnvironmentalSensorPort;
        attribute currentReading : AirQualityReading;
        attribute co2Threshold : Real = 1000.0;
        attribute vocThreshold : Real = 500.0;
        
        action measureAirQuality {
            out reading : AirQualityReading;
        }
    }
    
    part def PressureSensor {
        port sensorPort : EnvironmentalSensorPort;
        attribute currentReading : PressureReading;
        attribute minRange : Real = 80000.0;
        attribute maxRange : Real = 110000.0;
        
        action measurePressure {
            out reading : PressureReading;
        }
    }
    
    part def HVACController {
        port actuatorPort : ControlActuatorPort;
        attribute currentSetpoint : Real = 293.15;
        attribute operatingMode : String = "auto";
        attribute heatingCapacity : Real = 5000.0;
        attribute coolingCapacity : Real = 7000.0;
        
        action adjustTemperature {
            in targetTemp : Real;
            out commandSent : Boolean;
        }
        
        action adjustVentilation {
            in ventilationRate : Real;
            out commandSent : Boolean;
        }
    }
    
    part def HumidityController {
        port actuatorPort : ControlActuatorPort;
        attribute currentHumiditySetpoint : Real = 50.0;
        attribute humidificationCapacity : Real = 0.5;
        attribute dehumidificationCapacity : Real = 0.7;
        
        action adjustHumidity {
            in targetHumidity : Real;
            out commandSent : Boolean;
        }
    }
    
    part def PressureController {
        port actuatorPort : ControlActuatorPort;
        attribute currentPressureSetpoint : Real = 101325.0;
        attribute controlMode : String = "differential";
        
        action adjustPressure {
            in targetPressure : Real;
            out commandSent : Boolean;
        }
    }
    
    part def DataProcessor {
        port processingPort : DataProcessingPort;
        attribute historicalData : EnvironmentalConditions[*];
        attribute analysisInterval : Real = 60.0;
        attribute dataRetentionPeriod : Real = 2592000.0;
        
        action processEnvironmentalData {
            in sensorData : EnvironmentalConditions;
            out controlCommands : ControlSetpoint;
        }
        
        action detectAnomalies {
            in currentData : EnvironmentalConditions;
            out anomalyDetected : Boolean;
            out alertMessage : AlertMessage;
        }
        
        action optimizeConditions {
            in historicalTrends : EnvironmentalConditions[*];
            in experimentRequirements : ExperimentProtocol;
            out optimalSetpoint : ControlSetpoint;
        }
    }
    
    part def UserInterface {
        port uiPort : UserInterfacePort;
        attribute displayedData : EnvironmentalConditions;
        attribute userPreferences : ControlSetpoint;
        attribute accessLevel : Integer = 1;
        
        action displayStatus {
            in environmentalStatus : EnvironmentalConditions;
        }
        
        action receiveUserInput {
            out userSettings : ControlSetpoint;
        }
        
        action sendAlert {
            in alertData : AlertMessage;
        }
    }
    
    part def ExperimentManager {
        port experimentPort : ExperimentPort;
        attribute activeProtocols : ExperimentProtocol[*];
        attribute experimentQueue : ExperimentProtocol[*];
        
        action scheduleExperiment {
            in protocol : ExperimentProtocol;
            out scheduled : Boolean;
        }
        
        action executeExperiment {
            in protocol : ExperimentProtocol;
            out results : SampleData;
        }
        
        action validateConditions {
            in currentConditions : EnvironmentalConditions;
            in requiredConditions : ControlSetpoint;
            out conditionsMet : Boolean;
        }
    }
    
    action def MonitorEnvironment {
        in samplingInterval : Real;
        out environmentalReadings : EnvironmentalConditions[*];
        
        first start;
        then action collectTemperature {
            out tempReading : TemperatureReading;
        }
        then action collectHumidity {
            out humidityReading : HumidityReading;
        }
        then action collectAirQuality {
            out airQualityReading : AirQualityReading;
        }
        then action collectPressure {
            out pressureReading : PressureReading;
        }
        then action aggregateReadings {
            in temp : TemperatureReading = collectTemperature.tempReading;
            in humidity : HumidityReading = collectHumidity.humidityReading;
            in airQuality : AirQualityReading = collectAirQuality.airQualityReading;
            in pressure : PressureReading = collectPressure.pressureReading;
            out conditions : EnvironmentalConditions;
        }
        then done;
    }
    
    action def AnalyzeAndControl {
        in readings : EnvironmentalConditions[*];
        in targetSetpoint : ControlSetpoint;
        out controlActions : ControlSetpoint;
        
        first start;
        then action analyzeData {
            in currentReadings : EnvironmentalConditions[*] = readings;
            out deviations : Real[*];
            out anomalies : Boolean;
        }
        then decide;
            if analyzeData.anomalies then generateAlert;
            if not analyzeData.anomalies then computeControl;
        
        action generateAlert {
            in anomalyData : Boolean = analyzeData.anomalies;
            out alert : AlertMessage;
        }
        then computeControl;
        
        action computeControl {
            in deviations : Real[*] = analyzeData.deviations;
            in target : ControlSetpoint = targetSetpoint;
            out commands : ControlSetpoint;
        }
        then done;
    }
    
    action def SmartLabsOperation {
        first start;
        then merge monitoringLoop;
        
        action monitor : MonitorEnvironment {
            in samplingInterval = 30.0;
            out environmentalReadings;
        }
        
        then action analyze : AnalyzeAndControl {
            in readings = monitor.environmentalReadings;
            in targetSetpoint;
            out controlActions;
        }
        
        then decide;
            if analyze.controlActions != null then applyControl;
            if analyze.controlActions == null then monitoringLoop;
        
        action applyControl {
            in commands : ControlSetpoint = analyze.controlActions;
            out applied : Boolean;
        }
        
        then monitoringLoop;
    }
    
    state def LabEnvironmentState {
        entry action initializeSystems;
        do action continuousMonitoring;
        exit action shutdownSystems;
        
        state idle {
            entry action setIdleMode;
        }
        
        state conditioning {
            entry action startConditioning;
            do action maintainConditions;
        }
        
        state optimal {
            entry action logOptimalState;
            do action monitorStability;
        }
        
        state suboptimal {
            entry action raiseWarning;
            do action attemptCorrection;
        }
        
        state critical {
            entry action triggerAlarm;
            do action emergencyResponse;
        }
        
        state experimentRunning {
            entry action lockConditions;
            do action monitorExperiment;
        }
        
        transition idleToConditioning
            first idle
            accept startCmd : StartCommand
            then conditioning;
        
        transition conditioningToOptimal
            first conditioning
            accept conditionsAchieved : EnvironmentalConditions
            then optimal;
        
        transition optimalToExperimentRunning
            first optimal
            accept experimentStart : ExperimentProtocol
            then experimentRunning;
        
        transition optimalToSuboptimal
            first optimal
            accept deviationDetected : EnvironmentalConditions
            then suboptimal;
        
        transition suboptimalToOptimal
            first suboptimal
            accept correctionApplied : ControlSetpoint
            then optimal;
        
        transition suboptimalToCritical
            first suboptimal
            accept criticalDeviation : AirQualityReading
            then critical;
        
        transition criticalToConditioning
            first critical
            accept emergencyOk : EmergencyResolved
            then conditioning;
        
        transition experimentRunningToOptimal
            first experimentRunning
            accept experimentDone : ExperimentComplete
            then optimal;
    }
    
    requirement def TemperatureControlRequirement {
        doc /* Temperature control requirement for laboratory environment. */
        attribute minTemperature : Real = 291.15;
        attribute maxTemperature : Real = 297.15;
        attribute accuracy : Real = 0.5;
        attribute responseTime : Real = 300.0;
    }
    
    requirement def HumidityControlRequirement {
        doc /* Humidity control requirement for laboratory environment. */
        attribute minHumidity : Real = 30.0;
        attribute maxHumidity : Real = 70.0;
        attribute accuracy : Real = 5.0;
    }
    
    requirement def AirQualityControlRequirement {
        doc /* Air quality control requirement for laboratory environment. */
        attribute maxCO2Level : Real = 800.0;
        attribute maxVOCLevel : Real = 500.0;
        attribute maxParticulateMatter : Real = 50.0;
    }
    
    requirement def PressureControlRequirement {
        doc /* Pressure control requirement for laboratory environment. */
        attribute minPressure : Real = 95000.0;
        attribute maxPressure : Real = 105000.0;
        attribute differentialPressure : Real = 10.0;
    }
    
    requirement def ResponseTimeRequirement {
        doc /* Response time requirement for environmental control. */
        attribute maxDetectionTime : Real = 60.0;
        attribute maxResponseTime : Real = 120.0;
    }
    
    requirement def DataLoggingRequirement {
        doc /* Data logging requirement for environmental monitoring. */
        attribute loggingInterval : Real = 60.0;
        attribute retentionPeriod : Real = 2592000.0;
    }
    
    requirement def SafetyComplianceRequirement {
        doc /* Safety compliance requirement for laboratory operations. */
        attribute emergencyShutdownTime : Real = 30.0;
        attribute redundancyLevel : Integer = 2;
    }
    
    part def SmartLabsSystem {
        part tempSensor : TemperatureSensor;
        part humiditySensor : HumiditySensor;
        part airQualitySensor : AirQualitySensor;
        part pressureSensor : PressureSensor;
        part hvacController : HVACController;
        part humidityController : HumidityController;
        part pressureController : PressureController;
        part dataProcessor : DataProcessor;
        part userInterface : UserInterface;
        part experimentManager : ExperimentManager;
    }
    
    requirement def SmartLabsSystemRequirement {
        doc /* The SmartLabs system shall provide automated environmental control and monitoring 
               for laboratory facilities to ensure optimal conditions for scientific research and experiments. */
        
        subject smartLabsSystem : SmartLabsSystem;
        
        require temperatureControl : TemperatureControlRequirement;
        require humidityControl : HumidityControlRequirement;
        require airQualityControl : AirQualityControlRequirement;
        require pressureControl : PressureControlRequirement;
        require responseTime : ResponseTimeRequirement;
        require dataLogging : DataLoggingRequirement;
        require safetyCompliance : SafetyComplianceRequirement;
    }
    
    requirement <'REQ-001'> temperatureControl : TemperatureControlRequirement {
        doc /* The system shall maintain laboratory temperature between 18°C and 24°C 
               with an accuracy of ±0.5°C under all operating conditions. */
        
        attribute minTemperature : Real = 291.15;
        attribute maxTemperature : Real = 297.15;
        attribute accuracy : Real = 0.5;
        attribute responseTime : Real = 300.0;
    }
    
    requirement <'REQ-002'> humidityControl : HumidityControlRequirement {
        doc /* The system shall maintain relative humidity between 30% and 70% 
               with an accuracy of ±5% to prevent condensation and static buildup. */
        
        attribute minHumidity : Real = 30.0;
        attribute maxHumidity : Real = 70.0;
        attribute accuracy : Real = 5.0;
    }
    
    requirement <'REQ-003'> airQualityControl : AirQualityControlRequirement {
        doc /* The system shall maintain CO2 levels below 800 ppm and VOC levels below 500 ppb,
               activating ventilation when thresholds are exceeded. */
        
        attribute maxCO2Level : Real = 800.0;
        attribute maxVOCLevel : Real = 500.0;
        attribute maxParticulateMatter : Real = 50.0;
    }
    
    requirement <'REQ-004'> pressureControl : PressureControlRequirement {
        doc /* The system shall maintain differential pressure between laboratory zones
               to prevent cross-contamination. */
        
        attribute minPressure : Real = 95000.0;
        attribute maxPressure : Real = 105000.0;
        attribute differentialPressure : Real = 10.0;
    }
    
    requirement <'REQ-005'> responseTime : ResponseTimeRequirement {
        doc /* The system shall detect environmental deviations and initiate corrective actions
               within 2 minutes of detection. */
        
        attribute maxDetectionTime : Real = 60.0;
        attribute maxResponseTime : Real = 120.0;
    }
    
    requirement <'REQ-006'> dataLogging : DataLoggingRequirement {
        doc /* The system shall log all environmental data at 1-minute intervals
               and retain data for at least 30 days. */
        
        attribute loggingInterval : Real = 60.0;
        attribute retentionPeriod : Real = 2592000.0;
    }
    
    requirement <'REQ-007'> safetyCompliance : SafetyComplianceRequirement {
        doc /* The system shall comply with laboratory safety standards and provide
               fail-safe operation in case of system failures. */
        
        attribute emergencyShutdownTime : Real = 30.0;
        attribute redundancyLevel : Integer = 2;
    }
    
    part smartLabsSystem : SmartLabsSystem {
        part tempSensor : TemperatureSensor {
            perform labOperation.monitor.collectTemperature;
        }
        
        part humiditySensor : HumiditySensor {
            perform labOperation.monitor.collectHumidity;
        }
        
        part airQualitySensor : AirQualitySensor {
            perform labOperation.monitor.collectAirQuality;
        }
        
        part pressureSensor : PressureSensor {
            perform labOperation.monitor.collectPressure;
        }
        
        part hvacController : HVACController {
            perform labOperation.applyControl;
        }
        
        part humidityController : HumidityController {
            perform labOperation.applyControl;
        }
        
        part pressureController : PressureController {
            perform labOperation.applyControl;
        }
        
        part dataProcessor : DataProcessor {
            perform labOperation.analyze;
        }
        
        part userInterface : UserInterface;
        
        part experimentManager : ExperimentManager;
        
        perform action labOperation : SmartLabsOperation;
        
        exhibit state environmentState : LabEnvironmentState;
        
        connection tempSensorToProcessor connect 
            tempSensor.sensorPort.sensorData to dataProcessor.processingPort.rawData;
        
        connection humiditySensorToProcessor connect 
            humiditySensor.sensorPort.sensorData to dataProcessor.processingPort.rawData;
        
        connection airQualitySensorToProcessor connect 
            airQualitySensor.sensorPort.sensorData to dataProcessor.processingPort.rawData;
        
        connection pressureSensorToProcessor connect 
            pressureSensor.sensorPort.sensorData to dataProcessor.processingPort.rawData;
        
        connection processorToHVAC connect 
            dataProcessor.processingPort.processedData to hvacController.actuatorPort.controlSignal;
        
        connection processorToHumidity connect 
            dataProcessor.processingPort.processedData to humidityController.actuatorPort.controlSignal;
        
        connection processorToPressure connect 
            dataProcessor.processingPort.processedData to pressureController.actuatorPort.controlSignal;
        
        connection processorToUI connect 
            dataProcessor.processingPort.rawData to userInterface.uiPort.statusData;
        
        connection uiToProcessor connect 
            userInterface.uiPort.userCommand to dataProcessor.processingPort.rawData;
        
        connection processorToExperiment connect 
            dataProcessor.processingPort.rawData to experimentManager.experimentPort.protocol;
        
        satisfy temperatureControl;
        satisfy humidityControl;
        satisfy airQualityControl;
        satisfy pressureControl;
        satisfy responseTime;
        satisfy dataLogging;
        satisfy safetyCompliance;
    }
    
    occurrence def SmartLabsOperationalScenario {
        ref part lab :>> smartLabsSystem;
        
        message tempDataMessage of SensorData
            from lab.tempSensor.sensorPort.sensorData to lab.dataProcessor.processingPort.rawData;
        
        then message humidityDataMessage of SensorData
            from lab.humiditySensor.sensorPort.sensorData to lab.dataProcessor.processingPort.rawData;
        
        then message airQualityDataMessage of SensorData
            from lab.airQualitySensor.sensorPort.sensorData to lab.dataProcessor.processingPort.rawData;
        
        then message pressureDataMessage of SensorData
            from lab.pressureSensor.sensorPort.sensorData to lab.dataProcessor.processingPort.rawData;
        
        then message hvacControlMessage of ControlSignal
            from lab.dataProcessor.processingPort.processedData to lab.hvacController.actuatorPort.controlSignal;
        
        then message humidityControlMessage of ControlSignal
            from lab.dataProcessor.processingPort.processedData to lab.humidityController.actuatorPort.controlSignal;
        
        then message pressureControlMessage of ControlSignal
            from lab.dataProcessor.processingPort.processedData to lab.pressureController.actuatorPort.controlSignal;
        
        then message statusUpdateMessage of SensorData
            from lab.dataProcessor.processingPort.rawData to lab.userInterface.uiPort.statusData;
    }
}
