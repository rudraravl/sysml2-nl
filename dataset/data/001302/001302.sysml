package 'Ultrasonic Thickness Gauge System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def MaterialType;
    attribute def SoundVelocity :> ISQ::speed;
    attribute def ThicknessValue :> ISQ::length;
    attribute def TimeOfFlightValue :> ISQ::time;
    attribute def TemperatureValue :> ISQ::temperature;
    attribute def CalibrationData;
    attribute def MeasurementMode;
    
    item def UltrasonicPulse {
        attribute frequency :> ISQ::frequency;
        attribute amplitude :> ISQ::power;
        attribute duration :> ISQ::time;
    }
    
    item def EchoSignal {
        attribute timeOfFlight :> ISQ::time;
        attribute amplitude :> ISQ::power;
        attribute quality : Real;
    }
    
    item def MeasurementTrigger;
    item def CalibrationCommand;
    item def ModeSelection;
    
    enum def MeasurementStatus {
        idle;
        measuring;
        valid;
        invalid;
        error;
    }
    
    port def TransducerPort {
        out transmittedPulse : UltrasonicPulse;
        in receivedEcho : EchoSignal;
    }
    
    port def DisplayPort {
        in thicknessReading : ThicknessValue;
        in measurementStatus : MeasurementStatus;
    }
    
    port def UserControlPort {
        in measurementTrigger : MeasurementTrigger;
        in calibrationCommand : CalibrationCommand;
        in modeSelection : ModeSelection;
    }
    
    part def UltrasonicTransducer {
        port transducerInterface : TransducerPort;
        
        attribute operatingFrequency :> ISQ::frequency;
        attribute elementDiameter :> ISQ::length;
        attribute couplingType : MaterialType;
    }
    
    part def PulseGenerator {
        attribute pulseVoltage :> ISQ::voltage;
        attribute pulseWidth :> ISQ::time;
        attribute repetitionRate :> ISQ::frequency;
    }
    
    part def SignalProcessor {
        attribute samplingRate :> ISQ::frequency;
        attribute resolution : Real;
        attribute filterBandwidth :> ISQ::frequency;
    }
    
    part def ThicknessCalculator {
        attribute materialVelocity :> ISQ::speed;
        attribute temperatureCompensation :> ISQ::temperature;
    }
    
    part def CalibrationModule {
        attribute calibrationStandard : ThicknessValue;
        attribute velocityTable : SoundVelocity[*];
    }
    
    part def DisplayUnit {
        port displayInterface : DisplayPort;
        
        attribute displayResolution : Real;
        attribute updateRate :> ISQ::frequency;
    }
    
    part def ControlUnit {
        port controlInterface : UserControlPort;
        
        attribute currentMode : MeasurementMode;
        attribute measurementCount : Integer;
        attribute measurementValid : Boolean;
        attribute measurementInvalid : Boolean;
    }
    
    action def GenerateElectricalPulse {
        out electricalPulse : UltrasonicPulse;
    }
    
    action def TransmitUltrasonicPulse {
        in pulse : UltrasonicPulse;
        out transmittedPulse : UltrasonicPulse;
    }
    
    action def ReceiveEcho {
        in echo : EchoSignal;
        out timeOfFlight : TimeOfFlightValue;
    }
    
    action def AmplifySignal {
        in rawEcho : EchoSignal;
        out amplifiedEcho : EchoSignal;
    }
    
    action def FilterNoise {
        in noisySignal : EchoSignal;
        out cleanSignal : EchoSignal;
    }
    
    action def DetectEcho {
        in signal : EchoSignal;
        out detectedEcho : EchoSignal;
    }
    
    action def CalculateThickness {
        in timeOfFlight : TimeOfFlightValue;
        in soundVelocity : SoundVelocity;
        out thickness : ThicknessValue;
    }
    
    action def CompensateTemperature {
        in rawThickness : ThicknessValue;
        in temperature : TemperatureValue;
        out compensatedThickness : ThicknessValue;
    }
    
    action def ShowThickness {
        in thickness : ThicknessValue;
    }
    
    action def ShowStatus {
        in status : MeasurementStatus;
    }
    
    action def PerformCalibration {
        in knownThickness : ThicknessValue;
        in measuredTime : TimeOfFlightValue;
        out calibratedVelocity : SoundVelocity;
    }
    
    action def InitiateMeasurement;
    action def ProcessMeasurement;
    action def DisplayResult;
    action def HandleError;
    
    part def UltrasonicThicknessGauge {
        doc /*
            An ultrasonic thickness gauge is a non-destructive testing instrument
            that measures material thickness by transmitting ultrasonic pulses through
            the material and measuring the time it takes for the echo to return.
            
            Primary Function: Accurately measure the thickness of materials by analyzing
            the time-of-flight of ultrasonic waves reflected from the back surface of
            the test material, enabling non-invasive inspection of pipes, tanks, hulls,
            and structural components without requiring access to both sides.
        */
        
        part pulseGen : PulseGenerator;
        part transducer : UltrasonicTransducer;
        part signalProc : SignalProcessor;
        part calculator : ThicknessCalculator;
        part calibration : CalibrationModule;
        part display : DisplayUnit;
        part controller : ControlUnit;
        
        connection pulseGenToTransducer connect pulseGen to transducer;
        connection transducerToSignalProc connect transducer to signalProc;
        connection signalProcToCalculator connect signalProc to calculator;
        connection calculatorToDisplay connect calculator to display;
        connection controllerToDisplay connect controller to display;
    }
    
    part ultrasonicThicknessGauge : UltrasonicThicknessGauge {
        perform action measureThickness {
            first start;
            then action triggerMeasurement {
                out trigger : MeasurementTrigger;
            }
            then action generateAndTransmit {
                action genPulse : GenerateElectricalPulse {
                    out electricalPulse : UltrasonicPulse;
                }
                flow genPulse.electricalPulse to transmitPulse.pulse;
                action transmitPulse : TransmitUltrasonicPulse {
                    in pulse : UltrasonicPulse;
                    out transmittedPulse : UltrasonicPulse;
                }
            }
            then action receiveAndProcess {
                action receive : ReceiveEcho {
                    in echo : EchoSignal;
                    out timeOfFlight : TimeOfFlightValue;
                }
                action amplify : AmplifySignal {
                    in rawEcho : EchoSignal;
                    out amplifiedEcho : EchoSignal;
                }
                flow amplify.amplifiedEcho to filter.noisySignal;
                action filter : FilterNoise {
                    in noisySignal : EchoSignal;
                    out cleanSignal : EchoSignal;
                }
                flow filter.cleanSignal to detect.signal;
                action detect : DetectEcho {
                    in signal : EchoSignal;
                    out detectedEcho : EchoSignal;
                }
            }
            then action computeThickness {
                action calc : CalculateThickness {
                    in timeOfFlight : TimeOfFlightValue;
                    in soundVelocity : SoundVelocity;
                    out thickness : ThicknessValue;
                }
                flow calc.thickness to compensate.rawThickness;
                action compensate : CompensateTemperature {
                    in rawThickness : ThicknessValue;
                    in temperature : TemperatureValue;
                    out compensatedThickness : ThicknessValue;
                }
            }
            then action displayMeasurement {
                action showThick : ShowThickness {
                    in thickness : ThicknessValue;
                }
                action showStat : ShowStatus {
                    in status : MeasurementStatus;
                }
            }
            then done;
        }
    }
    
    requirement <'UTG-001'> primaryFunctionRequirement {
        doc /*
            The ultrasonic thickness gauge shall measure material thickness by
            transmitting ultrasonic pulses and analyzing echo return times.
        */
        
        subject ultrasonicThicknessGauge : UltrasonicThicknessGauge;
        
        require constraint {
            doc /* The system shall generate ultrasonic pulses. */
        }
        
        require constraint {
            doc /* The system shall detect and measure echo return time. */
        }
        
        require constraint {
            doc /* The system shall calculate thickness from time-of-flight data. */
        }
        
        require constraint {
            doc /* The system shall display thickness measurements to the user. */
        }
    }
    
    requirement <'UTG-002'> measurementAccuracyRequirement {
        doc /*
            The thickness measurement accuracy shall be within ±0.01 mm or ±1%
            of the reading, whichever is greater.
        */
    }
    
    requirement <'UTG-003'> measurementRangeRequirement {
        doc /*
            The system shall measure thickness in the range of 0.5 mm to 500 mm
            depending on material type and transducer selection.
        */
    }
    
    requirement <'UTG-004'> operatingFrequencyRequirement {
        doc /*
            The system shall support transducers with operating frequencies
            between 0.5 MHz and 20 MHz for various material applications.
        */
    }
}
