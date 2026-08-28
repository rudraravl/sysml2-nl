package IncrementalEncoderPositionControl {
    private import ScalarValues::*;
    private import SI::*;
    private import ISQ::*;
    private import Quantities::ScalarQuantityValue;
    private import Time::*;

    package Definitions {
        attribute def AngleValue :> ScalarQuantityValue;
        attribute def AngularVelocityValue :> ScalarQuantityValue;
        attribute def LengthValue :> ScalarQuantityValue;
        attribute def TimeValue :> ScalarQuantityValue;

        enum def RotationDirection {
            clockwise;
            counterClockwise;
            unknown;
        }

        item def Light;
        item def MechanicalTorque;

        item def PulseSignal {
            attribute level : Boolean;
            attribute phase : Real;
        }

        item def QuadraturePulse :> PulseSignal;
        item def IndexPulse :> PulseSignal;

        port def MechanicalShaftPort {
            inout torque : MechanicalTorque;
            attribute angularPosition : AngleValue;
            attribute angularVelocity : AngularVelocityValue;
        }

        port def EncoderOutputPort {
            out channelA : QuadraturePulse;
            out channelB : QuadraturePulse;
            out channelZ : IndexPulse;
        }

        port def EncoderInputPort {
            in channelA : QuadraturePulse;
            in channelB : QuadraturePulse;
            in channelZ : IndexPulse;
        }

        port def DecoderOutputPort {
            out position : AngleValue;
            out velocity : AngularVelocityValue;
            out direction : RotationDirection;
        }

        part def MotorShaft {
            attribute diameter : LengthValue;
            attribute maxRPM : Real;
            attribute angularPosition : AngleValue;
            attribute angularVelocity : AngularVelocityValue;
            attribute direction : RotationDirection;
            port shaftPort : MechanicalShaftPort;
        }

        part def OpticalDisk {
            attribute slotCount : Natural;
            attribute outerDiameter : LengthValue;
            attribute innerDiameter : LengthValue;
            attribute currentAngle : AngleValue;
        }

        part def LightSource {
            item emittedLight : Light;
            attribute wavelength : LengthValue;
            attribute isActive : Boolean = true;
        }

        part def Photodetector {
            in item receivedLight : Light;
            out item detectedPulse : PulseSignal;
            attribute threshold : Real;
            attribute sensitivity : Real;
        }

        part def PhotodetectorArray {
            part detectorA : Photodetector;
            part detectorB : Photodetector;
            part detectorZ : Photodetector;
        }

        part def IncrementalEncoder {
            port mechanicalInput : ~MechanicalShaftPort;
            port encoderOutput : EncoderOutputPort;
            part opticalDisk : OpticalDisk;
            part lightSource : LightSource;
            part photodetectors : PhotodetectorArray;
            attribute resolution : Natural = opticalDisk.slotCount;
            attribute quadraturePhaseOffset : Real = 90.0;
            assert constraint quadratureConstraint {
                encoderOutput.channelA.phase - encoderOutput.channelB.phase == 90.0
            }
            perform action generatePulses : GeneratePulses {
                in diskAngle = opticalDisk.currentAngle;
                in slotCount = opticalDisk.slotCount;
                out channelA = encoderOutput.channelA;
                out channelB = encoderOutput.channelB;
                out channelZ = encoderOutput.channelZ;
            }
        }

        part def DecoderController {
            port encoderInput : ~EncoderOutputPort;
            port controlOutput : DecoderOutputPort;
            attribute pulseCount : Integer = 0;
            attribute positionCount : Integer = 0;
            attribute lastChannelA : Boolean = false;
            attribute lastChannelB : Boolean = false;
            attribute indexReceived : Boolean = false;
            attribute countsPerRevolution : Natural;
            attribute direction : RotationDirection = unknown;
            attribute measuredPosition : AngleValue;
            attribute measuredVelocity : AngularVelocityValue;
            attribute lastTimestamp : TimeValue = 0 [s];
            exhibit state controllerBehavior : DecoderStateMachine;
        }

        action def GeneratePulses {
            in diskAngle : AngleValue;
            in slotCount : Natural;
            out channelA : QuadraturePulse;
            out channelB : QuadraturePulse;
            out channelZ : IndexPulse;
            assert constraint phaseRelation {
                channelA.phase - channelB.phase == 90.0
            }
        }

        action def DecodeQuadrature {
            in channelA : QuadraturePulse;
            in channelB : QuadraturePulse;
            in channelZ : IndexPulse;
            in countsPerRevolution : Natural;
            out position : AngleValue;
            out velocity : AngularVelocityValue;
            out direction : RotationDirection;
        }

        state def DecoderStateMachine {
            entry action { /* initialize counters and state */ }
            state WaitingForPulses;
            state CountingPulses {
                do action countPulses {
                    in a : QuadraturePulse;
                    in b : QuadraturePulse;
                    out count : Integer;
                }
            }
            state DirectionDetermined;
            state IndexReset;
            transition WaitingForPulses -> CountingPulses accept QuadraturePulse;
            transition CountingPulses -> DirectionDetermined accept QuadraturePulse;
            transition DirectionDetermined -> CountingPulses accept QuadraturePulse;
            transition CountingPulses -> IndexReset accept IndexPulse;
            transition IndexReset -> CountingPulses accept QuadraturePulse;
        }

        interface def MechanicalConnection {
            end shaftSide : ~MechanicalShaftPort;
            end encoderSide : MechanicalShaftPort;
            bind shaftSide.angularPosition = encoderSide.angularPosition;
            bind shaftSide.angularVelocity = encoderSide.angularVelocity;
        }

        interface def EncoderSignalConnection {
            end encoderEnd : EncoderOutputPort;
            end decoderEnd : ~EncoderOutputPort;
            flow of channelA : QuadraturePulse
                from encoderEnd.channelA to decoderEnd.channelA;
            flow of channelB : QuadraturePulse
                from encoderEnd.channelB to decoderEnd.channelB;
            flow of channelZ : IndexPulse
                from encoderEnd.channelZ to decoderEnd.channelZ;
        }
    }

    package Usages {
        part encoderSystem {
            part motorShaft : Definitions::MotorShaft {
                attribute diameter = 12.0 ['mm'];
                attribute maxRPM = 6000.0;
                attribute angularPosition = 0.0 ['deg'];
                attribute angularVelocity = 0.0 ['rad/s'];
                attribute direction = Definitions::RotationDirection::clockwise;
            }

            part encoder : Definitions::IncrementalEncoder {
                part opticalDisk {
                    attribute slotCount = 1000;
                    attribute outerDiameter = 50.0 ['mm'];
                    attribute innerDiameter = 10.0 ['mm'];
                    attribute currentAngle = 0.0 ['deg'];
                }
                part lightSource {
                    attribute wavelength = 850 ['nm'];
                    attribute isActive = true;
                }
                part photodetectors {
                    part detectorA {
                        attribute threshold = 0.5;
                        attribute sensitivity = 0.9;
                    }
                    part detectorB {
                        attribute threshold = 0.5;
                        attribute sensitivity = 0.9;
                    }
                    part detectorZ {
                        attribute threshold = 0.5;
                        attribute sensitivity = 0.9;
                    }
                }
                attribute resolution = opticalDisk.slotCount;
            }

            part decoder : Definitions::DecoderController {
                attribute countsPerRevolution = encoder.resolution;
                perform action decode : Definitions::DecodeQuadrature {
                    in channelA = encoderInput.channelA;
                    in channelB = encoderInput.channelB;
                    in channelZ = encoderInput.channelZ;
                    in countsPerRevolution = countsPerRevolution;
                    out position = controlOutput.position;
                    out velocity = controlOutput.velocity;
                    out direction = controlOutput.direction;
                }
            }

            connection mechanicalInterface : Definitions::MechanicalConnection
                connect motorShaft.shaftPort to encoder.mechanicalInput;

            connection signalInterface : Definitions::EncoderSignalConnection
                connect encoder.encoderOutput to decoder.encoderInput;
        }
    }

    package Requirements {
        requirement def PositionAccuracyRequirement {
            doc /* The decoder shall provide angular position within specified accuracy. */
            attribute maxError : AngleValue;
            subject decoderController : Definitions::DecoderController;
            require constraint {
                decoderController.measuredPosition >= 0.0 ['deg'] and
                decoderController.measuredPosition <= 360.0 ['deg']
            }
        }

        requirement def DirectionDetectionRequirement {
            doc /* The system shall correctly detect rotation direction from quadrature signals. */
            subject encoderSystem : Usages::encoderSystem;
            require constraint {
                encoderSystem.decoder.direction == Definitions::RotationDirection::clockwise or
                encoderSystem.decoder.direction == Definitions::RotationDirection::counterClockwise
            }
        }

        requirement def IndexResetRequirement {
            doc /* The Z-channel index pulse shall reset the position counter once per revolution. */
            subject decoderController : Definitions::DecoderController;
            require constraint {
                decoderController.indexReceived implies decoderController.positionCount == 0
            }
        }

        requirement def VelocityMeasurementRequirement {
            doc /* The decoder shall measure shaft velocity from pulse rate within specified range. */
            attribute minMeasurableRPM : Real;
            attribute maxMeasurableRPM : Real;
            subject decoderController : Definitions::DecoderController;
            require constraint {
                decoderController.measuredVelocity >= 0.0 ['rad/s'] and
                decoderController.measuredVelocity <= 628.0 ['rad/s']
            }
        }

        requirement def QuadraturePhaseRequirement {
            doc /* Channels A and B shall maintain a 90-degree phase offset. */
            subject encoder : Definitions::IncrementalEncoder;
            require constraint {
                encoder.quadraturePhaseOffset == 90.0
            }
        }

        requirement positionAccuracy : PositionAccuracyRequirement {
            attribute maxError = 0.36 ['deg'];
        }

        requirement directionDetection : DirectionDetectionRequirement;

        requirement indexReset : IndexResetRequirement;

        requirement velocityMeasurement : VelocityMeasurementRequirement {
            attribute minMeasurableRPM = 0.0;
            attribute maxMeasurableRPM = 6000.0;
        }

        requirement quadraturePhase : QuadraturePhaseRequirement;
    }
}
