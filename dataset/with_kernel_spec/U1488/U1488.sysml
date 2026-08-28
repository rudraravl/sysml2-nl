package 'Hydraulic Rudder System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import Time::*;
    
    attribute def AngleValue :> Real;
    attribute def PressureValue :> Real;
    attribute def ForceValue :> Real;
    
    item def RudderCommand {
        attribute desiredAngle : AngleValue;
    }
    item def RudderAngle {
        attribute actualAngle : AngleValue;
    }
    item def ActuatorCommand {
        attribute valvePosition : Real;
    }
    item def HydraulicFluid {
        attribute pressure : PressureValue;
    }
    item def MechanicalForce {
        attribute force : ForceValue;
    }
    item def Failure;
    item def SystemReset;
    
    part def SteeringMechanism {
        port commandPort {
            out command : RudderCommand;
        }
    }
    
    part def AngleSensor {
        port feedbackPort {
            out angle : RudderAngle;
        }
    }
    
    part def HydraulicPowerUnit {
        port fluidPort {
            out fluid : HydraulicFluid;
        }
    }
    
    part def RudderBlade {
        port forcePort {
            in force : MechanicalForce;
        }
        attribute angle : AngleValue;
    }
    
    part def HydraulicActuator {
        port commandPort {
            in command : ActuatorCommand;
        }
        port fluidPort {
            in fluid : HydraulicFluid;
        }
        port forcePort {
            out force : MechanicalForce;
        }
    }
    
    part def RudderController {
        port commandPort {
            in command : RudderCommand;
        }
        port feedbackPort {
            in angle : RudderAngle;
        }
        port actuatorCommandPort {
            out command : ActuatorCommand;
        }
        
        state rudderControlState {
            entry; then neutral;
            state neutral;
            accept cmd : RudderCommand via commandPort then deflecting;
            accept fail : Failure then emergency;
            state deflecting;
            accept ang : RudderAngle via feedbackPort then holding;
            accept fail : Failure then emergency;
            state holding;
            accept cmd : RudderCommand via commandPort then deflecting;
            accept fail : Failure then emergency;
            state emergency;
            accept reset : SystemReset then neutral;
        }
    }
    
    part def HydraulicRudderSystem {
        part steeringMechanism : SteeringMechanism;
        part rudderController : RudderController;
        part angleSensor : AngleSensor;
        part hydraulicPowerUnit : HydraulicPowerUnit;
        part hydraulicActuator : HydraulicActuator;
        part rudderBlade : RudderBlade;
        
        interface steeringToController connect steeringMechanism.commandPort to rudderController.commandPort;
        interface sensorToController connect angleSensor.feedbackPort to rudderController.feedbackPort;
        interface controllerToActuator connect rudderController.actuatorCommandPort to hydraulicActuator.commandPort;
        interface powerToActuator connect hydraulicPowerUnit.fluidPort to hydraulicActuator.fluidPort;
        interface actuatorToRudder connect hydraulicActuator.forcePort to rudderBlade.forcePort;
        
        requirement steeringForceReq : SteeringForceRequirement {
            attribute :>> actualForce = hydraulicActuator.forcePort.force.force;
            attribute :>> requiredForce = 1000;
        }
        requirement positioningAccuracyReq : PositioningAccuracyRequirement {
            attribute :>> commandedAngle = steeringMechanism.commandPort.command.desiredAngle;
            attribute :>> actualAngle = angleSensor.feedbackPort.angle.actualAngle;
        }
        requirement responseTimeReq : ResponseTimeRequirement {
            attribute :>> maxResponseTime = 2.0;
        }
    }
    
    requirement def SteeringForceRequirement {
        doc /* The hydraulic actuator shall provide sufficient steering force. */
        attribute actualForce : ForceValue;
        attribute requiredForce : ForceValue;
        require constraint { actualForce >= requiredForce }
    }
    
    requirement def PositioningAccuracyRequirement {
        doc /* The rudder angle shall be within 0.5 degrees of the commanded angle. */
        attribute commandedAngle : AngleValue;
        attribute actualAngle : AngleValue;
        attribute maxError : AngleValue = 0.5;
        require constraint { (commandedAngle - actualAngle <= maxError) and (actualAngle - commandedAngle <= maxError) }
    }
    
    requirement def ResponseTimeRequirement {
        doc /* The system shall reach the commanded angle within the specified response time. */
        attribute maxResponseTime : Real;
        require constraint { maxResponseTime <= 2.0 }
    }
}
