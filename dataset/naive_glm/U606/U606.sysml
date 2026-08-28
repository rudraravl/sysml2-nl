package AuxanometerModel {
    import ScalarValues::*;

    // ================================================================
    // VALUE TYPES WITH UNITS
    // ================================================================

    value type MicroMeter :> Real {
        doc § Linear displacement in micrometers (µm).;
    }

    value type MilliMeter :> Real {
        doc § Linear displacement in millimeters (mm).;
    }

    value type DegreeAngle :> Real {
        doc § Angular displacement in degrees (°).;
    }

    value type TimeSecond :> Real {
        doc § Elapsed time in seconds (s).;
    }

    value type FrequencyHz :> Real {
        doc § Sampling frequency in hertz (Hz).;
    }

    value type GrowthVelocity :> Real {
        doc § Plant growth velocity in µm/s.;
    }

    value type AmplificationRatio :> Real {
        doc § Dimensionless lever amplification factor.;
    }

    value type PulseTotal :> Integer {
        doc § Accumulated rotary encoder pulse count.;
    }

    value type EncoderPPR :> Integer {
        doc § Encoder resolution in pulses per revolution.;
    }

    // ================================================================
    // ITEM DEFINITIONS
    // ================================================================

    item def EncoderReading {
        doc § Raw angular measurement packet from the rotary encoder.;
        attribute angle : DegreeAngle;
        attribute pulseCount : PulseTotal;
        attribute timestamp : TimeSecond;
    }

    item def GrowthRecord {
        doc § Time-stamped growth measurement record for long-term storage.;
        attribute timestamp : TimeSecond;
        attribute cumulativeDisplacement : MicroMeter;
        attribute instantaneousGrowthRate : GrowthVelocity;
        attribute encoderAngle : DegreeAngle;
    }

    item def DisplayInfo {
        doc § Computed display data for the visual pointer.;
        attribute pointerAngle : DegreeAngle;
        attribute totalGrowth : MicroMeter;
    }

    item def CalibrationData {
        doc § Baseline calibration data establishing the zero reference.;
        attribute baselineAngle : DegreeAngle;
        attribute baselineDisplacement : MicroMeter;
    }

    item def CommandMsg {
        doc § Operator command message for state transitions.;
        attribute commandType : String;
        attribute timestamp : TimeSecond;
    }

    // ================================================================
    // PORT DEFINITIONS
    // ================================================================

    port def LinearMotionPort {
        doc § Port carrying linear displacement in micrometers.;
        inout displacement : MicroMeter;
    }

    port def RotaryMotionPort {
        doc § Port carrying angular displacement in degrees.;
        inout angle : DegreeAngle;
    }

    port def EncoderOutPort {
        doc § Output port for encoder readings.;
        out reading : EncoderReading;
    }

    port def EncoderInPort {
        doc § Input port for encoder readings.;
        in reading : EncoderReading;
    }

    port def RecordOutPort {
        doc § Output port for growth records.;
        out record : GrowthRecord;
    }

    port def RecordInPort {
        doc § Input port for growth records.;
        in record : GrowthRecord;
    }

    port def DisplayOutPort {
        doc § Output port for display information.;
        out info : DisplayInfo;
    }

    port def DisplayInPort {
        doc § Input port for display information.;
        in info : DisplayInfo;
    }

    port def CalibrationOutPort {
        doc § Output port for calibration data.;
        out calibration : CalibrationData;
    }

    port def CalibrationInPort {
        doc § Input port for calibration data.;
        in calibration : CalibrationData;
    }

    port def CommandOutPort {
        doc § Output port for operator commands.;
        out command : CommandMsg;
    }

    port def CommandInPort {
        doc § Input port for operator commands.;
        in command : CommandMsg;
    }

    // ================================================================
    // REQUIREMENT DEFINITIONS
    // ================================================================

    requirement def PrecisionRequirement {
        doc § The Auxanometer shall measure minute vertical plant growth with high precision.;
        attribute resolution : MicroMeter = 0.01;
        attribute fullScaleRange : MilliMeter = 50.0;
    }

    requirement def LeverAmplificationRequirement {
        doc § The lever arm shall magnify raw plant displacement by a known mechanical factor.;
        attribute amplificationFactor : AmplificationRatio = 50.0;
    }

    requirement def DualReadoutRequirement {
        doc § The instrument shall provide both a digital recording and a direct visual reading of total growth.;
    }

    requirement def StateMachineRequirement {
        doc § The instrument shall support idle, calibration, measuring, and paused operating states with operator commands for start, stop, pause, and resume.;
    }

    requirement def DataAcquisitionRequirement {
        doc § The data acquisition unit shall calculate linear displacement and growth rate at regular sampling intervals.;
        attribute samplingRate : FrequencyHz = 1.0;
    }

    requirement def ContinuousMonitoringRequirement {
        doc § The Auxanometer shall continuously monitor plant growth over extended experimental durations.;
        attribute maxDuration : TimeSecond = 86400.0;
    }

    requirement def EncoderResolutionRequirement {
        doc § The rotary encoder shall provide high-resolution angular measurement for precise growth tracking.;
        attribute pulsesPerRevolution : EncoderPPR = 1000;
    }

    requirement def AuxanometerSystemRequirement
        :> PrecisionRequirement, LeverAmplificationRequirement, DualReadoutRequirement,
           StateMachineRequirement, DataAcquisitionRequirement,
           ContinuousMonitoringRequirement, EncoderResolutionRequirement {
        doc § The Auxanometer is a precision instrument for automated measurement and recording of plant growth, combining mechanical amplification, electronic sensing, dual digital and visual readout, and flexible operator control for scientific and agricultural analysis.;
    }

    // ================================================================
    // PART DEFINITIONS WITH BEHAVIORS
    // ================================================================

    part def AttachmentPoint {
        doc § Delicate mechanical contact resting on the plant apex; transfers tiny vertical growth motion to the lever.;
        port apexPort : LinearMotionPort;
        attribute contactDisplacement : MicroMeter = 0.0;

        action def transferGrowth {
            doc § Transfer plant apex motion to the lever system.;
            in plantGrowth : MicroMeter;
            out leverInput : MicroMeter;
        }
    }

    part def LeverArm {
        doc § Mechanical lever amplifying the small plant apex displacement to a more easily measurable scale.;
        port inputPort : LinearMotionPort;
        port outputPort : LinearMotionPort;
        attribute amplificationFactor : AmplificationRatio = 50.0;

        action def amplifyDisplacement {
            doc § Magnify the input displacement by the lever amplification factor.;
            in plantDisplacement : MicroMeter;
            out amplifiedDisplacement : MicroMeter;
        }
    }

    part def Pulley {
        doc § Mechanical pulley converting amplified linear motion into rotation.;
        port linearInputPort : LinearMotionPort;
        port rotaryOutputPort : RotaryMotionPort;
        port pointerDrivePort : RotaryMotionPort;
        attribute pulleyRadius : MicroMeter = 5000.0;
        attribute currentAngle : DegreeAngle = 0.0;

        action def convertLinearToRotary {
            doc § Convert amplified linear displacement to angular rotation.;
            in linearDisplacement : MicroMeter;
            out angle : DegreeAngle;
        }
    }

    part def RotaryEncoder {
        doc § High-resolution electronic rotary encoder measuring the precise angle of pulley rotation.;
        port mechanicalInputPort : RotaryMotionPort;
        port dataOutputPort : EncoderOutPort;
        attribute pulsesPerRevolution : EncoderPPR = 1000;
        attribute currentAngle : DegreeAngle = 0.0;
        attribute currentPulseCount : PulseTotal = 0;

        action def measureAngle {
            doc § Measure the current rotation angle and emit an encoder reading.;
            in rotation : DegreeAngle;
            out reading : EncoderReading;
        }
    }

    part def DataAcquisitionUnit {
        doc § Electronic data acquisition unit that calculates linear displacement and growth rate from encoder readings at regular intervals.;
        port encoderInputPort : EncoderInPort;
        port recordOutputPort : RecordOutPort;
        port displayOutputPort : DisplayOutPort;
        port calibrationInputPort : CalibrationInPort;
        attribute samplingRate : FrequencyHz = 1.0;
        attribute calibration : CalibrationData;
        attribute lastDisplacement : MicroMeter = 0.0;
        attribute lastTimestamp : TimeSecond = 0.0;
        attribute leverFactor : AmplificationRatio = 50.0;
        attribute pulleyRadius : MicroMeter = 5000.0;

        action def processEncoderReading {
            doc § Process an encoder reading into a growth record and display data.;
            in reading : EncoderReading;
            out record : GrowthRecord;
            out display : DisplayInfo;
        }

        action def calculateDisplacement {
            doc § Calculate linear displacement from encoder angle and calibration baseline.;
            in angle : DegreeAngle;
            in cal : CalibrationData;
            out displacement : MicroMeter;
        }

        action def calculateGrowthRate {
            doc § Calculate instantaneous growth rate from successive displacement samples.;
            in currentDisplacement : MicroMeter;
            in previousDisplacement : MicroMeter;
            in currentTime : TimeSecond;
            in previousTime : TimeSecond;
            out rate : GrowthVelocity;
        }
    }

    part def RecordingDevice {
        doc § Long-term storage device for time-stamped growth measurement records.;
        port recordInputPort : RecordInPort;
        attribute storageCapacity : Integer = 1000000;
        attribute recordCount : Integer = 0;

        action def storeRecord {
            doc § Store a time-stamped growth record in non-volatile memory.;
            in record : GrowthRecord;
        }
    }

    part def Pointer {
        doc § Physical pointer attached to the mechanism, moving along a graduated scale for at-a-glance visual reading.;
        port motionPort : RotaryMotionPort;
        port displayInputPort : DisplayInPort;
        attribute currentAngle : DegreeAngle = 0.0;
        attribute currentDisplacement : MicroMeter = 0.0;

        action def updatePosition {
            doc § Position the pointer based on rotation and computed display data.;
            in rotation : DegreeAngle;
            in display : DisplayInfo;
        }
    }

    part def GraduatedScale {
        doc § Calibrated physical scale providing immediate visual reading of total cumulative growth.;
        attribute fullScaleRange : MilliMeter = 50.0;
        attribute numDivisions : Integer = 100;
        attribute micrometersPerDivision : MicroMeter = 500.0;
    }

    part def OperatorInterface {
        doc § Interface through which an operator issues commands to start, stop, pause, resume, or calibrate the measurement process.;
        port commandOutputPort : CommandOutPort;
        attribute lastCommand : CommandMsg;

        action def issueCommand {
            doc § Issue an operator command to the system.;
            out cmd : CommandMsg;
        }
    }

    part def Controller {
        doc § System controller managing operational states and coordinating subsystems based on operator commands.;
        port commandInputPort : CommandInPort;
        port calibrationOutputPort : CalibrationOutPort;
        port encoderMonitorPort : EncoderInPort;
        attribute currentState : String = "idle";
        attribute currentCommand : String = "";
        attribute baselineAngle : DegreeAngle = 0.0;
        attribute baselineDisplacement : MicroMeter = 0.0;

        action def resetSystem {
            doc § Reset the system to initial idle conditions.;
        }

        action def startCalibrationSequence {
            doc § Begin the calibration phase to establish a baseline.;
        }

        action def performCalibration {
            doc § Perform calibration measurement to establish baseline reference.;
            out calData : CalibrationData;
        }

        action def beginMeasurement {
            doc § Start the active measurement phase.;
        }

        action def sampleContinuously {
            doc § Continuously sample encoder data during active measurement.;
        }

        action def suspendSampling {
            doc § Pause ongoing measurements while retaining state.;
        }

        state machine AuxanometerStates {
            doc § Operational state machine: idle, calibration, measuring, paused with operator commands for start, stop, pause, resume, and calibrate.;

            state idle {
                doc § Instrument idle, not actively measuring.;
                entry action resetSystem;
            }

            state calibration {
                doc § Calibration phase establishing a baseline reference for zero displacement.;
                entry action startCalibrationSequence;
                do action performCalibration;
            }

            state measuring {
                doc § Actively measuring plant growth at the configured sampling rate.;
                entry action beginMeasurement;
                do action sampleContinuously;
            }

            state paused {
                doc § Measurement temporarily paused by the operator; state is preserved for resume.;
                entry action suspendSampling;
            }

            initial transition to idle;

            transition from idle to calibration
                when currentCommand == "calibrate";
            transition from calibration to measuring
                when currentCommand == "start";
            transition from measuring to paused
                when currentCommand == "pause";
            transition from paused to measuring
                when currentCommand == "resume";
            transition from measuring to idle
                when currentCommand == "stop";
            transition from paused to idle
                when currentCommand == "stop";
            transition from calibration to idle
                when currentCommand == "stop";
        }
    }

    // ================================================================
    // TOP-LEVEL ASSEMBLY
    // ================================================================

    part auxanometer :> AuxanometerSystemRequirement {
        doc § The complete Auxanometer: a precision automated plant growth measurement and recording system combining mechanical amplification, electronic sensing, dual digital and visual readout, and flexible operator control.;

        part attachment : AttachmentPoint;
        part lever : LeverArm;
        part pulley : Pulley;
        part encoder : RotaryEncoder;
        part acquisitionUnit : DataAcquisitionUnit;
        part storage : RecordingDevice;
        part pointer : Pointer;
        part scale : GraduatedScale;
        part operatorConsole : OperatorInterface;
        part controller : Controller;

        // --- Mechanical amplification chain ---
        connect attachment.apexPort to lever.inputPort {
            doc § Plant apex growth motion transferred from the attachment point to the lever input.;
        }
        connect lever.outputPort to pulley.linearInputPort {
            doc § Amplified linear motion from the lever drives the pulley.;
        }

        // --- Rotary distribution to encoder and pointer ---
        connect pulley.rotaryOutputPort to encoder.mechanicalInputPort {
            doc § Pulley rotation measured by the high-resolution rotary encoder for digital recording.;
        }
        connect pulley.pointerDrivePort to pointer.motionPort {
            doc § Pulley rotation drives the physical pointer along the graduated scale for visual inspection.;
        }

        // --- Digital data flow chain ---
        connect encoder.dataOutputPort to acquisitionUnit.encoderInputPort {
            doc § High-resolution encoder readings sent to the data acquisition unit for displacement and growth-rate calculation.;
        }
        connect encoder.dataOutputPort to controller.encoderMonitorPort {
            doc § Encoder readings also monitored by the controller for coordinated state management.;
        }
        connect acquisitionUnit.recordOutputPort to storage.recordInputPort {
            doc § Time-stamped growth records passed to the recording device for long-term storage.;
        }

        // --- Display data flow ---
        connect acquisitionUnit.displayOutputPort to pointer.displayInputPort {
            doc § Computed displacement data sent to the pointer for correlated visual display.;
        }

        // --- Control and calibration flow ---
        connect operatorConsole.commandOutputPort to controller.commandInputPort {
            doc § Operator commands (start, stop, pause, resume, calibrate) sent to the controller.;
        }
        connect controller.calibrationOutputPort to acquisitionUnit.calibrationInputPort {
            doc § Calibration baseline data sent from the controller to the data acquisition unit.;
        }
    }
}
