package WindowBlindSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percent : Real {
        :>> unit = "%";
    }

    attribute def Illuminance : Real {
        :>> unit = "lx";
    }

    attribute def AngleDegree : Real {
        :>> unit = "deg";
    }

    attribute def LengthMillimeter : Real {
        :>> unit = "mm";
    }

    attribute def TimeSecond : Real {
        :>> unit = "s";
    }

    attribute def ForceNewton : Real {
        :>> unit = "N";
    }

    enum def BlindMode {
        enum manual;
        enum automatic;
        enum locked;
        enum fault;
    }

    enum def MotionDirection {
        enum raise;
        enum lower;
        enum stop;
    }

    enum def TiltDirection {
        enum open;
        enum close;
        enum hold;
    }

    enum def BlindPositionState {
        enum fullyRaised;
        enum partiallyRaised;
        enum fullyLowered;
    }

    item def UserCommand {
        attribute requestedPosition : Percent;
        attribute requestedTilt : AngleDegree;
        attribute requestedMode : BlindMode;
    }

    item def LightCondition {
        attribute indoorIlluminance : Illuminance;
        attribute outdoorIlluminance : Illuminance;
    }

    item def MotionCommand {
        attribute direction : MotionDirection;
        attribute targetPosition : Percent;
        attribute speed : Percent;
    }

    item def TiltCommand {
        attribute direction : TiltDirection;
        attribute targetTilt : AngleDegree;
    }

    item def BlindStatus {
        attribute position : Percent;
        attribute tiltAngle : AngleDegree;
        attribute mode : BlindMode;
        attribute positionState : BlindPositionState;
        attribute obstructionDetected : Boolean;
        attribute faultPresent : Boolean;
    }

    port def UserCommandPort {
        in item command : UserCommand;
    }

    port def LightInputPort {
        in item light : LightCondition;
    }

    port def MotionControlPort {
        out item motion : MotionCommand;
    }

    port def TiltControlPort {
        out item tilt : TiltCommand;
    }

    port def StatusPort {
        out item status : BlindStatus;
    }

    port def StatusInputPort {
        in item status : BlindStatus;
    }

    part def WindowBlindSystem {
        attribute nominalWidth : LengthMillimeter = 1200;
        attribute nominalHeight : LengthMillimeter = 1500;
        attribute minimumPosition : Percent = 0;
        attribute maximumPosition : Percent = 100;
        attribute minimumTilt : AngleDegree = 0;
        attribute maximumTilt : AngleDegree = 90;
        attribute primaryFunction : String = "Regulate incoming daylight and privacy by positioning and tilting a window blind over a window opening.";

        port userInput : UserCommandPort;
        port ambientLightInput : LightInputPort;
        port systemStatus : StatusPort;

        part controller : BlindController;
        part driveUnit : BlindDriveUnit;
        part slatAssembly : SlatAssembly;
        part bottomRail : BottomRail;
        part headRail : HeadRail;
        part lightSensor : LightSensor;
        part obstructionSensor : ObstructionSensor;
        part manualInterface : ManualInterface;

        connect userInput.command to controller.userCommand.command;
        connect ambientLightInput.light to controller.lightInput.light;
        connect controller.motionOutput.motion to driveUnit.motionInput.motion;
        connect controller.tiltOutput.tilt to driveUnit.tiltInput.tilt;
        connect driveUnit.positionFeedback.status to controller.driveStatus.status;
        connect slatAssembly.assemblyStatus.status to controller.blindStatus.status;
        connect lightSensor.lightOutput.light to controller.lightInput.light;
        connect obstructionSensor.obstructionStatus.status to controller.obstructionInput.status;
        connect manualInterface.manualCommand.command to controller.userCommand.command;
        connect controller.statusOutput.status to systemStatus.status;
    }

    part def BlindController {
        attribute mode : BlindMode = BlindMode::manual;
        attribute targetPosition : Percent = 0;
        attribute targetTilt : AngleDegree = 45;
        attribute daylightSetpoint : Illuminance = 500;
        attribute privacyTilt : AngleDegree = 15;
        attribute glareLimit : Illuminance = 2000;
        attribute commandTimeout : TimeSecond = 2;

        port userCommand : UserCommandPort;
        port lightInput : LightInputPort;
        port obstructionInput : StatusInputPort;
        port blindStatus : StatusInputPort;
        port driveStatus : StatusInputPort;
        port motionOutput : MotionControlPort;
        port tiltOutput : TiltControlPort;
        port statusOutput : StatusPort;

        action decidePosition {
            in item command : UserCommand;
            in item light : LightCondition;
            out item motion : MotionCommand;
            out item tilt : TiltCommand;

            first start;
            then evaluateMode;

            action evaluateMode;
            then issueManualCommand if command.requestedMode == BlindMode::manual;
            then issueAutomaticCommand if command.requestedMode == BlindMode::automatic;
            then issueStopCommand if command.requestedMode == BlindMode::locked;

            action issueManualCommand {
                out item manualMotion : MotionCommand {
                    attribute direction = MotionDirection::stop;
                    attribute targetPosition = command.requestedPosition;
                    attribute speed = 60;
                }
                out item manualTilt : TiltCommand {
                    attribute direction = TiltDirection::hold;
                    attribute targetTilt = command.requestedTilt;
                }
            }

            action issueAutomaticCommand {
                out item automaticMotion : MotionCommand {
                    attribute direction = MotionDirection::lower;
                    attribute targetPosition = 65;
                    attribute speed = 35;
                }
                out item automaticTilt : TiltCommand {
                    attribute direction = TiltDirection::close;
                    attribute targetTilt = privacyTilt;
                }
            }

            action issueStopCommand {
                out item stopMotion : MotionCommand {
                    attribute direction = MotionDirection::stop;
                    attribute targetPosition = targetPosition;
                    attribute speed = 0;
                }
                out item holdTilt : TiltCommand {
                    attribute direction = TiltDirection::hold;
                    attribute targetTilt = targetTilt;
                }
            }

            then done;
        }

        state machine controllerStates {
            state idle;
            state manualControl;
            state automaticControl;
            state locked;
            state faulted;

            entry; then idle;

            transition idle_to_manual
                first idle
                accept UserCommand
                if userCommand.command.requestedMode == BlindMode::manual
                then manualControl;

            transition idle_to_auto
                first idle
                accept UserCommand
                if userCommand.command.requestedMode == BlindMode::automatic
                then automaticControl;

            transition manual_to_auto
                first manualControl
                accept UserCommand
                if userCommand.command.requestedMode == BlindMode::automatic
                then automaticControl;

            transition auto_to_manual
                first automaticControl
                accept UserCommand
                if userCommand.command.requestedMode == BlindMode::manual
                then manualControl;

            transition any_to_locked
                first manualControl
                accept UserCommand
                if userCommand.command.requestedMode == BlindMode::locked
                then locked;

            transition auto_to_fault
                first automaticControl
                if obstructionInput.status.obstructionDetected == true
                then faulted;

            transition manual_to_fault
                first manualControl
                if obstructionInput.status.obstructionDetected == true
                then faulted;

            transition locked_to_idle
                first locked
                accept UserCommand
                if userCommand.command.requestedMode != BlindMode::locked
                then idle;

            transition fault_to_idle
                first faulted
                accept UserCommand
                if obstructionInput.status.obstructionDetected == false
                then idle;
        }
    }

    part def BlindDriveUnit {
        attribute maximumLiftForce : ForceNewton = 45;
        attribute liftSpeed : Percent = 50;
        attribute currentPosition : Percent = 0;
        attribute currentTilt : AngleDegree = 45;

        port motionInput : MotionControlPort;
        port tiltInput : TiltControlPort;
        port positionFeedback : StatusPort;

        part liftMotor : LiftMotor;
        part tiltMotor : TiltMotor;
        part liftCord : LiftCord;
        part tiltRod : TiltRod;

        connect motionInput.motion to liftMotor.motionInput.motion;
        connect tiltInput.tilt to tiltMotor.tiltInput.tilt;
    }

    part def LiftMotor {
        attribute ratedForce : ForceNewton = 45;
        attribute ratedSpeed : Percent = 60;
        port motionInput : MotionControlPort;
    }

    part def TiltMotor {
        attribute ratedAngularRange : AngleDegree = 90;
        port tiltInput : TiltControlPort;
    }

    part def LiftCord {
        attribute tensileCapacity : ForceNewton = 120;
        attribute travelLength : LengthMillimeter = 1500;
    }

    part def TiltRod {
        attribute rotationRange : AngleDegree = 90;
    }

    part def SlatAssembly {
        attribute slatCount : Integer = 42;
        attribute slatWidth : LengthMillimeter = 35;
        attribute position : Percent = 0;
        attribute tiltAngle : AngleDegree = 45;

        port assemblyStatus : StatusPort;

        part slat[42] : Slat;
    }

    part def Slat {
        attribute width : LengthMillimeter = 35;
        attribute thickness : LengthMillimeter = 3;
        attribute tiltAngle : AngleDegree = 45;
    }

    part def BottomRail {
        attribute massEquivalentLoad : ForceNewton = 8;
        attribute width : LengthMillimeter = 1200;
    }

    part def HeadRail {
        attribute width : LengthMillimeter = 1200;
        attribute height : LengthMillimeter = 55;
    }

    part def LightSensor {
        attribute measuredIndoorIlluminance : Illuminance = 400;
        attribute measuredOutdoorIlluminance : Illuminance = 1200;
        port lightOutput : LightInputPort;
    }

    part def ObstructionSensor {
        attribute obstructionDetected : Boolean = false;
        port obstructionStatus : StatusPort;
    }

    part def ManualInterface {
        port manualCommand : UserCommandPort;
        attribute lastRequestedPosition : Percent = 0;
        attribute lastRequestedTilt : AngleDegree = 45;
    }

    requirement def PrimaryFunctionRequirement {
        subject blind : WindowBlindSystem;

        doc
        /* The window blind system shall regulate incoming daylight and privacy by raising, lowering, and tilting the blind assembly across a window opening. */

        require constraint {
            blind.minimumPosition == 0 and
            blind.maximumPosition == 100 and
            blind.minimumTilt == 0 and
            blind.maximumTilt == 90
        }
    }

    requirement def ManualControlRequirement {
        subject controller : BlindController;

        doc
        /* The controller shall accept a user command and produce lift and tilt commands matching the requested blind position and slat angle when operating in manual mode. */

        require constraint {
            controller.commandTimeout <= 2
        }
    }

    requirement def AutomaticLightRequirement {
        subject controller : BlindController;

        doc
        /* In automatic mode, the controller shall reduce excessive daylight by lowering the blind and closing the slats when outdoor illuminance exceeds the glare limit. */

        require constraint {
            controller.daylightSetpoint <= controller.glareLimit
        }
    }

    requirement def SafetyObstructionRequirement {
        subject controller : BlindController;

        doc
        /* The system shall stop motion and enter a fault state when an obstruction is detected during blind movement. */

        require constraint {
            controller.mode != BlindMode::fault or controller.obstructionInput.status.obstructionDetected == true
        }
    }

    requirement def TravelLimitRequirement {
        subject drive : BlindDriveUnit;

        doc
        /* The drive unit shall keep blind position within the physical travel range from fully raised to fully lowered. */

        require constraint {
            drive.currentPosition >= 0 and drive.currentPosition <= 100
        }
    }

    requirement def TiltLimitRequirement {
        subject drive : BlindDriveUnit;

        doc
        /* The drive unit shall keep slat tilt within the physical angular range from open to closed. */

        require constraint {
            drive.currentTilt >= 0 and drive.currentTilt <= 90
        }
    }

    satisfy PrimaryFunctionRequirement by WindowBlindSystem;
    satisfy ManualControlRequirement by BlindController;
    satisfy AutomaticLightRequirement by BlindController;
    satisfy SafetyObstructionRequirement by BlindController;
    satisfy TravelLimitRequirement by BlindDriveUnit;
    satisfy TiltLimitRequirement by BlindDriveUnit;

    part windowBlindSystem : WindowBlindSystem;
}