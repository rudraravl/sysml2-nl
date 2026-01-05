package PerineometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def PressureValue :> Real;
    attribute def DurationValue :> Real;
    attribute def StrengthIndex :> Real;
    
    enum def MeasurementMode {
        quick;
        extended;
        endurance;
    }
    
    enum def DeviceState {
        off;
        idle;
        calibrating;
        measuring;
        analyzing;
        displaying;
    }
    
    item def PressureReading {
        attribute pressure : PressureValue;
        attribute timestamp : Real;
    }
    
    item def AnalysisResult {
        attribute strengthIndex : StrengthIndex;
        attribute peakPressure : PressureValue;
        attribute sustainedDuration : DurationValue;
    }
    
    port def PressureDataPort {
        out item pressureData : PressureReading;
    }
    
    port def AnalysisDataPort {
        in item rawData : PressureReading;
        out item results : AnalysisResult;
    }
    
    port def DisplayDataPort {
        in item displayData : AnalysisResult;
    }
    
    part def PressureSensor {
        attribute maxPressure : PressureValue;
        attribute sensitivity : Real;
        attribute currentReading : PressureValue;
        
        port dataOut : PressureDataPort;
        
        action def SensePressure {
            out reading : PressureReading;
        }
    }
    
    part def InflatableProbe {
        attribute volume : VolumeValue;
        attribute inflationPressure : PressureValue;
        attribute insertionDepth : LengthValue;
        
        part sensor : PressureSensor {
            attribute :>> maxPressure = 250.0;
            attribute :>> sensitivity = 0.1;
        }
    }
    
    part def ProcessingUnit {
        attribute samplingRate : Real;
        attribute filterCutoff : Real;
        
        port dataIn : AnalysisDataPort;
        
        action def FilterSignal {
            in rawReading : PressureReading;
            out filteredReading : PressureReading;
        }
        
        action def CalculateStrength {
            in readings : PressureReading[*];
            out result : AnalysisResult;
        }
        
        state def ProcessingStateMachine {
            entry; then waitingForData;
            
            state waitingForData;
            accept dataReceived;
            then filtering;
            
            state filtering {
                do action filter : FilterSignal {
                    in rawReading : PressureReading;
                    out filteredReading : PressureReading;
                }
            }
            accept filterComplete;
            then calculating;
            
            state calculating {
                do action calculate : CalculateStrength {
                    in readings : PressureReading[*];
                    out result : AnalysisResult;
                }
            }
            accept calculationComplete;
            then outputting;
            
            state outputting;
            accept outputSent;
            then waitingForData;
        }
    }
    
    part def DisplayUnit {
        attribute screenSize : LengthValue;
        attribute brightness : Real;
        
        port dataIn : DisplayDataPort;
        
        action def RenderResults {
            in result : AnalysisResult;
        }
        
        action def ShowFeedback {
            in strength : StrengthIndex;
        }
    }
    
    part def ControlUnit {
        attribute operatingMode : MeasurementMode;
        attribute calibrationOffset : PressureValue;
        attribute sessionDuration : DurationValue;
        
        action def SetMode {
            in mode : MeasurementMode;
        }
        
        action def StartSession;
        action def StopSession;
    }
    
    part def Perineometer {
        doc /* A medical device for measuring and assessing pelvic floor muscle strength
             * through intravaginal pressure measurement, providing biofeedback for
             * rehabilitation and therapeutic exercises. */
        
        attribute deviceId : String;
        attribute currentState : DeviceState;
        attribute batteryLevel : Real;
        
        part probe : InflatableProbe {
            attribute :>> volume = 45.0;
            attribute :>> inflationPressure = 8.0;
            attribute :>> insertionDepth = 6.0;
        }
        
        part processor : ProcessingUnit {
            attribute :>> samplingRate = 100.0;
            attribute :>> filterCutoff = 10.0;
        }
        
        part display : DisplayUnit {
            attribute :>> screenSize = 7.0;
            attribute :>> brightness = 80.0;
        }
        
        part controller : ControlUnit {
            attribute :>> operatingMode = MeasurementMode::quick;
            attribute :>> calibrationOffset = 0.0;
            attribute :>> sessionDuration = 60.0;
        }
        
        connection probeSensorLink connect probe.sensor.dataOut to processor.dataIn;
        connection processorDisplayLink connect processor.dataIn to display.dataIn;
        
        state def OperationalStateMachine {
            entry; then off;
            
            state off {
                entry assign currentState = DeviceState::off;
            }
            accept powerOn;
            then idle;
            
            state idle {
                entry assign currentState = DeviceState::idle;
            }
            accept startCalibration;
            then calibrating;
            
            state calibrating {
                entry assign currentState = DeviceState::calibrating;
                do action calibrate : CalibrateDevice {
                    in baselinePressure : PressureValue;
                    out calibrationOffset : PressureValue;
                }
            }
            accept calibrationComplete;
            then measuring;
            
            state measuring {
                entry assign currentState = DeviceState::measuring;
                do action measure : PerformMeasurement {
                    in mode : MeasurementMode;
                    in duration : DurationValue;
                    out readings : PressureReading[*];
                }
            }
            accept measurementComplete;
            then analyzing;
            
            state analyzing {
                entry assign currentState = DeviceState::analyzing;
                do action analyze : AnalyzeData {
                    in readings : PressureReading[*];
                    out result : AnalysisResult;
                }
            }
            accept analysisComplete;
            then displaying;
            
            state displaying {
                entry assign currentState = DeviceState::displaying;
                do action showResults : ProvideFeedback {
                    in result : AnalysisResult;
                }
            }
            accept userAcknowledge;
            then idle;
            
            transition from idle to off accept powerOff;
        }
        
        perform action conductMeasurementSession[*] ordered references measurementWorkflow;
    }
    
    action def CalibrateDevice {
        in baselinePressure : PressureValue;
        out calibrationOffset : PressureValue;
    }
    
    action def PerformMeasurement {
        in mode : MeasurementMode;
        in duration : DurationValue;
        out readings : PressureReading[*];
    }
    
    action def AnalyzeData {
        in readings : PressureReading[*];
        out result : AnalysisResult;
    }
    
    action def ProvideFeedback {
        in result : AnalysisResult;
    }
    
    action measurementWorkflow : MeasurementSession {
        doc /* Complete workflow for conducting a pelvic floor muscle strength assessment. */
        
        first start;
        then merge beginSession;
        
        then action calibrate : CalibrateDevice {
            in baselinePressure : PressureValue;
            out calibrationOffset : PressureValue;
        }
        
        then action instructUser {
            doc /* Provide user instructions for probe insertion and positioning. */
        }
        
        then action measure : PerformMeasurement {
            in mode : MeasurementMode;
            in duration : DurationValue;
            out readings : PressureReading[*];
        }
        
        then action analyze : AnalyzeData {
            in readings = measure.readings;
            out result : AnalysisResult;
        }
        
        then action feedback : ProvideFeedback {
            in result = analyze.result;
        }
        
        then decide;
            if measure.mode == MeasurementMode::extended then continueSession;
            if measure.mode != MeasurementMode::extended then endSession;
        
        action continueSession {
            doc /* Continue with additional measurement cycles. */
        }
        then beginSession;
        
        action endSession {
            doc /* Finalize session and store results. */
        }
        then done;
    }
    
    requirement <'REQ-001'> primaryFunction {
        doc /* The perineometer system shall measure pelvic floor muscle strength
             * by detecting intravaginal pressure during muscle contractions and
             * provide real-time visual biofeedback to support rehabilitation therapy. */
        subject device : Perineometer;
    }
    
    requirement <'REQ-002'> measurementAccuracy {
        doc /* The pressure sensor shall measure with accuracy of ±2 kPa across
             * the operational range. */
        subject sensor :>> Perineometer::probe.sensor;
        assert constraint {
            sensor.sensitivity <= 0.2
        }
    }
    
    requirement <'REQ-003'> measurementRange {
        doc /* The device shall measure pressure from 0 to 250 kPa. */
        subject sensor :>> Perineometer::probe.sensor;
        assert constraint {
            sensor.maxPressure >= 250.0
        }
    }
    
    requirement <'REQ-004'> samplingFrequency {
        doc /* The processing unit shall sample pressure at minimum 50 Hz
             * to capture dynamic muscle contractions. */
        subject processor :>> Perineometer::processor;
        assert constraint {
            processor.samplingRate >= 50.0
        }
    }
    
    requirement <'REQ-005'> responseTime {
        doc /* Visual feedback shall be displayed within 200 ms of pressure change. */
        subject system : Perineometer;
    }
    
    part perineometerDevice : Perineometer {
        attribute :>> deviceId = "PRNM-2025-001";
        attribute :>> currentState = DeviceState::off;
        attribute :>> batteryLevel = 100.0;
        
        part :>> probe {
            part :>> sensor {
                attribute :>> maxPressure = 250.0;
                attribute :>> sensitivity = 0.15;
            }
        }
        
        part :>> processor {
            attribute :>> samplingRate = 100.0;
            attribute :>> filterCutoff = 12.0;
        }
        
        part :>> display {
            attribute :>> screenSize = 7.5;
            attribute :>> brightness = 85.0;
        }
        
        part :>> controller {
            attribute :>> operatingMode = MeasurementMode::quick;
            attribute :>> sessionDuration = 90.0;
        }
    }
    
    satisfy primaryFunction by perineometerDevice;
    satisfy measurementAccuracy by perineometerDevice.probe.sensor;
    satisfy measurementRange by perineometerDevice.probe.sensor;
    satisfy samplingFrequency by perineometerDevice.processor;
    satisfy responseTime by perineometerDevice;
}
