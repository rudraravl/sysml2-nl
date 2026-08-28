package MRI_System_Model {
    private import ISQ::*;
    private import SI::*;

    package Definitions {
        private import ISQ::*;
        private import SI::*;

        attribute def MagneticFieldStrength :> ISQ::MagneticFluxDensityValue;
        attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
        attribute def LengthValue :> ISQ::LengthValue;

        item def ScanProtocol;
        item def ControlSignal;
        item def RFPulse;
        item def GradientCommand;
        item def AnalogMRSignal;
        item def DigitalMRSignal;
        item def MRImage;
        item def CryogenicsStatus;
        item def TablePositionCommand;
        item def TablePositionStatus;

        port def CryoOutPort { out status : CryogenicsStatus; }
        port def CryoInPort { in status : CryogenicsStatus; }
        port def ControlPort { in command : ControlSignal; }
        port def ProtocolOutPort { out protocol : ScanProtocol; }
        port def ProtocolInPort { in protocol : ScanProtocol; }
        port def RFOutPort { out pulse : RFPulse; }
        port def RFInPort { in pulse : RFPulse; }
        port def AnalogOutPort { out signal : AnalogMRSignal; }
        port def AnalogInPort { in signal : AnalogMRSignal; }
        port def DigitalOutPort { out data : DigitalMRSignal; }
        port def DigitalInPort { in data : DigitalMRSignal; }
        port def ImageOutPort { out image : MRImage; }
        port def ImageInPort { in image : MRImage; }
        port def GradOutPort { out cmd : GradientCommand; }
        port def MagFieldOutPort { out field : MagneticFieldStrength; }
        port def TableCmdPort { in cmd : TablePositionCommand; }
        port def TableStatusPort { out status : TablePositionStatus; }

        part def SuperconductingMagnet {
            attribute fieldStrength : MagneticFieldStrength = 3.0 [SI::T];
            port cryoStatusIn : CryoInPort;
            port magFieldOut : MagFieldOutPort;
        }

        part def CryogenicCoolingSystem {
            attribute operatingTemp : TemperatureValue = 4.2 [SI::K];
            port cryoStatusOut : CryoOutPort;
        }

        part def PatientPositioningTable {
            port controlIn : TableCmdPort;
            port statusOut : TableStatusPort;
        }

        part def ScanControlComputer {
            port protocolIn : ProtocolInPort;
            port rfControlOut : ControlPort;
            port gradControlOut : ControlPort;
            port tableControlOut : TableCmdPort;
            port tableStatusIn : TableStatusPort;
            port imageIn : ImageInPort;
        }

        part def RFTransmitSystem {
            port controlIn : ControlPort;
            port rfOut : RFOutPort;
        }

        part def GradientCoilSystem {
            port controlIn : ControlPort;
            port gradXOut : GradOutPort;
            port gradYOut : GradOutPort;
            port gradZOut : GradOutPort;
        }

        part def RFReceiveSystem {
            port rfIn : RFInPort;
            port signalOut : AnalogOutPort;
        }

        part def SignalProcessingUnit {
            port signalIn : AnalogInPort;
            port dataOut : DigitalOutPort;
        }

        part def ImageReconstructionProcessor {
            port dataIn : DigitalInPort;
            port imageOut : ImageOutPort;
        }

        part def OperatorConsole {
            port imageIn : ImageInPort;
            port protocolOut : ProtocolOutPort;
        }

        part def MRISystem {
            part superconductingMagnet : SuperconductingMagnet;
            part cryoSystem : CryogenicCoolingSystem;
            part patientTable : PatientPositioningTable;
            part computer : ScanControlComputer;
            part rfTransmit : RFTransmitSystem;
            part gradientCoils : GradientCoilSystem;
            part rfReceive : RFReceiveSystem;
            part signalProcessor : SignalProcessingUnit;
            part imageProcessor : ImageReconstructionProcessor;
            part console : OperatorConsole;

            connect cryoSystem.cryoStatusOut to superconductingMagnet.cryoStatusIn;
            connect console.protocolOut to computer.protocolIn;
            connect computer.rfControlOut to rfTransmit.controlIn;
            connect computer.gradControlOut to gradientCoils.controlIn;
            connect computer.tableControlOut to patientTable.controlIn;
            connect patientTable.statusOut to computer.tableStatusIn;
            connect rfTransmit.rfOut to rfReceive.rfIn;
            connect rfReceive.signalOut to signalProcessor.signalIn;
            connect signalProcessor.dataOut to imageProcessor.dataIn;
            connect imageProcessor.imageOut to computer.imageIn;
        }

        action def 'Perform MR Scan' {
            in protocol : ScanProtocol;
            out image : MRImage;

            action 'Position Patient' {
                in cmd : TablePositionCommand;
                out patientReady : TablePositionStatus;
            }
            action 'Excite Nuclei' {
                in cmd : ControlSignal;
                out rfPulse : RFPulse;
            }
            action 'Spatially Encode' {
                in cmd : ControlSignal;
                out gradCmd : GradientCommand;
            }
            action 'Acquire Signal' {
                in rfPulse : RFPulse;
                in gradCmd : GradientCommand;
                out analogSignal : AnalogMRSignal;
            }
            action 'Digitize Signal' {
                in analogSignal : AnalogMRSignal;
                out digitalData : DigitalMRSignal;
            }
            action 'Reconstruct Image' {
                in digitalData : DigitalMRSignal;
                out reconstructedImage : MRImage;
            }

            flow 'Excite Nuclei'.rfPulse to 'Acquire Signal'.rfPulse;
            flow 'Spatially Encode'.gradCmd to 'Acquire Signal'.gradCmd;
            flow 'Acquire Signal'.analogSignal to 'Digitize Signal'.analogSignal;
            flow 'Digitize Signal'.digitalData to 'Reconstruct Image'.digitalData;

            bind image = 'Reconstruct Image'.reconstructedImage;

            first 'Position Patient' then 'Excite Nuclei';
            first 'Excite Nuclei' then 'Spatially Encode';
            first 'Spatially Encode' then 'Acquire Signal';
            first 'Acquire Signal' then 'Digitize Signal';
            first 'Digitize Signal' then 'Reconstruct Image';
        }

        state machine def 'MRI Operating States' {
            state 'Idle';
            state 'Scanning';
            state 'Cryogenic Maintenance';
            transition from 'Idle' to 'Scanning' when protocolReceived;
            transition from 'Scanning' to 'Idle' when scanComplete;
            transition from 'Idle' to 'Cryogenic Maintenance' when cryoLevelLow;
            transition from 'Cryogenic Maintenance' to 'Idle' when cryoLevelNormal;
        }
    }

    package Usages {
        private import Definitions::*;

        part mriSystemInstance : MRISystem;
    }

    package Requirements {
        private import Definitions::*;

        requirement def 'Magnetic Field Requirement' {
            doc "The superconducting magnet must generate a strong, stable static magnetic field.";
            subject magnet : SuperconductingMagnet;
            constraint { magnet.fieldStrength >= 1.5 [SI::T] }
        }

        requirement def 'Cryogenic Requirement' {
            doc "The cooling system must maintain the magnet at extremely low temperatures.";
            subject cooler : CryogenicCoolingSystem;
            constraint { cooler.operatingTemp <= 4.2 [SI::K] }
        }

        requirement def 'Image Resolution Requirement' {
            doc "The system must generate high-resolution cross-sectional images.";
            subject image : MRImage;
        }
    }
}
