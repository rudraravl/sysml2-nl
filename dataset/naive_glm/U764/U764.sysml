package MRI_System_Model {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    package ValueTypes {
        value type MagneticFluxDensity :> Real {
            :> ISQ::MagneticFluxDensity;
            unit tesla;
        }

        value type Temperature :> Real {
            :> ISQ::ThermodynamicTemperature;
            unit kelvin;
        }

        value type Frequency :> Real {
            :> ISQ::Frequency;
            unit hertz;
        }

        value type Power :> Real {
            :> ISQ::Power;
            unit watt;
        }

        value type ElectricCurrent :> Real {
            :> ISQ::ElectricCurrent;
            unit ampere;
        }

        value type Voltage :> Real {
            :> ISQ::Voltage;
            unit volt;
        }

        value type Distance :> Real {
            :> ISQ::Length;
            unit metre;
        }

        value type Duration :> Real {
            :> ISQ::Time;
            unit second;
        }

        value type FieldStabilityPPM :> Real;

        value type ComplexValue {
            attribute re : Real;
            attribute im : Real;
        }
    }

    package Items {
        item def Patient {
            attribute patientId : String;
            attribute weight : Real;
            attribute studyType : String;
        }

        item def ScanProtocol {
            attribute name : String;
            attribute sliceThickness : Distance;
            attribute sliceCount : Integer;
            attribute repetitionTime : Duration;
            attribute echoTime : Duration;
            attribute flipAngle : Real;
            attribute fieldOfView : Distance;
        }

        item def RFExcitationPulse {
            attribute centerFrequency : Frequency;
            attribute amplitude : Power;
            attribute duration : Duration;
            attribute flipAngle : Real;
        }

        item def MRSignal {
            attribute amplitude : Voltage;
            attribute phase : Real;
            attribute centerFrequency : Frequency;
            attribute bandwidth : Frequency;
        }

        item def DigitizedSignal {
            attribute samples : ComplexValue[0..*];
            attribute samplingRate : Frequency;
            attribute duration : Duration;
        }

        item def KSpaceLine {
            attribute kxValues : ComplexValue[0..*];
            attribute kyIndex : Integer;
            attribute kzIndex : Integer;
            attribute readoutTime : Duration;
        }

        item def KSpaceData {
            attribute lines : KSpaceLine[0..*];
            attribute matrixX : Integer;
            attribute matrixY : Integer;
            attribute matrixZ : Integer;
        }

        item def ImageSlice {
            attribute sliceNumber : Integer;
            attribute pixels : ComplexValue[0..*];
            attribute width : Integer;
            attribute height : Integer;
            attribute sliceThickness : Distance;
            attribute positionZ : Distance;
        }

        item def DiagnosticImage {
            attribute slices : ImageSlice[0..*];
            attribute protocolName : String;
            attribute acquisitionTime : Duration;
        }

        item def ControlCommand {
            attribute commandType : String;
            attribute parameters : String;
            attribute timestamp : Duration;
        }

        item def StatusReport {
            attribute subsystemName : String;
            attribute status : String;
            attribute timestamp : Duration;
            attribute isError : Boolean;
        }

        item def GradientCommand {
            attribute axisXAmplitude : ElectricCurrent;
            attribute axisYAmplitude : ElectricCurrent;
            attribute axisZAmplitude : ElectricCurrent;
            attribute duration : Duration;
            attribute rampTime : Duration;
        }

        item def TemperatureReading {
            attribute value : Temperature;
            attribute location : String;
            attribute timestamp : Duration;
        }
    }

    package Ports {
        port def ControlInPort {
            in command : ControlCommand;
        }
        port def ControlOutPort {
            out command : ControlCommand;
        }
        port def StatusInPort {
            in status : StatusReport;
        }
        port def StatusOutPort {
            out status : StatusReport;
        }
        port def PatientFlowInPort {
            in patient : Patient;
        }
        port def PatientFlowOutPort {
            out patient : Patient;
        }
        port def ProtocolInPort {
            in protocol : ScanProtocol;
        }
        port def ProtocolOutPort {
            out protocol : ScanProtocol;
        }
        port def RFOutPort {
            out pulse : RFExcitationPulse;
        }
        port def BoreRFInPort {
            in pulse : RFExcitationPulse;
        }
        port def BoreMROutPort {
            out signal : MRSignal;
        }
        port def MRSignalInPort {
            in signal : MRSignal;
        }
        port def MRSignalOutPort {
            out signal : MRSignal;
        }
        port def KSpaceOutPort {
            out data : KSpaceData;
        }
        port def KSpaceInPort {
            in data : KSpaceData;
        }
        port def ImageOutPort {
            out image : DiagnosticImage;
        }
        port def ImageInPort {
            in image : DiagnosticImage;
        }
        port def GradientOutPort {
            out gradient : GradientCommand;
        }
        port def GradientInPort {
            in gradient : GradientCommand;
        }
        port def TempOutPort {
            out reading : TemperatureReading;
        }
        port def TempInPort {
            in reading : TemperatureReading;
        }
    }

    package Behaviors {
        action def ScanSequenceAction {
            in protocol : ScanProtocol;
            action loadProtocol;
            action sendRFExcitation;
            action applyGradients;
            action acquireMRSignal;
            action processSignal;
            action reconstructImage;
            action displayImage;
            succession loadProtocol then sendRFExcitation;
            succession sendRFExcitation then applyGradients;
            succession applyGradients then acquireMRSignal;
            succession acquireMRSignal then processSignal;
            succession processSignal then reconstructImage;
            succession reconstructImage then displayImage;
        }

        state def CryogenicSystemStates {
            attribute targetTemperature : Temperature = 4.2;
            attribute currentTemperature : Temperature;
            state Initializing;
            state Cooling;
            state Stable;
            state Alarm;
            succession from Initializing to Cooling when currentTemperature < 300;
            succession from Cooling to Stable when currentTemperature <= 4.5;
            succession from Stable to Cooling when currentTemperature > 4.5;
            succession from Stable to Alarm when currentTemperature > 6.0;
            succession from Cooling to Alarm when currentTemperature > 6.0;
            succession from Alarm to Cooling when currentTemperature < 4.5;
        }

        state def ScanControllerStates {
            attribute scanStarted : Boolean = false;
            attribute protocolLoaded : Boolean = false;
            attribute acquisitionComplete : Boolean = false;
            attribute reconstructionComplete : Boolean = false;
            attribute userAcknowledged : Boolean = false;
            attribute systemError : Boolean = false;
            attribute errorCleared : Boolean = false;
            state Idle;
            state Preparing;
            state Scanning;
            state Reconstructing;
            state Complete;
            state Fault;
            succession from Idle to Preparing when scanStarted;
            succession from Preparing to Scanning when protocolLoaded;
            succession from Scanning to Reconstructing when acquisitionComplete;
            succession from Reconstructing to Complete when reconstructionComplete;
            succession from Complete to Idle when userAcknowledged;
            succession from Idle to Fault when systemError;
            succession from Fault to Idle when errorCleared;
        }
    }

    package Requirements {
        requirement def MagneticFieldStability {
            doc {
                The superconducting magnet shall maintain the static magnetic field
                with temporal stability of less than 0.1 ppm per hour during operation.
            }
            attribute maxDriftPpm : FieldStabilityPPM = 0.1;
        }

        requirement def CryogenicTemperatureRange {
            doc {
                The cryogenic cooling system shall maintain the superconducting magnet
                at temperatures below 4.5 K during normal operation.
            }
            attribute maxOperatingTemp : Temperature = 4.5;
        }

        requirement def ImageResolutionRequirement {
            doc {
                The MRI system shall produce diagnostic images with spatial resolution
                of at least 256x256 pixels per slice.
            }
            attribute minPixelsX : Integer = 256;
            attribute minPixelsY : Integer = 256;
        }

        requirement def ScanCoordinationRequirement {
            doc {
                The scan control computer shall coordinate RF excitation, gradient
                application, and signal acquisition with microsecond timing precision.
            }
            attribute timingPrecision : Duration = 1.0e-6;
        }

        requirement def SignalDetectionRequirement {
            doc {
                The RF receive system shall detect MR signals with amplitudes as low
                as 1 microvolt within the Larmor frequency band.
            }
            attribute minDetectableAmplitude : Voltage = 1.0e-6;
        }

        requirement def PatientPositioningRequirement {
            doc {
                The patient positioning table shall move the patient into the magnet
                bore with smooth motion and emergency stop capability.
            }
            attribute maxStroke : Distance = 1.6;
        }
    }

    package SystemParts {
        part def SuperconductingMagnet {
            attribute nominalFieldStrength : MagneticFluxDensity = 3.0;
            attribute boreDiameter : Distance = 0.6;
            attribute fieldStability : FieldStabilityPPM = 0.1;
            attribute isEnergized : Boolean = false;
            port controlIn : ControlInPort;
            port statusOut : StatusOutPort;
            port tempIn : TempInPort;
            port boreRfIn : BoreRFInPort;
            port boreMrOut : BoreMROutPort;
            port patientIn : PatientFlowInPort;
            action energize {
                assign isEnergized := true;
            }
            action rampDown {
                assign isEnergized := false;
            }
        }

        part def CryogenicCoolingSystem {
            attribute targetTemperature : Temperature = 4.2;
            attribute currentTemperature : Temperature;
            attribute coolantLevel : Real;
            attribute compressorRunning : Boolean = false;
            port controlIn : ControlInPort;
            port statusOut : StatusOutPort;
            port tempOut : TempOutPort;
            state machine coolingStates : CryogenicSystemStates;
            action startCompressor {
                assign compressorRunning := true;
            }
            action stopCompressor {
                assign compressorRunning := false;
            }
            action refillCoolant {
            }
        }

        part def PatientPositioningTable {
            attribute currentPosition : Distance = 0.0;
            attribute maxStroke : Distance = 1.6;
            attribute speed : Real = 0.05;
            attribute isMoving : Boolean = false;
            port patientIn : PatientFlowInPort;
            port patientOut : PatientFlowOutPort;
            port controlIn : ControlInPort;
            port statusOut : StatusOutPort;
            action moveIntoBore(distance : Distance) {
                assign currentPosition := currentPosition + distance;
                assign isMoving := true;
            }
            action moveToHome {
                assign currentPosition := 0.0;
            }
            action emergencyStop {
                assign isMoving := false;
            }
        }

        part def ScanControlComputer {
            attribute currentProtocol : ScanProtocol;
            attribute scanInProgress : Boolean = false;
            attribute sequenceCount : Integer = 0;
            port protocolIn : ProtocolInPort;
            port controlOut : ControlOutPort;
            port statusIn : StatusInPort;
            port statusOut : StatusOutPort;
            state machine scanStates : ScanControllerStates;
            action loadProtocol(protocol : ScanProtocol) {
                assign currentProtocol := protocol;
            }
            action beginScan {
                assign scanInProgress := true;
            }
            action endScan {
                assign scanInProgress := false;
            }
            action executeScanSequence : ScanSequenceAction;
        }

        part def RFTransmitSystem {
            attribute centerFrequency : Frequency = 127.7e6;
            attribute peakPower : Power = 30.0;
            attribute amplifierGain : Real = 1.0;
            attribute isEnabled : Boolean = false;
            port controlIn : ControlInPort;
            port statusOut : StatusOutPort;
            port rfOut : RFOutPort;
            action transmitPulse(pulse : RFExcitationPulse) {
            }
            action enable {
                assign isEnabled := true;
            }
            action disable {
                assign isEnabled := false;
            }
        }

        part def GradientCoil {
            attribute maxCurrent : ElectricCurrent = 200.0;
            attribute currentAmplitude : ElectricCurrent = 0.0;
            action applyCurrent(current : ElectricCurrent) {
                assign currentAmplitude := current;
            }
        }

        part def GradientCoilSystem {
            part xCoil : GradientCoil;
            part yCoil : GradientCoil;
            part zCoil : GradientCoil;
            port controlIn : ControlInPort;
            port statusOut : StatusOutPort;
            port gradientOut : GradientOutPort;
            action applyGradientCommand(cmd : GradientCommand) {
            }
        }

        part def RFReceiveSystem {
            attribute centerFrequency : Frequency;
            attribute bandwidth : Frequency;
            attribute gain : Real = 1.0;
            attribute noiseFigure : Real = 0.5;
            attribute isEnabled : Boolean = false;
            port controlIn : ControlInPort;
            port statusOut : StatusOutPort;
            port signalIn : MRSignalInPort;
            port signalOut : MRSignalOutPort;
            action acquireSignal {
                in analogSignal : MRSignal;
                out amplified : MRSignal;
            }
            action enable {
                assign isEnabled := true;
            }
        }

        part def SignalProcessingUnit {
            attribute samplingRate : Frequency = 1.0e6;
            attribute isProcessing : Boolean = false;
            attribute transformType : String = "FFT";
            port controlIn : ControlInPort;
            port statusOut : StatusOutPort;
            port signalIn : MRSignalInPort;
            port kspaceOut : KSpaceOutPort;
            action digitizeAnalog {
                in input : MRSignal;
                out digitized : DigitizedSignal;
            }
            action applyFourierTransform {
                in input : DigitizedSignal;
                out kspaceData : KSpaceData;
            }
            action reset {
                assign isProcessing := false;
            }
        }

        part def ImageReconstructionProcessor {
            attribute isReconstructing : Boolean = false;
            attribute reconstructionAlgorithm : String = "FFT";
            attribute sliceCount : Integer = 0;
            port controlIn : ControlInPort;
            port statusOut : StatusOutPort;
            port kspaceIn : KSpaceInPort;
            port imageOut : ImageOutPort;
            action reconstruct {
                in sliceCount2 : Integer;
                out image : DiagnosticImage;
            }
            action beginReconstruction {
                assign isReconstructing := true;
            }
            action completeReconstruction {
                assign isReconstructing := false;
            }
        }

        part def OperatorConsole {
            attribute displayBuffer : DiagnosticImage;
            attribute currentUser : String;
            attribute selectedProtocol : ScanProtocol;
            port protocolOut : ProtocolOutPort;
            port imageIn : ImageInPort;
            port controlOut : ControlOutPort;
            port statusIn : StatusInPort;
            action selectScanProtocol(name : String) {
                out protocol : ScanProtocol;
            }
            action displayImage(img : DiagnosticImage) {
                assign displayBuffer := img;
            }
            action acknowledgeComplete {
            }
        }

        part def MRISystem {
            doc {
                The Magnetic Resonance Imaging System integrates all subsystems for
                diagnostic imaging of patient anatomy using nuclear magnetic resonance.
                The system excites hydrogen nuclei via RF pulses, spatially encodes the
                emitted signals with gradient coils, acquires and processes the signals,
                and reconstructs detailed cross-sectional images for diagnosis.
            }
            attribute systemName : String = "MRI-1";
            attribute isOperational : Boolean = false;

            part superconductingMagnet : SuperconductingMagnet;
            part cryogenicCoolingSystem : CryogenicCoolingSystem;
            part patientTable : PatientPositioningTable;
            part scanControlComputer : ScanControlComputer;
            part rfTransmitSystem : RFTransmitSystem;
            part gradientCoilSystem : GradientCoilSystem;
            part rfReceiveSystem : RFReceiveSystem;
            part signalProcessingUnit : SignalProcessingUnit;
            part imageReconstructionProcessor : ImageReconstructionProcessor;
            part operatorConsole : OperatorConsole;

            flow of Patient from patientTable.patientOut to superconductingMagnet.patientIn;
            flow of TemperatureReading from cryogenicCoolingSystem.tempOut to superconductingMagnet.tempIn;

            connection scanControlComputer.controlOut to superconductingMagnet.controlIn;
            connection scanControlComputer.controlOut to cryogenicCoolingSystem.controlIn;
            connection scanControlComputer.controlOut to patientTable.controlIn;
            connection scanControlComputer.controlOut to rfTransmitSystem.controlIn;
            connection scanControlComputer.controlOut to gradientCoilSystem.controlIn;
            connection scanControlComputer.controlOut to rfReceiveSystem.controlIn;
            connection scanControlComputer.controlOut to signalProcessingUnit.controlIn;
            connection scanControlComputer.controlOut to imageReconstructionProcessor.controlIn;

            connection superconductingMagnet.statusOut to scanControlComputer.statusIn;
            connection cryogenicCoolingSystem.statusOut to scanControlComputer.statusIn;
            connection patientTable.statusOut to scanControlComputer.statusIn;
            connection rfTransmitSystem.statusOut to scanControlComputer.statusIn;
            connection gradientCoilSystem.statusOut to scanControlComputer.statusIn;
            connection rfReceiveSystem.statusOut to scanControlComputer.statusIn;
            connection signalProcessingUnit.statusOut to scanControlComputer.statusIn;
            connection imageReconstructionProcessor.statusOut to scanControlComputer.statusIn;

            connection operatorConsole.protocolOut to scanControlComputer.protocolIn;
            connection scanControlComputer.statusOut to operatorConsole.statusIn;

            flow of RFExcitationPulse from rfTransmitSystem.rfOut to superconductingMagnet.boreRfIn;
            flow of MRSignal from superconductingMagnet.boreMrOut to rfReceiveSystem.signalIn;

            connection rfReceiveSystem.signalOut to signalProcessingUnit.signalIn;
            flow of KSpaceData from signalProcessingUnit.kspaceOut to imageReconstructionProcessor.kspaceIn;
            connection imageReconstructionProcessor.imageOut to operatorConsole.imageIn;

            satisfy MagneticFieldStability by superconductingMagnet;
            satisfy CryogenicTemperatureRange by cryogenicCoolingSystem;
            satisfy ImageResolutionRequirement by imageReconstructionProcessor;
            satisfy ScanCoordinationRequirement by scanControlComputer;
            satisfy SignalDetectionRequirement by rfReceiveSystem;
            satisfy PatientPositioningRequirement by patientTable;
        }
    }
}
