package VelocityReceiverSystem {
    import ScalarValues::*;
    import ScalarFunctions::*;

    attribute def FrequencyUnit :> Real { unit "Hz"; }
    attribute def PowerUnit :> Real { unit "dBm"; }
    attribute def VelocityUnit :> Real { unit "m/s"; }
    attribute def TimeUnit :> Real { unit "s"; }
    attribute def ConfidenceUnit :> Real { unit "1"; min 0.0; max 1.0; }
    attribute def SNRUnit :> Real { unit "dB"; }
    attribute def DimensionlessUnit :> Real { unit "1"; }

    enum def ReceiverStatus {
        idle;
        acquiring;
        tracking;
        lost;
        calibrating;
    }

    item def RawSignal {
        attribute carrierFreq : FrequencyUnit;
        attribute power : PowerUnit;
        attribute snr : SNRUnit;
        attribute timestamp : TimeUnit;
        attribute sampleId : Integer;
    }

    item def ValidatedSignal :> RawSignal {
        attribute integrityOK : Boolean;
        attribute filtered : Boolean;
        attribute compensated : Boolean;
        attribute noiseFloor : PowerUnit;
    }

    item def VelocityVector {
        attribute vx : VelocityUnit;
        attribute vy : VelocityUnit;
        attribute vz : VelocityUnit;
    }

    item def VelocityMeasurement {
        attribute velocity : VelocityVector;
        attribute confidence : ConfidenceUnit;
        attribute status : ReceiverStatus;
        attribute timestamp : TimeUnit;
        attribute sampleId : Integer;
    }

    item def ReceiverCommand {
        attribute commandId : String;
        attribute targetMode : ReceiverStatus;
        attribute calibrationRequested : Boolean;
        attribute priority : Integer;
    }

    item def CalibrationParameters {
        attribute biasX : VelocityUnit;
        attribute biasY : VelocityUnit;
        attribute biasZ : VelocityUnit;
        attribute temperature : Real;
        attribute lastCalibrationTime : TimeUnit;
    }

    port def RawSignalInPort {
        in item signal : RawSignal;
    }

    port def RawSignalOutPort {
        out item signal : RawSignal;
    }

    port def ValidatedSignalPort {
        in item signal : ValidatedSignal;
    }

    port def ValidatedSignalOutPort {
        out item signal : ValidatedSignal;
    }

    port def VelocityDataOutPort {
        out item measurement : VelocityMeasurement;
    }

    port def CommandInPort {
        in item command : ReceiverCommand;
    }

    port def StatusOutPort {
        out item status : ReceiverStatus;
    }

    port def CalibrationPort {
        in item params : CalibrationParameters;
        out item ack : Boolean;
    }

    part def SignalAcquisitionUnit {
        port acquisitionIn : RawSignalInPort;
        port acquisitionOut : RawSignalOutPort;
        port statusOut : StatusOutPort;

        attribute lockThreshold : SNRUnit = 10.0 [dB];
        attribute trackThreshold : SNRUnit = 15.0 [dB];
        attribute lostThreshold : SNRUnit = 5.0 [dB];
        attribute searchBandwidth : FrequencyUnit = 2000.0 [Hz];
        attribute currentStatus : ReceiverStatus = ReceiverStatus::idle;

        action def SearchForSignalAction {
            in scanRange : FrequencyUnit;
            out detected : Boolean;
        }

        action def AttemptLockAction {
            in signal : RawSignal;
            out locked : Boolean;
        }

        action def TrackSignalAction {
            in signal : RawSignal;
            out tracking : Boolean;
        }

        state machine AcquisitionStateMachine {
            entry;
            then Searching;

            state Searching {
                entry { currentStatus = ReceiverStatus::acquiring; }
                do { performSearch(); }
                exit { send statusOut.status; }
            }

            state Locking {
                entry { currentStatus = ReceiverStatus::acquiring; }
                do { performLock(); }
                exit { send statusOut.status; }
            }

            state Tracking {
                entry { currentStatus = ReceiverStatus::tracking; }
                do { performTrack(); }
                exit { send statusOut.status; }
            }

            state Lost {
                entry { currentStatus = ReceiverStatus::lost; }
                do { logLoss(); }
                exit { send statusOut.status; }
            }

            transition from Searching to Locking
                when acquisitionIn.signal.snr > lockThreshold
                if acquisitionIn.signal.power > -120.0 [dBm];

            transition from Locking to Tracking
                when acquisitionIn.signal.snr > trackThreshold;

            transition from Locking to Searching
                when acquisitionIn.signal.snr < lostThreshold;

            transition from Tracking to Lost
                when acquisitionIn.signal.snr < lostThreshold;

            transition from Lost to Searching
                after 2.0 [s];
        }

        private action performSearch : SearchForSignalAction;
        private action performLock : AttemptLockAction;
        private action performTrack : TrackSignalAction;
        private action logLoss;
    }

    part def SignalProcessor {
        port processorIn : RawSignalInPort;
        port processorOut : ValidatedSignalOutPort;

        attribute minSNR : SNRUnit = 8.0 [dB];
        attribute filterCutoff : FrequencyUnit = 50.0 [Hz];
        attribute compensationEnabled : Boolean = true;
        attribute validated : Boolean = false;

        action def ValidateSignalAction {
            in signal : RawSignal;
            out valid : Boolean;
        }

        action def ApplyFiltersAction {
            in signal : RawSignal;
            out filtered : ValidatedSignal;
        }

        action def CompensateErrorsAction {
            in signal : ValidatedSignal;
            out compensated : ValidatedSignal;
        }

        state machine ProcessingStateMachine {
            entry;
            then Idle;

            state Idle {
                do { waitForSignal(); }
            }

            state Validating {
                do { runValidation(); }
            }

            state Filtering {
                do { runFiltering(); }
            }

            state Compensating {
                do { runCompensation(); }
            }

            state Emitting {
                entry { send processorOut.signal; }
            }

            transition from Idle to Validating
                when processorIn.signal.snr > minSNR;

            transition from Validating to Filtering
                when validated == true;

            transition from Validating to Idle
                when validated == false;

            transition from Filtering to Compensating;

            transition from Compensating to Emitting;

            transition from Emitting to Idle;
        }

        private action waitForSignal;
        private action runValidation : ValidateSignalAction;
        private action runFiltering : ApplyFiltersAction;
        private action runCompensation : CompensateErrorsAction;
    }

    part def VelocityEstimator {
        port estimatorIn : ValidatedSignalPort;
        port estimatorOut : VelocityDataOutPort;
        port calibrationIn : CalibrationPort;

        attribute updateRate : FrequencyUnit = 100.0 [Hz];
        attribute biasX : VelocityUnit = 0.0 [m/s];
        attribute biasY : VelocityUnit = 0.0 [m/s];
        attribute biasZ : VelocityUnit = 0.0 [m/s];
        attribute done : Boolean = false;

        action def ComputeVelocityAction {
            in signal : ValidatedSignal;
            in biasX : VelocityUnit;
            in biasY : VelocityUnit;
            in biasZ : VelocityUnit;
            out measurement : VelocityMeasurement;
        }

        action def ComputeConfidenceAction {
            in signal : ValidatedSignal;
            out confidence : ConfidenceUnit;
        }

        state machine EstimationStateMachine {
            entry;
            then Idle;

            state Idle;

            state Estimating {
                do { runCompute(); }
                entry { send estimatorOut.measurement; }
            }

            state Calibrating {
                do { applyCalibration(); }
            }

            transition from Idle to Estimating
                when estimatorIn.signal.filtered == true
                if estimatorIn.signal.compensated == true;

            transition from Estimating to Idle
                when done == true;

            transition from Idle to Calibrating
                when calibrationIn.params.lastCalibrationTime > 0.0 [s];

            transition from Calibrating to Idle
                when calibrationIn.ack == true;
        }

        private action runCompute : ComputeVelocityAction;
        private action applyCalibration;
    }

    part def ReceiverController {
        port cmdPort : CommandInPort;
        port statusOut : StatusOutPort;
        port calibrationOut : CalibrationPort;

        attribute currentMode : ReceiverStatus = ReceiverStatus::idle;
        attribute calibrationInterval : TimeUnit = 3600.0 [s];
        attribute lastCalibration : TimeUnit = 0.0 [s];
        attribute calibrationComplete : Boolean = false;

        action def MonitorCommandsAction {
            in command : ReceiverCommand;
            out accepted : Boolean;
        }

        action def SuperviseOperationAction {
            out healthy : Boolean;
        }

        action def PerformCalibrationAction {
            out params : CalibrationParameters;
        }

        state machine ControllerStateMachine {
            entry;
            then Standby;

            state Standby {
                entry { currentMode = ReceiverStatus::idle; }
                do { runMonitor(); }
                exit { send statusOut.status; }
            }

            state Operating {
                entry { currentMode = ReceiverStatus::tracking; }
                do { runSupervise(); }
                exit { send statusOut.status; }
            }

            state Calibrating {
                entry { currentMode = ReceiverStatus::calibrating; }
                do { runCalibration(); }
                exit { send statusOut.status; }
            }

            state Fault {
                entry { currentMode = ReceiverStatus::lost; }
                do { reportFault(); }
                exit { send statusOut.status; }
            }

            transition from Standby to Operating
                when cmdPort.command.targetMode == ReceiverStatus::tracking;

            transition from Operating to Calibrating
                when cmdPort.command.calibrationRequested == true;

            transition from Calibrating to Operating
                when calibrationComplete == true;

            transition from Operating to Fault
                when cmdPort.command.targetMode == ReceiverStatus::lost;

            transition from Fault to Standby
                when cmdPort.command.targetMode == ReceiverStatus::idle;
        }

        private action runMonitor : MonitorCommandsAction;
        private action runSupervise : SuperviseOperationAction;
        private action runCalibration : PerformCalibrationAction;
        private action reportFault;
    }

    part def VelocityReceiver {
        port externalSignalIn : RawSignalInPort;
        port externalCmdIn : CommandInPort;
        port velocityDataOut : VelocityDataOutPort;
        port systemStatusOut : StatusOutPort;

        part acquisitionUnit : SignalAcquisitionUnit;
        part processor : SignalProcessor;
        part estimator : VelocityEstimator;
        part controller : ReceiverController;

        connection acquisitionInput connect externalSignalIn to acquisitionUnit.acquisitionIn;
        connection rawSignalFlow connect acquisitionUnit.acquisitionOut to processor.processorIn;
        connection validatedSignalFlow connect processor.processorOut to estimator.estimatorIn;
        connection velocityOutput connect estimator.estimatorOut to velocityDataOut;
        connection commandFlow connect externalCmdIn to controller.cmdPort;
        connection controllerStatus connect controller.statusOut to systemStatusOut;
        connection acquisitionStatus connect acquisitionUnit.statusOut to systemStatusOut;
        connection calibrationLink connect controller.calibrationOut to estimator.calibrationIn;
    }

    requirement def VelocityAccuracyRequirement {
        attribute maxError : VelocityUnit = 0.05 [m/s];
        subject receiver : VelocityReceiver;
        objective {
            assert receiver.velocityDataOut.measurement.velocity.vx <= maxError
            and receiver.velocityDataOut.measurement.velocity.vy <= maxError
            and receiver.velocityDataOut.measurement.velocity.vz <= maxError
        }
    }

    requirement def UpdateRateRequirement {
        attribute minRate : FrequencyUnit = 50.0 [Hz];
        subject receiver : VelocityReceiver;
        objective {
            assert receiver.estimator.updateRate >= minRate
        }
    }

    requirement def ContinuousOperationRequirement {
        subject receiver : VelocityReceiver;
        objective {
            assert receiver.controller.currentMode == ReceiverStatus::tracking
        }
    }

    requirement def SignalIntegrityRequirement {
        attribute minSNR : SNRUnit = 8.0 [dB];
        subject processor : SignalProcessor;
        objective {
            assert processor.processorIn.signal.snr >= minSNR
            implies processor.processorOut.signal.integrityOK == true
        }
    }

    requirement def ConfidenceReportingRequirement {
        attribute minConfidence : ConfidenceUnit = 0.8;
        subject estimator : VelocityEstimator;
        objective {
            assert estimator.estimatorOut.measurement.confidence >= minConfidence
        }
    }

    requirement def AcquisitionRecoveryRequirement {
        attribute maxRecoveryTime : TimeUnit = 5.0 [s];
        subject acquisition : SignalAcquisitionUnit;
        objective {
            assert acquisition.currentStatus == ReceiverStatus::lost
            implies acquisition.AcquisitionStateMachine.recover within maxRecoveryTime
        }
    }

    satisfaction satisfyAccuracy by VelocityReceiver satisfies VelocityAccuracyRequirement;
    satisfaction satisfyUpdateRate by VelocityReceiver satisfies UpdateRateRequirement;
    satisfaction satisfyContinuous by VelocityReceiver satisfies ContinuousOperationRequirement;
    satisfaction satisfyIntegrity by SignalProcessor satisfies SignalIntegrityRequirement;
    satisfaction satisfyConfidence by VelocityEstimator satisfies ConfidenceReportingRequirement;
    satisfaction satisfyRecovery by SignalAcquisitionUnit satisfies AcquisitionRecoveryRequirement;
}
