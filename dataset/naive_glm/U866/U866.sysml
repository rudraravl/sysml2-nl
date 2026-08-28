package ScintillometerSystem {
    import ScalarValues::*;
    import ISQ::*;
    
    package Definitions {
        value type Distance :> Real { unit 'm'; }
        value type Temperature :> Real { unit 'K'; }
        value type Pressure :> Real { unit 'Pa'; }
        value type Humidity :> Real { unit '%'; }
        value type Intensity :> Real { unit 'W/m^2'; }
        value type Cn2 :> Real { unit 'm^-2/3'; }
        value type HeatFlux :> Real { unit 'W/m^2'; }
        
        item def OpticalBeam;
        item def ScintillatedBeam;
        item def AtmosphericData {
            attribute temp : Temperature;
            attribute press : Pressure;
            attribute humid : Humidity;
        }
        item def TurbulenceData {
            attribute cn2 : Cn2;
            attribute heatFlux : HeatFlux;
        }
        item def Command {
            attribute commandType : String;
        }
    }
    
    package Interfaces {
        port def OpticalOutPort {
            out beam : Definitions::OpticalBeam;
        }
        port def OpticalInPort {
            in beam : Definitions::ScintillatedBeam;
        }
        port def DataOutPort {
            out data : Definitions::TurbulenceData;
        }
        port def DataInPort {
            in data : Definitions::TurbulenceData;
        }
        port def AtmosDataOutPort {
            out data : Definitions::AtmosphericData;
        }
        port def AtmosDataInPort {
            in data : Definitions::AtmosphericData;
        }
        port def RawDataOutPort {
            out intensity : Definitions::Intensity;
        }
        port def RawDataInPort {
            in intensity : Definitions::Intensity;
        }
        port def CommandPort {
            in cmd : Definitions::Command;
        }
    }
    
    package Parts {
        part def LaserSource {
            out beam : Definitions::OpticalBeam;
        }
        
        part def TransmitterOptics {
            in beam : Definitions::OpticalBeam;
            out beam : Definitions::OpticalBeam;
        }
        
        part def Transmitter {
            part laser : LaserSource;
            part optics : TransmitterOptics;
            port opticalOut : Interfaces::OpticalOutPort;
            connect laser.beam to optics.beam;
            connect optics.beam to opticalOut.beam;
        }
        
        part def FocusingOptics {
            in beam : Definitions::ScintillatedBeam;
            out beam : Definitions::ScintillatedBeam;
        }
        
        part def Detector {
            in beam : Definitions::ScintillatedBeam;
            out intensity : Definitions::Intensity;
        }
        
        part def Receiver {
            part focusingOptics : FocusingOptics;
            part detector : Detector;
            port opticalIn : Interfaces::OpticalInPort;
            port rawOut : Interfaces::RawDataOutPort;
            connect opticalIn.beam to focusingOptics.beam;
            connect focusingOptics.beam to detector.beam;
            connect detector.intensity to rawOut.intensity;
        }
        
        part def AtmosphericSensor {
            port atmosOut : Interfaces::AtmosDataOutPort;
        }
        
        part def SignalProcessor {
            port rawIn : Interfaces::RawDataInPort;
            port atmosIn : Interfaces::AtmosDataInPort;
            port dataOut : Interfaces::DataOutPort;
            
            action def ProcessSignals {
                in intensity : Definitions::Intensity;
                in atmos : Definitions::AtmosphericData;
                out turbulence : Definitions::TurbulenceData;
            }
        }
        
        part def DataAcquisition {
            port dataIn : Interfaces::DataInPort;
            port dataOut : Interfaces::DataOutPort;
        }
        
        part def CommandInterface {
            port cmdPort : Interfaces::CommandPort;
        }
        
        part def Scintillometer {
            part transmitter : Transmitter;
            part receiver : Receiver;
            part signalProcessor : SignalProcessor;
            part dataAcquisition : DataAcquisition;
            part atmosphericSensor : AtmosphericSensor;
            part commandInterface : CommandInterface;
            
            connect transmitter.opticalOut to receiver.opticalIn;
            connect receiver.rawOut to signalProcessor.rawIn;
            connect atmosphericSensor.atmosOut to signalProcessor.atmosIn;
            connect signalProcessor.dataOut to dataAcquisition.dataIn;
            
            attribute pathLength : Definitions::Distance = 500 [m];
            
            state def OperationalState {
                state idle;
                state calibrating;
                state activeMeasuring;
                
                transition idle to calibrating when commandInterface.cmdPort.cmd.commandType == "calibrate";
                transition calibrating to activeMeasuring when commandInterface.cmdPort.cmd.commandType == "start";
                transition activeMeasuring to idle when commandInterface.cmdPort.cmd.commandType == "stop";
            }
            
            exhibit state OperationalState;
        }
    }
    
    package Requirements {
        requirement def PathLengthRange {
            doc "The system must support measurement paths from 50 meters up to 5 kilometers.";
            subject scint : Parts::Scintillometer;
            constraint { 50 [m] <= scint.pathLength <= 5000 [m] }
        }
        
        requirement def MeasureCn2 {
            doc "The system must calculate the Refractive Index Structure Parameter (Cn²).";
            subject processor : Parts::SignalProcessor;
            constraint { processor.dataOut.data.cn2 > 0 [m^-2/3] }
        }
        
        requirement def DeriveHeatFlux {
            doc "The system must derive sensible heat flux from Cn² and atmospheric data.";
            subject processor : Parts::SignalProcessor;
            constraint { processor.dataOut.data.heatFlux != 0 [W/m^2] }
        }
        
        requirement def ContinuousOperation {
            doc "The system must operate reliably across a wide range of environmental conditions for long-term field deployment.";
        }
        
        part def ScintillometerRequirements {
            requirement r1 : PathLengthRange;
            requirement r2 : MeasureCn2;
            requirement r3 : DeriveHeatFlux;
            requirement r4 : ContinuousOperation;
        }
    }
}
