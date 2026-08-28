package OzoneMonitoringSystem {
    import ScalarValues::*;
    
    value type OzoneConcentrationValue :> Real {
        unit 'ppb'; 
    }
    
    value type TemperatureValue :> Real {
        unit 'degC';
    }
    
    value type HumidityValue :> Real {
        unit '%';
    }
    
    value type AQIValue :> Real {
        unit 'dimensionless';
    }
    
    value type TimeValue :> Real {
        unit 's';
    }
    
    value type VoltageValue :> Real {
        unit 'V';
    }
    
    enum AirQualityLevel {
        good;
        moderate;
        unhealthy;
        hazardous;
    }
    
    item def RawSensorData {
        attribute ozoneLevel : OzoneConcentrationValue;
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
    }
    
    item def ProcessedData {
        attribute ozoneConcentration : OzoneConcentrationValue;
        attribute aqi : AQIValue;
        attribute airQualityLevel : AirQualityLevel;
    }
    
    port def RawDataOut {
        out rawSensorData : RawSensorData;
    }
    
    port def RawDataIn {
        in rawSensorData : RawSensorData;
    }
    
    port def ProcessedDataOut {
        out processedData : ProcessedData;
    }
    
    port def ProcessedDataIn {
        in processedData : ProcessedData;
    }
    
    port def AlarmTriggerOut {
        out trigger : Boolean;
    }
    
    port def AlarmTriggerIn {
        in trigger : Boolean;
    }
    
    port def PowerOut {
        out voltage : VoltageValue;
    }
    
    port def PowerIn {
        in voltage : VoltageValue;
    }
    
    part def OzoneSensor {
        port powerIn : PowerIn;
        port dataOut : RawDataOut;
        
        attribute samplingRate : TimeValue = 1 ['s'];
        
        action def sampleAir {
            out data : RawSensorData;
        }
        
        perform sampleAir;
    }
    
    part def DataProcessor {
        port powerIn : PowerIn;
        port dataIn : RawDataIn;
        port dataOut : ProcessedDataOut;
        port alarmOut : AlarmTriggerOut;
        
        action def processData {
            in raw : RawSensorData;
            out processed : ProcessedData;
            out triggerAlarm : Boolean;
        }
        
        perform processData;
    }
    
    part def DisplayUnit {
        port powerIn : PowerIn;
        port dataIn : ProcessedDataIn;
        
        action def displayData {
            in data : ProcessedData;
        }
        
        perform displayData;
    }
    
    part def DataLogger {
        port powerIn : PowerIn;
        port dataIn : ProcessedDataIn;
        
        attribute storageCapacity : Integer = 10000;
        
        action def logData {
            in data : ProcessedData;
        }
        
        perform logData;
    }
    
    part def AlarmUnit {
        port powerIn : PowerIn;
        port triggerIn : AlarmTriggerIn;
        
        action def soundAlarm {
            in trigger : Boolean;
        }
        
        perform soundAlarm;
    }
    
    part def PowerModule {
        port powerOut : PowerOut;
        
        attribute inputVoltage : VoltageValue = 12.0 ['V'];
        attribute outputVoltage : VoltageValue = 5.0 ['V'];
    }
    
    part def OzoneMonitoringSystem {
        attribute isPowered : Boolean;
        attribute hasNewData : Boolean;
        attribute isProcessed : Boolean;
        attribute isHazardous : Boolean;
        
        part powerModule : PowerModule;
        part ozoneSensor : OzoneSensor;
        part dataProcessor : DataProcessor;
        part displayUnit : DisplayUnit;
        part dataLogger : DataLogger;
        part alarmUnit : AlarmUnit;
        
        connection power1 connect powerModule.powerOut to ozoneSensor.powerIn;
        connection power2 connect powerModule.powerOut to dataProcessor.powerIn;
        connection power3 connect powerModule.powerOut to displayUnit.powerIn;
        connection power4 connect powerModule.powerOut to dataLogger.powerIn;
        connection power5 connect powerModule.powerOut to alarmUnit.powerIn;
        
        connection data1 connect ozoneSensor.dataOut to dataProcessor.dataIn;
        connection data2 connect dataProcessor.dataOut to displayUnit.dataIn;
        connection data3 connect dataProcessor.dataOut to dataLogger.dataIn;
        connection alarm1 connect dataProcessor.alarmOut to alarmUnit.triggerIn;
        
        state def SystemStates {
            state idle;
            state measuring;
            state processing;
            state displaying;
            state alarming;
            
            transition t1 first idle then measuring when isPowered;
            transition t2 first measuring then processing when hasNewData;
            transition t3 first processing then displaying when isProcessed;
            transition t4 first displaying then alarming when isHazardous;
            transition t5 first displaying then idle when !isHazardous;
            transition t6 first alarming then idle when !isHazardous;
        }
        
        exhibit SystemStates;
    }
    
    requirement def MonitorOzone {
        subject : OzoneMonitoringSystem;
        objective {
            doc "The system shall continuously measure ozone concentration in the air.";
        }
    }
    
    requirement def CalculateAQI {
        subject : OzoneMonitoringSystem;
        objective {
            doc "The system shall calculate the corresponding Air Quality Index (AQI).";
        }
    }
    
    requirement def AlertHazardous {
        subject : OzoneMonitoringSystem;
        objective {
            doc "The system shall alert users to potentially hazardous conditions.";
        }
    }
    
    requirement def ProtectPublicHealth {
        subject : OzoneMonitoringSystem;
        objective {
            doc "The system shall protect public health by providing real-time air quality information.";
        }
    }
}
