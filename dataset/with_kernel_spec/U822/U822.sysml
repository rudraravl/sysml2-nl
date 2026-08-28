package PiezometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        attribute def PressureValue :> Real;
        attribute def TemperatureValue :> Real;
        attribute def DepthValue :> Real;
        attribute def Timestamp :> String;
        
        item def RawSignal {
            attribute voltage : Real;
        }
        item def DigitalValue {
            attribute bits : Integer;
        }
        item def CalibrationCoefficients {
            attribute offset : Real;
            attribute scale : Real;
            attribute tempComp : Real;
        }
        item def DataRecord {
            attribute pressure : PressureValue;
            attribute temperature : TemperatureValue;
            attribute depth : DepthValue;
            attribute timestamp : Timestamp;
        }
        
        attribute def WakeUpSignal;
        attribute def SleepSignal;
        attribute def CalibrationStartSignal;
        attribute def CalibrationEndSignal;
        attribute def LowBatterySignal;
        attribute def MeasurementDoneSignal;
        attribute def TransmissionDoneSignal;
        
        action def 'Sense Pressure and Temperature' {
            out pressure : PressureValue;
            out temperature : TemperatureValue;
            out rawSignal : RawSignal;
        }
        action def 'Condition Signal' {
            in rawSignal : RawSignal;
            out conditionedSignal : RawSignal;
        }
        action def 'Convert to Digital' {
            in conditionedSignal : RawSignal;
            out digitalValue : DigitalValue;
        }
        action def 'Calibrate and Package' {
            in digitalValue : DigitalValue;
            in temperature : TemperatureValue;
            in coefficients : CalibrationCoefficients;
            in depth : DepthValue;
            out dataRecord : DataRecord;
        }
        action def 'Store Data' {
            in dataRecord : DataRecord;
        }
        action def 'Transmit Data' {
            in dataRecord : DataRecord;
        }
        action def 'Measurement Sequence' {
            action sense : 'Sense Pressure and Temperature';
            action condition : 'Condition Signal';
            action convert : 'Convert to Digital';
            action calibrate : 'Calibrate and Package';
            action store : 'Store Data';
            
            first sense;
            then condition;
            then convert;
            then calibrate;
            then store;
            then done;
        }
        
        state def 'Piezometer States';
        
        part def Battery {
            attribute chargeLevel : Real;
            port powerOut {
                out voltage : Real;
            }
        }
        part def PressureTransducer {
            port fluidContact;
            port signalOut {
                out rawSignal : RawSignal;
                out temperature : TemperatureValue;
            }
            perform action 'sense': 'Sense Pressure and Temperature';
        }
        part def SignalConditioner {
            port signalIn {
                in rawSignal : RawSignal;
            }
            port signalOut {
                out conditionedSignal : RawSignal;
            }
            perform action 'condition': 'Condition Signal';
        }
        part def ADC {
            port analogIn {
                in conditionedSignal : RawSignal;
            }
            port digitalOut {
                out digitalValue : DigitalValue;
            }
            perform action 'convert': 'Convert to Digital';
        }
        part def Microprocessor {
            port digitalIn {
                in digitalValue : DigitalValue;
            }
            port tempIn {
                in temperature : TemperatureValue;
            }
            port dataOut {
                out dataRecord : DataRecord;
            }
            attribute coefficients : CalibrationCoefficients;
            attribute depth : DepthValue;
            perform action 'calibrate': 'Calibrate and Package';
            perform action 'measure': 'Measurement Sequence';
            exhibit state 'processor states': 'Piezometer States';
        }
        part def MemoryModule {
            port dataIn {
                in dataRecord : DataRecord;
            }
            perform action 'store': 'Store Data';
        }
        part def CommunicationModule {
            port dataIn {
                in dataRecord : DataRecord;
            }
            port antenna;
            perform action 'transmit': 'Transmit Data';
        }
        
        part def Piezometer {
            attribute depth : DepthValue;
            part battery : Battery;
            part transducer : PressureTransducer;
            part conditioner : SignalConditioner;
            part adc : ADC;
            part processor : Microprocessor;
            part memory : MemoryModule;
            part comm : CommunicationModule;
            
            connection transducerToConditioner connect transducer.signalOut to conditioner.signalIn;
            connection conditionerToADC connect conditioner.signalOut to adc.analogIn;
            connection adcToProcessor connect adc.digitalOut to processor.digitalIn;
            connection tempToProcessor connect transducer.signalOut to processor.tempIn;
            connection processorToMemory connect processor.dataOut to memory.dataIn;
            connection processorToComm connect processor.dataOut to comm.dataIn;
            
            exhibit state 'piezometer states': 'Piezometer States';
        }
        
        requirement def 'Monitor Pore Pressure' {
            subject piezometer : Piezometer;
            doc /* The piezometer shall measure pore water pressure within soil or rock. */
        }
        requirement def 'Long Term Autonomy' {
            subject piezometer : Piezometer;
            doc /* The system shall operate autonomously for extended deployment periods. */
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        action 'measure': 'Measurement Sequence';
        action 'transmit': 'Transmit Data';
        
        part piezometerSystem : Piezometer;
        
        requirement 'req1': 'Monitor Pore Pressure' {
            subject piezometer : piezometerSystem;
        }
        requirement 'req2': 'Long Term Autonomy' {
            subject piezometer : piezometerSystem;
        }
        
        state 'piezometer states': 'Piezometer States' {
            entry; then standby;
            state standby;
            accept WakeUpSignal then activeMeasurement;
            accept LowBatterySignal then lowPower;
            
            state activeMeasurement {
                do 'measure';
            }
            accept MeasurementDoneSignal then dataTransmission;
            
            state dataTransmission {
                do 'transmit';
            }
            accept TransmissionDoneSignal then standby;
            accept SleepSignal then standby;
            
            state lowPower;
            accept WakeUpSignal then standby;
            
            state calibrationMode;
            accept CalibrationStartSignal then calibrationMode;
            accept CalibrationEndSignal then standby;
        }
    }
}
