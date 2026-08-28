package UltrasoundBoneFractureSystem {
    private import ISQ::*;
    private import ScalarValues::*;
    public import Definitions::*;

    package Definitions {
        attribute def Frequency :> ISQ::FrequencyValue;
        attribute def Power :> ISQ::PowerValue;
        attribute def Length :> ISQ::LengthValue;

        item def AcousticWave {
            attribute frequency : Frequency;
        }
        item def EchoSignal;
        item def ProcessedSignal;
        item def ImageData {
            attribute frameRate : Frequency;
        }
        item def DiagnosticReport {
            attribute fractureLocation : String;
            attribute fractureSize : Length;
            attribute confidenceScore : Real;
        }

        attribute def ControlCommand {
            attribute kind : String;
        }
        attribute def BeamControlCommand;

        port def BeamControlPort { out beamCmd : BeamControlCommand; }
        port def EchoPort { out echo : EchoSignal; }
        port def SignalPort { out signal : ProcessedSignal; }
        port def ImagePort { out image : ImageData; }
        port def ReportPort { out report : DiagnosticReport; }
        port def ControlPort { out cmd : ControlCommand; }
        port def PowerPort { out power : Power; }

        part def UltrasoundProbe {
            port beamControlIn : ~BeamControlPort;
            port echoOut : EchoPort;
            port powerIn : ~PowerPort;
            part transducerArray;
        }

        part def BeamFormer {
            port controlIn : ~ControlPort;
            port beamControlOut : BeamControlPort;
            port powerIn : ~PowerPort;
        }

        part def SignalProcessingUnit {
            port echoIn : ~EchoPort;
            port signalOut : SignalPort;
            port powerIn : ~PowerPort;
        }

        part def ImageReconstructionEngine {
            port signalIn : ~SignalPort;
            port imageOut : ImagePort;
            port powerIn : ~PowerPort;
        }

        part def FractureDetectionAlgorithm {
            port imageIn : ~ImagePort;
            port reportOut : ReportPort;
            port powerIn : ~PowerPort;
        }

        part def ControlConsole {
            port controlOut : ControlPort;
            port powerIn : ~PowerPort;
        }

        part def DisplayMonitor {
            port imageIn : ~ImagePort;
            port reportIn : ~ReportPort;
            port powerIn : ~PowerPort;
        }

        part def PowerManagementUnit {
            port powerOut : PowerPort;
        }

        action def FocusAndSteer {
            in cmd : ControlCommand;
            out beamCmd : BeamControlCommand;
        }
        action def TransmitAndReceive {
            in beamCmd : BeamControlCommand;
            out echo : EchoSignal;
        }
        action def FilterAndAmplify {
            in echo : EchoSignal;
            out signal : ProcessedSignal;
        }
        action def ReconstructImage {
            in signal : ProcessedSignal;
            out image : ImageData;
        }
        action def AnalyzeFracture {
            in image : ImageData;
            out report : DiagnosticReport;
        }

        action def ScanProcess {
            in controlSignal : ControlCommand;
            out diagnosticReport : DiagnosticReport;

            action focus : FocusAndSteer {
                in cmd = controlSignal;
                out beamCmd : BeamControlCommand;
            }
            action transmitReceive : TransmitAndReceive {
                in beamCmd = focus.beamCmd;
                out echo : EchoSignal;
            }
            flow transmitReceive.echo to process.echo;
            action process : FilterAndAmplify {
                in echo : EchoSignal;
                out signal : ProcessedSignal;
            }
            flow process.signal to reconstruct.signal;
            action reconstruct : ReconstructImage {
                in signal : ProcessedSignal;
                out image : ImageData;
            }
            flow reconstruct.image to analyze.image;
            action analyze : AnalyzeFracture {
                in image : ImageData;
                out report : DiagnosticReport;
            }
        }

        state def SystemOperation {
            entry; then Standby;
            state Standby;
            state Calibration;
            state ActiveScanning;
            state Analysis;
            state Reporting;

            transition first Standby accept startCalibration : ControlCommand then Calibration;
            transition first Calibration accept calibrationComplete : ControlCommand then Standby;
            transition first Calibration accept startScan : ControlCommand then ActiveScanning;
            transition first ActiveScanning accept scanComplete : ControlCommand then Analysis;
            transition first Analysis then Reporting;
            transition first Reporting accept reset : ControlCommand then Standby;
        }

        requirement def NonInvasiveDetection {
            text = "The system shall provide non-invasive detection and analysis of bone fractures as an alternative to X-rays.";
        }
        requirement def RealTimeImaging {
            text = "The system shall generate real-time two-dimensional visual images of bone and surrounding tissues.";
            attribute minFrameRate : Frequency = 20.0;
        }
        requirement def AIFractureDetection {
            text = "The system shall include an AI-based algorithm to identify fracture location and size with a confidence score.";
            attribute minConfidence : Real = 0.9;
        }
        requirement def PointOfCare {
            text = "The system shall operate as a rapid, point-of-care diagnostic tool.";
        }
        requirement def PowerDistribution {
            text = "The Power Management Unit shall distribute electrical power to all system components.";
        }
    }

    package Usages {
        private import Definitions::*;

        part ultrasoundSystem {
            part powerManagementUnit : PowerManagementUnit {
                port powerOut : PowerPort;
            }
            part controlConsole : ControlConsole {
                port controlOut : ControlPort;
                port powerIn : ~PowerPort;
            }
            part ultrasoundProbe : UltrasoundProbe {
                port beamControlIn : ~BeamControlPort;
                port echoOut : EchoPort;
                port powerIn : ~PowerPort;
                part transducerArray;
            }
            part beamFormer : BeamFormer {
                port controlIn : ~ControlPort;
                port beamControlOut : BeamControlPort;
                port powerIn : ~PowerPort;
            }
            part signalProcessingUnit : SignalProcessingUnit {
                port echoIn : ~EchoPort;
                port signalOut : SignalPort;
                port powerIn : ~PowerPort;
            }
            part imageReconstructionEngine : ImageReconstructionEngine {
                port signalIn : ~SignalPort;
                port imageOut : ImagePort;
                port powerIn : ~PowerPort;
            }
            part fractureDetectionAlgorithm : FractureDetectionAlgorithm {
                port imageIn : ~ImagePort;
                port reportOut : ReportPort;
                port powerIn : ~PowerPort;
            }
            part displayMonitor : DisplayMonitor {
                port imageIn : ~ImagePort;
                port reportIn : ~ReportPort;
                port powerIn : ~PowerPort;
            }

            connect powerManagementUnit.powerOut to controlConsole.powerIn;
            connect powerManagementUnit.powerOut to ultrasoundProbe.powerIn;
            connect powerManagementUnit.powerOut to beamFormer.powerIn;
            connect powerManagementUnit.powerOut to signalProcessingUnit.powerIn;
            connect powerManagementUnit.powerOut to imageReconstructionEngine.powerIn;
            connect powerManagementUnit.powerOut to fractureDetectionAlgorithm.powerIn;
            connect powerManagementUnit.powerOut to displayMonitor.powerIn;

            connect controlConsole.controlOut to beamFormer.controlIn;
            connect beamFormer.beamControlOut to ultrasoundProbe.beamControlIn;
            connect ultrasoundProbe.echoOut to signalProcessingUnit.echoIn;
            connect signalProcessingUnit.signalOut to imageReconstructionEngine.signalIn;
            connect imageReconstructionEngine.imageOut to fractureDetectionAlgorithm.imageIn;
            connect imageReconstructionEngine.imageOut to displayMonitor.imageIn;
            connect fractureDetectionAlgorithm.reportOut to displayMonitor.reportIn;

            action scan : ScanProcess {
                in controlSignal : ControlCommand;
                out diagnosticReport : DiagnosticReport;
            }

            state systemState : SystemOperation;
        }

        requirement nonInvasiveReq : NonInvasiveDetection;
        requirement realTimeReq : RealTimeImaging;
        requirement aiReq : AIFractureDetection;
        requirement pocReq : PointOfCare;
        requirement powerReq : PowerDistribution;

        satisfy nonInvasiveReq by ultrasoundSystem;
        satisfy realTimeReq by ultrasoundSystem.imageReconstructionEngine;
        satisfy aiReq by ultrasoundSystem.fractureDetectionAlgorithm;
        satisfy pocReq by ultrasoundSystem;
        satisfy powerReq by ultrasoundSystem.powerManagementUnit;
    }
}
