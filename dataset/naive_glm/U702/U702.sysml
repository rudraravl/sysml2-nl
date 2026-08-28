package GyroNavigationSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----
    value type AngularRateValue :> Real { unit 'rad/s'; }
    value type AngleValue :> Real { unit 'rad'; }
    value type VoltageValue :> Real { unit 'V'; }
    value type CurrentValue :> Real { unit 'A'; }
    value type PowerValue :> Real { unit 'W'; }
    value type FrequencyValue :> Real { unit 'Hz'; }
    value type TimeValue :> Real { unit 's'; }

    // ---- Enumerations ----
    enum def OperationalMode { init; calibration; operational; stopped; }
    enum def CommandKind { initialize; calibrate; operate; stop; }
    enum def HealthStatus { healthy; degraded; fault; }

    // ---- Item definitions ----
    item def RawSignal {
        attribute voltage : VoltageValue;
        attribute noiseFloor : VoltageValue;
        attribute axis : String;
    }

    item def ConditionedSignal {
        attribute voltage : VoltageValue;
        attribute rate : AngularRateValue;
        attribute axis : String;
    }

    item def CorrectedRate {
        attribute rollRate : AngularRateValue;
        attribute pitchRate : AngularRateValue;
        attribute yawRate : AngularRateValue;
    }

    item def Attitude {
        attribute roll : AngleValue;
        attribute pitch : AngleValue;
        attribute yaw : AngleValue;
    }

    item def CalibrationData {
        attribute rollBias : AngularRateValue;
        attribute pitchBias : AngularRateValue;
        attribute yawBias : AngularRateValue;
        attribute temperature : Real;
        attribute valid : Boolean;
    }

    item def Command {
        attribute kind : CommandKind;
        attribute timestamp : TimeValue;
    }

    item def StatusReport {
        attribute mode : OperationalMode;
        attribute health : HealthStatus;
        attribute timestamp : TimeValue;
        attribute calibrationValid : Boolean;
    }

    item def NavData {
        attribute rates : CorrectedRate;
        attribute attitude : Attitude;
        attribute status : StatusReport;
    }

    item def PowerFlow {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        attribute available : PowerValue;
    }

    // ---- Port definitions ----
    port def PowerInPort {
        in item power : PowerFlow;
    }

    port def PowerOutPort {
        out item power : PowerFlow;
    }

    port def CommandInPort {
        in item command : Command;
    }

    port def CommandOutPort {
        out item command : Command;
    }

    port def NavDataOutPort {
        out item navData : NavData;
    }

    port def NavDataInPort {
        in item navData : NavData;
    }

    port def RawSignalOutPort {
        out item raw : RawSignal;
    }

    port def RawSignalInPort {
        in item raw : RawSignal;
    }

    port def ConditionedSignalOutPort {
        out item conditioned : ConditionedSignal;
    }

    port def ConditionedSignalInPort {
        in item conditioned : ConditionedSignal;
    }

    port def CalibrationDataOutPort {
        out item calData : CalibrationData;
    }

    port def CalibrationDataInPort {
        in item calData : CalibrationData;
    }

    // ---- Internal components ----
    part def SensingElement {
        port rawOut : RawSignalOutPort;
        attribute sensitivity : Real;
        attribute bandwidth : FrequencyValue;
        attribute temperature : Real;

        action def SenseRotation {
            in rotation : AngularRateValue;
            in axis : String;
            out raw : RawSignal;
        }

        action sense : SenseRotation;
    }

    part def SignalConditioner {
        port rawIn : RawSignalInPort;
        port conditionedOut : ConditionedSignalOutPort;
        attribute gain : Real;
        attribute cutoffFreq : FrequencyValue;
        attribute noiseReduction : Real;

        action def Condition {
            in raw : RawSignal;
            out conditioned : ConditionedSignal;
        }

        action condition : Condition;
    }

    part def CalibrationModule {
        port calDataOut : CalibrationDataOutPort;
        attribute sampleCount : Integer;
        attribute averagingWindow : TimeValue;
        attribute lastCalibration : TimeValue;

        action def RunCalibration {
            in duration : TimeValue;
            out calData : CalibrationData;
        }

        action runCalibration : RunCalibration;
    }

    part def DigitalProcessor {
        port conditionedIn : ConditionedSignalInPort;
        port calDataIn : CalibrationDataInPort;
        port navDataOut : NavDataOutPort;
        attribute currentAttitude : Attitude;
        attribute currentRates : CorrectedRate;
        attribute activeCalibration : CalibrationData;
        attribute samplePeriod : TimeValue;

        action def ApplyBiasCorrection {
            in signal : ConditionedSignal;
            in calData : CalibrationData;
            out corrected : CorrectedRate;
        }

        action def IntegrateAttitude {
            in rates : CorrectedRate;
            in dt : TimeValue;
            inout attitude : Attitude;
        }

        action def PublishNavData {
            in rates : CorrectedRate;
            in attitude : Attitude;
            in mode : OperationalMode;
            out navData : NavData;
        }

        action correct : ApplyBiasCorrection;
        action integrate : IntegrateAttitude;
        action publish : PublishNavData;
    }

    // ---- Gyroscope unit (core assembly) ----
    part def GyroscopeUnit {
        port powerIn : PowerInPort;
        port cmdIn : CommandInPort;
        port navOut : NavDataOutPort;

        attribute mode : OperationalMode := OperationalMode::init;
        attribute initialized : Boolean := false;

        part sensing : SensingElement;
        part conditioner : SignalConditioner;
        part processor : DigitalProcessor;
        part calibrator : CalibrationModule;

        connection rawFlow connect sensing.rawOut to conditioner.rawIn;
        connection conditionedFlow connect conditioner.conditionedOut to processor.conditionedIn;
        connection calFlow connect calibrator.calDataOut to processor.calDataIn;

        state def GyroStateMachine {
            entry; then Initializing;

            state Initializing {
                entry action { mode := OperationalMode::init; }
                do action { initialized := false; }
                exit action { initialized := true; }
            }

            transition init_to_calib
                from Initializing
                to Calibrating
                when cmdIn.command.kind == CommandKind::calibrate;

            transition init_to_op
                from Initializing
                to Operational
                when cmdIn.command.kind == CommandKind::operate
                if initialized;

            state Calibrating {
                entry action { mode := OperationalMode::calibration; }
                do action calibrator.runCalibration;
            }

            transition calib_to_op
                from Calibrating
                to Operational
                when cmdIn.command.kind == CommandKind::operate
                if processor.calDataIn.calData.valid;

            transition calib_to_init
                from Calibrating
                to Initializing
                when cmdIn.command.kind == CommandKind::initialize;

            state Operational {
                entry action { mode := OperationalMode::operational; }
                do action {
                    processor.correct;
                    processor.integrate;
                    processor.publish;
                }
            }

            transition op_to_calib
                from Operational
                to Calibrating
                when cmdIn.command.kind == CommandKind::calibrate;

            transition op_to_stopped
                from Operational
                to Stopped
                when cmdIn.command.kind == CommandKind::stop;

            state Stopped {
                entry action { mode := OperationalMode::stopped; }
            }

            transition stopped_to_init
                from Stopped
                to Initializing
                when cmdIn.command.kind == CommandKind::initialize;
        }

        behavior stateMachine : GyroStateMachine;
    }

    // ---- External integration parts ----
    part def PowerSource {
        port powerOut : PowerOutPort;
        attribute nominalVoltage : VoltageValue;
        attribute maxPower : PowerValue;
        attribute regulated : Boolean;
    }

    part def NavigationComputer {
        port navIn : NavDataInPort;
        attribute lastReceived : NavData;
        attribute updateRate : FrequencyValue;

        action def ConsumeNavData {
            in navData : NavData;
        }

        action consume : ConsumeNavData;
    }

    part def PlatformController {
        port cmdOut : CommandOutPort;
        attribute commandQueue : Command[*];

        action def IssueCommand {
            in kind : CommandKind;
            out command : Command;
        }

        action issue : IssueCommand;
    }

    // ---- Top-level system ----
    part def GyroNavigationSystem {
        part gyro : GyroscopeUnit;
        part navComputer : NavigationComputer;
        part powerSource : PowerSource;
        part controller : PlatformController;

        connection powerLink connect powerSource.powerOut to gyro.powerIn;
        connection dataLink connect gyro.navOut to navComputer.navIn;
        connection commandLink connect controller.cmdOut to gyro.cmdIn;
    }

    // ---- Requirements ----
    requirement def RotationMeasurementRequirement {
        subject gyroUnit : GyroscopeUnit;
        requirement : The gyroUnit shall measure rotation about three orthogonal axes and produce a raw electronic signal proportional to the angular rate.
    }

    requirement def SignalConditioningRequirement {
        subject conditioner : SignalConditioner;
        requirement : The conditioner shall amplify the raw signal and filter out interference above its cutoff frequency before forwarding it.
    }

    requirement def BiasCorrectionRequirement {
        subject processor : DigitalProcessor;
        requirement : The processor shall apply bias corrections derived from calibration data to compensate for inherent sensor drift.
    }

    requirement def AttitudeIntegrationRequirement {
        subject processor : DigitalProcessor;
        requirement : The processor shall integrate corrected angular rates over time to continuously compute roll, pitch, and yaw angles.
    }

    requirement def CalibrationRequirement {
        subject calibrator : CalibrationModule;
        requirement : The calibrator shall produce valid calibration data on command and provide it to the processor.
    }

    requirement def OperationalModesRequirement {
        subject gyroUnit : GyroscopeUnit;
        requirement : The gyroUnit shall support initialization, calibration, operational, and stopped modes controlled by external commands.
    }

    requirement def ContinuousOutputRequirement {
        subject gyroUnit : GyroscopeUnit;
        requirement : While in operational mode, the gyroUnit shall continuously output angular rotation rates, calculated attitude, and operational status.
    }

    requirement def ExternalPowerRequirement {
        subject gyroUnit : GyroscopeUnit;
        requirement : The gyroUnit shall receive electrical power from an external source through its power port.
    }

    requirement def NavigationInterfaceRequirement {
        subject system : GyroNavigationSystem;
        requirement : The system shall deliver navigation data to the navigation computer for use in stabilization and guidance.
    }

    requirement def StopBehaviorRequirement {
        subject gyroUnit : GyroscopeUnit;
        requirement : The gyroUnit shall cease continuous output upon receiving a stop command and remain in stopped mode until reinitialized.
    }

    // ---- Requirement satisfaction ----
    satisfaction satisfy RotationMeasurementRequirement by gyro.sensing;
    satisfaction satisfy SignalConditioningRequirement by gyro.conditioner;
    satisfaction satisfy BiasCorrectionRequirement by gyro.processor.correct;
    satisfaction satisfy AttitudeIntegrationRequirement by gyro.processor.integrate;
    satisfaction satisfy CalibrationRequirement by gyro.calibrator;
    satisfaction satisfy OperationalModesRequirement by gyro.stateMachine;
    satisfaction satisfy ContinuousOutputRequirement by gyro.processor.publish;
    satisfaction satisfy ExternalPowerRequirement by gyro.powerIn;
    satisfaction satisfy NavigationInterfaceRequirement by system.dataLink;
    satisfaction satisfy StopBehaviorRequirement by gyro.stateMachine;
}
