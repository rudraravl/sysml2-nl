package DigitalSensorSystem {
    import ISQ::*;
    import ScalarValues::*;
    
    value type Voltage :> Real { :>> unit = "V"; }
    value type Frequency :> Real { :>> unit = "Hz"; }
    value type Temperature :> Real { :>> unit = "C"; }
    value type DigitalCount :> Integer;
    
    enum def QualityScore {
        enum excellent;
        enum good;
        enum marginal;
    }
    
    item def AnalogSignal {
        value voltage : Voltage;
    }
    
    item def DigitalSample {
        value count : DigitalCount;
    }
    
    item def ProcessedMeasurement {
        value temperature : Temperature;
        value quality : QualityScore;
    }
    
    item def NetworkMeasurement {
        value sensorId : String;
        value measurement : ProcessedMeasurement;
    }
    
    item def StartMeasurement;
    item def StopMeasurement;
    item def RunCalibration;
    item def ResetFault;
    item def ErrorDetected;
    item def CalibrationComplete;
    
    port def AnalogFlowPort {
        out signal : AnalogSignal;
    }
    
    port def DigitalFlowPort {
        out sample : DigitalSample;
    }
    
    port def ProcessedFlowPort {
        out measurement : ProcessedMeasurement;
    }
    
    port def CommandFlowPort {
        in startCmd : StartMeasurement;
        in stopCmd : StopMeasurement;
        in calibrateCmd : RunCalibration;
        in resetCmd : ResetFault;
    }
    
    port def NetworkInputFlowPort {
        in measurement : NetworkMeasurement;
    }
    
    port def NetworkOutputFlowPort {
        out aggregatedMeasurement : ProcessedMeasurement;
    }
    
    part def SignalConditioner {
        port in rawSignal : AnalogFlowPort;
        port out cleanSignal : AnalogFlowPort;
        
        attribute gain : Real = 5.0;
        attribute cutoffFrequency : Frequency = 1000 [Hz];
        
        action def Condition {
            in signal : AnalogSignal;
            out conditioned : AnalogSignal;
        }
    }
    
    part def AnalogToDigitalConverter {
        port in analogInput : AnalogFlowPort;
        port out digitalOutput : DigitalFlowPort;
        
        attribute samplingRate : Frequency = 10000 [Hz];
        attribute resolution : Integer = 16;
        
        action def Convert {
            in analog : AnalogSignal;
            out digital : DigitalSample;
        }
    }
    
    part def DataProcessor {
        port in digitalInput : DigitalFlowPort;
        port out processedOutput : ProcessedFlowPort;
        
        attribute scaleFactor : Real = 0.01;
        attribute offset : Temperature = -5 [C];
        
        action def Process {
            in sample : DigitalSample;
            out measurement : ProcessedMeasurement;
        }
    }
    
    part def CommunicationInterface {
        port in processedInput : ProcessedFlowPort;
        port out externalOutput : ProcessedFlowPort;
        
        attribute protocol : String = "I2C";
        
        action def Transmit {
            in measurement : ProcessedMeasurement;
        }
    }
    
    part def DigitalSensorUnit {
        port in analogInputPort : AnalogFlowPort;
        port in cmdPort : CommandFlowPort;
        port out dataPort : ProcessedFlowPort;
        
        part signalConditioner : SignalConditioner;
        part adc : AnalogToDigitalConverter;
        part dataProcessor : DataProcessor;
        part commInterface : CommunicationInterface;
        
        connection analogToConditioner connect analogInputPort to signalConditioner.rawSignal;
        connection conditionerToADC connect signalConditioner.cleanSignal to adc.analogInput;
        connection adcToProcessor connect adc.digitalOutput to dataProcessor.digitalInput;
        connection processorToComm connect dataProcessor.processedOutput to commInterface.processedInput;
        connection commToOutput connect commInterface.externalOutput to dataPort;
        
        state machine SensorState {
            entry; then standby;
            
            state standby;
            state active;
            state calibration;
            state fault;
            
            transition standby_to_active first standby then active accept StartMeasurement via cmdPort;
            transition active_to_standby first active then standby accept StopMeasurement via cmdPort;
            transition standby_to_calibration first standby then calibration accept RunCalibration via cmdPort;
            transition calibration_to_standby first calibration then standby accept CalibrationComplete;
            transition standby_to_fault first standby then fault accept ErrorDetected;
            transition active_to_fault first active then fault accept ErrorDetected;
            transition fault_to_standby first fault then standby accept ResetFault via cmdPort;
        }
    }
    
    part def DataCollector {
        port in networkInput : NetworkInputFlowPort;
        port out networkOutput : NetworkOutputFlowPort;
        
        action def Aggregate {
            in measurements : NetworkMeasurement[0..*];
            out aggregated : ProcessedMeasurement;
        }
    }
    
    part def SensorNetwork {
        part collector : DataCollector;
        part sensorUnits : DigitalSensorUnit[1..*];
        
        connection sensorToCollector connect sensorUnits.dataPort to collector.networkInput;
    }
}
