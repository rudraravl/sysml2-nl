package fMRISystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types ----
    value def MagneticFieldStrength :> Real { unit 'T'; }
    value def Frequency :> Real { unit 'MHz'; }
    value def Voltage :> Real { unit 'uV'; }
    value def ElectricCurrent :> Real {> Real { unit 'A'; }
    value def Temperature :> Real { unit 'K'; }
    value def Duration :> Real { unit 's'; }
    value def Distance :> Real { unit 'mm'; }
    value def Power :> Real { unit 'W'; }
    value def DataRate :> Real { unit 'MB/s'; }
    value def SignalToNoiseRatio :> Real { unit '1'; }
    value def FlipAngle :> Real { unit 'deg'; }

    // ---- Item Definitions ----
    item def RawMRSignal {
        attribute frequency : Frequency;
        attribute amplitude : Voltage;
        attribute channel : Integer;
        attribute acquisitionTime : Duration;
    }

    item def DigitizedKSpaceData {
        attribute kx : Real;
        attribute ky : Real;
        attribute kz : Real;
        attribute magnitude : Real;
        attribute phase : Real;
        attribute channel : Integer;
        attribute volumeIndex : Integer;
    }

    item def ImageVolume {
        attribute voxelData : Real[*];
        attribute dimensions : Integer[3];
        attribute voxelSize : Distance[3];
        attribute timestamp : Duration;
        attribute volumeIndex : Integer;
    }

    item def TimeSeriesImages {
        attribute volumes : ImageVolume[0..*] ordered;
        attribute repetitionTime : Duration;
        attribute numberOfVolumes : Integer;
    }

    item def FunctionalMap {
        attribute activationValues : Real[*];
        attribute statisticalThreshold : Real;
        attribute tStatistics : Real[*];
        attribute pValues : Real[*];
        attribute anatomicalOverlay : ImageVolume;
    }

    item def ScanProtocol {
        attribute sliceThickness : Distance;
        attribute numberOfSlices : Integer;
        attribute repetitionTime : Duration;
        attribute echoTime : Duration;
        attribute flipAngle : FlipAngle;
        attribute fieldOfView : Distance[2];
        attribute matrixSize : Integer[2];
        attribute taskParadigm : String;
        attribute numberOfVolumes : Integer;
    }

    item def ShimParameters {
        attribute coefficients : Real[*];
        attribute targetUniformity : MagneticFieldStrength;
    }

    item def GradientWaveform {
        attribute xGradient : Real[*];
        attribute yGradient : Real[*];
        attribute zGradient : Real[*];
        attribute duration : Duration;
    }

    item def RFPulse {
        attribute centerFrequency : Frequency;
        attribute amplitude : Power;
        attribute duration : Duration;
        attribute flipAngle : FlipAngle;
        attribute sliceSelectGradient : GradientWaveform;
    }

    // ---- Port Definitions ----
    port def MagneticFieldPort {
        out attribute fieldStrength : MagneticFieldStrength;
        out attribute uniformity : MagneticFieldStrength;
    }

    port def RFTransmitPort {
        out item pulse : RFPulse;
    }

    port def RFReceivePort {
        in item signal : RawMRSignal;
    }

    port def DigitalDataPort {
        out item data : DigitizedKSpaceData;
    }

    port def ImageDataPort {
        out item image : ImageVolume;
    }

    port def TimeSeriesPort {
        out item series : TimeSeriesImages;
    }

    port def FunctionalMapPort {
        out item map : FunctionalMap;
    }

    port def ControlPort {
        in attribute command : String;
        in item protocol : ScanProtocol;
        out attribute status : String;
    }

    port def MechanicalMotionPort {
        out attribute position : Distance;
        out attribute velocity : Distance;
    }

    // ---- Part Definitions ----
    part def SuperconductingMagnet {
        attribute nominalField : MagneticFieldStrength = 3.0;
        attribute fieldStability : MagneticFieldStrength = 0.1e-6;
        attribute boreDiameter : Distance = 600;
        attribute operatingTemperature : Temperature = 4.2;
        attribute heliumLevel : Real = 100;
        port fieldOut : MagneticFieldPort;
    }

    part def ShimCoilSystem {
        attribute numberOfChannels : Integer = 16;
        attribute maxCurrent : ElectricCurrent = 10;
        port fieldCorrectionOut : MagneticFieldPort;
        port controlIn : ControlPort;
        action def PerformShimming {
            in params : ShimParameters;
            out correctedField : MagneticFieldStrength;
        }
        perform PerformShimming;
    }

    part def PatientTable {
        attribute maxLoad : Real = 200;
        attribute travelRange : Distance = 2000;
        attribute currentPosition : Distance = 0;
        port motionOut : MechanicalMotionPort;
        port controlIn : ControlPort;
        action def MovePatient {
            in targetPosition : Distance;
            out position : Distance;
        }
        perform MovePatient;
    }

    part def GradientCoilSystem {
        attribute maxGradientStrength : MagneticFieldStrength = 45e-3;
        attribute slewRate : MagneticFieldStrength = 200;
        attribute numberOfAxes : Integer = 3;
        port waveformOut : RFTransmitPort;
        port controlIn : ControlPort;
        action def GenerateGradients {
            in waveform : GradientWaveform;
            out xField : MagneticFieldStrength;
            out yField : MagneticFieldStrength;
            out zField : MagneticFieldStrength;
        }
        perform GenerateGradients;
    }

    part def RFTransmitCoil {
        attribute operatingFrequency : Frequency = 127.74;
        attribute peakPower : Power = 30000;
        attribute bandwidth : Frequency = 1.0;
        port rfOut : RFTransmitPort;
        port controlIn : ControlPort;
        action def TransmitPulse {
            in pulse : RFPulse;
            out emittedEnergy : Power;
        }
        perform TransmitPulse;
    }

    part def RFReceiveCoil {
        attribute numberOfChannels : Integer = 32;
        attribute sensitivity : Voltage = 0.1;
        attribute noiseFigure : Real = 0.5;
        port signalOut : RFReceivePort;
        action def ReceiveSignals {
            in nucleiRelaxation : RawMRSignal;
            out acquiredSignal : RawMRSignal;
        }
        perform ReceiveSignals;
    }

    part def SignalAmplifier {
        attribute gain : Real = 1000;
        attribute bandwidth : Frequency = 500;
        port signalIn : RFReceivePort;
        port signalOut : RFReceivePort;
        action def Amplify {
            in inputSignal : RawMRSignal;
            out amplifiedSignal : RawMRSignal;
        }
        perform Amplify;
    }

    part def Digitizer {
        attribute samplingRate : Frequency = 1000;
        attribute resolution : Integer = 16;
        attribute numberOfChannels : Integer = 32;
        port analogIn : RFReceivePort;
        port digitalOut : DigitalDataPort;
        action def Digitize {
            in analogSignal : RawMRSignal;
            out digitalData : DigitizedKSpaceData;
        }
        perform Digitize;
    }

    part def ImageReconstructor {
        attribute algorithm : String = "SENSE";
        attribute accelerationFactor : Integer = 4;
        attribute coilSensitivityMaps : Real[*];
        port dataIn : DigitalDataPort;
        port imageOut : ImageDataPort;
        action def ReconstructVolume {
            in kspaceData : DigitizedKSpaceData[*];
            out imageVolume : ImageVolume;
        }
        perform ReconstructVolume;
    }

    part def FunctionalAnalysisEngine {
        attribute statisticalModel : String = "General Linear Model";
        attribute significanceLevel : Real = 0.001;
        attribute motionCorrection : Boolean = true;
        attribute spatialSmoothing : Distance = 6;
        port seriesIn : TimeSeriesPort;
        port mapOut : FunctionalMapPort;
        action def AnalyzeTimeSeries {
            in series : TimeSeriesImages;
            in protocol : ScanProtocol;
            out functionalMap : FunctionalMap;
        }
        perform AnalyzeTimeSeries;
    }

    part def ControlConsole {
        attribute displayResolution : Integer[2] = [1920, 1200];
        attribute operatorInterface : String = "GUI";
        port controlOut : ControlPort;
        port mapIn : FunctionalMapPort;
        port imageIn : ImageDataPort;
        action def ManageScan {
            in protocol : ScanProtocol;
            out commands : String;
        }
        perform ManageScan;
    }

    part def Operator {
        attribute name : String;
        attribute role : String = "Technician";
        port consoleInterface : ControlPort;
    }

    part def Patient {
        attribute identifier : String;
        attribute headPosition : Distance = 0;
        attribute brainActivity : Boolean = true;
    }

    // ---- Top-level fMRI System ----
    part def fMRISystem {
        part magnet : SuperconductingMagnet;
        part shimCoils : ShimCoilSystem;
        part patientTable : PatientTable;
        part gradientSystem : GradientCoilSystem;
        part rfTransmit : RFTransmitCoil;
        part rfReceive : RFReceiveCoil;
        part amplifier : SignalAmplifier;
        part digitizer : Digitizer;
        part reconstructor : ImageReconstructor;
        part analysisEngine : FunctionalAnalysisEngine;
        part console : ControlConsole;
        part operator : Operator;
        part patient : Patient;

        connection magnet.fieldOut to shimCoils.fieldCorrectionOut;
        connection shimCoils.fieldCorrectionOut to gradientSystem.controlIn;
        connection gradientSystem.waveformOut to rfTransmit.rfOut;
        connection rfTransmit.rfOut to rfReceive.signalOut;
        connection rfReceive.signalOut to amplifier.signalIn;
        connection amplifier.signalOut to digitizer.analogIn;
        connection digitizer.digitalOut to reconstructor.dataIn;
        connection reconstructor.imageOut to analysisEngine.seriesIn;
        connection analysisEngine.mapOut to console.mapIn;
        connection console.controlOut to shimCoils.controlIn;
        connection console.controlOut to patientTable.controlIn;
        connection console.controlOut to gradientSystem.controlIn;
        connection console.controlOut to rfTransmit.controlIn;
        connection operator.consoleInterface to console.controlOut;
        connection patientTable.motionOut to patient.headPosition;

        // ---- State Machine ----
        state def fMRIOperation {
            entry; then standby;

            state standby {
                entry action { /* System idle, magnet energized, awaiting protocol */ }
                transition standby to calibration
                    when operator.consoleInterface.command == "startScan"
                    do action { console.controlOut.command := "beginCalibration"; }
            }

            state calibration {
                entry action {
                    shimCoils.PerformShimming(params := ShimParameters{coefficients := {0,0,0,0,0,0,0,0}; targetUniformity := 0.001;});
                }
                transition calibration to activeScanning
                    when shimCoils.controlIn.status == "shimComplete"
                    do action { console.controlOut.command := "beginScan"; }
            }

            state activeScanning {
                entry action {
                    gradientSystem.GenerateGradients(waveform := GradientWaveform{xGradient := {0}; yGradient := {0}; zGradient := {0}; duration := 0;});
                    rfTransmit.TransmitPulse(pulse := RFPulse{centerFrequency := 127.74; amplitude := 1000; duration := 0.001; flipAngle := 90; sliceSelectGradient := GradientWaveform{xGradient := {0}; yGradient := {0}; zGradient := {0}; duration := 0.001;};});
                    rfReceive.ReceiveSignals(nucleiRelaxation := RawMRSignal{frequency := 127.74; amplitude := 0.5; channel := 1; acquisitionTime := 0;});
                }
                do action {
                    amplifier.Amplify(inputSignal := rfReceive.signalOut.signal);
                    digitizer.Digitize(analogSignal := amplifier.signalOut.signal);
                    reconstructor.ReconstructVolume(kspaceData := {digitizer.digitalOut.data});
                }
                transition activeScanning to dataProcessing
                    when reconstructor.imageOut.image.volumeIndex == patient.numberOfVolumes
                    do action { console.controlOut.status := "scanComplete"; }
            }

            state dataProcessing {
                entry action {
                    analysisEngine.AnalyzeTimeSeries(series := TimeSeriesImages{volumes := {reconstructor.imageOut.image}; repetitionTime := 2.0; numberOfVolumes := patient.numberOfVolumes;}, protocol := console.controlOut.protocol);
                }
                transition dataProcessing to completion
                    when analysisEngine.mapOut.map != null
                    do action { console.controlOut.status := "processingComplete"; }
            }

            state completion {
                entry action { /* Display functional map overlaid on anatomical image */ }
                transition completion to standby
                    when operator.consoleInterface.command == "reset"
                    do action { console.controlOut.command := "standby"; }
            }
        }

        perform fMRIOperation;

        // ---- Requirements ----
        requirement def MagneticFieldRequirement {
            subject magnet : SuperconductingMagnet;
            requirement :>> magnet.nominalField == 3.0 [MagneticFieldStrength];
            requirement :>> magnet.fieldStability <= 0.1e-6 [MagneticFieldStrength];
        }

        requirement def FieldUniformityRequirement {
            subject shimCoils : ShimCoilSystem;
            requirement :>> shimCoils.fieldCorrectionOut.uniformity <= 0.001 [MagneticFieldStrength];
        }

        requirement def ReceiveCoilRequirement {
            subject rfReceive : RFReceiveCoil;
            requirement :>> rfReceive.numberOfChannels == 32;
            requirement :>> rfReceive.sensitivity >= 0.1 [Voltage];
        }

        requirement def ReconstructionRequirement {
            subject reconstructor : ImageReconstructor;
            requirement :>> reconstructor.algorithm == "SENSE";
            requirement :>> reconstructor.accelerationFactor >= 4;
        }

        requirement def AnalysisRequirement {
            subject analysisEngine : FunctionalAnalysisEngine;
            requirement :>> analysisEngine.statisticalModel == "General Linear Model";
            requirement :>> analysisEngine.significanceLevel <= 0.001;
        }

        requirement def SystemFunctionalRequirement {
            subject system : fMRISystem;
            requirement :>> system.magnet.nominalField == 3.0 [MagneticFieldStrength];
            requirement :>> system.rfReceive.numberOfChannels == 32;
            requirement :>> system.reconstructor.algorithm == "SENSE";
            requirement :>> system.analysisEngine.statisticalModel == "General Linear Model";
            requirement :>> system.analysisEngine.mapOut.map != null;
        }

        satisfy MagneticFieldRequirement by magnet;
        satisfy FieldUniformityRequirement by shimCoils;
        satisfy ReceiveCoilRequirement by rfReceive;
        satisfy ReconstructionRequirement by reconstructor;
        satisfy AnalysisRequirement by analysisEngine;
        satisfy SystemFunctionalRequirement by fMRISystem;
    }
}
