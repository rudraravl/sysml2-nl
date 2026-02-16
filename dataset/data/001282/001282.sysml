package ThermometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TemperatureReading {
        attribute value : TemperatureValue;
        attribute timestamp : TimeValue;
        attribute accuracy : TemperatureValue;
    }
    
    attribute def CalibrationData {
        attribute offset : TemperatureValue;
        attribute scale : Real;
        attribute lastCalibrationDate : TimeValue;
    }
    
    attribute def TemperatureRange {
        attribute minTemp : TemperatureValue;
        attribute maxTemp : TemperatureValue;
    }
    
    port def TemperatureSensorPort {
        out rawSignal : Real;
    }
    
    port def DisplayPort {
        in displayValue : TemperatureValue;
        in displayUnit : String;
    }
    
    port def CalibrationPort {
        in calibrationCommand : CalibrationData;
        out calibrationStatus : String;
    }
    
    part def TemperatureSensor {
        attribute operatingRange : TemperatureRange {
            attribute minTemp = 233.15[SI::K];
            attribute maxTemp = 373.15[SI::K];
        }
        attribute sensitivity : Real = 0.1;
        
        port sensorOutput : TemperatureSensorPort;
        
        perform action senseTemperature {
            out signal : Real;
        }
    }
    
    part def SignalProcessor {
        attribute calibration : CalibrationData {
            attribute offset = 0.0[SI::K];
            attribute scale = 1.0;
            attribute lastCalibrationDate = 0.0[SI::s];
        }
        
        in port rawInput {
            in signal : Real;
        }
        
        out port processedOutput {
            out temperature : TemperatureValue;
        }
        
        port calibrationInterface : CalibrationPort;
        
        perform action processSignal {
            in rawValue : Real;
            in calibrationData : CalibrationData;
            out processedTemp : TemperatureValue;
        }
    }
    
    part def Display {
        attribute displayMode : String = "Celsius";
        attribute refreshRate : FrequencyValue = 1.0[SI::Hz];
        
        in port displayInput : DisplayPort;
        
        perform action updateDisplay {
            in temperature : TemperatureValue;
            in mode : String;
        }
    }
    
    part def PowerSupply {
        attribute voltage : ElectricPotentialValue = 3.3[SI::V];
        attribute current : ElectricCurrentValue = 0.05[SI::A];
        
        out port powerOutput {
            out voltage : ElectricPotentialValue;
            out current : ElectricCurrentValue;
        }
    }
    
    action def MeasureTemperature {
        in environmentalTemp : TemperatureValue;
        out reading : TemperatureReading;
    }
    
    action def CalibrateSystem {
        in referenceTemp : TemperatureValue;
        in measuredTemp : TemperatureValue;
        out newCalibration : CalibrationData;
    }
    
    action def ConvertTemperature {
        in tempKelvin : TemperatureValue;
        in targetUnit : String;
        out convertedValue : Real;
    }
    
    part def ThermometerSystemDef {
        attribute systemAccuracy : TemperatureValue = 0.5[SI::K];
        attribute measurementInterval : TimeValue = 1.0[SI::s];
        
        part sensor : TemperatureSensor;
        part processor : SignalProcessor;
        part display : Display;
        part power : PowerSupply;
        
        connection sensorToProcessor connect 
            sensor.sensorOutput.rawSignal to processor.rawInput.signal;
        
        connection processorToDisplay connect 
            processor.processedOutput.temperature to display.displayInput.displayValue;
        
        perform action operateThermometer {
            first start;
            then action initialize {
                action powerOn;
                then action selfTest;
                then action loadCalibration;
            }
            then merge continuousMeasurement;
            then action measurementCycle : MeasureTemperature {
                in environmentalTemp : TemperatureValue;
                out reading : TemperatureReading;
                
                action acquireRawSignal {
                    out rawValue : Real;
                }
                then action processRawSignal {
                    in raw : Real = acquireRawSignal.rawValue;
                    out processed : TemperatureValue;
                }
                then action createReading {
                    in temp : TemperatureValue = processRawSignal.processed;
                    out finalReading : TemperatureReading;
                }
            }
            then action displayReading {
                in reading : TemperatureReading = measurementCycle.reading;
            }
            then action waitInterval {
                in interval : TimeValue = measurementInterval;
            }
            then decide;
                if systemActive then continuousMeasurement;
                if not systemActive then shutdown;
            action shutdown;
            then done;
            
            private attribute systemActive : Boolean = true;
        }
    }
    
    attribute def PowerOnSignal;
    attribute def SignalReadyEvent;
    attribute def ProcessingCompleteEvent;
    attribute def DisplayCompleteEvent;
    attribute def CalibrationRequestEvent;
    attribute def CalibrationCompleteEvent;
    attribute def PowerOffSignal;
    
    state def ThermometerState {
        entry; then idle;
        
        state idle;
        transition idle_to_measuring
            first idle
            accept powerOnEvent : PowerOnSignal
            then measuring;
        
        state measuring {
            entry; then acquiring;
            
            state acquiring;
            transition acquiring_to_processing
                first acquiring
                accept signalReadyEvent : SignalReadyEvent
                then processing;
            
            state processing;
            transition processing_to_displaying
                first processing
                accept processingCompleteEvent : ProcessingCompleteEvent
                then displaying;
            
            state displaying;
            transition displaying_to_acquiring
                first displaying
                accept displayCompleteEvent : DisplayCompleteEvent
                then acquiring;
        }
        
        transition measuring_to_calibrating
            first measuring
            accept calibrationRequestEvent : CalibrationRequestEvent
            then calibrating;
        
        state calibrating;
        transition calibrating_to_measuring
            first calibrating
            accept calibrationCompleteEvent : CalibrationCompleteEvent
            then measuring;
        
        transition measuring_to_idle
            first measuring
            accept powerOffEvent : PowerOffSignal
            then idle;
    }
    
    requirement def AccuracyRequirement {
        doc /* The thermometer shall measure temperature with an accuracy of ±0.5K across its operating range. */
        
        subject thermometer : ThermometerSystemDef;
        
        require constraint {
            thermometer.systemAccuracy <= 0.5[SI::K]
        }
    }
    
    requirement def RangeRequirement {
        doc /* The thermometer shall operate within the temperature range of -40°C to +100°C. */
        
        subject sensor : TemperatureSensor;
        
        require constraint {
            sensor.operatingRange.minTemp == 233.15[SI::K] and
            sensor.operatingRange.maxTemp == 373.15[SI::K]
        }
    }
    
    requirement def ResponseTimeRequirement {
        doc /* The thermometer shall update the displayed temperature at least once per second. */
        
        subject system : ThermometerSystemDef;
        
        require constraint {
            system.measurementInterval <= 1.0[SI::s]
        }
    }
    
    requirement <'THERM-001'> thermometerSystemRequirement {
        doc /* The thermometer system shall continuously measure and display ambient temperature 
               with high accuracy and reliability for environmental monitoring applications. */
        
        subject system : ThermometerSystemDef;
        
        assume constraint validEnvironment {
            doc /* The system operates in a stable environment within sensor operating range. */
        }
        
        require accuracyReq : AccuracyRequirement;
        require rangeReq : RangeRequirement;
        require responseReq : ResponseTimeRequirement;
    }
    
    part thermometerSystem : ThermometerSystemDef;
}
