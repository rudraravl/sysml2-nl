package 'Hydraulic Flap System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    unit deg;
    unit 'deg_per_s';

    item def FlapCommand {
        attribute targetAngle : Real;
    }

    item def PositionFeedback {
        attribute currentAngle : Real;
    }

    item def ActuatorCommand;
    item def ExtendCommand :> ActuatorCommand;
    item def RetractCommand :> ActuatorCommand;
    item def HoldCommand :> ActuatorCommand;

    action def 'Sense Position' {
        out angle : Real;
    }

    state def 'Flap Control States';
    state def 'Actuator States';

    port def CommandPort {
        in command : FlapCommand;
    }
    port def FeedbackInPort {
        in feedback : PositionFeedback;
    }
    port def FeedbackOutPort {
        out feedback : PositionFeedback;
    }
    port def ActuatorInPort {
        in command : ActuatorCommand;
    }
    port def ActuatorOutPort {
        out command : ActuatorCommand;
    }

    part def FlapSurface {
        attribute surfaceArea : Real = 8.5 [m^2];
        attribute minDeflection : Real = 0 [deg];
        attribute maxDeflection : Real = 40 [deg];
        attribute currentAngle : Real = 0 [deg];
    }

    part def HydraulicActuator {
        attribute maxSpeed : Real = 15 ['deg_per_s'];
        attribute operatingPressure : Real = 20680000 [Pa];
        port commandIn : ActuatorInPort;
        exhibit state 'actuator states' : 'Actuator States' {
            entry; then idle;
            state idle;
            accept ExtendCommand via commandIn then extending;
            accept RetractCommand via commandIn then retracting;
            state extending;
            accept HoldCommand via commandIn then idle;
            accept RetractCommand via commandIn then retracting;
            state retracting;
            accept HoldCommand via commandIn then idle;
            accept ExtendCommand via commandIn then extending;
        }
    }

    part def FlapController {
        attribute actualAngle : Real = 0 [deg];
        port commandIn : CommandPort;
        port feedbackIn : FeedbackInPort;
        port actuatorOut : ActuatorOutPort;
    }

    part def PositionSensor {
        attribute accuracy : Real = 0.5 [deg];
        attribute sampleRate : Real = 50 [Hz];
        attribute measuredAngle : Real = 0 [deg];
        port feedbackOut : FeedbackOutPort;
    }

    part def FlapSystem {
        part flapSurface : FlapSurface;
        part hydraulicActuator : HydraulicActuator;
        part positionSensor : PositionSensor {
            action sensePosition {
                action sense : 'Sense Position';
                then action sendFeedback send new PositionFeedback() to feedbackOut;
            }
        }
        part flapController : FlapController {
            exhibit state 'flap control states' : 'Flap Control States' {
                entry; then retracted;
                state retracted;
                accept FlapCommand via commandIn
                    if commandIn.command.targetAngle > 0 [deg]
                    do send new ExtendCommand() to actuatorOut
                    then extending;
                state extending;
                accept PositionFeedback via feedbackIn
                    if actualAngle >= commandIn.command.targetAngle and commandIn.command.targetAngle >= 40 [deg]
                    then extended;
                accept PositionFeedback via feedbackIn
                    if actualAngle >= commandIn.command.targetAngle and commandIn.command.targetAngle < 40 [deg]
                    then holding;
                state extended;
                accept FlapCommand via commandIn
                    if commandIn.command.targetAngle < 40 [deg]
                    do send new RetractCommand() to actuatorOut
                    then retracting;
                state retracting;
                accept PositionFeedback via feedbackIn
                    if actualAngle <= commandIn.command.targetAngle and commandIn.command.targetAngle <= 0 [deg]
                    then retracted;
                accept PositionFeedback via feedbackIn
                    if actualAngle <= commandIn.command.targetAngle and commandIn.command.targetAngle > 0 [deg]
                    then holding;
                state holding;
                accept FlapCommand via commandIn
                    if commandIn.command.targetAngle > actualAngle
                    do send new ExtendCommand() to actuatorOut
                    then extending;
                accept FlapCommand via commandIn
                    if commandIn.command.targetAngle < actualAngle
                    do send new RetractCommand() to actuatorOut
                    then retracting;
            }
        }

        port externalCommandPort : CommandPort;
        bind externalCommandPort = flapController.commandIn;
        bind flapController.actualAngle = positionSensor.measuredAngle;
        bind positionSensor.measuredAngle = flapSurface.currentAngle;

        flow actuatorCommandFlow of ActuatorCommand
            from flapController.actuatorOut.command
            to hydraulicActuator.commandIn.command;
        flow feedbackFlow of PositionFeedback
            from positionSensor.feedbackOut.feedback
            to flapController.feedbackIn.feedback;
    }

    requirement def 'Flap System Requirements' {
        subject flapSys : FlapSystem;
        requirement 'Surface Area Requirement' {
            constraint { flapSys.flapSurface.surfaceArea == 8.5 [m^2] }
        }
        requirement 'Deflection Range Requirement' {
            constraint { flapSys.flapSurface.minDeflection == 0 [deg] and flapSys.flapSurface.maxDeflection == 40 [deg] }
        }
        requirement 'Actuator Speed Requirement' {
            constraint { flapSys.hydraulicActuator.maxSpeed == 15 ['deg_per_s'] }
        }
        requirement 'Sensor Accuracy Requirement' {
            constraint { flapSys.positionSensor.accuracy == 0.5 [deg] }
        }
        requirement 'Sensor Sample Rate Requirement' {
            constraint { flapSys.positionSensor.sampleRate == 50 [Hz] }
        }
        requirement 'Closed Loop Control Requirement' {
            doc /* The flap controller shall use position feedback to adjust the actuator until the commanded flap angle is reached and held. */
        }
    }

    part aircraftFlapSystem : FlapSystem;
    requirement flapSystemRequirements : 'Flap System Requirements' {
        subject flapSys = aircraftFlapSystem;
    }
}
