package ContinuumRobotSystem {
    private import ScalarValues::*;
    
    unit def mm;
    unit def kg;
    unit def N;
    unit def Pa;
    unit def V;
    unit def A;
    unit def rad;
    unit def h;
    
    attribute def Length :> Real;
    attribute def Force :> Real;
    attribute def Mass :> Real;
    attribute def Pressure :> Real;
    attribute def Voltage :> Real;
    attribute def Current :> Real;
    attribute def Angle :> Real;
    attribute def Time :> Real;
    
    item def ShapeData;
    item def ForceData;
    item def ActuatorCommand;
    item def TrajectoryPlan;
    item def TaskCommand;
    item def SystemEvent;
    item def InitCmd :> SystemEvent;
    item def CalDoneCmd :> SystemEvent;
    item def TaskComplete :> SystemEvent;
    item def FaultCmd :> SystemEvent;
    item def ResetCmd :> SystemEvent;
    
    port def ActuatorOutPort {
        out cmd : ActuatorCommand[3];
    }
    port def ActuatorInPort {
        in cmd : ActuatorCommand[3];
    }
    port def ShapeOutPort {
        out shapeData : ShapeData;
    }
    port def ShapeInPort {
        in shapeData : ShapeData;
    }
    port def ForceOutPort {
        out forceData : ForceData;
    }
    port def ForceInPort {
        in forceData : ForceData;
    }
    port def GripperOutPort {
        out cmd : ActuatorCommand;
    }
    port def GripperInPort {
        in cmd : ActuatorCommand;
    }
    port def PowerOutPort {
        out voltage : Voltage;
        out current : Current;
    }
    port def PowerInPort {
        in voltage : Voltage;
        in current : Current;
    }
    
    part def PneumaticActuator {
        port cmdIn : ActuatorInPort;
    }
    part def ShapeSensor {
        port shapeOut : ShapeOutPort;
    }
    part def ForceSensor {
        port forceOut : ForceOutPort;
    }
    part def Finger {
        attribute maxLoad : Mass = 1 [mm];
    }
    
    part def Segment {
        attribute segmentLength : Length = 200 [mm];
        part actuators[3] : PneumaticActuator;
        part shapeSensor : ShapeSensor;
        port actuatorIn : ActuatorInPort;
        port shapeOut : ShapeOutPort;
        flow actuatorDistrib of ActuatorCommand from actuatorIn.cmd to actuators.cmdIn.cmd;
        flow shapeFlow of ShapeData from shapeSensor.shapeOut.shapeData to shapeOut.shapeData;
    }
    
    part def Gripper {
        attribute maxPayload : Mass = 2 [kg];
        part fingers[2] : Finger;
        part forceSensor : ForceSensor;
        port cmdIn : GripperInPort;
        port forceOut : ForceOutPort;
        flow forceFlow of ForceData from forceSensor.forceOut.forceData to forceOut.forceData;
    }
    
    part def ContinuumArm {
        attribute totalLength : Length = 600 [mm];
        part segment1 : Segment;
        part segment2 : Segment;
        part segment3 : Segment;
        part gripper : Gripper;
        port actuatorBus[3] : ActuatorInPort;
        port shapeBus[3] : ShapeOutPort;
        port forceBus : ForceOutPort;
        port gripperCmdPort : GripperInPort;
        
        bind segment1.actuatorIn = actuatorBus[0];
        bind segment2.actuatorIn = actuatorBus[1];
        bind segment3.actuatorIn = actuatorBus[2];
        bind segment1.shapeOut = shapeBus[0];
        bind segment2.shapeOut = shapeBus[1];
        bind segment3.shapeOut = shapeBus[2];
        bind gripper.forceOut = forceBus;
        flow gripperCmdFlow of ActuatorCommand from gripperCmdPort.cmd to gripper.cmdIn.cmd;
    }
    
    part def PowerSupply {
        attribute nominalVoltage : Voltage = 24 [V];
        attribute maxCurrent : Current = 10 [A];
        port powerOut : PowerOutPort;
    }
    
    action def ProcessFeedback {
        in shapeFeedback : ShapeData[3];
        in forceFeedback : ForceData;
    }
    action def PlanTrajectory {
        in shapeFeedback : ShapeData[3];
        out trajectory : TrajectoryPlan;
    }
    action def ExecuteMovement {
        in trajectory : TrajectoryPlan;
        out actuatorCommands : ActuatorCommand[9];
    }
    action def ControlLoop {
        action processFeedback : ProcessFeedback;
        action planTrajectory : PlanTrajectory;
        action executeMovement : ExecuteMovement;
    }
    
    state def ControlStateMachine {
        entry;
        then idle;
        state idle;
        transition init first idle accept InitCmd then calibrating;
        state calibrating;
        transition cal_done first calibrating accept CalDoneCmd then ready;
        state ready;
        transition task_start first ready accept TaskCommand then executing;
        state executing {
            entry;
            do ControlLoop;
        }
        transition task_end first executing accept TaskComplete then ready;
        transition fault_det first executing accept FaultCmd then fault;
        state fault;
        transition reset_cmd first fault accept ResetCmd then idle;
    }
    
    part def ControlComputer {
        port powerIn : PowerInPort;
        port shapeIn[3] : ShapeInPort;
        port forceIn : ForceInPort;
        port actuatorOut[3] : ActuatorOutPort;
        port gripperOut : GripperOutPort;
        exhibit controlStates : ControlStateMachine;
    }
    
    part def ContinuumRobot {
        attribute totalLength : Length = 600 [mm];
        requirement positioningAcc : PositioningAccuracyReq;
        requirement payloadCap : PayloadCapacityReq;
        requirement taskSuccess : TaskSuccessReq;
        requirement reliability : ReliabilityReq;
        
        part controlComputer : ControlComputer;
        part powerSupply : PowerSupply;
        part arm : ContinuumArm;
        
        bind controlComputer.powerIn = powerSupply.powerOut;
        bind arm.actuatorBus = controlComputer.actuatorOut;
        bind arm.shapeBus = controlComputer.shapeIn;
        bind arm.forceBus = controlComputer.forceIn;
        bind arm.gripperCmdPort = controlComputer.gripperOut;
    }
    
    requirement def PositioningAccuracyReq {
        doc /* The system shall achieve a positioning accuracy of 2mm. */
        attribute maxError : Length = 2 [mm];
    }
    requirement def PayloadCapacityReq {
        doc /* The end-effector shall handle payloads up to 2kg. */
        attribute maxPayload : Mass = 2 [kg];
    }
    requirement def TaskSuccessReq {
        doc /* The system shall maintain a high rate of task success. */
        attribute minSuccessRate : Real = 0.99;
    }
    requirement def ReliabilityReq {
        doc /* The system shall exhibit high overall reliability. */
        attribute minMTBF : Time = 10000 [h];
    }
}
