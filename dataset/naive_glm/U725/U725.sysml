package PositionControlSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQTime::*;

    // ---- Value Types with Units ----
    value type AngleDeg :> Real {
        unit deg;
    }

    value type AngularVelocityRPM :> Real {
        unit rpm;
    }

    value type AngularVelocityRadPerSec :> Real {
        unit 'rad/s';
    }

    value type PulseCount :> Integer;

    value type PulseRate :> Real {
        unit Hz;
    }

    value type TimeStamp :> Real {
        unit s;
    }

    value type Wavelength :> Real {
        unit nm;
    }

    enumeration def RotationDirection {
        clockwise;
        counterClockwise;
    }

    enumeration def LogicLevel {
        high;
        low;
    }

    // ---- Item Definitions ----
    item def PulseSignal {
        attribute level : LogicLevel = LogicLevel::low;
        attribute timestamp : TimeStamp;
        attribute pulseWidth : TimeStamp;
    }

    item def QuadraturePulse :> PulseSignal {
        attribute channel : String;
        attribute phaseOffset : AngleDeg;
    }

    item def IndexPulse :> PulseSignal {
        attribute revolutionIndex : PulseCount;
    }

    // ---- Port Definitions ----
    port def MechanicalShaftPort {
        attribute angularPosition : AngleDeg;
        attribute angularVelocity : AngularVelocityRPM;
        attribute direction : RotationDirection;
    }

    port def EncoderOutputPort {
        out channelA : PulseSignal;
        out channelB : PulseSignal;
        out channelZ : PulseSignal;
    }

    port def DecoderDataPort {
        out position : AngleDeg;
        out velocity : AngularVelocityRPM;
        out direction : RotationDirection;
        out indexReceived : Boolean;
        out pulseCount : PulseCount;
    }

    // ---- Requirements ----
    requirement def PositionAccuracyRequirement {
        doc "The system shall measure angular position with high precision.";
        attribute maxError : AngleDeg = 0.05 [deg];
        subject positionError : AngleDeg;
        constraint { positionError <= maxError }
    }

    requirement def VelocityMeasurementRequirement {
        doc "The system shall measure shaft velocity over the operating range.";
        attribute minVelocity : AngularVelocityRPM = 0 [rpm];
        attribute maxVelocity : AngularVelocityRPM = 6000 [rpm];
        subject measuredVelocity : AngularVelocityRPM;
        constraint { measuredVelocity >= minVelocity and measuredVelocity <= maxVelocity }
    }

    requirement def DirectionDetectionRequirement {
        doc "The system shall determine rotation direction from quadrature phase relationship.";
        subject detectedDirection : RotationDirection;
    }

    requirement def IndexResetRequirement {
        doc "The system shall reset the position count upon receipt of a Z-channel index pulse.";
        subject indexPulse : PulseSignal;
    }

    requirement def QuadraturePhaseRequirement {
        doc "Channels A and B shall be 90 degrees out of phase."
        attribute requiredPhase : AngleDeg = 90 [deg];
        subject phaseDifference : AngleDeg;
        constraint { phaseDifference == requiredPhase }
    }

    // ---- Motor Shaft ----
    part def MotorShaft {
        port mechanicalOutput : MechanicalShaftPort;

        attribute currentAngle : AngleDeg = 0 [deg];
        attribute currentVelocity : AngularVelocityRPM = 0 [rpm];
        attribute currentDirection : RotationDirection = RotationDirection::clockwise;

        action def Rotate(in duration : TimeStamp) {
            out newAngle : AngleDeg;
            // Compute new angle from velocity, direction, and duration
        }

        state def ShaftDynamics {
            entry; then Stopped;
            state Stopped;
            state RotatingCW;
            state RotatingCCW;

            transition Stopped
                when currentVelocity > 0 [rpm] and currentDirection == RotationDirection::clockwise
                to RotatingCW;

            transition Stopped
                when currentVelocity > 0 [rpm] and currentDirection == RotationDirection::counterClockwise
                to RotatingCCW;

            transition RotatingCW
                when currentVelocity == 0 [rpm]
                to Stopped;

            transition RotatingCCW
                when currentVelocity == 0 [rpm]
                to Stopped;
        }
    }

    // ---- Optical Disk ----
    part def OpticalDisk {
        attribute slotCount : Integer = 1000;
        attribute slotPitch : AngleDeg = 360.0 / slotCount [deg];
        attribute indexSlotPosition : AngleDeg = 0 [deg];
        port mechanicalInput : MechanicalShaftPort;
    }

    part def LightSource {
        attribute wavelength : Wavelength = 850 [nm];
        attribute active : Boolean = true;
        attribute intensity : Real = 1.0;
    }

    part def Photodetector {
        attribute channel : String;
        attribute sensitivity : Real = 0.9;
        out detected : PulseSignal;
    }

    part def PhotodetectorArray {
        part detectorA : Photodetector { attribute channel = "A"; }
        part detectorB : Photodetector { attribute channel = "B"; }
        part detectorZ : Photodetector { attribute channel = "Z"; }
    }

    // ---- Incremental Encoder ----
    part def IncrementalEncoder {
        port mechanicalInput : MechanicalShaftPort;
        port encoderOutput : EncoderOutputPort;

        attribute resolution : Integer = 1000; // pulses per revolution
        attribute quadraturePhase : AngleDeg = 90 [deg];
        attribute indexPulsesPerRev : Integer = 1;

        part disk : OpticalDisk {
            attribute slotCount = resolution;
        }
        part light : LightSource;
        part detectors : PhotodetectorArray;

        satisfy QuadraturePhaseRequirement {
            subject phaseDifference = quadraturePhase;
        }

        action def GeneratePulses {
            in shaftAngle : AngleDeg;
            in shaftVelocity : AngularVelocityRPM;
            in shaftDirection : RotationDirection;
            out pulseA : QuadraturePulse;
            out pulseB : QuadraturePulse;
            out pulseZ : IndexPulse;

            // Determine slot crossing for channel A
            // Channel B is offset by 90 degrees (quarter period)
            // Channel Z fires once per revolution at index slot
        }

        state def EncoderOperation {
            entry; then Idle;
            state Idle;
            state EmittingA;
            state EmittingB;
            state EmittingZ;

            transition Idle
                when mechanicalInput.angularVelocity != 0 [rpm]
                to EmittingA;

            transition EmittingA
                to EmittingB {
                // Phase-shifted emission of channel B
            }

            transition EmittingB
                to EmittingA {
                // Continue quadrature cycle
            }

            transition EmittingA
                when mechanicalInput.angularPosition == 0 [deg]
                to EmittingZ;

            transition EmittingZ
                to EmittingA;

            transition EmittingA
                when mechanicalInput.angularVelocity == 0 [rpm]
                to Idle;
        }
    }

    // ---- Decoder Controller ----
    part def DecoderController {
        port encoderInput : EncoderOutputPort;
        port dataOutput : DecoderDataPort;

        attribute positionCount : PulseCount = 0;
        attribute lastChannelALevel : LogicLevel = LogicLevel::low;
        attribute lastChannelBLevel : LogicLevel = LogicLevel::low;
        attribute measuredPosition : AngleDeg = 0 [deg];
        attribute measuredVelocity : AngularVelocityRPM = 0 [rpm];
        attribute measuredDirection : RotationDirection = RotationDirection::clockwise;
        attribute pulsesPerRevolution : Integer = 1000;
        attribute lastPulseTime : TimeStamp = 0 [s];
        attribute indexReceivedFlag : Boolean = false;

        satisfy PositionAccuracyRequirement {
            subject positionError = measuredPosition;
        }
        satisfy VelocityMeasurementRequirement {
            subject measuredVelocity = measuredVelocity;
        }
        satisfy DirectionDetectionRequirement {
            subject detectedDirection = measuredDirection;
        }
        satisfy IndexResetRequirement {
            subject indexPulse = encoderInput.channelZ;
        }

        action def ProcessQuadrature {
            in pulseA : PulseSignal;
            in pulseB : PulseSignal;
            in currentTime : TimeStamp;
            out newCount : PulseCount;
            out direction : RotationDirection;
            out velocity : AngularVelocityRPM;

            // If A leads B -> clockwise; if B leads A -> counter-clockwise
            // Count increments/decrements based on direction
            // Velocity computed from pulse interval
        }

        action def CalculateVelocity {
            in pulseInterval : TimeStamp;
            out velocity : AngularVelocityRPM;
            // velocity = (1 / pulseInterval) * 60 / pulsesPerRevolution
        }

        action def ResetOnIndex {
            in indexPulse : PulseSignal;
            inout positionCount : PulseCount;
            // Reset positionCount to zero on rising edge of Z
        }

        action def UpdatePosition {
            in count : PulseCount;
            out angle : AngleDeg;
            // angle = (count / pulsesPerRevolution) * 360
        }

        state def DecoderBehavior {
            entry; then Monitoring;

            state Monitoring;
            state Counting;
            state DirectionEval;
            state VelocityCalc;
            state IndexReset;

            transition Monitoring
                when encoderInput.channelA.level != lastChannelALevel
                to Counting;

            transition Counting
                to DirectionEval {
                // Increment or decrement positionCount
            }

            transition DirectionEval
                to VelocityCalc {
                // Compare phase of A and B to set measuredDirection
            }

            transition VelocityCalc
                to Monitoring {
                // Compute measuredVelocity from pulse interval
            }

            transition Monitoring
                when encoderInput.channelZ.level == LogicLevel::high
                to IndexReset;

            transition IndexReset
                to Monitoring {
                // Reset positionCount and measuredPosition
            }
        }
    }

    // ---- Top-Level System ----
    part positionControlSystem {
        doc "High-precision position control system using an optical incremental encoder and decoder controller.";

        part motorShaft : MotorShaft {
            attribute currentVelocity = 1200 [rpm];
        }
        part encoder : IncrementalEncoder {
            attribute resolution = 1000;
        }
        part decoder : DecoderController {
            attribute pulsesPerRevolution = 1000;
        }

        connection mechanicalLink connect motorShaft.mechanicalOutput to encoder.mechanicalInput;
        connection signalLink connect encoder.encoderOutput to decoder.encoderInput;

        port systemOutput : DecoderDataPort;
        connection dataLink connect decoder.dataOutput to systemOutput;
    }
}
