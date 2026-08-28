package ReactiveNavigationRobot {
    import ScalarValues::Real;
    
    item def Distance :> Real;
    item def Speed :> Real;
    item def Direction :> Real;
    
    item def ObstacleInfo {
        attribute distance : Distance;
        attribute direction : Direction;
    }
    
    item def EnvironmentModel {
        attribute closestObstacleDistance : Distance;
        attribute closestObstacleDirection : Direction;
        attribute mostOpenDirection : Direction;
    }
    
    item def MotorCommand {
        attribute targetSpeed : Speed;
    }
    
    part def Sensor {
        attribute minRange : Distance;
        attribute maxRange : Distance;
        port sensorOut {
            out obstacle : ObstacleInfo;
        }
    }
    
    part def UltrasonicSensor :> Sensor;
    part def InfraredSensor :> Sensor;
    
    part def WheelMotor {
        port commandIn {
            in command : MotorCommand;
        }
        attribute currentSpeed : Speed;
    }
    
    part def PerceptionSubsystem {
        port perceptionIn1 {
            in obstacle : ObstacleInfo;
        }
        port perceptionIn2 {
            in obstacle : ObstacleInfo;
        }
        port perceptionIn3 {
            in obstacle : ObstacleInfo;
        }
        port perceptionIn4 {
            in obstacle : ObstacleInfo;
        }
        port modelOut {
            out model : EnvironmentModel;
        }
        
        action fuseSensorData {
            in obs1 : ObstacleInfo;
            in obs2 : ObstacleInfo;
            in obs3 : ObstacleInfo;
            in obs4 : ObstacleInfo;
            out envModel : EnvironmentModel;
            first start;
            then action identifyClosestObstacle;
            then action determineOpenDirection;
            then done;
        }
    }
    
    part def ReactiveController {
        port modelIn {
            in model : EnvironmentModel;
        }
        port leftMotorOut {
            out command : MotorCommand;
        }
        port rightMotorOut {
            out command : MotorCommand;
        }
        
        state def NavigationStates {
            in model : EnvironmentModel;
            attribute safeDistance : Distance = 0.3;
            attribute criticalDistance : Distance = 0.1;
            
            state MovingForward;
            state TurningLeft;
            state TurningRight;
            state BackingUp;
            
            transition forwardToLeft
                from MovingForward to TurningLeft
                when model.closestObstacleDirection < 0.0
                and model.closestObstacleDistance < safeDistance;
            transition forwardToRight
                from MovingForward to TurningRight
                when model.closestObstacleDirection > 0.0
                and model.closestObstacleDistance < safeDistance;
            transition leftToForward
                from TurningLeft to MovingForward
                when model.closestObstacleDistance >= safeDistance;
            transition rightToForward
                from TurningRight to MovingForward
                when model.closestObstacleDistance >= safeDistance;
            transition forwardToBack
                from MovingForward to BackingUp
                when model.closestObstacleDistance < criticalDistance;
            transition backToForward
                from BackingUp to MovingForward
                when model.closestObstacleDistance >= safeDistance;
        }
        
        exhibit NavigationStates {
            in model = modelIn.model;
        }
        
        action decideAndCommand {
            in envModel : EnvironmentModel;
            out leftCommand : MotorCommand;
            out rightCommand : MotorCommand;
            first start;
            then action evaluateRules;
            then action generateMotorCommands;
            then done;
        }
    }
    
    part def Robot {
        part frontUltrasonic : UltrasonicSensor {
            :>> minRange = 0.02;
            :>> maxRange = 4.0;
        }
        part rearUltrasonic : UltrasonicSensor {
            :>> minRange = 0.02;
            :>> maxRange = 4.0;
        }
        part leftInfrared : InfraredSensor {
            :>> minRange = 0.01;
            :>> maxRange = 0.8;
        }
        part rightInfrared : InfraredSensor {
            :>> minRange = 0.01;
            :>> maxRange = 0.8;
        }
        part perception : PerceptionSubsystem;
        part controller : ReactiveController;
        part leftMotor : WheelMotor;
        part rightMotor : WheelMotor;
        
        flow frontFlow of ObstacleInfo
            from frontUltrasonic.sensorOut.obstacle to perception.perceptionIn1.obstacle;
        flow rearFlow of ObstacleInfo
            from rearUltrasonic.sensorOut.obstacle to perception.perceptionIn2.obstacle;
        flow leftFlow of ObstacleInfo
            from leftInfrared.sensorOut.obstacle to perception.perceptionIn3.obstacle;
        flow rightFlow of ObstacleInfo
            from rightInfrared.sensorOut.obstacle to perception.perceptionIn4.obstacle;
        flow modelFlow of EnvironmentModel
            from perception.modelOut.model to controller.modelIn.model;
        flow leftCommandFlow of MotorCommand
            from controller.leftMotorOut.command to leftMotor.commandIn.command;
        flow rightCommandFlow of MotorCommand
            from controller.rightMotorOut.command to rightMotor.commandIn.command;
        
        action reactiveLoop {
            first start;
            then action sense {
                out front : ObstacleInfo;
                out rear : ObstacleInfo;
                out left : ObstacleInfo;
                out right : ObstacleInfo;
            }
            then action fuse {
                in front : ObstacleInfo;
                in rear : ObstacleInfo;
                in left : ObstacleInfo;
                in right : ObstacleInfo;
                out model : EnvironmentModel;
            }
            then action decide {
                in model : EnvironmentModel;
                out leftCmd : MotorCommand;
                out rightCmd : MotorCommand;
            }
            then action actuate {
                in leftCmd : MotorCommand;
                in rightCmd : MotorCommand;
            }
            then done;
        }
    }
    
    requirement def ReactiveNavigationRequirement {
        doc /* The robot must navigate without an internal map by reacting to immediate sensor data. */
        subject robot : Robot;
        requirement {
            doc /* The robot must detect obstacles in 360 degrees. */
        }
        requirement {
            doc /* The robot must maintain a minimum safe distance of 0.3 m from any obstacle. */
        }
        requirement {
            doc /* The robot must continuously loop sensing, fusing, deciding, and actuating. */
        }
    }
    
    part def ReactiveRobot :> Robot {
        requirement reactiveNavReq : ReactiveNavigationRequirement {
            :>> robot = ReactiveRobot;
        }
    }
}
