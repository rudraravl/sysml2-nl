package MillimeterWaveScannerSystemModel {

    import ScalarValues::*;
    import Quantities::*;
    import MeasurementReferences::*;

    attribute def Frequency :> ScalarValues::Real;
    attribute def Power :> ScalarValues::Real;
    attribute def Time :> ScalarValues::Real;
    attribute def Length :> ScalarValues::Real;
    attribute def Angle :> ScalarValues::Real;
    attribute def Temperature :> ScalarValues::Real;
    attribute def DataRate :> ScalarValues::Real;
    attribute def Probability :> ScalarValues::Real;

    item def ElectricalPower {
        attribute voltage : ScalarValues::Real;
        attribute current : ScalarValues::Real;
        attribute power : Power;
    }

    item def MillimeterWaveSignal {
        attribute centerFrequency : Frequency;
        attribute bandwidth : Frequency;
        attribute transmitPower : Power;
        attribute polarization : String;
        attribute pulseDuration : Time;
    }

    item def ReflectedWaveSignal {
        attribute receivedPower : Power;
        attribute timeOfFlight : Time;
        attribute phaseShift : Angle;
        attribute antennaElementId : Integer;
    }

    item def ScanCommand {
        attribute scanMode : String;
        attribute subjectPresent : Boolean;
        attribute requestedResolution : Length;
        attribute maxScanDuration : Time;
    }

    item def ScannerStatus {
        attribute operationalState : String;
        attribute faultCode : String;
        attribute enclosureClosed : Boolean;
        attribute temperature : Temperature;
        attribute readyForScan : Boolean;
    }

    item def ImageVoxel {
        attribute x : Length;
        attribute y : Length;
        attribute z : Length;
        attribute reflectivity : ScalarValues::Real;
        attribute confidence : Probability;
    }

    item def VolumetricImage {
        attribute voxelCount : Integer;
        attribute spatialResolution : Length;
        attribute acquisitionTime : Time;
        part voxels : ImageVoxel[0..*];
    }

    item def ThreatFinding {
        attribute findingId : String;
        attribute materialClass : String;
        attribute probabilityOfThreat : Probability;
        attribute locationX : Length;
        attribute locationY : Length;
        attribute locationZ : Length;
        attribute boundingBoxWidth : Length;
        attribute boundingBoxHeight : Length;
        attribute boundingBoxDepth : Length;
    }

    item def ScanResult {
        attribute scanId : String;
        attribute cleared : Boolean;
        attribute operatorMessage : String;
        attribute processingLatency : Time;
        part image : VolumetricImage;
        part findings : ThreatFinding[0..*];
    }

    port def PowerInputPort {
        in item powerIn : ElectricalPower;
    }

    port def ControlPort {
        in item command : ScanCommand;
        out item status : ScannerStatus;
    }

    port def RadioTransmitPort {
        out item transmittedSignal : MillimeterWaveSignal;
    }

    port def RadioReceivePort {
        in item reflectedSignal : ReflectedWaveSignal;
    }

    port def ResultPort {
        out item result : ScanResult;
    }

    port def CoolingPort {
        out item heatLoad : Power;
        in item coolingCapacity : Power;
    }

    part def MillimeterWaveScannerSystem {
        attribute primaryFunction : String = "Scan a subject with low-power millimeter-wave radiation, reconstruct a volumetric reflectivity image, and identify concealed objects or anomalies for operator review.";
        attribute nominalScanDuration : Time = 2.5;
        attribute operatingFrequencyLow : Frequency = 24000000000.0;
        attribute operatingFrequencyHigh : Frequency = 30000000000.0;
        attribute maximumTransmitPower : Power = 0.01;
        attribute minimumDetectableObjectSize : Length = 0.005;
        attribute probabilityOfDetectionTarget : Probability = 0.95;
        attribute falseAlarmRateTarget : Probability = 0.05;

        port powerPort : PowerInputPort;
        port operatorControlPort : ControlPort;
        port resultPort : ResultPort;
        port thermalPort : CoolingPort;

        part scanController : ScanController;
        part rfSubsystem : RadioFrequencySubsystem;
        part antennaArray : AntennaArray;
        part subjectPositioner : SubjectPositioner;
        part signalProcessor : SignalProcessingComputer;
        part threatAnalyzer : ThreatAnalysisComputer;
        part operatorConsole : OperatorConsole;
        part safetySubsystem : SafetySubsystem;
        part thermalManager : ThermalManagementSubsystem;
        part enclosure : ScannerEnclosure;

        connect powerPort.powerIn to scanController.powerPort.powerIn;
        connect powerPort.powerIn to rfSubsystem.powerPort.powerIn;
        connect powerPort.powerIn to signalProcessor.powerPort.powerIn;
        connect powerPort.powerIn to threatAnalyzer.powerPort.powerIn;
        connect powerPort.powerIn to operatorConsole.powerPort.powerIn;
        connect powerPort.powerIn to thermalManager.powerPort.powerIn;

        connect operatorControlPort.command to scanController.controlPort.command;
        connect scanController.controlPort.status to operatorControlPort.status;

        connect scanController.scanCommandOut.command to rfSubsystem.controlPort.command;
        connect scanController.scanCommandOut.command to antennaArray.controlPort.command;
        connect scanController.scanCommandOut.command to signalProcessor.controlPort.command;

        connect rfSubsystem.transmitPort.transmittedSignal to antennaArray.transmitPort.transmittedSignal;
        connect antennaArray.receivePort.reflectedSignal to rfSubsystem.receivePort.reflectedSignal;
        connect rfSubsystem.samplePort.reflectedSignal to signalProcessor.sampleInputPort.reflectedSignal;

        connect signalProcessor.imageOutput.image to threatAnalyzer.imageInput.image;
        connect threatAnalyzer.resultOutput.result to resultPort.result;
        connect threatAnalyzer.resultOutput.result to operatorConsole.resultPort.result;

        connect safetySubsystem.statusPort.status to scanController.safetyStatusPort.status;
        connect enclosure.statusPort.status to safetySubsystem.enclosureStatusPort.status;

        connect rfSubsystem.thermalPort.heatLoad to thermalManager.rfHeatInput.heatLoad;
        connect signalProcessor.thermalPort.heatLoad to thermalManager.processorHeatInput.heatLoad;
        connect thermalManager.coolingPort.coolingCapacity to thermalPort.coolingCapacity;
        connect thermalManager.coolingPort.heatLoad to thermalPort.heatLoad;

        perform action scanSubject : PerformHighLevelScan;
        exhibit state scannerLifecycle : ScannerLifecycle;
    }

    part def ScanController {
        attribute controllerCycleTime : Time = 0.01;
        attribute scanIdCounter : Integer = 0;

        port powerPort : PowerInputPort;
        port controlPort : ControlPort;
        port scanCommandOut : ControlPort;
        port safetyStatusPort : ControlPort;

        perform action coordinateScan : CoordinateScanAction;
    }

    part def RadioFrequencySubsystem {
        attribute centerFrequency : Frequency = 27000000000.0;
        attribute instantaneousBandwidth : Frequency = 2000000000.0;
        attribute transmitPowerLimit : Power = 0.01;
        attribute receiverNoiseFigure : ScalarValues::Real = 5.0;

        port powerPort : PowerInputPort;
        port controlPort : ControlPort;
        port transmitPort : RadioTransmitPort;
        port receivePort : RadioReceivePort;
        port samplePort : RadioReceivePort;
        port thermalPort : CoolingPort;

        part waveformGenerator : WaveformGenerator;
        part powerAmplifier : PowerAmplifier;
        part lowNoiseReceiver : LowNoiseReceiver;
        part digitizer : HighSpeedDigitizer;

        connect waveformGenerator.txOut.transmittedSignal to powerAmplifier.txIn.transmittedSignal;
        connect powerAmplifier.txOut.transmittedSignal to transmitPort.transmittedSignal;
        connect receivePort.reflectedSignal to lowNoiseReceiver.rxIn.reflectedSignal;
        connect lowNoiseReceiver.rxOut.reflectedSignal to digitizer.rxIn.reflectedSignal;
        connect digitizer.sampleOut.reflectedSignal to samplePort.reflectedSignal;
    }

    part def WaveformGenerator {
        attribute chirpStartFrequency : Frequency = 24000000000.0;
        attribute chirpStopFrequency : Frequency = 30000000000.0;
        attribute chirpDuration : Time = 0.0005;
        port txOut : RadioTransmitPort;
    }

    part def PowerAmplifier {
        attribute gain : ScalarValues::Real = 20.0;
        attribute maximumOutputPower : Power = 0.01;
        port txIn : RadioTransmitPort;
        port txOut : RadioTransmitPort;
    }

    part def LowNoiseReceiver {
        attribute gain : ScalarValues::Real = 35.0;
        attribute noiseFigure : ScalarValues::Real = 5.0;
        port rxIn : RadioReceivePort;
        port rxOut : RadioReceivePort;
    }

    part def HighSpeedDigitizer {
        attribute sampleRate : Frequency = 5000000000.0;
        attribute resolutionBits : Integer = 14;
        port rxIn : RadioReceivePort;
        port sampleOut : RadioReceivePort;
    }

    part def AntennaArray {
        attribute elementCount : Integer = 256;
        attribute horizontalFieldOfView : Angle = 120.0;
        attribute verticalFieldOfView : Angle = 90.0;
        attribute angularStep : Angle = 0.5;

        port controlPort : ControlPort;
        port transmitPort : RadioTransmitPort;
        port receivePort : RadioReceivePort;

        part transmitElements : AntennaElement[128];
        part receiveElements : AntennaElement[128];
        part beamSteeringUnit : BeamSteeringUnit;

        perform action steerAndAcquire : BeamSteeredAcquisitionAction;
    }

    part def AntennaElement {
        attribute elementId : Integer;
        attribute gain : ScalarValues::Real = 8.0;
        attribute polarization : String = "linear";
        port transmitPort : RadioTransmitPort;
        port receivePort : RadioReceivePort;
    }

    part def BeamSteeringUnit {
        attribute phaseControlResolution : Angle = 0.1;
        attribute beamUpdateTime : Time = 0.0001;
        port controlPort : ControlPort;
    }

    part def SubjectPositioner {
        attribute standingAreaWidth : Length = 0.9;
        attribute standingAreaDepth : Length = 0.7;
        attribute subjectHeightRangeMin : Length = 1.2;
        attribute subjectHeightRangeMax : Length = 2.1;

        part presenceSensor : PresenceSensor;
        part positionGuide : PositionGuide;
    }

    part def PresenceSensor {
        attribute detectionRange : Length = 2.0;
        attribute updatePeriod : Time = 0.05;
        port statusPort : ControlPort;
    }

    part def PositionGuide {
        attribute visualIndicatorCount : Integer = 4;
        attribute audiblePromptEnabled : Boolean = true;
        port controlPort : ControlPort;
    }

    part def SignalProcessingComputer {
        attribute computeThroughput : DataRate = 12000000000.0;
        attribute reconstructionLatencyTarget : Time = 0.5;
        attribute imageResolution : Length = 0.005;

        port powerPort : PowerInputPort;
        port controlPort : ControlPort;
        port sampleInputPort : RadioReceivePort;
        port imageOutput : ImageOutputPort;
        port thermalPort : CoolingPort;

        perform action reconstructImage : ReconstructVolumetricImageAction;
    }

    port def ImageOutputPort {
        out item image : VolumetricImage;
    }

    port def ImageInputPort {
        in item image : VolumetricImage;
    }

    part def ThreatAnalysisComputer {
        attribute classifierVersion : String = "concealed-object-detector-4.2";
        attribute detectionThreshold : Probability = 0.75;
        attribute maximumAnalysisLatency : Time = 0.4;

        port powerPort : PowerInputPort;
        port imageInput : ImageInputPort;
        port resultOutput : ResultPort;

        perform action analyzeImage : AnalyzeThreatsAction;
    }

    part def OperatorConsole {
        attribute displayRefreshRate : Frequency = 60.0;
        attribute alertSoundLevel : ScalarValues::Real = 65.0;

        port powerPort : PowerInputPort;
        port resultPort : ResultPort;
        port commandPort : ControlPort;
    }

    part def SafetySubsystem {
        attribute maximumPermittedExposure : Power = 0.02;
        attribute emergencyStopEngaged : Boolean = false;

        port statusPort : ControlPort;
        port enclosureStatusPort : ControlPort;

        perform action evaluateSafetyInterlocks : SafetyInterlockAction;
    }

    part def ThermalManagementSubsystem {
        attribute maximumInternalTemperature : Temperature = 55.0;
        attribute nominalCoolingCapacity : Power = 250.0;

        port powerPort : PowerInputPort;
        port rfHeatInput : CoolingPort;
        port processorHeatInput : CoolingPort;
        port coolingPort : CoolingPort;

        part fanAssembly : FanAssembly;
        part heatSink : HeatSink;
    }

    part def FanAssembly {
        attribute fanCount : Integer = 3;
        attribute maximumAirflow : ScalarValues::Real = 0.18;
        attribute acousticNoise : ScalarValues::Real = 45.0;
    }

    part def HeatSink {
        attribute thermalResistance : ScalarValues::Real = 0.15;
        attribute surfaceArea : ScalarValues::Real = 0.45;
    }

    part def ScannerEnclosure {
        attribute enclosureHeight : Length = 2.3;
        attribute enclosureWidth : Length = 1.4;
        attribute enclosureDepth : Length = 1.2;
        attribute accessDoorClosed : Boolean = true;
        attribute shieldingEffectiveness : ScalarValues::Real = 60.0;

        port statusPort : ControlPort;
    }

    action def PerformHighLevelScan {
        in item command : ScanCommand;
        out item result : ScanResult;

        first start;
        then verifyReadiness;
        then emitMillimeterWaveEnergy;
        then receiveReflections;
        then reconstructVolume;
        then detectConcealedObjects;
        then reportResult;
        then done;

        action start;
        action verifyReadiness;
        action emitMillimeterWaveEnergy;
        action receiveReflections;
        action reconstructVolume;
        action detectConcealedObjects;
        action reportResult;
        action done;
    }

    action def CoordinateScanAction {
        in item requestedScan : ScanCommand;
        in item safetyStatus : ScannerStatus;
        out item issuedScan : ScanCommand;
        out item controllerStatus : ScannerStatus;

        action validateCommand;
        action checkSafetyStatus;
        action issueRfAndAntennaCommands;
        action monitorCompletion;
    }

    action def BeamSteeredAcquisitionAction {
        in item scanCommand : ScanCommand;
        in item waveform : MillimeterWaveSignal;
        out item reflectedSamples : ReflectedWaveSignal[0..*];

        action setBeamAngle;
        action transmitPulse;
        action collectReflection;
        action advanceBeamPattern;
    }

    action def ReconstructVolumetricImageAction {
        in item reflectedSamples : ReflectedWaveSignal[0..*];
        out item image : VolumetricImage;

        action calibrateSamples;
        action removeBackground;
        action estimateRange;
        action synthesizeAperture;
        action formVoxelGrid;
    }

    action def AnalyzeThreatsAction {
        in item image : VolumetricImage;
        out item result : ScanResult;

        action segmentBodySurface;
        action identifyAnomalies;
        action classifyMaterialResponse;
        action createFindings;
        action decideClearOrAlarm;
    }

    action def SafetyInterlockAction {
        in item enclosureStatus : ScannerStatus;
        out item safetyStatus : ScannerStatus;

        action verifyDoorClosed;
        action verifyExposureLimit;
        action verifyThermalLimit;
        action verifyEmergencyStop;
        action publishSafetyState;
    }

    state def ScannerLifecycle {
        entry action initializeElectronics;

        state Off;
        state Startup;
        state SelfTest;
        state Ready;
        state PositioningSubject;
        state Scanning;
        state Processing;
        state Reporting;
        state Fault;
        state EmergencyStop;

        transition initial then Off;
        transition powerApplied first Off then Startup;
        transition startupComplete first Startup then SelfTest;
        transition selfTestPassed first SelfTest then Ready;
        transition subjectDetected first Ready then PositioningSubject;
        transition subjectAligned first PositioningSubject then Scanning;
        transition acquisitionComplete first Scanning then Processing;
        transition analysisComplete first Processing then Reporting;
        transition reportAcknowledged first Reporting then Ready;
        transition recoverableFaultDetected first Startup then Fault;
        transition selfTestFailed first SelfTest then Fault;
        transition scanFaultDetected first Scanning then Fault;
        transition processorFaultDetected first Processing then Fault;
        transition faultCleared first Fault then SelfTest;
        transition emergencyStopPressed first Ready then EmergencyStop;
        transition emergencyStopPressedDuringScan first Scanning then EmergencyStop;
        transition emergencyStopReset first EmergencyStop then SelfTest;
    }

    requirement def PrimaryFunctionRequirement {
        subject scanner : MillimeterWaveScannerSystem;
        doc /* The scanner shall perform non-contact inspection of a positioned subject using millimeter-wave illumination, reflected-signal acquisition, volumetric image reconstruction, and automated anomaly detection. */
        require constraint {
            scanner.nominalScanDuration <= 3.0 and
            scanner.minimumDetectableObjectSize <= 0.005 and
            scanner.probabilityOfDetectionTarget >= 0.95
        }
    }

    requirement def ExposureSafetyRequirement {
        subject scanner : MillimeterWaveScannerSystem;
        doc /* The scanner shall limit transmitted millimeter-wave energy to a low-power operating envelope suitable for routine personnel screening. */
        require constraint {
            scanner.maximumTransmitPower <= 0.01
        }
    }

    requirement def FrequencyBandRequirement {
        subject scanner : MillimeterWaveScannerSystem;
        doc /* The scanner shall operate in a millimeter-wave frequency band sufficient to resolve small concealed objects through clothing. */
        require constraint {
            scanner.operatingFrequencyLow >= 24000000000.0 and
            scanner.operatingFrequencyHigh <= 30000000000.0
        }
    }

    requirement def ThroughputRequirement {
        subject scanner : MillimeterWaveScannerSystem;
        doc /* The scanner shall complete acquisition, reconstruction, analysis, and operator reporting within a short screening interval. */
        require constraint {
            scanner.nominalScanDuration <= 3.0
        }
    }

    requirement def ThreatDetectionRequirement {
        subject scanner : MillimeterWaveScannerSystem;
        doc /* The scanner shall identify concealed-object candidates and report their approximate three-dimensional locations to the operator. */
        require constraint {
            scanner.probabilityOfDetectionTarget >= 0.95 and
            scanner.falseAlarmRateTarget <= 0.05
        }
    }

    requirement def EnclosureInterlockRequirement {
        subject scanner : MillimeterWaveScannerSystem;
        doc /* The scanner shall inhibit millimeter-wave transmission unless the enclosure and safety interlocks report a safe state. */
        require constraint {
            scanner.enclosure.accessDoorClosed == true
        }
    }

    satisfy PrimaryFunctionRequirement by MillimeterWaveScannerSystem;
    satisfy ExposureSafetyRequirement by RadioFrequencySubsystem;
    satisfy FrequencyBandRequirement by WaveformGenerator;
    satisfy ThroughputRequirement by ScanController;
    satisfy ThreatDetectionRequirement by ThreatAnalysisComputer;
    satisfy EnclosureInterlockRequirement by SafetySubsystem;
}