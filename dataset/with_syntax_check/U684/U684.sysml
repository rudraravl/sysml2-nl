package ForceGaugeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def CalibrationFactor :> Real;
    attribute def SensorSensitivity :> Real;
    
    item def ForceReading {
        attribute magnitude : ForceValue;
        attribute timestamp : Real;
        attribute isValid : Boolean;
    }
    
    item def CalibrationCommand {
        attribute referenceForce : ForceValue;
        attribute executeCalibration : Boolean;
    }
    
    port def ForceInputPort {
        in item appliedForce : ForceValue;
    }
    
    port def MeasurementOutputPort {
        out item reading : ForceReading;
    }
    
    port def CalibrationPort {
        in item calibrationCmd : CalibrationCommand;
        out item calibrationStatus : Boolean;
    }
    
    part def StrainGaugeSensor {
        attribute sensitivity : SensorSensitivity = 2.0;
        attribute maxLoad : ForceValue = 5000.0 [N];
        
        port forceIn : ForceInputPort;
        port voltageOut {
            out attribute voltage : ISQ::VoltageValue;
        }
        
        action senseForce {
            in appliedForce : ForceValue;
            out outputVoltage : ISQ::VoltageValue;
        }
    }
    
    part def SignalAmplifier {
        attribute gain : Real = 100.0;
        attribute bandwidth : FrequencyValue = 1000.0 [Hz];
        
        port voltageIn {
            in attribute inputVoltage : ISQ::VoltageValue;
        }
        port voltageOut {
            out attribute amplifiedVoltage : ISQ::VoltageValue;
        }
        
        action amplifySignal {
            in inputSignal : ISQ::VoltageValue;
            out amplifiedSignal : ISQ::VoltageValue;
        }
    }
    
    part def AnalogDigitalConverter {
        attribute resolution : Integer = 16;
        attribute samplingRate : FrequencyValue = 1000.0 [Hz];
        attribute referenceVoltage : ISQ::VoltageValue = 5.0 [V];
        
        port analogIn {
            in attribute analogVoltage : ISQ::VoltageValue;
        }
        port digitalOut {
            out attribute digitalValue : Real;
        }
        
        action convertToDigital {
            in analogInput : ISQ::VoltageValue;
            out digitalOutput : Real;
        }
    }
    
    part def MicroprocessorUnit {
        attribute calibrationFactor : CalibrationFactor = 1.0;
        attribute zeroOffset : Real = 0.0;
        
        port digitalIn {
            in attribute rawValue : Real;
        }
        port calibrationPort : CalibrationPort;
        port measurementOut : MeasurementOutputPort;
        
        action processData {
            in rawDigital : Real;
            in calibration : CalibrationFactor;
            out force : ForceValue;
        }
        
        action performCalibration {
            in calibrationCmd : CalibrationCommand;
            out success : Boolean;
        }
        
        action initializeSystem;
        action startMeasurement;
        action continuousMeasurement;
        action finalizeMeasurement;
        action beginCalibration;
        action executeCalibration;
        action completeCalibration;
        action logError;
        
        state idle;
        state measuring;
        state calibrating;
        state error;
    }
    
    part def DisplayUnit {
        attribute updateRate : FrequencyValue = 10.0 [Hz];
        attribute displayPrecision : Integer = 2;
        
        port readingIn {
            in item measurement : ForceReading;
        }
        
        action displayReading {
            in reading : ForceReading;
        }
        
        action updateDisplay {
            in force : ForceValue;
        }
    }
    
    part def PowerSupply {
        attribute nominalVoltage : ISQ::VoltageValue = 12.0 [V];
        attribute maxCurrent : ElectricCurrentValue = 2.0 [A];
        
        port powerOut {
            out attribute voltage : ISQ::VoltageValue;
            out attribute current : ElectricCurrentValue;
        }
    }
    
    action def MeasureAppliedForce {
        in appliedForce : ForceValue;
        out forceReading : ForceReading;
    }
    
    action def PerformSystemCalibration {
        in referenceForce : ForceValue;
        out calibrationSuccess : Boolean;
    }
    
    part def ForceGauge {
        doc /* 
            A force gauge system that measures applied mechanical forces and provides 
            accurate digital readings. The primary function is to sense external forces, 
            convert them to electrical signals, process the data, and display the 
            measured force value to the user with high accuracy and reliability.
        */
        
        attribute measurementRange : ForceValue = 5000.0 [N];
        attribute accuracy : Real = 0.01;
        attribute operatingTemperatureMin : TemperatureValue = 253.15 [K];
        attribute operatingTemperatureMax : TemperatureValue = 353.15 [K];
        
        port forceInput : ForceInputPort;
        port measurementOutput : MeasurementOutputPort;
        port calibrationInterface : CalibrationPort;
        
        part sensor : StrainGaugeSensor {
            :>> sensitivity = 2.0;
            :>> maxLoad = 5000.0 [N];
        }
        
        part amplifier : SignalAmplifier {
            :>> gain = 100.0;
            :>> bandwidth = 1000.0 [Hz];
        }
        
        part adc : AnalogDigitalConverter {
            :>> resolution = 16;
            :>> samplingRate = 1000.0 [Hz];
            :>> referenceVoltage = 5.0 [V];
        }
        
        part processor : MicroprocessorUnit {
            :>> calibrationFactor = 1.0;
            :>> zeroOffset = 0.0;
        }
        
        part display : DisplayUnit {
            :>> updateRate = 10.0 [Hz];
            :>> displayPrecision = 2;
        }
        
        part power : PowerSupply {
            :>> nominalVoltage = 12.0 [V];
            :>> maxCurrent = 2.0 [A];
        }
        
        connect sensor.voltageOut to amplifier.voltageIn;
        connect amplifier.voltageOut to adc.analogIn;
        connect adc.digitalOut to processor.digitalIn;
        connect processor.measurementOut to display.readingIn;
        
        action measureForce : MeasureAppliedForce {
            in appliedForce : ForceValue;
            out forceReading : ForceReading;
            
            first start;
            then action acquireForce {
                in force = appliedForce;
                out sensorVoltage : ISQ::VoltageValue;
            }
            then action amplify {
                in voltage = acquireForce.sensorVoltage;
                out amplifiedVoltage : ISQ::VoltageValue;
            }
            then action digitize {
                in analogVoltage = amplify.amplifiedVoltage;
                out digitalValue : Real;
            }
            then action calculateForce {
                in digitalInput = digitize.digitalValue;
                out computedForce : ForceValue;
            }
            then action validateReading {
                in force = calculateForce.computedForce;
                out validatedReading : ForceReading;
            }
            then action displayMeasurement {
                in reading = validateReading.validatedReading;
            }
            then done;
        }
        
        action calibrate : PerformSystemCalibration {
            in referenceForce : ForceValue;
            out calibrationSuccess : Boolean;
            
            first start;
            then action zeroCalibration;
            then action applyReferenceLoad {
                in reference = referenceForce;
            }
            then action measureReference {
                out referenceReading : Real;
            }
            then action computeCalibrationFactor {
                in reference = referenceForce;
                in measured = measureReference.referenceReading;
                out newFactor : CalibrationFactor;
            }
            then action storeCalibration {
                in factor = computeCalibrationFactor.newFactor;
                out success : Boolean;
            }
            then done;
        }
    }
    
    requirement def AccuracyRequirement {
        doc /* The force gauge shall measure forces with accuracy within ±1% of full scale. */
        
        subject gauge : ForceGauge;
        
        require constraint {
            gauge.accuracy <= 0.01
        }
    }
    
    requirement def RangeRequirement {
        doc /* The force gauge shall measure forces from 0 N to 5000 N. */
        
        subject gauge : ForceGauge;
        
        require constraint {
            gauge.measurementRange == 5000.0 [N]
        }
    }
    
    requirement def ResponseTimeRequirement {
        doc /* The force gauge shall update measurements at minimum 10 Hz. */
        
        subject gauge : ForceGauge;
        
        require constraint {
            gauge.display.updateRate >= 10.0 [Hz]
        }
    }
    
    requirement def OperatingTemperatureRequirement {
        doc /* The force gauge shall operate within temperature range 253.15 K to 353.15 K. */
        
        subject gauge : ForceGauge;
        
        require constraint {
            gauge.operatingTemperatureMin == 253.15 [K] and
            gauge.operatingTemperatureMax == 353.15 [K]
        }
    }
    
    requirement forceGaugeSystemRequirements {
        doc /* 
            The force gauge system shall accurately measure and display applied forces 
            within specified range, accuracy, and environmental conditions.
        */
        
        subject forceGauge : ForceGauge;
        
        require accuracyReq : AccuracyRequirement;
        require rangeReq : RangeRequirement;
        require responseReq : ResponseTimeRequirement;
        require temperatureReq : OperatingTemperatureRequirement;
    }
    
    part gaugeSystem : ForceGauge {
        perform action measureForce[*] ordered;
        perform action calibrate[*];
    }
}
