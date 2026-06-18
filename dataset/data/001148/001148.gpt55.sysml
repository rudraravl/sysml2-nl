package MillimeterWaveScannerSystem {

    import ScalarValues::*;
    import SI::*;

    attribute def Frequency :> ISQBase::frequency;
    attribute def Bandwidth :> ISQBase::frequency;
    attribute def Power :> ISQBase::power;
    attribute def Voltage :> ISQBase::electricPotential;
    attribute def Current :> ISQBase::electricCurrent;
    attribute def Time :> ISQBase::time;
    attribute def Length :> ISQBase::length;
    attribute def Angle;
    attribute def Temperature :> ISQBase::thermodynamicTemperature;
    attribute def DataRate;
    attribute def Probability;
    attribute def Count;
    attribute def BooleanFlag :> ScalarValues::Boolean;
    attribute def Identifier :> ScalarValues::String;

    enum def ScannerMode {
        enum off;
        enum standby;
        enum selfTest;
        enum ready;
        enum scanning;
        enum processing;
        enum alarm;
        enum fault;
        enum maintenance;
    }

    enum def ScreeningDecision {
        enum clear;
        enum potentialThreat;
        enum rescanRequired;
        enum systemUnavailable;
    }

    enum def ThreatClass {
        enum none;
        enum metallicObject;
        enum nonMetallicObject;
        enum concealedPackage;
        enum anatomicalAnomaly;
        enum unknownReflectiveFeature;
    }

    enum def AlarmSeverity {
        enum none;
        enum advisory;
        enum caution;
        enum critical;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : Power;
        attribute nominalFrequency : Frequency;
    }

    item def ControlCommand {
        attribute commandId : Identifier;
        attribute requestedMode : ScannerMode;
        attribute operatorId : Identifier;
        attribute timeTag : Time;
    }

    item def OperatorMessage {
        attribute messageId : Identifier;
        attribute severity : AlarmSeverity;
        attribute text : Identifier;
        attribute timeTag : Time;
    }

    item def MillimeterWaveChirp {
        attribute startFrequency : Frequency = 24.0 [GHz];
        attribute stopFrequency : Frequency = 30.0 [GHz];
        attribute bandwidth : Bandwidth = 6.0 [GHz];
        attribute transmitPower : Power = 10.0 [mW];
        attribute chirpDuration : Time = 1.0 [ms];
        attribute polarizationAngle : Angle;
    }

    item def ReflectedMillimeterWaveSignal {
        attribute centerFrequency : Frequency;
        attribute receivedPower : Power;
        attribute timeOfFlight : Time;
        attribute phaseAngle : Angle;
        attribute azimuthAngle : Angle;
        attribute elevationAngle : Angle;
        attribute signalToNoiseRatio;
    }

    item def RawScanFrame {
        attribute frameId : Identifier;
        attribute frameTime : Time;
        attribute antennaElementCount : Count;
        attribute sampleCount : Count;
        attribute frameDuration : Time;
    }

    item def ReconstructedBodySurface {
        attribute surfaceId : Identifier;
        attribute voxelResolution : Length = 5.0 [mm];
        attribute coverageHeight : Length = 2.20 [m];
        attribute coverageWidth : Length = 1.20 [m];
        attribute reconstructionConfidence : Probability;
    }

    item def DetectedAnomaly {
        attribute anomalyId : Identifier;
        attribute threatClass : ThreatClass;
        attribute confidence : Probability;
        attribute approximateHeight : Length;
        attribute approximateWidth : Length;
        attribute approximateDepth : Length;
        attribute bodyZone : Identifier;
    }

    item def ScreeningResult {
        attribute resultId : Identifier;
        attribute decision : ScreeningDecision;
        attribute highestSeverity : AlarmSeverity;
        attribute scanDuration : Time;
        attribute detectionProbability : Probability;
        attribute falseAlarmProbability : Probability;
        attribute privacyProtected : BooleanFlag = true;
    }

    port def ACInputPort {
        in item supply : ElectricalPower;
    }

    port def DCOutputPort {
        out item supply : ElectricalPower;
    }

    port def RFTransmitPort {
        out item chirp : MillimeterWaveChirp;
    }

    port def RFReceivePort {
        in item echo : ReflectedMillimeterWaveSignal;
    }

    port def BidirectionalRFPort {
        out item chirp : MillimeterWaveChirp;
        in item echo : ReflectedMillimeterWaveSignal;
    }

    port def CommandPort {
        in item command : ControlCommand;
    }

    port def StatusPort {
        out item status : OperatorMessage;
    }

    port def ScanFramePort {
        out item frame : RawScanFrame;
    }

    port def ProcessedSurfacePort {
        out item surface : ReconstructedBodySurface;
    }

    port def DetectionPort {
        out item anomaly : DetectedAnomaly;
        out item result : ScreeningResult;
    }

    port def DisplayPort {
        in item result : ScreeningResult;
        in item anomaly : DetectedAnomaly;
        out item message : OperatorMessage;
    }

    port def NetworkPort {
        out item result : ScreeningResult;
        in item command : ControlCommand;
    }

    port def CoolingPort {
        in item heatLoad : Power;
        out item removedHeat : Power;
    }

    part def PowerDistributionUnit {
        attribute inputVoltage : Voltage = 120.0 [V];
        attribute dcBusVoltage : Voltage = 48.0 [V];
        attribute maximumOutputPower : Power = 1500.0 [W];
        attribute conversionEfficiency : Probability = 0.92;

        port acIn : ACInputPort;
        port dcOut : DCOutputPort;
        port statusOut : StatusPort;
    }

    part def MillimeterWaveTransceiver {
        attribute minimumFrequency : Frequency = 24.0 [GHz];
        attribute maximumFrequency : Frequency = 30.0 [GHz];
        attribute instantaneousBandwidth : Bandwidth = 6.0 [GHz];
        attribute peakTransmitPower : Power = 10.0 [mW];
        attribute receiverNoiseFigure;
        attribute chirpRepetitionInterval : Time = 2.0 [ms];

        port powerIn : DCOutputPort;
        port rfPort : BidirectionalRFPort;
        port frameOut : ScanFramePort;
        port commandIn : CommandPort;
        port statusOut : StatusPort;

        action generateChirp {
            out item chirp : MillimeterWaveChirp;
        }

        action captureEchoes {
            in item echo : ReflectedMillimeterWaveSignal;
            out item frame : RawScanFrame;
        }
    }

    part def PhasedAntennaArray {
        attribute elementCount : Count = 256;
        attribute horizontalFieldOfView : Angle = 120.0;
        attribute verticalFieldOfView : Angle = 90.0;
        attribute beamSteeringStep : Angle = 1.0;
        attribute apertureWidth : Length = 0.80 [m];
        attribute apertureHeight : Length = 1.80 [m];

        port rfPort : BidirectionalRFPort;

        action steerBeam {
            in attribute azimuth : Angle;
            in attribute elevation : Angle;
        }

        action illuminateScreeningVolume {
            out item chirp : MillimeterWaveChirp;
        }
    }

    part def ScreeningVolume {
        attribute height : Length = 2.20 [m];
        attribute width : Length = 1.20 [m];
        attribute depth : Length = 1.20 [m];
        attribute minimumStandoffDistance : Length = 0.30 [m];
        attribute maximumStandoffDistance : Length = 1.00 [m];

        port incidentRF : RFTransmitPort;
        port reflectedRF : RFReceivePort;
    }

    part def SignalProcessor {
        attribute maximumFrameRate;
        attribute reconstructionResolution : Length = 5.0 [mm];
        attribute processingLatency : Time = 500.0 [ms];
        attribute memoryCapacity;
        attribute operatingTemperatureLimit : Temperature = 70.0 [degC];

        port frameIn : ScanFramePort;
        port surfaceOut : ProcessedSurfacePort;
        port statusOut : StatusPort;

        action calibrateReceiverChannels {
            out attribute calibrationValid : BooleanFlag;
        }

        action reconstructSurface {
            in item frame : RawScanFrame;
            out item surface : ReconstructedBodySurface;
        }
    }

    part def ThreatDetectionProcessor {
        attribute minimumDetectionProbability : Probability = 0.95;
        attribute maximumFalseAlarmProbability : Probability = 0.05;
        attribute anomalySizeThreshold : Length = 10.0 [mm];
        attribute decisionLatency : Time = 300.0 [ms];

        port surfaceIn : ProcessedSurfacePort;
        port detectionOut : DetectionPort;
        port statusOut : StatusPort;

        action detectAnomalies {
            in item surface : ReconstructedBodySurface;
            out item anomaly : DetectedAnomaly;
        }

        action classifyThreat {
            in item anomaly : DetectedAnomaly;
            out item result : ScreeningResult;
        }
    }

    part def PrivacyFilter {
        attribute storesAnatomicalImage : BooleanFlag = false;
        attribute generatesGenericAvatar : BooleanFlag = true;
        attribute maximumRetainedResultTime : Time = 60.0 [s];

        port detectionIn : DetectionPort;
        port filteredResultOut : DetectionPort;

        action anonymizeResult {
            in item result : ScreeningResult;
            out item privacySafeResult : ScreeningResult;
        }
    }

    part def OperatorConsole {
        attribute displaySize : Length = 0.60 [m];
        attribute audibleAlarmEnabled : BooleanFlag = true;
        attribute visualAlarmEnabled : BooleanFlag = true;

        port commandOut : CommandPort;
        port displayIn : DisplayPort;
        port statusIn : StatusPort;

        action requestScreening {
            out item command : ControlCommand;
        }

        action presentDecision {
            in item result : ScreeningResult;
            in item anomaly : DetectedAnomaly;
        }
    }

    part def SafetyInterlockController {
        attribute emergencyStopAvailable : BooleanFlag = true;
        attribute enclosureDoorClosed : BooleanFlag = true;
        attribute humanPresenceVerified : BooleanFlag = true;
        attribute rfExposureWithinLimit : BooleanFlag = true;

        port commandIn : CommandPort;
        port statusOut : StatusPort;

        action inhibitTransmit {
            out item status : OperatorMessage;
        }

        action authorizeTransmit {
            out item status : OperatorMessage;
        }
    }

    part def ThermalManagementUnit {
        attribute maximumHeatRemoval : Power = 800.0 [W];
        attribute nominalAirflow;
        attribute fanRedundancyCount : Count = 2;

        port heatIn : CoolingPort;
        port statusOut : StatusPort;

        action removeHeat {
            in item heatLoad : Power;
            out item removedHeat : Power;
        }
    }

    action def PerformMillimeterWaveScreening {
        in item command : ControlCommand;
        out item result : ScreeningResult;

        action verifySafety;
        action transmitLowPowerMillimeterWaveChirps;
        action receiveReflectedEnergy;
        action buildRawScanFrame;
        action reconstructPrivacyPreservingSurface;
        action detectConcealedAnomalies;
        action presentScreeningDecision;

        first start;
        then verifySafety;
        then transmitLowPowerMillimeterWaveChirps;
        then receiveReflectedEnergy;
        then buildRawScanFrame;
        then reconstructPrivacyPreservingSurface;
        then detectConcealedAnomalies;
        then presentScreeningDecision;
        then done;
    }

    state def ScannerLifecycle {
        state off;
        state standby;
        state selfTest;
        state ready;
        state scanning;
        state processing;
        state alarm;
        state fault;
        state maintenance;

        transition initialToOff first off;
        transition powerApplied from off to selfTest;
        transition selfTestPassed from selfTest to standby;
        transition operatorArmed from standby to ready;
        transition scanRequested from ready to scanning;
        transition scanDataComplete from scanning to processing;
        transition clearDecision from processing to ready;
        transition threatDecision from processing to alarm;
        transition alarmAcknowledged from alarm to ready;
        transition faultDetected from standby to fault;
        transition faultDuringReady from ready to fault;
        transition faultDuringScanning from scanning to fault;
        transition maintenanceRequested from standby to maintenance;
        transition maintenanceComplete from maintenance to selfTest;
        transition powerRemoved from standby to off;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The millimeter wave scanner shall perform non-contact screening by emitting low-power millimeter wave signals into a defined screening volume, receiving reflected energy from a person and carried objects, reconstructing a privacy-protected representation, and producing a clear, rescan, or potential-threat decision for the operator. */

        subject scanner : MillimeterWaveScanner;

        require constraint {
            scanner.operationalFrequencyLow >= 24.0 [GHz] and
            scanner.operationalFrequencyHigh <= 30.0 [GHz]
        }
    }

    requirement def SafetyExposureRequirement {
        doc /* The scanner shall limit emitted millimeter wave power to a level intended for safe short-duration human screening. */

        subject scanner : MillimeterWaveScanner;

        require constraint {
            scanner.maximumTransmitPower <= 10.0 [mW]
        }
    }

    requirement def ScreeningPerformanceRequirement {
        doc /* The scanner shall complete a normal screening cycle quickly enough to support checkpoint throughput while maintaining anomaly detection performance. */

        subject scanner : MillimeterWaveScanner;

        require constraint {
            scanner.nominalScreeningTime <= 3.0 [s] and
            scanner.nominalDetectionProbability >= 0.95 and
            scanner.nominalFalseAlarmProbability <= 0.05
        }
    }

    requirement def PrivacyRequirement {
        doc /* The scanner shall not retain raw anatomical images as operator-facing output and shall present only a privacy-filtered result and threat-location indication. */

        subject scanner : MillimeterWaveScanner;

        require constraint {
            scanner.rawImageStored == false and
            scanner.privacyProtectedOutput == true
        }
    }

    requirement def AvailabilityRequirement {
        doc /* The scanner shall enter a safe fault state when safety interlocks, thermal limits, power quality, or self-test checks are not satisfied. */

        subject scanner : MillimeterWaveScanner;

        require constraint {
            scanner.safeFaultInhibitTransmit == true
        }
    }

    part def MillimeterWaveScanner {
        attribute scannerId : Identifier;
        attribute operationalFrequencyLow : Frequency = 24.0 [GHz];
        attribute operationalFrequencyHigh : Frequency = 30.0 [GHz];
        attribute maximumTransmitPower : Power = 10.0 [mW];
        attribute nominalScreeningTime : Time = 2.5 [s];
        attribute nominalDetectionProbability : Probability = 0.95;
        attribute nominalFalseAlarmProbability : Probability = 0.05;
        attribute rawImageStored : BooleanFlag = false;
        attribute privacyProtectedOutput : BooleanFlag = true;
        attribute safeFaultInhibitTransmit : BooleanFlag = true;
        attribute currentMode : ScannerMode = ScannerMode::off;

        port acPower : ACInputPort;
        port operatorCommands : CommandPort;
        port operatorDisplay : DisplayPort;
        port checkpointNetwork : NetworkPort;
        port status : StatusPort;

        part powerUnit : PowerDistributionUnit;
        part transceiver : MillimeterWaveTransceiver;
        part antennaArray : PhasedAntennaArray;
        part screeningVolume : ScreeningVolume;
        part signalProcessor : SignalProcessor;
        part threatProcessor : ThreatDetectionProcessor;
        part privacyFilter : PrivacyFilter;
        part console : OperatorConsole;
        part interlockController : SafetyInterlockController;
        part thermalUnit : ThermalManagementUnit;

        connect acPower to powerUnit.acIn;
        connect powerUnit.dcOut to transceiver.powerIn;
        connect transceiver.rfPort to antennaArray.rfPort;
        connect antennaArray.rfPort to screeningVolume.incidentRF;
        connect screeningVolume.reflectedRF to antennaArray.rfPort;
        connect transceiver.frameOut to signalProcessor.frameIn;
        connect signalProcessor.surfaceOut to threatProcessor.surfaceIn;
        connect threatProcessor.detectionOut to privacyFilter.detectionIn;
        connect privacyFilter.filteredResultOut to console.displayIn;
        connect console.commandOut to operatorCommands;
        connect operatorCommands to transceiver.commandIn;
        connect operatorCommands to interlockController.commandIn;
        connect privacyFilter.filteredResultOut to checkpointNetwork;
        connect console.displayIn to operatorDisplay;
        connect powerUnit.statusOut to status;
        connect transceiver.statusOut to status;
        connect signalProcessor.statusOut to status;
        connect threatProcessor.statusOut to status;
        connect interlockController.statusOut to status;
        connect thermalUnit.statusOut to status;

        perform screeningBehavior : PerformMillimeterWaveScreening;
        exhibit lifecycle : ScannerLifecycle;

        satisfy PrimaryFunctionRequirement by screeningBehavior;
        satisfy SafetyExposureRequirement by transceiver;
        satisfy ScreeningPerformanceRequirement by signalProcessor;
        satisfy ScreeningPerformanceRequirement by threatProcessor;
        satisfy PrivacyRequirement by privacyFilter;
        satisfy AvailabilityRequirement by interlockController;
    }

    part scannerSystem : MillimeterWaveScanner {
        attribute scannerId = "MMW-SCANNER-001";
    }

}
