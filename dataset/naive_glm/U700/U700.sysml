package GPR_System {
    import ScalarValues::*;
    
    value type Length > Real { unit = "m"; }
    value type Frequency > Real { unit = "Hz"; }
    value type Voltage > Real { unit = "V"; }
    value type Time > Real { unit = "s"; }
    
    item def EM_Pulse {
        attr frequency : Frequency;
        attr amplitude : Voltage;
    }
    item def EchoSignal {
        attr amplitude : Voltage;
        attr timeOfFlight : Time;
    }
    item def DigitalEchoData {
        attr amplitude : Real;
        attr timeOfFlight : Time;
    }
    item def DepthMeasurement {
        attr depth : Length;
    }
    item def SubsurfaceImage {
        attr resolution : Length;
    }
    item def ControlCommand {
        attr mode : String;
        attr speed : Real;
    }
    item def SystemStatus {
        attr state : String;
    }
    
    interface def PulseFlow {
        end pulse : EM_Pulse;
    }
    interface def EchoFlow {
        end echo : EchoSignal;
    }
    interface def DigitalDataFlow {
        end data : DigitalEchoData;
    }
    interface def DepthDataFlow {
        end depth : DepthMeasurement;
    }
    interface def ImageFlow {
        end image : SubsurfaceImage;
    }
    interface def CommandFlow {
        end command : ControlCommand;
    }
    interface def StatusFlow {
        end status : SystemStatus;
    }
    
    part def PulseGenerator {
        port in cmdIn : CommandFlow;
        port out pulseOut : PulseFlow;
        attr frequency : Frequency;
    }
    
    part def TransmitAntenna {
        port in pulseIn : PulseFlow;
        port out groundPulseOut : PulseFlow;
    }
    
    part def ReceiveAntenna {
        port in groundEchoIn : EchoFlow;
        port out echoOut : EchoFlow;
    }
    
    part def SignalAmplifier {
        port in echoIn : EchoFlow;
        port out amplifiedEchoOut : EchoFlow;
    }
    
    part def DSP {
        port in cmdIn : CommandFlow;
        port in analogIn : EchoFlow;
        port out digitalOut : DigitalDataFlow;
    }
    
    part def DepthCalculator {
        port in cmdIn : CommandFlow;
        port in digitalIn : DigitalDataFlow;
        port out depthOut : DepthDataFlow;
    }
    
    part def ImageGenerator {
        port in cmdIn : CommandFlow;
        port in depthIn : DepthDataFlow;
        port out imageOut : ImageFlow;
    }
    
    part def DisplayMonitor {
        port in cmdIn : CommandFlow;
        port in imageIn : ImageFlow;
    }
    
    part def ControlUnit {
        port in operatorCmd : CommandFlow;
        port in statusIn : StatusFlow;
        port out cmdPulseGen : CommandFlow;
        port out cmdDSP : CommandFlow;
        port out cmdDepthCalc : CommandFlow;
        port out cmdImgGen : CommandFlow;
        port out cmdDisplay : CommandFlow;
        port out operatorStatus : StatusFlow;
    }
    
    part def Ground {
        port in pulseIn : PulseFlow;
        port out echoOut : EchoFlow;
    }
    
    part def GPR {
        port in operatorCommand : CommandFlow;
        port out operatorStatus : StatusFlow;
        
        attr maxDepth : Length = 15 [m];
        attr verticalResolution : Length = 0.05 [m];
        attr minFrequency : Frequency = 100e6 [Hz];
        attr maxFrequency : Frequency = 1000e6 [Hz];
        
        part pulseGenerator : PulseGenerator;
        part transmitAntenna : TransmitAntenna;
        part receiveAntenna : ReceiveAntenna;
        part signalAmplifier : SignalAmplifier;
        part dsp : DSP;
        part depthCalculator : DepthCalculator;
        part imageGenerator : ImageGenerator;
        part displayMonitor : DisplayMonitor;
        part controlUnit : ControlUnit;
        part ground : Ground;
        
        connect operatorCommand to controlUnit.operatorCmd;
        connect controlUnit.operatorStatus to operatorStatus;
        
        connect controlUnit.cmdPulseGen to pulseGenerator.cmdIn;
        connect controlUnit.cmdDSP to dsp.cmdIn;
        connect controlUnit.cmdDepthCalc to depthCalculator.cmdIn;
        connect controlUnit.cmdImgGen to imageGenerator.cmdIn;
        connect controlUnit.cmdDisplay to displayMonitor.cmdIn;
        
        connect pulseGenerator.pulseOut to transmitAntenna.pulseIn;
        connect transmitAntenna.groundPulseOut to ground.pulseIn;
        connect ground.echoOut to receiveAntenna.groundEchoIn;
        connect receiveAntenna.echoOut to signalAmplifier.echoIn;
        connect signalAmplifier.amplifiedEchoOut to dsp.analogIn;
        connect dsp.digitalOut to depthCalculator.digitalIn;
        connect depthCalculator.depthOut to imageGenerator.depthIn;
        connect imageGenerator.imageOut to displayMonitor.imageIn;
        
        state def GPR_States {
            state standby;
            state initializing;
            state scanning {
                do action scanCycle {
                    // transmit, receive, process, update
                }
            }
            state error;
            
            transition standby to initializing 
                when operatorCommand.command.mode == "scan";
            transition initializing to scanning 
                when controlUnit.statusIn.status.state == "ready";
            transition scanning to standby 
                when operatorCommand.command.mode == "stop";
            transition standby to error 
                when controlUnit.statusIn.status.state == "fault";
            transition scanning to error 
                when controlUnit.statusIn.status.state == "fault";
            transition initializing to error 
                when controlUnit.statusIn.status.state == "fault";
            transition error to standby 
                when operatorCommand.command.mode == "reset";
        }
    }
    
    requirement def GPR_Requirements {
        subject gpr : GPR_System::GPR;
        
        requirement MaxDepthReq {
            doc /* The system shall scan to a maximum depth of 15 meters. */
            constraint { gpr.maxDepth == 15 [m] }
        }
        
        requirement VerticalResolutionReq {
            doc /* The system shall distinguish between objects 5 cm apart vertically. */
            constraint { gpr.verticalResolution == 0.05 [m] }
        }
        
        requirement FrequencyRangeReq {
            doc /* The system shall operate over a frequency range of 100 MHz to 1000 MHz. */
            constraint { gpr.minFrequency == 100e6 [Hz] and gpr.maxFrequency == 1000e6 [Hz] }
        }
    }
}
