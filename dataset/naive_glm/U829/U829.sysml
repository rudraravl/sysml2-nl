package PositionSensingUnitModel {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types with Units ----

    value type Voltage :> Real {
        :>> unit = 'V';
    }

    value type Distance :> Real {
        :>> unit = 'm';
    }

    value type Frequency :> Real {
        :>> unit = 'Hz';
    }

    value type DataRate :> Real {
        :>> unit = 'Hz';
    }

    value type AccuracySpec :> Real {
        :>> unit = 'mm';
    }

    value type OffsetValue :> Real {
        :>> unit = 'm';
    }

    value type ScaleFactor :> Real {
        :>> unit = '1';
    }

    value type Angle :> Real {
        :>> unit = 'deg';
    }

    // ---- Item Definitions ----

    item def RawPositionSignal {
        attribute xVoltage : Voltage;
        attribute yVoltage : Voltage;
        attribute zVoltage : Voltage;
    }

    item def Position3D {
        attribute x : Distance;
        attribute y : Distance;
        attribute z : Distance;
    }

    item def CalibratedPosition {
        :>> position : Position3D;
        attribute timestamp : Time;
        attribute confidence : Real;
    }

    item def CalibrationParameters {
        attribute xOffset : OffsetValue;
        attribute yOffset : OffsetValue;
        attribute zOffset : OffsetValue;
        attribute xScale : ScaleFactor;
        attribute yScale : ScaleFactor;
        attribute zScale : ScaleFactor;
        attribute rollMisalignment : Angle;
        attribute pitchMisalignment : Angle;
        attribute yawMisalignment : Angle;
    }

    item def ReferencePosition {
        :>> position : Position3D;
        attribute uncertainty : AccuracySpec;
    }

    item def MeasurementCommand {
        attribute commandKind : CommandKind;
    }

    enum def CommandKind {
        START_MEASURING;
        STOP_MEASURING;
        RECALIBRATE;
        RESET;
    }

    item def StatusReport {
        attribute state : String;
        attribute errorCode : Integer;
        attribute uptime : Time;
    }

    item def PowerStatus {
        attribute voltageOK : Boolean;
        attribute supplyVoltage : Voltage;
    }

    // ---- Port Definitions ----

    port def ExternalPowerPort {
        in attribute supplyVoltage : Voltage;
        out attribute powerStatus : PowerStatus;
    }

    port def RS485Port {
        in item commands : MeasurementCommand;
        out item measurements : CalibratedPosition;
        out item status : StatusReport;
        attribute baudRate : DataRate = 115200;
        attribute updateRate : DataRate = 100;
    }

    port def RawSignalPort {
        out item rawSignal : RawPositionSignal;
    }

    port def ProcessedSignalPort {
        out item processedPosition : Position3D;
    }

    port def CalibrationPort {
        out item calibrationParams : CalibrationParameters;
        in item referencePosition : ReferencePosition;
    }

    port def InternalPowerPort {
        out attribute regulatedVoltage : Voltage;
        out attribute powerAvailable : Boolean;
    }

    // ---- Part Definitions ----

    part def SensingElement {
        port rawOut : RawSignalPort;
        attribute measurementRange : Distance = 10 [m];
        attribute noiseFloor : Voltage = 0.002 [V];

        action def captureRawPosition {
            in objectPosition : Position3D;
            out raw : RawPositionSignal;
        }

        perform captureRawPosition;
    }

    part def SignalProcessor {
        port rawIn : RawSignalPort[0..1] {:>> direction = in;}
        port processedOut : ProcessedSignalPort;
        port calibIn : CalibrationPort[0..1] {:>> direction = in;}

        attribute filterCoeff : Real = 0.85;
        attribute currentCalibration : CalibrationParameters;

        action def convertVoltageToDistance {
            in raw : RawPositionSignal;
            in calib : CalibrationParameters;
            out pos : Position3D;

            // Conceptual conversion: voltage scaled and offset-corrected
        }

        action def applyDigitalFilter {
            in posIn : Position3D;
            out posOut : Position3D;
        }

        action def applyCalibrationCorrection {
            in posIn : Position3D;
            in calib : CalibrationParameters;
            out posOut : Position3D;
        }

        perform convertVoltageToDistance;
        perform applyDigitalFilter;
        perform applyCalibrationCorrection;
    }

    part def CalibrationModule {
        port calibOut : CalibrationPort;
        port refIn : CalibrationPort[0..1] {:>> direction = in;}

        attribute storedParameters : CalibrationParameters;
        attribute calibrationIterations : Integer = 0;
        attribute maxIterations : Integer = 100;

        action def computeOffsets {
            in measured : Position3D;
            in reference : ReferencePosition;
            out offsets : CalibrationParameters;
        }

        action def computeScalingFactors {
            in measured : Position3D;
            in reference : ReferencePosition;
            out scales : CalibrationParameters;
        }

        action def computeRotationalMisalignment {
            in measured : Position3D;
            in reference : ReferencePosition;
            out rotations : CalibrationParameters;
        }

        action def generateCalibrationParameters {
            in measured : Position3D;
            in reference : ReferencePosition;
            out params : CalibrationParameters;

            then computeOffsets;
            then computeScalingFactors;
            then computeRotationalMisalignment;
        }

        perform generateCalibrationParameters;
    }

    part def PositionSensor {
        part sensingElement : SensingElement;
        part signalProcessor : SignalProcessor;
        part calibrationModule : CalibrationModule;

        connect sensingElement.rawOut to signalProcessor.rawIn;
        connect calibrationModule.calibOut to signalProcessor.calibIn;
        connect signalProcessor.calibIn to calibrationModule.refIn;

        attribute accuracy : AccuracySpec = 1 [mm];
        attribute range : Distance = 10 [m];
    }

    part def PowerSupply {
        port extPower : ExternalPowerPort;
        port intPower : InternalPowerPort;

        attribute inputVoltage : Voltage = 24 [V];
        attribute regulated5V : Voltage = 5 [V];
        attribute regulated3V3 : Voltage = 3.3 [V];
        attribute powerGood : Boolean;

        action def regulatePower {
            in extVoltage : Voltage;
            out regulated : InternalPowerPort;
        }

        perform regulatePower;
    }

    part def DataAcquisitionInterface {
        port rs485 : RS485Port;
        port dataIn : ProcessedSignalPort[0..1] {:>> direction = in;}

        attribute protocol : String = "RS485";
        attribute reportingRate : DataRate = 100 [Hz];
        attribute baudRate : DataRate = 115200 [Hz];

        action def transmitMeasurement {
            in position : Position3D;
            out calibrated : CalibratedPosition;
        }

        action def receiveCommand {
            in cmd : MeasurementCommand;
        }

        perform transmitMeasurement;
        perform receiveCommand;
    }

    // ---- Top-Level Part with State Machine ----

    part def PositionSensingUnit {

        port extPowerPort : ExternalPowerPort;
        port commPort : RS485Port;

        part powerSupply : PowerSupply;
        part positionSensor : PositionSensor;
        part dataInterface : DataAcquisitionInterface;

        connect extPowerPort to powerSupply.extPower;
        connect powerSupply.intPower to positionSensor;
        connect powerSupply.intPower to dataInterface;
        connect positionSensor.signalProcessor.processedOut to dataInterface.dataIn;
        connect dataInterface.rs485 to commPort;

        attribute systemAccuracy : AccuracySpec = 1 [mm];
        attribute measurementRange : Distance = 10 [m];
        attribute reportingRate : DataRate = 100 [Hz];

        // ---- State Machine ----

        state def PositionSensingUnitLifecycle {

            entry action initializeHardware {
                // Power up sensing element, signal processor, calibration module, data interface
            }

            state PoweredOff;

            state Initializing {
                entry action powerOnSequence;
                do action configureSubsystems;
                exit action verifyHardwareReady;
            }

            state Calibrating {
                entry action startCalibration;
                do action runCalibrationSequence;
                exit action storeCalibrationParameters;
            }

            state Ready {
                entry action enterReadyMode;
                do action awaitCommand;
            }

            state ActiveMeasuring {
                entry action startContinuousMeasurement;
                do action continuouslyMeasureAndReport;
                exit action stopMeasurement;
            }

            state Fault {
                entry action logFault;
                do action awaitReset;
            }

            transition from PoweredOff to Initializing
                when extPowerPort.supplyVoltage == 24 [V]
                accept PowerStatus;

            transition from Initializing to Calibrating
                when powerSupply.powerGood == true
                accept StatusReport;

            transition from Calibrating to Ready
                accept CalibrationParameters;

            transition from Calibrating to Fault
                when positionSensor.calibrationModule.calibrationIterations > positionSensor.calibrationModule.maxIterations;

            transition from Ready to ActiveMeasuring
                accept MeasurementCommand
                if commPort.commands.commandKind == CommandKind::START_MEASURING;

            transition from ActiveMeasuring to Ready
                accept MeasurementCommand
                if commPort.commands.commandKind == CommandKind::STOP_MEASURING;

            transition from Ready to Calibrating
                accept MeasurementCommand
                if commPort.commands.commandKind == CommandKind::RECALIBRATE;

            transition from ActiveMeasuring to Calibrating
                accept MeasurementCommand
                if commPort.commands.commandKind == CommandKind::RECALIBRATE;

            transition from ActiveMeasuring to Fault
                when positionSensor.signalProcessor.currentCalibration == null;

            transition from Ready to Fault
                when powerSupply.powerGood == false;

            transition from Fault to Initializing
                accept MeasurementCommand
                if commPort.commands.commandKind == CommandKind::RESET;

            // Behaviors invoked during states
            action powerOnSequence {
                // Sequence subsystem power-up
            }

            action configureSubsystems {
                // Configure signal processor filter coefficients and data interface rate
            }

            action verifyHardwareReady {
                // Confirm all subsystems report ready
            }

            action startCalibration {
                // Trigger calibration module to begin parameter generation
            }

            action runCalibrationSequence {
                // Iterate offset, scale, rotation computation against reference
            }

            action storeCalibrationParameters {
                // Persist calibration parameters in signal processor
            }

            action enterReadyMode {
                // Set unit to standby, ready to accept commands
            }

            action awaitCommand {
                // Listen on RS485 for commands
            }

            action startContinuousMeasurement {
                // Begin 100 Hz measurement loop
            }

            action continuouslyMeasureAndReport {
                // Capture, process, calibrate, transmit
            }

            action stopMeasurement {
                // Halt measurement loop
            }

            action logFault {
                // Record error code and notify external system
            }

            action awaitReset {
                // Wait for reset command
            }
        }

        exhibit PositionSensingUnitLifecycle;
    }

    // ---- Requirements ----

    package Requirements {

        requirement def AccuracyRequirement {
            subject : PositionSensingUnit;
            attribute requiredAccuracy : AccuracySpec = 1 [mm];
            require constraint { subject.systemAccuracy <= requiredAccuracy }
            doc /* The system shall provide measurements with an accuracy of 1 millimeter or better. */
        }

        requirement def RangeRequirement {
            subject : PositionSensingUnit;
            attribute requiredRange : Distance = 10 [m];
            require constraint { subject.measurementRange >= requiredRange }
            doc /* The system shall measure position over a range of at least 10 meters. */
        }

        requirement def ReportingRateRequirement {
            subject : PositionSensingUnit;
            attribute requiredRate : DataRate = 100 [Hz];
            require constraint { subject.reportingRate >= requiredRate }
            doc /* The system shall report measurements via RS485 at a rate of 100 Hz. */
        }

        requirement def PowerSupplyRequirement {
            subject : PositionSensingUnit;
            attribute requiredInput : Voltage = 24 [V];
            require constraint { subject.powerSupply.inputVoltage == requiredInput }
            doc /* The system shall operate from an external 24V power source. */
        }

        requirement def CalibrationRequirement {
            subject : PositionSensingUnit;
            require constraint { subject.positionSensor.calibrationModule.storedParameters != null }
            doc /* The system shall be calibrated before entering the ready state. */
        }

        requirement def LifecycleRequirement {
            subject : PositionSensingUnit;
            doc /* The system shall follow the lifecycle: power on, initialize, calibrate, ready, active measuring, with fault handling. */
        }

        requirement def SelfContainedRequirement {
            subject : PositionSensingUnit;
            doc /* The system shall be a self-contained device integrating sensor, power supply, and communication interface. */
        }

        requirement def ThreeAxisMeasurementRequirement {
            subject : PositionSensingUnit;
            doc /* The system shall measure and report three-dimensional spatial position (X, Y, Z). */
        }

        requirement accuracyReq : AccuracyRequirement {
            :>> subject = PositionSensingUnit::self;
        }

        requirement rangeReq : RangeRequirement {
            :>> subject = PositionSensingUnit::self;
        }

        requirement rateReq : ReportingRateRequirement {
            :>> subject = PositionSensingUnit::self;
        }

        requirement powerReq : PowerSupplyRequirement {
            :>> subject = PositionSensingUnit::self;
        }

        requirement calibReq : CalibrationRequirement {
            :>> subject = PositionSensingUnit::self;
        }

        requirement lifecycleReq : LifecycleRequirement {
            :>> subject = PositionSensingUnit::self;
        }

        requirement selfContainedReq : SelfContainedRequirement {
            :>> subject = PositionSensingUnit::self;
        }

        requirement threeAxisReq : ThreeAxisMeasurementRequirement {
            :>> subject = PositionSensingUnit::self;
        }
    }

    // ---- Package-level instantiation for verification context ----

    part sensingUnitInstance : PositionSensingUnit {
        satisfy Requirements::accuracyReq;
        satisfy Requirements::rangeReq;
        satisfy Requirements::rateReq;
        satisfy Requirements::powerReq;
        satisfy Requirements::calibReq;
        satisfy Requirements::lifecycleReq;
        satisfy Requirements::selfContainedReq;
        satisfy Requirements::threeAxisReq;
    }

}
