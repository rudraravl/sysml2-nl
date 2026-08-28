package DigitalSensorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    public import Definitions::*;
    
    package Definitions {
        attribute def VoltageValue :> Real;
        attribute def FrequencyValue :> Real;
        attribute def TimeValue :> Real;
        
        item def AnalogSignal {
            attribute voltage : VoltageValue;
            attribute timestamp : TimeValue;
        }
        item def DigitalSample {
            attribute rawValue : Integer;
            attribute timestamp : TimeValue;
        }
        item def CalibratedMeasurement {
            attribute value : Real;
            attribute unit : String;
            attribute quality : String;
            attribute timestamp : TimeValue;
        }
        
        attribute def StartCmd;
        attribute def StopCmd;
        attribute def CalibrateCmd;
        attribute def ResetCmd;
        attribute def ErrorEvent;
        
        port def AnalogInputPort { in signal : AnalogSignal; }
        port def AnalogOutputPort { out signal : AnalogSignal; }
        port def DigitalStreamPort { out sample : DigitalSample; }
        port def ProcessedDataPort { out measurement : CalibratedMeasurement; }
        port def CommandPort {
            in startCmd : StartCmd;
            in stopCmd : StopCmd;
            in calibrateCmd : CalibrateCmd;
            in resetCmd : ResetCmd;
        }
        port def NetworkPort { out measurement : CalibratedMeasurement; }
        
        action def ConditionSignal {
            in rawSignal : AnalogSignal;
            in gain : Real;
            in cutoffFrequency : FrequencyValue;
            out cleanSignal : AnalogSignal;
        }
        action def ConvertSignal {
            in analogSignal : AnalogSignal;
            in resolution : Integer;
            in samplingRate : FrequencyValue;
            out digitalSample : DigitalSample;
        }
        action def ProcessData {
            in sample : DigitalSample;
            in scale : Real;
            in offset : Real;
            out measurement : CalibratedMeasurement;
        }
        action def TransmitData {
            in measurement : CalibratedMeasurement;
        }
        action def AggregateData {
            in measurements : CalibratedMeasurement[*];
            out aggregatedStream : CalibratedMeasurement[*];
        }
        action def MeasurementCycle;
        action def CalibrationRoutine;
        
        part def SignalConditioner {
            port analogIn : AnalogInputPort;
            port analogOut : AnalogOutputPort;
            attribute gain : Real;
            attribute cutoffFrequency : FrequencyValue;
            perform action condition : ConditionSignal {
                in rawSignal = analogIn.signal;
                in gain = gain;
                in cutoffFrequency = cutoffFrequency;
                out cleanSignal = analogOut.signal;
            }
        }
        
        part def ADC {
            port analogIn : AnalogInputPort;
            port digitalOut : DigitalStreamPort;
            attribute resolution : Integer;
            attribute samplingRate : FrequencyValue;
            perform action convert : ConvertSignal {
                in analogSignal = analogIn.signal;
                in resolution = resolution;
                in samplingRate = samplingRate;
                out digitalSample = digitalOut.sample;
            }
        }
        
        part def DataProcessor {
            port digitalIn : DigitalStreamPort;
            port dataOut : ProcessedDataPort;
            attribute scale : Real;
            attribute offset : Real;
            perform action process : ProcessData {
                in sample = digitalIn.sample;
                in scale = scale;
                in offset = offset;
                out measurement = dataOut.measurement;
            }
        }
        
        part def CommunicationInterface {
            port dataIn : ProcessedDataPort;
            port netOut : NetworkPort;
            perform action transmit : TransmitData {
                in measurement = dataIn.measurement;
            }
        }
        
        state def SensorStates {
            in commandPort : CommandPort;
            entry; then standby;
            state standby;
            accept cmd : StartCmd via commandPort then active;
            state active {
                do action measurementCycle : MeasurementCycle;
            }
            accept cmd : StopCmd via commandPort then standby;
            accept cmd : CalibrateCmd via commandPort then calibration;
            state calibration {
                do action calibrationRoutine : CalibrationRoutine;
            }
            accept cmd : StartCmd via commandPort then active;
            accept ErrorEvent then fault;
            state fault;
            accept cmd : ResetCmd via commandPort then standby;
        }
        
        part def DigitalSensorUnit {
            port analogInput : AnalogInputPort;
            port commandInput : CommandPort;
            port networkOutput : NetworkPort;
            
            part conditioner : SignalConditioner;
            part adc : ADC;
            part processor : DataProcessor;
            part comm : CommunicationInterface;
            
            connect analogInput to conditioner.analogIn;
            connect conditioner.analogOut to adc.analogIn;
            connect adc.digitalOut to processor.digitalIn;
            connect processor.dataOut to comm.dataIn;
            connect comm.netOut to networkOutput;
            
            exhibit state sensorStates : SensorStates {
                in commandPort = commandInput;
            }
        }
        
        part def DataCollector {
            port sensorDataIn : NetworkPort[*];
            port aggregatedDataOut : NetworkPort;
            perform action aggregate : AggregateData {
                in measurements = sensorDataIn.measurement;
                out aggregatedStream = aggregatedDataOut.measurement;
            }
        }
        
        part def SensorNetwork {
            part sensors : DigitalSensorUnit[*];
            part collector : DataCollector;
            connect sensors.networkOutput to collector.sensorDataIn;
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part tempSensor : DigitalSensorUnit {
            part redefines conditioner {
                redefines gain = 10.0;
            }
            part redefines adc {
                redefines resolution = 16;
                redefines samplingRate = 2000;
            }
            part redefines processor {
                redefines scale = 0.01;
                redefines offset = -273.15;
            }
        }
        
        part pressureSensor : DigitalSensorUnit {
            part redefines conditioner {
                redefines gain = 5.0;
            }
            part redefines adc {
                redefines resolution = 12;
                redefines samplingRate = 1000;
            }
            part redefines processor {
                redefines scale = 0.1;
                redefines offset = 0.0;
            }
        }
        
        part sensorNetwork : SensorNetwork {
            part sensors : DigitalSensorUnit[2];
        }
    }
    
    package Requirements {
        private import Definitions::*;
        
        requirement def SensorAccuracyReq {
            doc /* The sensor unit shall convert analog signals to digital with a resolution of at least 16 bits. */
            attribute minResolution : Integer = 16;
        }
        requirement def SamplingRateReq {
            doc /* The ADC sampling rate shall be at least 1 kHz. */
            attribute minSamplingRate : FrequencyValue;
        }
        requirement def DataQualityReq {
            doc /* The quality score of transmitted measurements shall be excellent or good. */
        }
        requirement def NetworkSyncReq {
            doc /* All sensor data in the network shall be synchronized to within 1 ms. */
            attribute maxTimeSkew : TimeValue;
        }
        
        requirement sensorAccuracyReq : SensorAccuracyReq {
            attribute minResolution = 16;
        }
        requirement samplingRateReq : SamplingRateReq;
        requirement dataQualityReq : DataQualityReq;
        requirement networkSyncReq : NetworkSyncReq;
    }
}
