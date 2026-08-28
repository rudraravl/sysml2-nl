package BangBangRobotSystem {
    import ISQ::*;
    import ScalarValues::*;

    // Value Types
    item def PositionData {
        attribute position: Length;
        attribute velocity: Velocity;
    }

    item def ActuatorForce {
        attribute force: Force;
    }

    enum def ControlCommand {
        forward;
        reverse;
        off;
    }

    // Requirements
    requirement def PositioningPrecision {
        doc /* The system must position the object within a 0.01 m deadband. */
        attribute deadbandTolerance: Length = 0.01 [m];
        subject robot: BangBangRobot;
        require robot.controller.deadband <= deadbandTolerance;
    }

    requirement def ForceCapability {
        doc /* The actuator must provide at least 100 N of force. */
        attribute minForce: Force = 100 [N];
        subject robot: BangBangRobot;
        require robot.actuator.maxForce >= minForce;
    }

    requirement def PayloadCapacity {
        doc /* The system must handle a payload of at least 5 kg. */
        attribute minPayload: Mass = 5 [kg];
        subject robot: BangBangRobot;
        require robot.targetObject.mass <= minPayload;
    }

    requirement def ResponseTime {
        doc /* The system must respond within 0.01 s. */
        attribute maxResponseTime: Time = 0.01 [s];
        subject robot: BangBangRobot;
        require robot.responseTime <= maxResponseTime;
    }

    // Parts
    part def TargetObject {
        port appliedForce: ForceInPort;
        attribute mass: Mass = 2 [kg];
        attribute position: Length = 0 [m];
        attribute velocity: Velocity = 0 [m/s];
    }

    // Ports
    port def PositionOutPort {
        out positionData: PositionData;
    }

    port def PositionInPort {
        in positionData: PositionData;
    }

    port def SetpointInPort {
        in setpoint: Length;
    }

    port def CommandOutPort {
        out command: ControlCommand;
    }

    port def CommandInPort {
        in command: ControlCommand;
    }

    port def ForceOutPort {
        out force: ActuatorForce;
    }

    port def ForceInPort {
        in force: ActuatorForce;
    }

    port def EmergencyStopPort {
        in trigger: Boolean;
    }

    // Components
    part def PositionSensor {
        port positionOut: PositionOutPort;
        attribute measuredObject: TargetObject;
        
        action MeasureAction {
            out measurement: PositionData;
            
            measurement.position = measuredObject.position;
            measurement.velocity = measuredObject.velocity;
        }
    }

    part def BangBangController {
        port positionIn: PositionInPort;
        port setpointIn: SetpointInPort;
        port commandOut: CommandOutPort;
        
        attribute deadband: Length = 0.01 [m];
        
        action ComputeCommandAction {
            in position: PositionData;
            in setpoint: Length;
            out command: ControlCommand;
            
            if (setpoint - position.position > deadband) {
                command = ControlCommand::forward;
            } else if (position.position - setpoint > deadband) {
                command = ControlCommand::reverse;
            } else {
                command = ControlCommand::off;
            }
        }
    }

    part def LinearActuator {
        port commandIn: CommandInPort;
        port forceOut: ForceOutPort;
        
        attribute maxForce: Force = 100 [N];
        
        action GenerateForceAction {
            in command: ControlCommand;
            out force: ActuatorForce;
            
            if (command == ControlCommand::forward) {
                force.force = maxForce;
            } else if (command == ControlCommand::reverse) {
                force.force = -maxForce;
            } else {
                force.force = 0 [N];
            }
        }
    }

    part def RoboticManipulator {
        port forceIn: ForceInPort;
        port objectInteraction: ForceOutPort;
        
        action ApplyForceAction {
            in force: ActuatorForce;
            in object: TargetObject;
            
            // Apply force to object, changing its acceleration
            // a = F/m
        }
    }

    // System
    part def BangBangRobot {
        port setpoint: SetpointInPort;
        port emergencyStop: EmergencyStopPort;
        attribute responseTime: Time = 0.005 [s];
        
        part positionSensor: PositionSensor;
        part controller: BangBangController;
        part actuator: LinearActuator;
        part manipulator: RoboticManipulator;
        part targetObject: TargetObject;
        
        // Connections
        flow positionSensor.positionOut to controller.positionIn;
        flow controller.commandOut to actuator.commandIn;
        flow actuator.forceOut to manipulator.forceIn;
        flow manipulator.objectInteraction to targetObject.appliedForce;
        
        // State Machine
        state machine RobotStates {
            state initializing;
            state standby;
            state executing;
            state holding;
            state safeShutdown;
            
            transition from initializing to standby;
            transition from standby to executing when setpoint.setpoint > 0 [m];
            transition from executing to holding when targetObject.position == setpoint.setpoint;
            transition from holding to executing when targetObject.position != setpoint.setpoint;
            transition from * to safeShutdown when emergencyStop.trigger == true;
        }
        
        // Requirements satisfaction
        requirement posPrecision: PositioningPrecision;
        requirement forceCap: ForceCapability;
        requirement payloadCap: PayloadCapacity;
        requirement responseT: ResponseTime;
        
        satisfy posPrecision by controller.deadband;
        satisfy forceCap by actuator.maxForce;
        satisfy payloadCap by targetObject.mass;
        satisfy responseT by responseTime;
    }
}
