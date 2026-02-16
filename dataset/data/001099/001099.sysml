package IncrementalEncoderSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def PulsesPerRevolution :> Integer;
    attribute def PulseCount :> Integer;

    enum def ChannelState {
        low;
        high;
    }

    enum def RotationDirection {
        clockwise;
        counterClockwise;
        stationary;
    }

    item def QuadratureSignal {
        attribute channelA : ChannelState;
        attribute channelB : ChannelState;
        attribute indexZ : ChannelState;
    }

    port def MechanicalShaftPort {
        in shaftAngle : AngleValue;
        in shaftSpeed : AngularVelocityValue;
    }

    port def QuadratureOutputPort {
        out channelA : ChannelState;
        out channelB : ChannelState;
        out indexZ : ChannelState;
    }

    port def PositionDataPort {
        out position : AngleValue;
        out velocity : AngularVelocityValue;
        out direction : RotationDirection;
    }

    part def OpticalDisk {
        attribute slotCount : Integer;
        attribute diskRadius : LengthValue;
    }

    part def PhotodetectorArray {
        attribute channelADetector;
        attribute channelBDetector;
        attribute indexDetector;
        attribute sensitivity : Real;
    }

    part def SignalProcessor {
        attribute hysteresisThreshold : Real;
        attribute outputVoltageHigh : Real;
        attribute outputVoltageLow : Real;
    }

    part def IncrementalEncoder {
        doc /* An incremental encoder converts rotational motion into digital pulse signals.
             * It generates quadrature output signals (channels A and B) that are 90 degrees
             * out of phase, enabling both position measurement and direction detection.
             * An index pulse (channel Z) provides a reference point once per revolution.
             */

        attribute resolution : PulsesPerRevolution;
        attribute maxSpeed : AngularVelocityValue;

        port shaftInput : MechanicalShaftPort;
        port quadratureOutput : QuadratureOutputPort;

        part disk : OpticalDisk {
            attribute :>> slotCount = resolution;
            attribute :>> diskRadius = 25.0 [mm];
        }

        part photodetectors : PhotodetectorArray {
            attribute :>> sensitivity = 0.85;
        }

        part processor : SignalProcessor {
            attribute :>> hysteresisThreshold = 0.15;
            attribute :>> outputVoltageHigh = 5.0;
            attribute :>> outputVoltageLow = 0.0;
        }

        state encoderStates {
            entry; then operational;

            state operational {
                do action generatePulses {
                    in angle : AngleValue = shaftInput.shaftAngle;
                    in speed : AngularVelocityValue = shaftInput.shaftSpeed;
                    out chA : ChannelState = quadratureOutput.channelA;
                    out chB : ChannelState = quadratureOutput.channelB;
                    out idx : ChannelState = quadratureOutput.indexZ;
                }
            }
        }
    }

    part def DecoderController {
        doc /* The decoder controller interprets quadrature signals from the encoder
             * to determine position, velocity, and direction of rotation.
             */

        attribute pulseCounter : PulseCount;
        attribute encoderResolution : PulsesPerRevolution;
        attribute currentPosition : AngleValue;
        attribute currentVelocity : AngularVelocityValue;
        attribute rotationDir : RotationDirection;

        port encoderInput : QuadratureOutputPort;
        port dataOutput : PositionDataPort;

        action def DecodeQuadrature {
            in chA : ChannelState;
            in chB : ChannelState;
            inout counter : PulseCount;
            out dir : RotationDirection;

            first start;
            then decide;
                if (chA == ChannelState::high and chB == ChannelState::low) then incrementCW;
                if (chA == ChannelState::low and chB == ChannelState::high) then incrementCCW;
                if (chA == ChannelState::low and chB == ChannelState::low) then noChange;

            action incrementCW {
                counter = counter + 1;
                dir = RotationDirection::clockwise;
            }
            then done;

            action incrementCCW {
                counter = counter - 1;
                dir = RotationDirection::counterClockwise;
            }
            then done;

            action noChange {
                dir = RotationDirection::stationary;
            }
            then done;
        }

        action def CalculatePosition {
            in count : PulseCount;
            in resolution : PulsesPerRevolution;
            out position : AngleValue;
        }

        action def CalculateVelocity {
            in deltaPosition : AngleValue;
            in deltaTime : DurationValue;
            out velocity : AngularVelocityValue;
        }

        action def ResetOnIndex {
            in indexSignal : ChannelState;
            inout counter : PulseCount;

            first start;
            then decide;
                if indexSignal == ChannelState::high then reset;
                if indexSignal == ChannelState::low then skip;

            action reset {
                counter = 0;
            }
            then done;

            action skip;
            then done;
        }

        action processSignals {
            first decode : DecodeQuadrature {
                in chA = encoderInput.channelA;
                in chB = encoderInput.channelB;
                inout counter = pulseCounter;
                out dir = rotationDir;
            }
            then resetCheck : ResetOnIndex {
                in indexSignal = encoderInput.indexZ;
                inout counter = pulseCounter;
            }
            then calcPos : CalculatePosition {
                in count = pulseCounter;
                in resolution = encoderResolution;
                out position = currentPosition;
            }
            then calcVel : CalculateVelocity {
                in deltaPosition = currentPosition;
                in deltaTime = 0.001 [s];
                out velocity = currentVelocity;
            }
            then done;
        }

        state decoderStates {
            entry; then idle;

            state idle;
            accept at when powerOn
            then tracking;

            state tracking {
                do action trackingAction : processSignals;
            }
            accept at when powerOff
            then idle;
        }
    }

    part def MotorShaft {
        attribute shaftPosition : AngleValue;
        attribute shaftRotationSpeed : AngularVelocityValue;
        attribute shaftTorque : TorqueValue;

        port mechanicalOutput : MechanicalShaftPort;
    }

    part def PositionControlSystem {
        doc /* The position control system uses incremental encoder feedback to monitor
             * and control the angular position and velocity of a motor shaft. This enables
             * precise motion control for applications such as robotics, CNC machining,
             * and automated assembly systems.
             */

        attribute systemResolution : PulsesPerRevolution = 2048;
        attribute maxOperatingSpeed : AngularVelocityValue = 6000.0 [rpm];
        attribute measuredPosition : AngleValue;
        attribute measuredVelocity : AngularVelocityValue;
        attribute detectedDirection : RotationDirection;

        part shaft : MotorShaft {
            attribute :>> shaftPosition = 0.0 [deg];
            attribute :>> shaftRotationSpeed = 0.0 [rpm];
        }

        part encoder : IncrementalEncoder {
            attribute :>> resolution = systemResolution;
            attribute :>> maxSpeed = maxOperatingSpeed;
        }

        part decoder : DecoderController {
            attribute :>> encoderResolution = systemResolution;
            attribute :>> pulseCounter = 0;
        }

        connection shaftToEncoder connect shaft.mechanicalOutput to encoder.shaftInput;
        connection encoderToDecoder connect encoder.quadratureOutput to decoder.encoderInput;

        assert constraint positionCalculation {
            measuredPosition == decoder.currentPosition
        }

        assert constraint velocityCalculation {
            measuredVelocity == decoder.currentVelocity
        }

        assert constraint directionDetection {
            detectedDirection == decoder.rotationDir
        }
    }

    requirement <'REQ-ENC-001'> primaryFunction {
        doc /* The incremental encoder system shall convert rotational shaft motion
             * into quadrature digital pulse signals that enable measurement of angular
             * position, velocity, and direction of rotation.
             */
        subject system : PositionControlSystem;
    }

    requirement <'REQ-ENC-002'> resolutionRequirement {
        doc /* The encoder shall provide a minimum resolution of 2048 pulses per
             * revolution to achieve position accuracy of 0.176 degrees or better.
             */
        subject system : PositionControlSystem;
        assert constraint {
            system.encoder.resolution >= 2048 and
            (360.0 [deg] / system.encoder.resolution) <= 0.176 [deg]
        }
    }

    requirement <'REQ-ENC-003'> quadraturePhasing {
        doc /* The encoder shall generate channel A and channel B signals with
             * 90-degree phase offset to enable bidirectional rotation detection.
             */
        subject encoder : IncrementalEncoder;
    }

    requirement <'REQ-ENC-004'> indexPulse {
        doc /* The encoder shall provide one index pulse (channel Z) per complete
             * revolution to establish an absolute reference position.
             */
        subject encoder : IncrementalEncoder;
    }

    requirement <'REQ-DEC-001'> positionTracking {
        doc /* The decoder controller shall continuously track cumulative position
             * by counting and decoding quadrature pulses from the encoder.
             */
        subject decoder : DecoderController;
    }

    requirement <'REQ-DEC-002'> directionDetection {
        doc /* The decoder controller shall determine rotation direction by analyzing
             * the phase relationship between channel A and channel B signals.
             */
        subject decoder : DecoderController;
    }

    requirement <'REQ-SYS-001'> closedLoopControl {
        doc /* The position control system shall provide real-time position and
             * velocity feedback to enable closed-loop motion control applications.
             */
        subject system : PositionControlSystem;
    }

    satisfy primaryFunction by PositionControlSystem;
    satisfy resolutionRequirement by PositionControlSystem;
    satisfy quadraturePhasing by PositionControlSystem::encoder;
    satisfy indexPulse by PositionControlSystem::encoder;
    satisfy positionTracking by PositionControlSystem::decoder;
    satisfy directionDetection by PositionControlSystem::decoder;
    satisfy closedLoopControl by PositionControlSystem;
}
