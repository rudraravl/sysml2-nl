package RotaryEncoderSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ============ Value Types ============
    value type AngularPositionValue :> AngleValue;
    value type AngularVelocityMeasure :> AngularVelocityValue;
    value type PulseCountValue :> Integer;

    enum def RotationDirection {
        clockwise;
        counterClockwise;
        stationary;
    }

    // ============ Items ============
    item def EncoderData {
        attribute absoluteAngle : AngularPositionValue;
        attribute relativePulseCount : PulseCountValue;
        attribute angularVelocity : AngularVelocityMeasure;
        attribute direction : RotationDirection;
    }

    item def ChannelSignal {
        attribute level : Boolean;
        attribute timestamp : TimeValue;
    }

    // ============ Ports ============
    port def MechanicalShaftPort {
        attribute angularDisplacement : AngularPositionValue;
        attribute angularVelocity : AngularVelocityMeasure;
    }

    port def SignalPort {
        attribute signal : ChannelSignal;
    }

    port def DigitalOutputPort {
        attribute data : EncoderData;
    }

    // ============ Requirements ============
    requirement def OpticalResolutionRequirement {
        doc "The optical disk shall feature 2048 slots on the main track and a single index slot per revolution.";
        attribute mainTrackSlotsPerRevolution : Integer = 2048;
        attribute indexTrackSlotsPerRevolution : Integer = 1;
    }

    requirement def QuadratureDirectionRequirement {
        doc "Direction shall be inferred from the phase relationship between Channel A and Channel B.";
        subject encoderSystem : RotaryEncoder;
        assume {
            channel A and channel B are 90 degrees out of phase;
        }
        require {
            when channel A leads channel B, direction shall be clockwise;
            when channel B leads channel A, direction shall be counterClockwise;
        }
    }

    requirement def OutputReportingRequirement {
        doc "The output stream shall include absolute angular position in degrees, relative pulse count, angular velocity, and direction.";
        subject outputData : EncoderData;
        require {
            outputData.absoluteAngle >= 0 ['deg'];
            outputData.absoluteAngle < 360 ['deg'];
            outputData.direction == clockwise or
            outputData.direction == counterClockwise or
            outputData.direction == stationary;
        }
    }

    // ============ Part Definitions ============
    part def OpticalDisk {
        attribute slotsPerRevolution : Integer = 2048;
        attribute indexSlotsPerRevolution : Integer = 1;
        port in shaftInput : MechanicalShaftPort;
        port out mainTrackOutput : MechanicalShaftPort;
        port out indexTrackOutput : MechanicalShaftPort;
    }

    part def Photosensor {
        attribute channelId : String;
        attribute phaseOffsetDeg : Real;
        port in diskRotation : MechanicalShaftPort;
        port out signalOutput : SignalPort;

        action generateSquareWave {
            // Detects slot transitions on the main track and produces a square wave signal
        }
    }

    part def IndexSensor {
        port in diskRotation : MechanicalShaftPort;
        port out signalOutput : SignalPort;

        action generateIndexPulse {
            // Detects the index slot and produces a single pulse per revolution
        }
    }

    part def SignalProcessor {
        attribute pulsesPerRevolution : Integer = 2048;
        attribute pulseCount : PulseCountValue = 0;
        attribute directionState : RotationDirection = stationary;
        attribute previousChannelA : Boolean = false;
        attribute previousChannelB : Boolean = false;
        attribute lastEdgeTime : TimeValue = 0 ['s'];
        attribute angularVelocityMeasured : AngularVelocityMeasure = 0 ['rad/s'];
        attribute absoluteAngleMeasured : AngularPositionValue = 0 ['deg'];
        attribute resetRequested : Boolean = false;

        port in channelAInput : SignalPort;
        port in channelBInput : SignalPort;
        port in indexInput : SignalPort;
        port out digitalOutput : DigitalOutputPort;

        action decodeDirection {
            // Determines rotation direction by examining the phase relationship between Channel A and Channel B
        }

        action updatePulseCount {
            // Increments or decrements pulse count based on detected direction
        }

        action computeAbsoluteAngle {
            // Converts pulse count to absolute angle using the 2048 pulses per revolution resolution
        }

        action computeAngularVelocity {
            // Computes angular velocity from the time rate of pulse arrivals
        }

        action resetOnIndex {
            // Resets the absolute reference on detection of the index pulse
        }

        state machine ProcessorStateMachine {
            state Idle;
            state Counting;
            state Indexed;
            state Fault;

            transition initial then Idle;
            transition Idle then Counting
                when (channelAInput.signal.level != previousChannelA or
                      channelBInput.signal.level != previousChannelB);
            transition Counting then Indexed
                when (indexInput.signal.level == true);
            transition Indexed then Counting
                when (indexInput.signal.level == false);
            transition Counting then Fault
                when (channelAInput.signal.level == previousChannelA and
                      channelBInput.signal.level == previousChannelB);
            transition Fault then Idle
                when (resetRequested == true);
        }
    }

    part def RotaryEncoder {
        port in mechanicalInput : MechanicalShaftPort;
        port out dataOutput : DigitalOutputPort;

        part opticalDisk : OpticalDisk;
        part sensorA : Photosensor {
            channelId = "A";
            phaseOffsetDeg = 0.0;
        }
        part sensorB : Photosensor {
            channelId = "B";
            phaseOffsetDeg = 90.0;
        }
        part indexSensor : IndexSensor;
        part processor : SignalProcessor;

        requirement resolutionRequirement : OpticalResolutionRequirement;
        requirement directionRequirement : QuadratureDirectionRequirement;
        requirement outputRequirement : OutputReportingRequirement;

        connect mechanicalInput to opticalDisk.shaftInput;
        connect opticalDisk.mainTrackOutput to sensorA.diskRotation;
        connect opticalDisk.mainTrackOutput to sensorB.diskRotation;
        connect opticalDisk.indexTrackOutput to indexSensor.diskRotation;
        connect sensorA.signalOutput to processor.channelAInput;
        connect sensorB.signalOutput to processor.channelBInput;
        connect indexSensor.signalOutput to processor.indexInput;
        connect processor.digitalOutput to dataOutput;
    }
}
