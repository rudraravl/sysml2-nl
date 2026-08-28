package EnvironmentalSensingUnit {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def TemperatureValue :> Real;
    attribute def VoltageValue :> Real;
    attribute def TimeValue :> Real;
    
    item def RawSignal {
        attribute signalLevel : VoltageValue;
    }
    item def ProcessedMeasurement {
        attribute temperature : TemperatureValue;
        attribute timestamp : TimeValue;
        attribute isValid : Boolean;
    }
    item def Power;
    
    attribute def ControlSignal;
    attribute def StartSensing :> ControlSignal;
    attribute def StartCalibration :> ControlSignal {
        attribute referenceTemp : TemperatureValue;
    }
    attribute def CalibrationComplete :> ControlSignal;
    attribute def ErrorEvent :> ControlSignal;
    attribute def Reset :> ControlSignal;
    
    port def PowerPort {
        out power : Power;
    }
    port def RawSignalPort {
        out rawSignal : RawSignal;
    }
    port def ProcessedDataPort {
        out measurement : ProcessedMeasurement;
    }
    port def CommandPort {
        in command : ControlSignal;
    }
    
    action def TakeReading;
    action def ProcessReading;
    action def OutputData;
    action def Calibrate;
    action def HandleError;
    
    state def Lifecycle {
        entry; then idle;
        state idle;
        transition t_idle_to_sensing
            first idle
            accept StartSensing
            then sensing;
        state sensing {
            do action takeReading : TakeReading;
        }
        transition t_sensing_to_processing
            first sensing
            then processing;
        state processing {
            do action processReading : ProcessReading;
        }
        transition t_processing_to_outputting
            first processing
            then outputting;
        state outputting {
            do action outputData : OutputData;
        }
        transition t_outputting_to_idle
            first outputting
            then idle;
        
        state calibration {
            do action calibrate : Calibrate;
        }
        transition t_idle_to_calibration
            first idle
            accept StartCalibration
            then calibration;
        transition t_calibration_to_idle
            first calibration
            accept CalibrationComplete
            then idle;
        
        state error {
            do action handleError : HandleError;
        }
        transition t_sensing_to_error
            first sensing
            accept ErrorEvent
            then error;
        transition t_processing_to_error
            first processing
            accept ErrorEvent
            then error;
        transition t_error_to_idle
            first error
            accept Reset
            then idle;
    }
    
    requirement def MeasurementAccuracy {
        doc /* The measurement accuracy shall be ±0.5°C or better. */
        attribute accuracyValue : TemperatureValue = 0.5;
        constraint { accuracyValue <= 0.5 }
    }
    requirement def ResponseTimeReq {
        doc /* The response time shall be under one second. */
        attribute responseTime : TimeValue = 1.0;
        constraint { responseTime < 1.0 }
    }
    requirement def OperationalTempRangeReq {
        doc /* The operational temperature range shall be -40°C to 100°C. */
        attribute minTemp : TemperatureValue = -40.0;
        attribute maxTemp : TemperatureValue = 100.0;
        constraint { minTemp >= -40.0 and maxTemp <= 100.0 }
    }
    
    part def SensingElement {
        port rawOutPort : RawSignalPort;
        port powerInPort : ~PowerPort;
        action senseTemp : TakeReading {
            out raw : RawSignal;
        }
    }
    
    part def SignalProcessor {
        port rawInPort : ~RawSignalPort;
        port processedOutPort : ProcessedDataPort;
        port powerInPort : ~PowerPort;
        action amplify;
        action filterSignal;
        action convertToDigital;
        action validate;
        action processSignal : ProcessReading;
    }
    
    part def PowerManagement {
        port powerInPort : ~PowerPort;
        port powerOutPort : PowerPort;
        attribute regulatedVoltage : VoltageValue = 5.0;
        action regulateVoltage;
    }
    
    part def DataBuffer {
        port bufferInPort : ~ProcessedDataPort;
        port bufferOutPort : ProcessedDataPort;
        port powerInPort : ~PowerPort;
        attribute capacity : Integer = 100;
        action storeData;
        action retrieveData;
    }
    
    part def SensorNode {
        part sensingElement : SensingElement;
        part signalProcessor : SignalProcessor;
        part powerManagement : PowerManagement;
        part dataBuffer : DataBuffer;
        
        port powerPort : ~PowerPort;
        port dataOutPort : ProcessedDataPort;
        
        connect powerPort to powerManagement.powerInPort;
        connect powerManagement.powerOutPort to sensingElement.powerInPort;
        connect powerManagement.powerOutPort to signalProcessor.powerInPort;
        connect powerManagement.powerOutPort to dataBuffer.powerInPort;
        connect sensingElement.rawOutPort to signalProcessor.rawInPort;
        connect signalProcessor.processedOutPort to dataBuffer.bufferInPort;
        connect dataBuffer.bufferOutPort to dataOutPort;
    }
    
    part def PowerSupply {
        port powerInPort : ~PowerPort;
        port powerOutPort : PowerPort;
        attribute outputVoltage : VoltageValue = 24.0;
        action providePower;
    }
    
    part def DataAcquisitionSystem {
        port dataInPort : ~ProcessedDataPort;
        port dataOutPort : ProcessedDataPort;
        action receiveData;
    }
    
    part def Enclosure {
        attribute material : String = "Stainless Steel";
        attribute ipRating : String = "IP67";
        attribute mountingType : String = "Wall-mountable";
    }
    
    part def SensingUnit {
        part sensorNode : SensorNode;
        part powerSupply : PowerSupply;
        part dataAcquisition : DataAcquisitionSystem;
        part enclosure : Enclosure;
        
        port externalPowerPort : ~PowerPort;
        port externalDataPort : ProcessedDataPort;
        port commandPort : CommandPort;
        
        connect externalPowerPort to powerSupply.powerInPort;
        connect powerSupply.powerOutPort to sensorNode.powerPort;
        connect sensorNode.dataOutPort to dataAcquisition.dataInPort;
        connect dataAcquisition.dataOutPort to externalDataPort;
        
        satisfy MeasurementAccuracy;
        satisfy ResponseTimeReq;
        satisfy OperationalTempRangeReq;
        
        exhibit state lifecycle : Lifecycle;
    }
    
    part sensingUnitInst : SensingUnit;
}
