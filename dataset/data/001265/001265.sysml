package StreamGaugeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def WaterLevelValue :> LengthValue;
    attribute def FlowRateValue :> VolumeFlowRateValue;
    attribute def TemperatureValue :> ThermodynamicTemperatureValue;
    attribute def VelocityValue :> SpeedValue;
    attribute def BatteryChargeValue :> Real;
    
    enum def OperationalMode {
        normal;
        lowPower;
        maintenance;
        emergency;
    }
    
    enum def AlertStatus {
        none;
        advisory;
        warning;
        critical;
    }
    
    item def MeasurementRecord {
        attribute timestamp : String;
        attribute waterLevel : WaterLevelValue;
        attribute flowRate : FlowRateValue;
        attribute waterTemp : TemperatureValue;
        attribute velocity : VelocityValue;
    }
    
    port def SensorDataPort {
        out level : WaterLevelValue;
        out temperature : TemperatureValue;
    }
    
    port def ProcessedDataPort {
        out flowRate : FlowRateValue;
        out velocity : VelocityValue;
    }
    
    port def CommunicationPort {
        out transmissionData : MeasurementRecord;
        in configurationCommand : String;
    }
    
    port def PowerSupplyPort {
        out voltage : Real;
        out current : Real;
    }
    
    part def UltrasonicLevelSensor {
        doc /* Measures water surface level using ultrasonic ranging */
        attribute measurementRange : LengthValue[2] = (0.0[m], 15.0[m]);
        attribute accuracy : LengthValue = 0.003[m];
        port sensorOutput : SensorDataPort;
        
        action measureWaterLevel {
            out levelReading : WaterLevelValue;
        }
    }
    
    part def TemperatureSensor {
        doc /* Measures water temperature for flow calculation correction */
        attribute measurementRange : TemperatureValue[2] = (253.15[K], 323.15[K]);
        attribute accuracy : TemperatureValue = 0.5[K];
        port tempOutput : SensorDataPort;
        
        action measureTemperature {
            out tempReading : TemperatureValue;
        }
    }
    
    part def VelocitySensor {
        doc /* Measures water velocity using Doppler or electromagnetic method */
        attribute measurementRange : VelocityValue[2] = (0.0[m/s], 10.0[m/s]);
        attribute accuracy : VelocityValue = 0.01[m/s];
        
        action measureVelocity {
            out velocityReading : VelocityValue;
        }
    }
    
    part def DataProcessor {
        doc /* Processes sensor data and calculates flow rate */
        attribute channelWidth : LengthValue = 5.0[m];
        attribute channelDepth : LengthValue;
        port dataInput : SensorDataPort;
        port dataOutput : ProcessedDataPort;
        
        action calculateFlowRate {
            in waterLevel : WaterLevelValue;
            in velocity : VelocityValue;
            out discharge : FlowRateValue;
        }
        
        action applyRatingCurve {
            in level : WaterLevelValue;
            out estimatedFlow : FlowRateValue;
        }
    }
    
    part def DataLogger {
        doc /* Stores measurement records locally */
        attribute storageCapacity : Real = 50000.0;
        attribute recordCount : Real = 0.0;
        attribute recordingInterval : Real = 900.0;
        
        action storeRecord {
            in record : MeasurementRecord;
            out success : Boolean;
        }
        
        action retrieveRecords {
            in startTime : String;
            in endTime : String;
            out records : MeasurementRecord[*];
        }
    }
    
    part def TelemetryUnit {
        doc /* Transmits data to remote monitoring center */
        attribute transmissionInterval : Real = 900.0;
        attribute signalStrength : Real;
        attribute lastTransmission : String;
        port commPort : CommunicationPort;
        
        action transmitData {
            in data : MeasurementRecord;
            out transmitSuccess : Boolean;
        }
        
        action receiveConfiguration {
            out command : String;
        }
    }
    
    part def PowerSystem {
        doc /* Provides power using solar panel and battery backup */
        attribute batteryCapacity : Real = 100.0;
        attribute batteryCharge : BatteryChargeValue = 85.0;
        attribute solarPanelOutput : Real = 50.0;
        port powerOutput : PowerSupplyPort;
        
        action monitorBattery {
            out chargeLevel : BatteryChargeValue;
            out voltage : Real;
        }
        
        action managePower {
            in currentLoad : Real;
            out mode : OperationalMode;
        }
    }
    
    part def AlertManager {
        doc /* Evaluates conditions and generates flood alerts */
        attribute normalThreshold : WaterLevelValue = 2.5[m];
        attribute advisoryThreshold : WaterLevelValue = 4.0[m];
        attribute warningThreshold : WaterLevelValue = 5.5[m];
        attribute criticalThreshold : WaterLevelValue = 7.0[m];
        attribute currentAlert : AlertStatus = AlertStatus::none;
        
        action evaluateConditions {
            in waterLevel : WaterLevelValue;
            in flowRate : FlowRateValue;
            out alertLevel : AlertStatus;
        }
        
        action issueAlert {
            in level : AlertStatus;
            out notification : String;
        }
    }
    
    action def AcquireSensorData {
        out level : WaterLevelValue;
        out temperature : TemperatureValue;
        out velocity : VelocityValue;
    }
    
    action def ProcessMeasurements {
        in level : WaterLevelValue;
        in temperature : TemperatureValue;
        in velocity : VelocityValue;
        out flowRate : FlowRateValue;
        out record : MeasurementRecord;
    }
    
    action def MonitorAndReport {
        first start;
        then merge monitoringLoop;
        
        then action acquireData : AcquireSensorData {
            out waterLevel : WaterLevelValue;
            out waterTemp : TemperatureValue;
            out waterVelocity : VelocityValue;
        }
        
        then action processMeasurements : ProcessMeasurements {
            in level = acquireData.waterLevel;
            in temperature = acquireData.waterTemp;
            in velocity = acquireData.waterVelocity;
            out discharge : FlowRateValue;
            out dataRecord : MeasurementRecord;
        }
        
        then action logMeasurement {
            in record = processMeasurements.dataRecord;
        }
        
        then action checkAlertConditions {
            in level = acquireData.waterLevel;
            in flow = processMeasurements.discharge;
            out alert : AlertStatus;
        }
        
        then decide;
            if checkAlertConditions.alert != AlertStatus::none then generateAlert;
            else transmitData;
        
        action generateAlert {
            in alertLevel = checkAlertConditions.alert;
        }
        then transmitData;
        
        action transmitData {
            in data = processMeasurements.dataRecord;
        }
        
        then action waitForNextCycle {
            in interval : Real = 900.0;
        }
        
        then monitoringLoop;
    }
    
    part def StreamGauge {
        doc /* Autonomous stream monitoring station for hydrological data collection */
        attribute stationIdentifier : String;
        attribute geographicLocation : String;
        attribute installationDate : String;
        attribute operationalMode : OperationalMode = OperationalMode::normal;
        
        part levelSensor : UltrasonicLevelSensor;
        part tempSensor : TemperatureSensor;
        part velocitySensor : VelocitySensor;
        part processor : DataProcessor;
        part logger : DataLogger;
        part telemetry : TelemetryUnit;
        part power : PowerSystem;
        part alertMgr : AlertManager;
        
        connection sensorToProcessor {
            end source : levelSensor.sensorOutput;
            end sink : processor.dataInput;
        }
        
        connection processorToTelemetry {
            end source : processor.dataOutput;
            end sink : telemetry.commPort;
        }
        
        connection powerDistribution {
            end source : power.powerOutput;
            end sink1 : levelSensor;
            end sink2 : processor;
            end sink3 : telemetry;
        }
        
        perform action continuousMonitoring : MonitorAndReport;
    }
    
    requirement <'REQ-SG-100'> primaryFunction {
        doc /* The stream gauge system shall continuously monitor water level, 
             * flow rate, temperature, and velocity of a stream, and transmit 
             * this hydrological data to a remote monitoring center for flood 
             * forecasting, water resource management, and environmental monitoring.
             */
        subject gauge : StreamGauge;
    }
    
    requirement <'REQ-SG-101'> levelMeasurementAccuracy {
        doc /* The stream gauge shall measure water level with an accuracy 
             * of ±3 mm over the full operational range.
             */
        subject sensor :>> StreamGauge::levelSensor;
        assert constraint {
            sensor.accuracy <= 0.003[m]
        }
    }
    
    requirement <'REQ-SG-102'> dataTransmissionFrequency {
        doc /* The stream gauge shall transmit measurement data at intervals 
             * not exceeding 15 minutes during normal operation.
             */
        subject telemetryUnit :>> StreamGauge::telemetry;
        assert constraint {
            telemetryUnit.transmissionInterval <= 900.0
        }
    }
    
    requirement <'REQ-SG-103'> floodAlertCapability {
        doc /* The stream gauge shall generate and transmit flood alerts when 
             * water level exceeds predefined thresholds corresponding to 
             * advisory, warning, and critical flood stages.
             */
        subject alertSystem :>> StreamGauge::alertMgr;
    }
    
    requirement <'REQ-SG-104'> autonomousOperation {
        doc /* The stream gauge shall operate autonomously for at least 30 days 
             * without maintenance using solar power and battery backup.
             */
        subject powerSys :>> StreamGauge::power;
    }
    
    requirement <'REQ-SG-105'> dataStorageCapacity {
        doc /* The stream gauge shall store at least 50,000 measurement records 
             * locally for data recovery in case of communication failure.
             */
        subject dataLog :>> StreamGauge::logger;
        assert constraint {
            dataLog.storageCapacity >= 50000.0
        }
    }
    
    requirement <'REQ-SG-106'> flowRateCalculation {
        doc /* The stream gauge shall calculate flow rate using measured water 
             * level, velocity, and channel geometry with temperature compensation.
             */
        subject dataProc :>> StreamGauge::processor;
    }
    
    part riverMonitoringStation : StreamGauge {
        attribute :>> stationIdentifier = "USGS-05447500";
        attribute :>> geographicLocation = "Mississippi River at Clinton, Iowa";
        attribute :>> installationDate = "2024-01-15";
        
        part :>> levelSensor {
            attribute :>> accuracy = 0.003[m];
            attribute :>> measurementRange = (0.0[m], 15.0[m]);
        }
        
        part :>> tempSensor {
            attribute :>> accuracy = 0.5[K];
        }
        
        part :>> velocitySensor {
            attribute :>> accuracy = 0.01[m/s];
        }
        
        part :>> processor {
            attribute :>> channelWidth = 280.0[m];
        }
        
        part :>> logger {
            attribute :>> storageCapacity = 75000.0;
            attribute :>> recordingInterval = 900.0;
        }
        
        part :>> telemetry {
            attribute :>> transmissionInterval = 900.0;
        }
        
        part :>> power {
            attribute :>> batteryCapacity = 150.0;
            attribute :>> batteryCharge = 92.0;
        }
        
        part :>> alertMgr {
            attribute :>> normalThreshold = 3.0[m];
            attribute :>> advisoryThreshold = 5.0[m];
            attribute :>> warningThreshold = 7.0[m];
            attribute :>> criticalThreshold = 9.0[m];
        }
    }
    
    satisfy primaryFunction by riverMonitoringStation;
    satisfy levelMeasurementAccuracy by riverMonitoringStation.levelSensor;
    satisfy dataTransmissionFrequency by riverMonitoringStation.telemetry;
    satisfy floodAlertCapability by riverMonitoringStation.alertMgr;
    satisfy autonomousOperation by riverMonitoringStation.power;
    satisfy dataStorageCapacity by riverMonitoringStation.logger;
    satisfy flowRateCalculation by riverMonitoringStation.processor;
}
