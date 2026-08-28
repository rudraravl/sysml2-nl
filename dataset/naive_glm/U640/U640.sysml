package CrankshaftPositionSensingUnit {
    import ScalarValues::*;

    // ===== Units =====
    unit volt;
    unit rpm;
    unit deg;
    unit ms;
    unit hz;

    // ===== Value Types =====
    attribute def Voltage :> Real { unit volt; }
    attribute def AngularVelocity :> Real { unit rpm; }
    attribute def Angle :> Real { unit deg; }
    attribute def TimeMs :> Real { unit ms; }
    attribute def Frequency :> Real { unit hz; }

    // ===== Item Definitions =====
    item def ToothPassage {
        attribute angle : Angle;
        attribute isReferenceGap : Boolean;
        attribute timestamp : TimeMs;
    }

    item def RawVoltagePulse {
        attribute amplitude : Voltage;
        attribute duration : TimeMs;
        attribute timestamp : TimeMs;
    }

    item def AmplifiedSignal {
        attribute amplitude : Voltage;
        attribute duration : TimeMs;
        attribute timestamp : TimeMs;
    }

    item def FilteredSignal {
        attribute amplitude : Voltage;
        attribute duration : TimeMs;
        attribute timestamp : TimeMs;
    }

    item def ToothEvent {
        attribute timestamp : TimeMs;
        attribute toothIndex : Integer;
        attribute isReferenceGap : Boolean;
        attribute interval : TimeMs;
    }

    item def CrankshaftPositionData {
        attribute angularPosition : Angle;
        attribute angularVelocity : AngularVelocity;
        attribute synchronized : Boolean;
        attribute timestamp : TimeMs;
    }

    item def DiagnosticInfo {
        attribute faultCode : Integer;
        attribute description : String;
        attribute timestamp : TimeMs;
    }

    // ===== Occurrence Definitions =====
    occurrence def PowerOn;
    occurrence def InitializationComplete;
    occurrence def ReferenceGapDetected;
    occurrence def ErrorDetected;
    occurrence def RecoveryInitiated;
    occurrence def RecoverySuccessful;
    occurrence def RecoveryFailed;
    occurrence def PowerOff;

    // ===== Port Definitions =====
    port def ToothPassagePort {
        out toothPassage : ToothPassage;
    }

    port def RawSignalPort {
        out rawPulse : RawVoltagePulse;
    }

    port def AmplifiedSignalPort {
        out amplifiedSignal : AmplifiedSignal;
    }

    port def FilteredSignalPort {
        out filteredSignal : FilteredSignal;
    }

    port def PositionDataPort {
        out positionData : CrankshaftPositionData;
    }

    port def DiagnosticPort {
        out diagnostic : DiagnosticInfo;
    }

    // ===== Action Definitions =====
    action def GenerateToothPassages {
        in rotationalSpeed : AngularVelocity;
        in currentAngle : Angle;
        out toothPassage : ToothPassage;
    }

    action def SenseTooth {
        in toothPassage : ToothPassage;
        out rawPulse : RawVoltagePulse;
    }

    action def AmplifySignalAction {
        in rawPulse : RawVoltagePulse;
        in gain : Real;
        out amplifiedSignal : AmplifiedSignal;
    }

    action def FilterNoiseAction {
        in inputSignal : AmplifiedSignal;
        in cutoffFrequency : Frequency;
        out filteredSignal : FilteredSignal;
    }

    action def DetectTransition {
        in filteredSignal : FilteredSignal;
        out toothEvent : ToothEvent;
    }

    action def CalculateRPMAction {
        in interval : TimeMs;
        out rpm : AngularVelocity;
    }

    action def DetectReferenceGapAction {
        in interval : TimeMs;
        in normalInterval : TimeMs;
        in threshold : Real;
        out gapDetected : Boolean;
    }

    action def UpdatePositionAction {
        in gapDetected : Boolean;
        in toothCount : Integer;
        in toothPitch : Angle;
        out angle : Angle;
        out synchronized : Boolean;
    }

    action def ReportPositionData {
        in angularPosition : Angle;
        in angularVelocity : AngularVelocity;
        in synchronized : Boolean;
        out positionData : CrankshaftPositionData;
    }

    action def ReportDiagnostic {
        in faultCode : Integer;
        in description : String;
        out diagnostic : DiagnosticInfo;
    }

    // ===== Part Definitions =====

    part def ReluctorWheel {
        attribute totalTeeth : Integer = 60;
        attribute missingTeeth : Integer = 2;
        attribute effectiveTeeth : Integer = 58;
        attribute toothPitch : Angle = 6.0;
        attribute gapAngle : Angle = 12.0;
        attribute rotationalSpeed : AngularVelocity;
        attribute currentAngle : Angle;

        port toothPassageOut : ToothPassagePort;

        perform generatePassages : GenerateToothPassages {
            in rotationalSpeed = self.rotationalSpeed;
            in currentAngle = self.currentAngle;
        }
    }

    part def Crankshaft {
        attribute rotationalSpeed : AngularVelocity;
        attribute currentAngle : Angle;
        attribute maxRPM : AngularVelocity = 8000.0;

        part reluctorWheel : ReluctorWheel {
            attribute rotationalSpeed = self.rotationalSpeed;
            attribute currentAngle = self.currentAngle;
        }
    }

    part def HallEffectSensor {
        attribute sensitivity : Voltage = 0.05;
        attribute operatingTempMin : Integer = -40;
        attribute operatingTempMax : Integer = 150;
        attribute supplyVoltage : Voltage = 12.0;

        in port sensorInput : ToothPassagePort;
        out port sensorOutput : RawSignalPort;

        perform sense : SenseTooth;
    }

    part def SignalAmplifier {
        attribute gain : Real = 100.0;
        attribute bandwidth : Frequency = 10000.0;
        attribute inputImpedance : Integer = 10000;

        in port amplifierInput : RawSignalPort;
        out port amplifierOutput : AmplifiedSignalPort;

        perform amplify : AmplifySignalAction {
            in gain = self.gain;
        }
    }

    part def SignalFilter {
        attribute cutoffFrequency : Frequency = 5000.0;
        attribute filterOrder : Integer = 4;
        attribute stopbandAttenuation : Real = 40.0;

        in port filterInput : AmplifiedSignalPort;
        out port filterOutput : FilteredSignalPort;

        perform filterNoise : FilterNoiseAction {
            in cutoffFrequency = self.cutoffFrequency;
        }
    }

    part def SignalProcessor {
        attribute toothCount : Integer = 0;
        attribute lastToothTimestamp : TimeMs = 0.0;
        attribute currentRPM : AngularVelocity = 0.0;
        attribute currentAngle : Angle = 0.0;
        attribute isSynchronized : Boolean = false;
        attribute referenceGapDetected : Boolean = false;
        attribute expectedToothInterval : TimeMs = 0.0;
        attribute gapDetectionThreshold : Real = 1.5;
        attribute toothPitch : Angle = 6.0;
        attribute errorCounter : Integer = 0;
        attribute maxErrorCount : Integer = 5;

        in port processorInput : FilteredSignalPort;
        out port positionOutput : PositionDataPort;
        out port diagnosticOutput : DiagnosticPort;

        perform detectTransition : DetectTransition;
        perform calculateRPM : CalculateRPMAction;
        perform detectGap : DetectReferenceGapAction {
            in threshold = self.gapDetectionThreshold;
        }
        perform updatePosition : UpdatePositionAction {
            in toothPitch = self.toothPitch;
        }
        perform reportData : ReportPositionData;
        perform reportDiagnostic : ReportDiagnostic;
    }

    // ===== State Machine Definition =====
    state def SensingUnitStates {
        state off {
            entry {
                // Unit is powered off; no signal processing occurs
            }
        }

        state initializing {
            entry {
                // Perform power-on self-test
                // Initialize sensor parameters and reset counters
                // Verify internal communication between subcomponents
            }
            do {
                // Run diagnostic checks on amplifier, filter, and processor
            }
        }

        state synchronizing {
            entry {
                // Begin searching for the missing-tooth reference gap
                // Monitor incoming filtered signal for tooth transitions
                // Measure intervals between consecutive tooth events
            }
            do {
                // Continuously compare each interval against expected interval
                // If interval exceeds threshold times normal interval, flag as reference gap
                // Accumulate tooth count to verify 58-tooth pattern between gaps
            }
        }

        state operational {
            entry {
                // Reference gap detected; unit is fully synchronized
                // Begin reporting angular position and velocity
            }
            do {
                // Continuously process incoming tooth events
                // Update angular position based on tooth count and pitch
                // Calculate RPM from measured intervals
                // Watch for loss of synchronization or signal anomalies
            }
        }

        state fault {
            entry {
                // Log fault code and description
                // Output diagnostic information to ECU
                // Cease reporting position data
            }
            do {
                // Wait for recovery initiation
            }
        }

        state recovery {
            entry {
                // Attempt to recover from fault condition
                // Re-initialize sensor parameters
                // Clear error counters
            }
            do {
                // Re-attempt synchronization
                // If synchronization succeeds, transition to synchronizing
                // If recovery fails after max retries, transition to fault
            }
        }

        transition first off then initializing accept PowerOn;
        transition first initializing then synchronizing accept InitializationComplete;
        transition first synchronizing then operational accept ReferenceGapDetected;
        transition first operational then fault accept ErrorDetected;
        transition first synchronizing then fault accept ErrorDetected;
        transition first fault then recovery accept RecoveryInitiated;
        transition first recovery then synchronizing accept RecoverySuccessful;
        transition first recovery then fault accept RecoveryFailed;
        transition first operational then off accept PowerOff;
        transition first fault then off accept PowerOff;
        transition first synchronizing then off accept PowerOff;
    }

    // ===== Main Sensing Unit Assembly =====
    part def CrankshaftPositionSensingUnit {
        in port wheelInterface : ToothPassagePort;
        port positionDataOut : PositionDataPort;
        port diagnosticOut : DiagnosticPort;

        part hallSensor : HallEffectSensor;
        part amplifier : SignalAmplifier;
        part filter : SignalFilter;
        part processor : SignalProcessor;

        connection wheelToSensor connect wheelInterface to hallSensor.sensorInput;
        connection sensorToAmplifier connect hallSensor.sensorOutput to amplifier.amplifierInput;
        connection amplifierToFilter connect amplifier.amplifierOutput to filter.filterInput;
        connection filterToProcessor connect filter.filterOutput to processor.processorInput;
        connection processorToPositionOut connect processor.positionOutput to positionDataOut;
        connection processorToDiagnosticOut connect processor.diagnosticOutput to diagnosticOut;

        exhibit state sensingUnitBehavior : SensingUnitStates;
    }

    part def EngineControlUnit {
        attribute ignitionTiming : Angle;
        attribute fuelInjectionTiming : Angle;
        attribute targetIdleRPM : AngularVelocity = 800.0;

        in port positionDataIn : PositionDataPort;
        in port diagnosticIn : DiagnosticPort;

        perform action manageEngine {
            in positionData : CrankshaftPositionData;
            in diagnostic : DiagnosticInfo;
            // Use crankshaft position and velocity for ignition timing
            // and fuel injection control
        }
    }

    // ===== System Context =====
    part def EngineSystem {
        part crankshaft : Crankshaft;
        part sensingUnit : CrankshaftPositionSensingUnit;
        part ecu : EngineControlUnit;

        connection wheelToSensingUnit connect crankshaft.reluctorWheel.toothPassageOut to sensingUnit.wheelInterface;
        connection sensingUnitToECU connect sensingUnit.positionDataOut to ecu.positionDataIn;
        connection sensingUnitDiagToECU connect sensingUnit.diagnosticOut to ecu.diagnosticIn;
    }

    // ===== Requirements =====
    requirement def PositionSensingRequirement {
        subject sensingUnit : CrankshaftPositionSensingUnit;

        requirement shallDetectCrankshaftPosition {
            doc "The sensing unit shall detect the absolute angular position of the crankshaft using the missing-tooth reference gap on the reluctor wheel.";
        }

        requirement shallMeasureRPM {
            doc "The sensing unit shall measure the real-time angular velocity of the crankshaft in RPM by measuring the time interval between consecutive tooth transitions.";
        }

        requirement shallIdentifyReferenceGap {
            doc "The sensing unit shall identify the missing-tooth gap once per crankshaft revolution to establish absolute position reference.";
        }

        requirement shallReportPositionAndVelocity {
            doc "The sensing unit shall output crankshaft angular position and velocity data to the engine control unit when in the operational state.";
        }
    }

    requirement def SignalProcessingRequirement {
        subject sensingUnit : CrankshaftPositionSensingUnit;

        requirement shallAmplifyRawSignal {
            doc "The unit shall amplify the raw Hall effect sensor voltage pulse to a stronger, more usable signal level.";
        }

        requirement shallFilterElectricalNoise {
            doc "The unit shall filter electrical noise from the amplified signal to ensure a clean and reliable signal for processing.";
        }

        requirement shallDetectToothTransitions {
            doc "The signal processor shall detect the signal transitions corresponding to each passing tooth on the reluctor wheel.";
        }

        requirement shallDetectGapByInterval {
            doc "The signal processor shall identify the missing-tooth gap by detecting a longer-than-usual pause in the signal that exceeds 1.5 times the normal tooth-to-tooth interval.";
        }
    }

    requirement def StateBehaviorRequirement {
        subject sensingUnit : CrankshaftPositionSensingUnit;

        requirement shallInitializeOnPowerOn {
            doc "The unit shall enter an initialization phase upon power-on, performing self-tests and parameter setup.";
        }

        requirement shallSynchronizeBeforeOperational {
            doc "The unit shall enter a synchronizing phase to search for the reference gap before transitioning to the operational state.";
        }

        requirement shallEnterFaultStateOnError {
            doc "The unit shall enter a fault state upon detecting an error during initialization, synchronization, or operational phases.";
        }

        requirement shallAttemptRecovery {
            doc "The unit shall attempt to recover from a fault state by re-initializing and re-synchronizing with the reluctor wheel.";
        }

        requirement shallReportDiagnosticsInFault {
            doc "The unit shall output diagnostic information including fault codes and descriptions when in the fault state.";
        }
    }

    requirement def ReluctorWheelRequirement {
        subject wheel : ReluctorWheel;

        requirement shallHave60Minus2Pattern {
            doc "The reluctor wheel shall have 60 teeth with 2 intentionally missing teeth creating a reference gap.";
            assert wheel.totalTeeth == 60 and wheel.missingTeeth == 2;
        }

        requirement shallProvideOneReferencePerRevolution {
            doc "The reluctor wheel shall provide exactly one reference gap per crankshaft revolution for absolute position determination.";
        }
    }

    requirement def RobustnessRequirement {
        subject sensingUnit : CrankshaftPositionSensingUnit;

        requirement shallOperateAcrossTemperatureRange {
            doc "The Hall effect sensor shall operate across a temperature range of -40 to 150 degrees Celsius.";
        }

        requirement shallTolerateSignalNoise {
            doc "The unit shall tolerate electrical noise from the engine environment through active filtering.";
        }

        requirement shallRecoverFromTransientFaults {
            doc "The unit shall be capable of recovering from transient faults and resuming synchronized operation.";
        }
    }
}
