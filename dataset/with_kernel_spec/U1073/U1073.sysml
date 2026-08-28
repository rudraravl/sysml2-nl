package HexapodRobotModel {
    value def Distance :> Real;
    value def Angle :> Real;
    value def Torque :> Real;
    value def Duration :> Real;
    
    item def SensorData {
        attribute distance : Distance;
        attribute inContact : Boolean;
    }
    
    item def JointCommand {
        attribute targetAngle : Angle;
        attribute targetTorque : Torque;
    }
    
    item def MoveCommand;
    item def StopCommand;
    
    requirement def BalanceRequirement {
        doc /* The robot shall maintain stability by keeping at least three legs in contact with the ground at any time during locomotion. */
    }
    
    requirement def BatteryLifeRequirement {
        doc /* The rechargeable battery pack shall allow for at least one hour of continuous operation. */
        attribute minDuration : Duration = 1.0;
    }
    
    requirement def ObstacleAvoidanceRequirement {
        doc /* If an obstacle is detected, the robot shall enter an obstacle avoidance mode to navigate around it before resuming its path. */
    }
    
    part def Body {
        attribute mass : Real;
    }
    
    part def Joint {
        port cmdInPort {
            in cmd : JointCommand;
        }
        attribute currentAngle : Angle;
    }
    
    part def GroundSensor {
        port sensorOutPort {
            out data : SensorData;
        }
    }
    
    part def Leg {
        part coxa : Joint;
        part femur : Joint;
        part tibia : Joint;
        part groundSensor : GroundSensor;
    }
    
    part def Battery {
        attribute capacity : Duration = 1.0;
        attribute voltage : Real;
    }
    
    part def Controller {
        port commandIn {
            in cmd : MoveCommand;
            in stopCmd : StopCommand;
        }
        
        port sensorIn1 { in data : SensorData; }
        port sensorIn2 { in data : SensorData; }
        port sensorIn3 { in data : SensorData; }
        port sensorIn4 { in data : SensorData; }
        port sensorIn5 { in data : SensorData; }
        port sensorIn6 { in data : SensorData; }
        
        port cmdOut1 { out cmd : JointCommand; }
        port cmdOut2 { out cmd : JointCommand; }
        port cmdOut3 { out cmd : JointCommand; }
        port cmdOut4 { out cmd : JointCommand; }
        port cmdOut5 { out cmd : JointCommand; }
        port cmdOut6 { out cmd : JointCommand; }
        port cmdOut7 { out cmd : JointCommand; }
        port cmdOut8 { out cmd : JointCommand; }
        port cmdOut9 { out cmd : JointCommand; }
        port cmdOut10 { out cmd : JointCommand; }
        port cmdOut11 { out cmd : JointCommand; }
        port cmdOut12 { out cmd : JointCommand; }
        port cmdOut13 { out cmd : JointCommand; }
        port cmdOut14 { out cmd : JointCommand; }
        port cmdOut15 { out cmd : JointCommand; }
        port cmdOut16 { out cmd : JointCommand; }
        port cmdOut17 { out cmd : JointCommand; }
        port cmdOut18 { out cmd : JointCommand; }
        
        attribute obstacleDetected : Boolean;
        attribute pathClear : Boolean;
        
        action locomotionCycle {
            action scanEnvironment;
            then action selectGait;
            then action generateJointCommands;
            then action sendJointCommands;
        }
        
        action avoidObstacle;
        
        state controllerBehavior {
            state standby;
            state activeLocomotion {
                do locomotionCycle;
            }
            state obstacleAvoidance {
                do avoidObstacle;
            }
            
            transition first standby accept cmd : MoveCommand via commandIn then activeLocomotion;
            transition first activeLocomotion if obstacleDetected then obstacleAvoidance;
            transition first obstacleAvoidance if pathClear then activeLocomotion;
            transition first activeLocomotion accept stopCmd : StopCommand via commandIn then standby;
        }
    }
    
    part def HexapodRobot {
        part body : Body;
        part controller : Controller;
        part battery : Battery;
        part leg1 : Leg;
        part leg2 : Leg;
        part leg3 : Leg;
        part leg4 : Leg;
        part leg5 : Leg;
        part leg6 : Leg;
        
        flow s1 of SensorData from leg1.groundSensor.sensorOutPort.data to controller.sensorIn1.data;
        flow s2 of SensorData from leg2.groundSensor.sensorOutPort.data to controller.sensorIn2.data;
        flow s3 of SensorData from leg3.groundSensor.sensorOutPort.data to controller.sensorIn3.data;
        flow s4 of SensorData from leg4.groundSensor.sensorOutPort.data to controller.sensorIn4.data;
        flow s5 of SensorData from leg5.groundSensor.sensorOutPort.data to controller.sensorIn5.data;
        flow s6 of SensorData from leg6.groundSensor.sensorOutPort.data to controller.sensorIn6.data;
        
        flow c1 of JointCommand from controller.cmdOut1.cmd to leg1.coxa.cmdInPort.cmd;
        flow c2 of JointCommand from controller.cmdOut2.cmd to leg1.femur.cmdInPort.cmd;
        flow c3 of JointCommand from controller.cmdOut3.cmd to leg1.tibia.cmdInPort.cmd;
        flow c4 of JointCommand from controller.cmdOut4.cmd to leg2.coxa.cmdInPort.cmd;
        flow c5 of JointCommand from controller.cmdOut5.cmd to leg2.femur.cmdInPort.cmd;
        flow c6 of JointCommand from controller.cmdOut6.cmd to leg2.tibia.cmdInPort.cmd;
        flow c7 of JointCommand from controller.cmdOut7.cmd to leg3.coxa.cmdInPort.cmd;
        flow c8 of JointCommand from controller.cmdOut8.cmd to leg3.femur.cmdInPort.cmd;
        flow c9 of JointCommand from controller.cmdOut9.cmd to leg3.tibia.cmdInPort.cmd;
        flow c10 of JointCommand from controller.cmdOut10.cmd to leg4.coxa.cmdInPort.cmd;
        flow c11 of JointCommand from controller.cmdOut11.cmd to leg4.femur.cmdInPort.cmd;
        flow c12 of JointCommand from controller.cmdOut12.cmd to leg4.tibia.cmdInPort.cmd;
        flow c13 of JointCommand from controller.cmdOut13.cmd to leg5.coxa.cmdInPort.cmd;
        flow c14 of JointCommand from controller.cmdOut14.cmd to leg5.femur.cmdInPort.cmd;
        flow c15 of JointCommand from controller.cmdOut15.cmd to leg5.tibia.cmdInPort.cmd;
        flow c16 of JointCommand from controller.cmdOut16.cmd to leg6.coxa.cmdInPort.cmd;
        flow c17 of JointCommand from controller.cmdOut17.cmd to leg6.femur.cmdInPort.cmd;
        flow c18 of JointCommand from controller.cmdOut18.cmd to leg6.tibia.cmdInPort.cmd;
        
        requirement balanceReq : BalanceRequirement;
        requirement batteryReq : BatteryLifeRequirement;
        requirement obstacleReq : ObstacleAvoidanceRequirement;
        
        satisfy balanceReq by controller;
        satisfy batteryReq by battery;
        satisfy obstacleReq by controller;
    }
}
