package RotaryEncoderSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    enum def RotationDirection {
        clockwise;
        counterClockwise;
    }

    attribute def EncoderFeedback {
        attribute absoluteAngle : ISQ::AngleValue;
        attribute relativePulseCount : ScalarValues::Integer;
        attribute angularVelocity : ISQ::AngularVelocityValue;
        attribute direction : RotationDirection;
    }

    port def MechanicalRotationPort {
        out attribute angle : ISQ::AngleValue;
        out attribute angularVelocity : ISQ::AngularVelocityValue;
    }

    port def EncoderDataPort {
        out attribute feedback : EncoderFeedback;
    }

    port def OpticalSignalPort {
        out attribute intensity : ScalarValues::Real;
    }

    port def ElectricalPulsePort {
        out attribute level : ScalarValues::Boolean;
        out attribute timestamp : ISQ::DurationValue;
    }

    part def Shaft {
        attribute angularPosition : ISQ::AngleValue := 0 [SI::degree];
        port rotation : MechanicalRotationPort;
    }

    part def OpticalDisk {
        doc /* Optical disk with 2048-slot quadrature track and single-slot index track. */
        attribute slotCount : ScalarValues::Integer = 2048;
        attribute indexSlotCount : ScalarValues::Integer = 1;
        port shaftRotation : ~MechanicalRotationPort;
        port channelATrack : OpticalSignalPort;
        port channelBTrack : OpticalSignalPort;
        port indexTrack : OpticalSignalPort;
    }

    part def Photosensor {
        doc /* Converts optical slot intensity into an electrical pulse signal. */
        port opticalInput : ~OpticalSignalPort;
        port pulseOutput : ElectricalPulsePort;
    }

    calc def ComputePulseDelta {
        in a : ScalarValues::Boolean;
        in b : ScalarValues::Boolean;
        in prevA : ScalarValues::Boolean;
        in prevB : ScalarValues::Boolean;
        return : ScalarValues::Integer =
            if a and not prevA then (if b then -1 else 1)
            else if b and not prevB then (if a then 1 else -1)
            else 0;
    }

    calc def ComputeDirection {
        in a : ScalarValues::Boolean;
        in b : ScalarValues::Boolean;
        in prevA : ScalarValues::Boolean;
        in prevB : ScalarValues::Boolean;
        return : RotationDirection =
            if a and not prevA then (if b then RotationDirection::counterClockwise else RotationDirection::clockwise)
            else if b and not prevB then (if a then RotationDirection::clockwise else RotationDirection::counterClockwise)
            else RotationDirection::clockwise;
    }

    calc def PulseCountToAngle {
        in pulseCount : ScalarValues::Integer;
        in slotsPerRevolution : ScalarValues::Integer;
        return : ScalarValues::Real = (pulseCount mod slotsPerRevolution) * (360.0 / slotsPerRevolution);
    }

    part def SignalProcessor {
        port channelA : ~ElectricalPulsePort;
        port channelB : ~ElectricalPulsePort;
        port indexPulse : ~ElectricalPulsePort;
        port dataOut : EncoderDataPort;

        attribute pulseCount : ScalarValues::Integer := 0;
        attribute prevA : ScalarValues::Boolean := false;
        attribute prevB : ScalarValues::Boolean := false;
        attribute lastEdgeTime : ISQ::DurationValue := 0 [SI::s];
        attribute slotsPerRev : ScalarValues::Integer := 2048;
        attribute currentFeedback : EncoderFeedback;

        action processTick {
            attribute delta : ScalarValues::Integer;
            attribute dir : RotationDirection;
            attribute angleDeg : ScalarValues::Real;
            attribute timeDelta : ISQ::DurationValue;
            attribute vel : ISQ::AngularVelocityValue;

            assign delta := ComputePulseDelta(channelA.level, channelB.level, prevA, prevB);
            assign dir := ComputeDirection(channelA.level, channelB.level, prevA, prevB);

            if indexPulse.level then
                assign pulseCount := 0;
            else
                assign pulseCount := pulseCount + delta;
            end if;

            assign prevA := channelA.level;
            assign prevB := channelB.level;

            assign angleDeg := PulseCountToAngle(pulseCount, slotsPerRev);
            assign currentFeedback.absoluteAngle := angleDeg [SI::degree];
            assign currentFeedback.relativePulseCount := pulseCount;
            assign currentFeedback.direction := dir;

            assign timeDelta := channelA.timestamp - lastEdgeTime;
            if channelA.timestamp > lastEdgeTime then
                assign vel := (delta * (360.0 / slotsPerRev) [SI::degree]) / timeDelta;
            else
                assign vel := 0 [SI::degree/SI::s];
            end if;
            assign currentFeedback.angularVelocity := vel;
            assign lastEdgeTime := channelA.timestamp;
        }

        state def ProcessingStates {
            entry assign pulseCount := 0;
            then state idle;
            state idle {
                do perform processTick;
            }
            accept after 0.001 [SI::s] then idle;
        }

        state processing : ProcessingStates;

        bind dataOut.feedback = currentFeedback;
    }

    part def RotaryEncoder {
        port mechanicalRotation : ~MechanicalRotationPort;
        port channelA : ElectricalPulsePort;
        port channelB : ElectricalPulsePort;
        port indexPulse : ElectricalPulsePort;

        part shaft : Shaft;
        part disk : OpticalDisk;
        part sensorA : Photosensor;
        part sensorB : Photosensor;
        part sensorIndex : Photosensor;

        connect mechanicalRotation to shaft.rotation;
        connect shaft.rotation to disk.shaftRotation;
        connect disk.channelATrack to sensorA.opticalInput;
        connect disk.channelBTrack to sensorB.opticalInput;
        connect disk.indexTrack to sensorIndex.opticalInput;
        connect sensorA.pulseOutput to channelA;
        connect sensorB.pulseOutput to channelB;
        connect sensorIndex.pulseOutput to indexPulse;
    }

    part def EncoderSystem {
        port shaftRotation : ~MechanicalRotationPort;
        port feedback : EncoderDataPort;

        part encoder : RotaryEncoder;
        part processor : SignalProcessor;

        connect shaftRotation to encoder.mechanicalRotation;
        connect encoder.channelA to processor.channelA;
        connect encoder.channelB to processor.channelB;
        connect encoder.indexPulse to processor.indexPulse;
        connect processor.dataOut to feedback;
    }

    requirement def HighResolutionEncoderRequirement {
        doc /* The system shall measure absolute angular position, relative pulse count, angular velocity, and direction with a resolution of 2048 pulses per revolution. */
        attribute resolutionPulsesPerRevolution : ScalarValues::Integer = 2048;
        attribute requiredOutputs : ScalarValues::Integer = 4;
    }

    requirement def MotionControlFeedbackRequirement {
        doc /* The system shall provide a clean digital data stream suitable for motion control applications. */
        attribute minimumUpdateRate : ISQ::FrequencyValue = 1000 [SI::Hz];
    }
}
