package OpticalLinearEncoderModel {
    import ScalarValues::*;
    
    attribute def mm;
    attribute def um;
    attribute def ms;
    attribute def mm_per_s;
    attribute def mV;
    
    value def DistanceMm :> Real { unit :> mm; }
    value def DistanceUm :> Real { unit :> um; }
    value def TimeMs :> Real { unit :> ms; }
    value def VelocityMmPerS :> Real { unit :> mm_per_s; }
    value def VoltageMv :> Real { unit :> mV; }
    
    port def OpticalInterface;
    
    item def AnalogSignal {
        attribute voltageA : VoltageMv;
        attribute voltageB : VoltageMv;
    }
    
    item def DigitalEncoderData {
        attribute position : DistanceUm;
        attribute timestamp : TimeMs;
    }
    
    item def MeasurementData {
        attribute position : DistanceMm;
        attribute velocity : VelocityMmPerS;
        attribute timestamp : TimeMs;
    }
    
    item def ControlCommand {
        attribute command : String;
    }
    
    action def AcquireOpticalSignal {
        out analog : AnalogSignal;
    }
    
    action def ProcessOpticalSignal {
        in analog : AnalogSignal;
        out digital : DigitalEncoderData;
    }
    
    action def CalculateMeasurement {
        in digital : DigitalEncoderData;
        out measurement : MeasurementData;
    }
    
    part def GraduatedScale {
        attribute material : String = "Glass";
        attribute length : DistanceMm = 1000;
        attribute markingPitch : DistanceUm = 20;
        port scaleOpticalInterface : OpticalInterface;
    }
    
    part def LightSource {
        attribute type : String = "LED";
        attribute power : Real;
        attribute wavelength : DistanceUm = 0.850;
    }
    
    part def Photodetector {
        attribute responsivity : Real;
    }
    
    part def ReadHead {
        attribute isMoving : Boolean = false;
        part led : LightSource;
        part detectors : Photodetector[4];
        port headOpticalInterface : OpticalInterface;
        port out analogOut : AnalogSignal;
        
        action acquire : AcquireOpticalSignal {
            out analog = analogOut;
        }
    }
    
    part def SignalProcessor {
        port in analogIn : AnalogSignal;
        port out digitalOut : DigitalEncoderData;
        attribute interpolationFactor : Integer = 40;
        attribute resolution : DistanceUm = 0.5;
        
        action process : ProcessOpticalSignal {
            in analog = analogIn;
            out digital = digitalOut;
        }
    }
    
    part def Controller {
        port in digitalIn : DigitalEncoderData;
        port in cmdIn : ControlCommand;
        port out dataOut : MeasurementData;
        
        attribute previousPosition : DistanceMm = 0;
        attribute previousTime : TimeMs = 0;
        attribute currentPosition : DistanceMm = 0;
        attribute currentVelocity : VelocityMmPerS = 0;
        
        action calculate : CalculateMeasurement {
            in digital = digitalIn;
            out measurement = dataOut;
        }
    }
    
    part def MountingAssembly {
        attribute alignmentTolerance : DistanceUm = 5;
        part scaleMount;
        part headMount;
    }
    
    part def OpticalLinearEncoder {
        port in extCmdIn : ControlCommand;
        port out extDataOut : MeasurementData;
        
        part scale : GraduatedScale;
        part head : ReadHead;
        part processor : SignalProcessor;
        part controller : Controller;
        part mount : MountingAssembly;
        
        connection opticalCoupling connect head.headOpticalInterface to scale.scaleOpticalInterface;
        
        flow from head.analogOut to processor.analogIn;
        flow from processor.digitalOut to controller.digitalIn;
        flow from extCmdIn to controller.cmdIn;
        flow from controller.dataOut to extDataOut;
        
        attribute powerOn : Boolean = false;
        attribute initComplete : Boolean = false;
        attribute startCommand : Boolean = false;
        attribute stopCommand : Boolean = false;
        attribute powerOff : Boolean = false;
        attribute faultDetected : Boolean = false;
        attribute recoverySuccess : Boolean = false;
        
        state machine lifecycle {
            state Off;
            state Initializing {
                entry action {
                    // Run self-test
                }
                do action {
                    // Run calibration routine
                    initComplete = true;
                }
            }
            state Ready;
            state Measuring {
                state Acquiring {
                    do action {
                        head.acquire();
                    }
                }
                state Processing {
                    do action {
                        processor.process();
                    }
                }
                state Transmitting {
                    do action {
                        controller.calculate();
                    }
                }
                transition from Acquiring to Processing;
                transition from Processing to Transmitting;
                transition from Transmitting to Acquiring;
            }
            state Stopped;
            state Error {
                entry action {
                    faultDetected = false;
                }
                do action {
                    recoverySuccess = true;
                }
            }
            
            transition from Off to Initializing when powerOn;
            transition from Initializing to Ready when initComplete;
            transition from Ready to Measuring when startCommand;
            transition from Measuring to Stopped when stopCommand;
            transition from Stopped to Off when powerOff;
            transition from * to Error when faultDetected;
            transition from Error to Ready when recoverySuccess;
            transition from Error to Off when powerOff;
        }
    }
    
    requirement OpticalEncoderRequirements {
        doc /* High-precision optical linear encoder system requirements. */
        subject encoder : OpticalLinearEncoder;
        
        requirement ResolutionRequirement {
            doc /* The encoder must achieve a measurement resolution of 0.5 micrometers. */
            subject proc : SignalProcessor = encoder.processor;
            constraint { proc.resolution == 0.5; }
        }
        
        requirement ScalePitchRequirement {
            doc /* The graduated scale must have fine evenly spaced markings. */
            subject scale : GraduatedScale = encoder.scale;
            constraint { scale.markingPitch == 20; }
        }
        
        requirement LifecycleRequirement {
            doc /* The system must support initialization, ready, measuring, stopped, and error states. */
            subject enc : OpticalLinearEncoder = encoder;
        }
    }
}
