package InfraredSensingUnit {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def Voltage :> Real {
        @unit = "V";
    }
    
    item def IRRadiation {
        attribute power : PowerValue;
    }
    
    item def FocusedIR {
        attribute intensity : PowerValue;
    }
    
    item def RawVoltage {
        attribute value : Voltage;
    }
    
    item def ConditionedSignal {
        attribute value : Voltage;
    }
    
    item def DigitalSample {
        attribute count : Integer;
    }
    
    item def TemperatureReading {
        attribute value : TemperatureValue;
        attribute uncertainty : TemperatureValue;
    }
    
    item def EmissivitySetting {
        attribute factor : Real;
    }
    
    item def CalibrationData;
    
    item def PowerOn;
    item def StartMeasurement;
    item def StopMeasurement;
    item def CalibrateCommand;
    item def CalibrateComplete;
    item def FaultOccurrence;
    item def FaultClear;
    
    action def warmUpSequence;
    action def performMeasurement;
    action def performCalibration;
    action def reportFault;
    
    part def OpticalSystem {
        in item incomingRadiation : IRRadiation;
        out item focusedRadiation : FocusedIR;
        attribute fieldOfView : Real = 5.0;
    }
    
    part def IRDetector {
        in item focusedRadiation : FocusedIR;
        out item rawVoltage : RawVoltage;
        attribute spectralRange : String = "8-14 um";
        attribute stabilizationTime : TimeValue = 5 [s];
    }
    
    part def SignalConditioner {
        in item rawVoltage : RawVoltage;
        out item conditionedSignal : ConditionedSignal;
        attribute gain : Real = 1000.0;
        attribute offsetCorrection : Voltage = 0.005;
        attribute noiseFloor : Voltage = 0.001;
    }
    
    part def ADC {
        in item conditionedSignal : ConditionedSignal;
        out item digitalValue : DigitalSample;
        attribute resolution : Integer = 16;
        attribute samplingRate : Real = 100.0;
    }
    
    part def TemperatureProcessor {
        in item digitalValue : DigitalSample;
        in item ambientTemperature : TemperatureValue;
        in item emissivity : EmissivitySetting;
        in item calibration : CalibrationData;
        out item temperature : TemperatureReading;
        attribute defaultEmissivity : Real = 0.95;
    }
    
    part def IRThermometer {
        in item targetRadiation : IRRadiation;
        out item measuredTemperature : TemperatureReading;
        
        part opticalSystem : OpticalSystem;
        part detector : IRDetector;
        part conditioner : SignalConditioner;
        part adc : ADC;
        part processor : TemperatureProcessor;
        
        flow targetRadiation to opticalSystem.incomingRadiation;
        flow opticalSystem.focusedRadiation to detector.focusedRadiation;
        flow detector.rawVoltage to conditioner.rawVoltage;
        flow conditioner.conditionedSignal to adc.conditionedSignal;
        flow adc.digitalValue to processor.digitalValue;
        flow processor.temperature to measuredTemperature;
        
        attribute responseTime : TimeValue = 0.05 [s];
        
        state operationalState {
            entry; then standby;
            
            state standby;
            state warmUp {
                do action warmUpSequence;
            }
            state ready;
            state continuousMeasurement {
                do action performMeasurement;
            }
            state calibration {
                do action performCalibration;
            }
            state faultState {
                do action reportFault;
            }
            
            transition first standby accept PowerOn then warmUp;
            transition first warmUp then ready;
            transition first ready accept StartMeasurement then continuousMeasurement;
            transition first continuousMeasurement accept StopMeasurement then ready;
            transition first ready accept CalibrateCommand then calibration;
            transition first calibration accept CalibrateComplete then ready;
            transition first continuousMeasurement accept FaultOccurrence then faultState;
            transition first faultState accept FaultClear then standby;
        }
    }
    
    requirement HighAccuracy {
        subject reading : TemperatureReading;
        constraint { reading.uncertainty <= 0.5 [K] }
    }
    
    requirement MeasurementRange {
        subject reading : TemperatureReading;
        constraint { reading.value >= 233.15 [K] and reading.value <= 773.15 [K] }
    }
    
    requirement FastResponse {
        subject thermometer : IRThermometer;
        constraint { thermometer.responseTime <= 0.1 [s] }
    }
}
