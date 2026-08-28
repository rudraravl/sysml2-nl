package GroundPenetratingRadarSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    package Definitions {
        item def EM_Pulse;
        item def Echo;
        item def AnalogSignal;
        item def DigitalData;
        item def DepthMeasurement;
        item def CrossSectionImage;
        item def ControlCommand;
        
        attribute def StartScan;
        attribute def StopScan;
        attribute def Reset;
        attribute def CalibrationComplete;
        attribute def SystemError;
        
        action def GeneratePulse { out pulse : EM_Pulse; }
        action def TransmitPulse { in pulse : EM_Pulse; }
        action def ReceiveEcho { out echo : Echo; }
        action def AmplifySignal { in echo : Echo; out signal : AnalogSignal; }
        action def ProcessSignal { in signal : AnalogSignal; out data : DigitalData; }
        action def CalculateDepth { in data : DigitalData; out depth : DepthMeasurement; }
        action def GenerateImage { in depth : DepthMeasurement; out image : CrossSectionImage; }
        action def DisplayImage { in image : CrossSectionImage; }
        action def RunCalibration;
        action def HandleFault;
        
        action def ScanCycle {
            action gen : GeneratePulse;
            action tx : TransmitPulse;
            action rx : ReceiveEcho;
            action amp : AmplifySignal;
            action proc : ProcessSignal;
            action depthCalc : CalculateDepth;
            action genImg : GenerateImage;
            action disp : DisplayImage;
            succession first gen then tx;
            succession first tx then rx;
            succession first rx then amp;
            succession first amp then proc;
            succession first proc then depthCalc;
            succession first depthCalc then genImg;
            succession first genImg then disp;
        }
        
        port def PulseOut { out pulse : EM_Pulse; }
        port def PulseIn { in pulse : EM_Pulse; }
        port def EchoOut { out echo : Echo; }
        port def EchoIn { in echo : Echo; }
        port def AnalogOut { out signal : AnalogSignal; }
        port def AnalogIn { in signal : AnalogSignal; }
        port def DigitalOut { out data : DigitalData; }
        port def DigitalIn { in data : DigitalData; }
        port def DepthOut { out depth : DepthMeasurement; }
        port def DepthIn { in depth : DepthMeasurement; }
        port def ImageOut { out image : CrossSectionImage; }
        port def ImageIn { in image : CrossSectionImage; }
        port def ControlOut { out cmd : ControlCommand; }
        port def ControlIn { in cmd : ControlCommand; }
        
        state def GPR_States;
        
        part def PulseGenerator {
            port pulseOut : PulseOut;
            perform action generate : GeneratePulse;
        }
        part def TransmitAntenna {
            port pulseIn : PulseIn;
            perform action transmit : TransmitPulse;
        }
        part def ReceiveAntenna {
            port echoOut : EchoOut;
            perform action receive : ReceiveEcho;
        }
        part def SignalAmplifier {
            port echoIn : EchoIn;
            port analogOut : AnalogOut;
            perform action amplify : AmplifySignal;
        }
        part def DigitalSignalProcessor {
            port analogIn : AnalogIn;
            port digitalOut : DigitalOut;
            perform action process : ProcessSignal;
        }
        part def DepthCalculator {
            port digitalIn : DigitalIn;
            port depthOut : DepthOut;
            perform action calculate : CalculateDepth;
        }
        part def ImageGenerator {
            port depthIn : DepthIn;
            port imageOut : ImageOut;
            perform action generate : GenerateImage;
        }
        part def DisplayMonitor {
            port imageIn : ImageIn;
            perform action display : DisplayImage;
        }
        part def ControlUnit {
            port controlOut : ControlOut;
        }
        
        requirement def MaxDepthRequirement {
            doc
            /* The GPR system shall scan to a maximum depth of 15 meters. */
            attribute maxDepth : LengthValue = 15 [m];
        }
        requirement def VerticalResolutionRequirement {
            doc
            /* The GPR system shall distinguish objects 5 cm apart vertically. */
            attribute minResolution : LengthValue = 5 [cm];
        }
        requirement def FrequencyRangeRequirement {
            doc
            /* The GPR system shall operate over 100 MHz to 1000 MHz. */
            attribute minFreq : FrequencyValue = 100 [MHz];
            attribute maxFreq : FrequencyValue = 1000 [MHz];
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part def GroundPenetratingRadar {
            port controlIn : ControlIn;
            
            part pulseGen : PulseGenerator;
            part txAntenna : TransmitAntenna;
            part rxAntenna : ReceiveAntenna;
            part amp : SignalAmplifier;
            part dsp : DigitalSignalProcessor;
            part depthCalc : DepthCalculator;
            part imgGen : ImageGenerator;
            part monitor : DisplayMonitor;
            part controller : ControlUnit;
            
            connect pulseGen.pulseOut to txAntenna.pulseIn;
            connect rxAntenna.echoOut to amp.echoIn;
            connect amp.analogOut to dsp.analogIn;
            connect dsp.digitalOut to depthCalc.digitalIn;
            connect depthCalc.depthOut to imgGen.depthIn;
            connect imgGen.imageOut to monitor.imageIn;
            connect controller.controlOut to controlIn;
            
            action 'run calibration' : RunCalibration;
            action 'handle fault' : HandleFault;
            action 'scan cycle' : ScanCycle;
            
            exhibit state 'gpr states' : GPR_States {
                entry; then standby;
                
                state standby;
                accept StartScan
                    then initializing;
                
                state initializing {
                    do 'run calibration';
                }
                accept CalibrationComplete
                    then scanning;
                
                state scanning {
                    do 'scan cycle';
                }
                accept StopScan
                    then standby;
                accept SystemError
                    then error;
                
                state error {
                    do 'handle fault';
                }
                accept Reset
                    then standby;
            }
        }
        
        part gprSystem : GroundPenetratingRadar {
            satisfy MaxDepthRequirement;
            satisfy VerticalResolutionRequirement;
            satisfy FrequencyRangeRequirement;
        }
    }
}
