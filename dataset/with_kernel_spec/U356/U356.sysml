package PlethysmographModel {
    private import ScalarValues::*;
    private import ISQ::*;
    private import Time::*;

    package ValueTypes {
        attribute def VolumeValue :> ISQ::volume;
        attribute def VolumeFlowRateValue :> ISQ::volumeFlowRate;
        attribute def PressureValue :> ISQ::pressure;
        attribute def VoltageValue :> ISQ::electricPotential;
        attribute def FrequencyValue :> ISQ::frequency;
        attribute def TemperatureValue :> ISQ::temperature;
        attribute def DurationValue :> ISQ::duration;
        attribute def LengthValue :> ISQ::length;
        attribute def SignalQualityValue :> ScalarValues::Real;
        attribute def StrainValue :> ScalarValues::Real;
    }

    package Enums {
        enum def SensingModeKind { strainGauge; impedance; photoelectric; pressure; }
        enum def CommandKind { start; stop; calibrate; setMode; reset; }
        enum def MeasurementModeKind { limbVolume; bloodFlow; vascularHealth; }
    }

    package SignalTypes {
        attribute def PowerOnSignal;
        attribute def PowerOffSignal;
        attribute def SelfTestPassSignal;
        attribute def SelfTestFailSignal;
        attribute def CalibrationCompleteSignal;
        attribute def CalibrationFailedSignal;
        attribute def StartMeasurementSignal;
        attribute def StopMeasurementSignal;
        attribute def ErrorDetectedSignal;
        attribute def ResetSignal;
        attribute def ConfigureModeSignal;
        attribute def ConfigurationCompleteSignal;
        attribute def OverTempSignal;
        attribute def MaintenanceScheduledSignal;
    }

    package ItemTypes {
        private import ValueTypes::*;
        private import Enums::*;

        item def RawSensorData {
            attribute rawVoltage : VoltageValue;
            attribute strainReading : StrainValue;
            attribute pressureReading : PressureValue;
            attribute impedanceReading : ScalarValues::Real;
            attribute photoelectricReading : VoltageValue;
            attribute timestamp : DurationValue;
            attribute sensorId : String;
            attribute sensingMode : SensingModeKind;
        }

        item def ProcessedData {
            attribute volumeChange : VolumeValue;
            attribute flowRate : VolumeFlowRateValue;
            attribute signalQuality : SignalQualityValue;
            attribute isValid : Boolean;
            attribute isNoisy : Boolean;
            attribute timestamp : DurationValue;
        }

        item def MeasurementResult {
            attribute bloodFlowRate : VolumeFlowRateValue;
            attribute totalVolumeChange : VolumeValue;
            attribute isValid : Boolean;
            attribute qualityIndicator : SignalQualityValue;
            attribute measurementMode : MeasurementModeKind;
            attribute timestamp : DurationValue;
        }

        item def CalibrationData {
            attribute baselineValue : VoltageValue;
            attribute sensitivityFactor : Real;
            attribute calibrationTimestamp : DurationValue;
        }

        item def ControlCommand {
            attribute commandKind : CommandKind;
            attribute measurementMode : MeasurementModeKind;
            attribute sensingMode : SensingModeKind;
        }

        item def DisplayUpdate {
            attribute waveform : Real[0..*];
            attribute numericReadout : MeasurementResult;
            attribute validityIndicator : Boolean;
            attribute timestamp : DurationValue;
        }

        item def SystemStatus {
            attribute currentState : String;
            attribute errorCode : Integer;
            attribute isCalibrated : Boolean;
            attribute currentMode : MeasurementModeKind;
        }
    }

    package PortTypes {
        private import ItemTypes::*;

        port def RawDataOutPort {
            out raw : RawSensorData;
        }
        port def RawDataInPort {
            in raw : RawSensorData;
        }
        port def ProcessedDataOutPort {
            out processed : ProcessedData;
        }
        port def ProcessedDataInPort {
            in processed : ProcessedData;
        }
        port def ResultOutPort {
            out result : MeasurementResult;
        }
        port def ResultInPort {
            in result : MeasurementResult;
        }
        port def DisplayUpdateOutPort {
            out update : DisplayUpdate;
        }
        port def DisplayUpdateInPort {
            in update : DisplayUpdate;
        }
        port def CmdOutPort {
            out command : ControlCommand;
        }
        port def CmdInPort {
            in command : ControlCommand;
        }
        port def StatusOutPort {
            out status : SystemStatus;
        }
        port def StatusInPort {
            in status : SystemStatus;
        }
    }

    package ActionTypes {
        private import ValueTypes::*;
        private import ItemTypes::*;
        private import Enums::*;

        action def DetectVolumeChange {
            in sensingMode : SensingModeKind;
            in physiologicalInput : PressureValue;
            out rawOutput : RawSensorData;
        }

        action def AmplifySignal {
            in rawIn : RawSensorData;
            out amplifiedOut : RawSensorData;
        }

        action def FilterNoise {
            in amplifiedIn : RawSensorData;
            out filteredOut : RawSensorData;
        }

        action def ExtractParameters {
            in filteredIn : RawSensorData;
            out volumeChange : VolumeValue;
            out flowRate : VolumeFlowRateValue;
        }

        action def AssessSignalQuality {
            in rawIn : RawSensorData;
            in filteredIn : RawSensorData;
            out quality : SignalQualityValue;
            out isReliable : Boolean;
        }

        action def CompileResult {
            in volumeChange : VolumeValue;
            in flowRate : VolumeFlowRateValue;
            in quality : SignalQualityValue;
            in isReliable : Boolean;
            in mode : MeasurementModeKind;
            out result : MeasurementResult;
        }

        action def ProcessSignal {
            in raw : RawSensorData;
            in mode : MeasurementModeKind;
            out result : MeasurementResult;

            action amplify : AmplifySignal;
            action filter : FilterNoise;
            action extract : ExtractParameters;
            action assess : AssessSignalQuality;
            action compile : CompileResult;

            succession first amplify then filter;
            succession first filter then extract;
            succession first filter then assess;
            succession first extract then compile;
            succession first assess then compile;
        }

        action def AcquireData {
            in sensingMode : SensingModeKind;
            out rawData : RawSensorData;
        }

        action def PerformSelfTest {
            out passed : Boolean;
            out diagnosticCode : Integer;
        }

        action def PerformCalibration {
            out calibrationData : CalibrationData;
            out success : Boolean;
        }

        action def MonitorTemperature {
            out temperature : TemperatureValue;
            out exceeded : Boolean;
        }

        action def ConfigureMode {
            in mode : MeasurementModeKind;
            in sensingMode : SensingModeKind;
        }

        action def HandleError {
            in errorCode : Integer;
            out status : SystemStatus;
        }

        action def RenderWaveform {
            in data : ProcessedData;
        }

        action def DisplayNumericReadouts {
            in result : MeasurementResult;
        }

        action def ShowValidityIndicator {
            in isValid : Boolean;
        }

        action def UpdateDisplay {
            in data : ProcessedData;
            in result : MeasurementResult;
            out update : DisplayUpdate;
        }

        action def ApplyCalibrationParameters;
        action def RunDiagnostics;
        action def AwaitCommand;
        action def StartDataAcquisition;
        action def StopDataAcquisition;
        action def LogError;
        action def SendOverheatingAlert;
        action def EnterMaintenanceMode;
        action def ApplyConfiguration;
        action def MonitorTemp;
        action def Process;
        action def Detect;
    }

    package StateTypes {
        private import SignalTypes::*;
        private import ActionTypes::*;
        private import ItemTypes::*;
        private import PortTypes::*;
        private import Enums::*;

        state def OperationalStates {
            entry; then Off;

            state Off;

            transition first Off
                accept PowerOnSignal
                then SelfTesting;

            state SelfTesting {
                entry action performSelfTest;
                do action runDiagnostics;
            }

            transition first SelfTesting
                accept SelfTestPassSignal
                then Calibrating;

            transition first SelfTesting
                accept SelfTestFailSignal
                then ErrorState;

            state Calibrating {
                entry action performCalibration;
                do action applyCalibrationParameters;
            }

            transition first Calibrating
                accept CalibrationCompleteSignal
                then Ready;

            transition first Calibrating
                accept CalibrationFailedSignal
                then ErrorState;

            state Ready {
                do action awaitCommand;
            }

            transition first Ready
                accept StartMeasurementSignal
                then Measuring;

            transition first Ready
                accept ConfigureModeSignal
                then Configuring;

            state Configuring {
                entry action applyConfiguration;
            }

            transition first Configuring
                accept ConfigurationCompleteSignal
                then Ready;

            state Measuring {
                entry action startDataAcquisition;
                do action acquireData;
                exit action stopDataAcquisition;
            }

            transition first Measuring
                accept StopMeasurementSignal
                then Ready;

            transition first Measuring
                accept ErrorDetectedSignal
                then ErrorState;

            state ErrorState {
                entry action handleError;
                do action logError;
            }

            transition first ErrorState
                accept ResetSignal
                then Off;

            transition first Off
                accept PowerOffSignal
                then done;
        }

        state def HealthStates {
            entry; then Normal;

            state Normal {
                do action monitorTemp;
            }

            transition first Normal
                accept OverTempSignal
                then Degraded;

            transition first Normal
                accept MaintenanceScheduledSignal
                then Maintenance;

            state Degraded {
                entry action sendOverheatingAlert;
            }

            transition first Degraded
                accept ResetSignal
                then Normal;

            state Maintenance {
                entry action enterMaintenanceMode;
            }

            transition first Maintenance
                accept ResetSignal
                then Normal;
        }

        state def SignalProcessorStates {
            entry; then Idle;

            state Idle;

            transition first Idle
                accept s : RawSensorData
                then Processing;

            state Processing {
                entry action process;
            }

            transition first Processing
                accept CalibrationCompleteSignal
                then Idle;
        }

        state def TransducerStates {
            attribute sensingMode : SensingModeKind;
            entry; then Idle;

            state Idle;

            transition first Idle
                accept c : ControlCommand
                if c.commandKind == CommandKind::start
                then Sensing;

            state Sensing {
                do action detect;
            }

            transition first Sensing
                accept c : ControlCommand
                if c.commandKind == CommandKind::stop
                then Idle;
        }

        state def DisplayStates {
            entry; then Idle;

            state Idle;

            transition first Idle
                accept d : ProcessedData
                then Displaying;

            state Displaying {
                entry action updateDisplay;
            }

            transition first Displaying
                accept u : DisplayUpdate
                then Idle;
        }
    }

    package PartDefinitions {
        private import PortTypes::*;
        private import ValueTypes::*;
        private import ItemTypes::*;
        private import ActionTypes::*;
        private import StateTypes::*;
        private import Enums::*;

        part def PressureSensor {
            port output : RawDataOutPort;
            attribute sensitivity : PressureValue;
            perform action detectVolumeChange;
        }

        part def StrainGaugeSensor {
            port output : RawDataOutPort;
            attribute gaugeFactor : Real;
            attribute maxStrain : StrainValue;
            perform action detectVolumeChange;
        }

        part def ImpedanceSensor {
            port output : RawDataOutPort;
            attribute excitationFrequency : FrequencyValue;
            perform action detectVolumeChange;
        }

        part def PhotoelectricSensor {
            port output : RawDataOutPort;
            attribute wavelength : LengthValue;
            perform action detectVolumeChange;
        }

        part def TransducerAssembly {
            port dataOut : RawDataOutPort;
            port cmdIn : CmdInPort;
            attribute sensingMode : SensingModeKind;
            attribute measurementMode : MeasurementModeKind;

            part pressureSensor : PressureSensor;
            part strainGauge : StrainGaugeSensor;
            part impedanceSensor : ImpedanceSensor[0..1];
            part photoelectricSensor : PhotoelectricSensor[0..1];

            connect pressureSensor.output to dataOut;
            connect strainGauge.output to dataOut;
            connect impedanceSensor.output to dataOut;
            connect photoelectricSensor.output to dataOut;

            perform action detectVolumeChange;
            exhibit state transducerState : TransducerStates;
        }

        part def SignalProcessor {
            port rawDataIn : RawDataInPort;
            port processedDataOut : ProcessedDataOutPort;
            port cmdIn : CmdInPort;
            port statusOut : StatusOutPort;
            port resultOut : ResultOutPort;

            attribute amplificationGain : Real;
            attribute filterCutoff : FrequencyValue;
            attribute qualityThreshold : SignalQualityValue;

            perform action amplifySignal;
            perform action filterNoise;
            perform action extractParameters;
            perform action assessSignalQuality;
            perform action processSignal;
            perform action compileResult;

            exhibit state processingState : SignalProcessorStates;
        }

        part def ControlUnit {
            port transducerCmdOut : CmdOutPort;
            port processorCmdOut : CmdOutPort;
            port displayCmdOut : CmdOutPort;
            port displayDataOut : DisplayUpdateOutPort;
            port processorDataIn : ResultInPort;
            port statusIn : StatusInPort;
            port operatorIn : CmdInPort;

            attribute currentMode : MeasurementModeKind;
            attribute currentSensingMode : SensingModeKind;
            attribute isCalibrated : Boolean;
            attribute maxTemperature : TemperatureValue;

            perform action performSelfTest;
            perform action performCalibration;
            perform action acquireData;
            perform action handleError;
            perform action monitorTemperature;
            perform action configureMode;

            exhibit state operationalStates : OperationalStates;
            exhibit state healthStates : HealthStates;
        }

        part def DisplayInterface {
            port waveformIn : ProcessedDataInPort;
            port resultIn : DisplayUpdateInPort;
            port cmdIn : CmdInPort;

            attribute displayRefreshRate : FrequencyValue;

            perform action renderWaveform;
            perform action displayNumericReadouts;
            perform action showValidityIndicator;
            perform action updateDisplay;

            exhibit state displayState : DisplayStates;
        }

        part def Plethysmograph {
            part transducerAssembly : TransducerAssembly;
            part signalProcessor : SignalProcessor;
            part controlUnit : ControlUnit;
            part displayInterface : DisplayInterface;

            connect transducerAssembly.dataOut to signalProcessor.rawDataIn;
            connect signalProcessor.processedDataOut to displayInterface.waveformIn;
            connect signalProcessor.resultOut to controlUnit.processorDataIn;
            connect signalProcessor.statusOut to controlUnit.statusIn;
            connect controlUnit.transducerCmdOut to transducerAssembly.cmdIn;
            connect controlUnit.processorCmdOut to signalProcessor.cmdIn;
            connect controlUnit.displayCmdOut to displayInterface.cmdIn;
            connect controlUnit.displayDataOut to displayInterface.resultIn;
        }
    }

    package Requirements {
        private import ValueTypes::*;
        private import PartDefinitions::*;

        requirement def MeasurementAccuracyRequirement {
            doc /* The plethysmograph shall measure volume changes with an accuracy of at least ±2% of full scale. */
            subject plethysmograph : Plethysmograph;
            attribute maxErrorFraction : Real = 0.02;
            requirement {
                | maxErrorFraction <= 0.02
            }
        }

        requirement def SignalQualityRequirement {
            doc /* The signal processor shall flag measurements with signal quality below 0.7 as potentially unreliable. */
            subject signalProcessor : SignalProcessor;
            attribute minQualityThreshold : SignalQualityValue = 0.7;
            requirement {
                | minQualityThreshold >= 0.7
            }
        }

        requirement def ResponseTimeRequirement {
            doc /* The system shall respond to a measurement command within 2 seconds. */
            subject plethysmograph : Plethysmograph;
            attribute maxResponseTime : DurationValue = 2.0;
            requirement {
                | maxResponseTime <= 2.0
            }
        }

        requirement def DisplayUpdateRateRequirement {
            doc /* The display shall update the waveform at a minimum rate of 60 Hz. */
            subject displayInterface : DisplayInterface;
            attribute minUpdateRate : FrequencyValue = 60.0;
            requirement {
                | minUpdateRate >= 60.0
            }
        }

        requirement def CalibrationRequirement {
            doc /* The system shall perform calibration before entering the Ready state and shall not allow measurement without successful calibration. */
            subject controlUnit : ControlUnit;
            attribute requiredCalibrated : Boolean = true;
            requirement {
                | requiredCalibrated == true
            }
        }

        requirement def MultiModeSensingRequirement {
            doc /* The transducer assembly shall support strain-gauge, impedance, photoelectric, and pressure sensing modes. */
            subject transducerAssembly : TransducerAssembly;
            attribute supportedModes : Integer = 4;
            requirement {
                | supportedModes >= 4
            }
        }

        requirement def RealTimeDisplayRequirement {
            doc /* The display interface shall render waveforms and numeric readouts with latency less than 100 ms. */
            subject displayInterface : DisplayInterface;
            attribute maxLatency : DurationValue = 0.1;
            requirement {
                | maxLatency <= 0.1
            }
        }

        requirement measurementAccuracyReq : MeasurementAccuracyRequirement;
        requirement signalQualityReq : SignalQualityRequirement;
        requirement responseTimeReq : ResponseTimeRequirement;
        requirement displayUpdateRateReq : DisplayUpdateRateRequirement;
        requirement calibrationReq : CalibrationRequirement;
        requirement multiModeSensingReq : MultiModeSensingRequirement;
        requirement realTimeDisplayReq : RealTimeDisplayRequirement;
    }

    package Usages {
        private import PartDefinitions::*;
        private import Requirements::*;
        private import ItemTypes::*;
        private import ValueTypes::*;
        private import Enums::*;

        part plethysmographSystem : Plethysmograph {
            part transducerAssembly : TransducerAssembly {
                attribute redefines sensingMode = SensingModeKind::strainGauge;
                attribute redefines measurementMode = MeasurementModeKind::bloodFlow;
            }
            part signalProcessor : SignalProcessor {
                attribute redefines amplificationGain = 100.0;
                attribute redefines filterCutoff = 50.0;
                attribute redefines qualityThreshold = 0.7;
            }
            part controlUnit : ControlUnit {
                attribute redefines currentMode = MeasurementModeKind::bloodFlow;
                attribute redefines currentSensingMode = SensingModeKind::strainGauge;
                attribute redefines isCalibrated = false;
                attribute redefines maxTemperature = 40.0;
            }
            part displayInterface : DisplayInterface {
                attribute redefines displayRefreshRate = 60.0;
            }

            satisfy measurementAccuracyReq by signalProcessor;
            satisfy signalQualityReq by signalProcessor;
            satisfy responseTimeReq by controlUnit;
            satisfy displayUpdateRateReq by displayInterface;
            satisfy calibrationReq by controlUnit;
            satisfy multiModeSensingReq by transducerAssembly;
            satisfy realTimeDisplayReq by displayInterface;
        }

        action operatePlethysmograph {
            in patientInput : PressureValue;
            out finalResult : MeasurementResult;
            in sensingMode : SensingModeKind = SensingModeKind::strainGauge;
            in measurementMode : MeasurementModeKind = MeasurementModeKind::bloodFlow;

            action detect : DetectVolumeChange;
            action process : ProcessSignal;

            succession first detect then process;
        }
    }
}
