package ReactiveRobotModel {
    import ScalarValues::*;
    import ISQ::*;
    
    value type Distance :> Real [mm];
    value type Speed :> Real [m/s];
    
    enum def OpenDirection { front; rear; left; right; none; }
    
    item def SensorReading {
        value distance : Distance;
        value isDetected : Boolean;
    }
    
    item def EnvironmentModel {
        value frontDistance : Distance;
        value rearDistance : Distance;
        value leftClear : Boolean;
        value rightClear : Boolean;
        value minObstacleDistance : Distance;
        value bestOpenDirection : OpenDirection;
    }
    
    item def MotorCommand {
        value targetSpeed : Speed;
    }
    
    port def SensorDataOut {
        out reading : SensorReading;
    }
    port def SensorDataIn {
        in reading : SensorReading;
    }
    port def EnvModelOut {
        out model : EnvironmentModel;
    }
    port def EnvModelIn {
        in model : EnvironmentModel;
    }
    port def MotorCmdOut {
        out command : MotorCommand;
    }
    port def MotorCmdIn {
        in command : MotorCommand;
    }
    
    part def ForwardUltrasonicSensor {
        attribute maxRange : Distance = 2000 [mm];
        port sensorOut : SensorDataOut;
    }
    
    part def RearUltrasonicSensor {
        attribute maxRange : Distance = 1500 [mm];
        port sensorOut : SensorDataOut;
    }
    
    part def InfraredProximitySensor {
        attribute detectionRange : Distance = 150 [mm];
        port sensorOut : SensorDataOut;
    }
    
    part def WheelMotor {
        attribute currentSpeed : Speed;
        port cmdIn : MotorCmdIn;
    }
    
    part def PerceptionSubsystem {
        port frontSensorIn : SensorDataIn;
        port rearSensorIn : SensorDataIn;
        port leftSensorIn : SensorDataIn;
        port rightSensorIn : SensorDataIn;
        port envModelOut : EnvModelOut;
        
        action fuseData {
            in front : SensorReading;
            in rear : SensorReading;
            in left : SensorReading;
            in right : SensorReading;
            out env : EnvironmentModel;
            
            assign env.frontDistance := front.distance;
            assign env.rearDistance := rear.distance;
            assign env.leftClear := not left.isDetected;
            assign env.rightClear := not right.isDetected;
            
            decide {
                if front.distance < rear.distance {
                    assign env.minObstacleDistance := front.distance;
                } else {
                    assign env.minObstacleDistance := rear.distance;
                }
            }
            
            decide {
                if env.minObstacleDistance > 1000 [mm] {
                    assign env.bestOpenDirection := OpenDirection::front;
                } else if env.leftClear {
                    assign env.bestOpenDirection := OpenDirection::left;
                } else if env.rightClear {
                    assign env.bestOpenDirection := OpenDirection::right;
                } else {
                    assign env.bestOpenDirection := OpenDirection::rear;
                }
            }
        }
    }
    
    part def ReactiveController {
        attribute minSafeDistance : Distance = 200 [mm];
        attribute cruiseSpeed : Speed = 0.5 [m/s];
        attribute turnSpeed : Speed = 0.3 [m/s];
        attribute reverseSpeed : Speed = -0.2 [m/s];
        
        port envModelIn : EnvModelIn;
        port leftMotorCmdOut : MotorCmdOut;
        port rightMotorCmdOut : MotorCmdOut;
        
        state machine ControlStateMachine {
            state Idle {
                entry {
                    assign leftMotorCmdOut.command.targetSpeed := 0 [m/s];
                    assign rightMotorCmdOut.command.targetSpeed := 0 [m/s];
                }
            }
            state MoveForward {
                entry {
                    assign leftMotorCmdOut.command.targetSpeed := cruiseSpeed;
                    assign rightMotorCmdOut.command.targetSpeed := cruiseSpeed;
                }
            }
            state TurnLeft {
                entry {
                    assign leftMotorCmdOut.command.targetSpeed := -turnSpeed;
                    assign rightMotorCmdOut.command.targetSpeed := turnSpeed;
                }
            }
            state TurnRight {
                entry {
                    assign leftMotorCmdOut.command.targetSpeed := turnSpeed;
                    assign rightMotorCmdOut.command.targetSpeed := -turnSpeed;
                }
            }
            state Backup {
                entry {
                    assign leftMotorCmdOut.command.targetSpeed := reverseSpeed;
                    assign rightMotorCmdOut.command.targetSpeed := reverseSpeed;
                }
            }
            
            transition from Idle to MoveForward when envModelIn.model.minObstacleDistance > minSafeDistance;
            transition from MoveForward to TurnLeft when envModelIn.model.minObstacleDistance <= minSafeDistance and envModelIn.model.bestOpenDirection == OpenDirection::left;
            transition from MoveForward to TurnRight when envModelIn.model.minObstacleDistance <= minSafeDistance and envModelIn.model.bestOpenDirection == OpenDirection::right;
            transition from MoveForward to Backup when envModelIn.model.minObstacleDistance <= minSafeDistance and envModelIn.model.bestOpenDirection == OpenDirection::rear;
            transition from TurnLeft to MoveForward when envModelIn.model.minObstacleDistance > minSafeDistance;
            transition from TurnRight to MoveForward when envModelIn.model.minObstacleDistance > minSafeDistance;
            transition from Backup to TurnRight when envModelIn.model.minObstacleDistance > minSafeDistance;
        }
    }
    
    part def ReactiveRobot {
        part forwardSensor : ForwardUltrasonicSensor;
        part rearSensor : RearUltrasonicSensor;
        part leftIRSensor : InfraredProximitySensor;
        part rightIRSensor : InfraredProximitySensor;
        
        part leftWheel : WheelMotor;
        part rightWheel : WheelMotor;
        
        part perception : PerceptionSubsystem;
        part controller : ReactiveController;
        
        connect forwardSensor.sensorOut to perception.frontSensorIn;
        connect rearSensor.sensorOut to perception.rearSensorIn;
        connect leftIRSensor.sensorOut to perception.leftSensorIn;
        connect rightIRSensor.sensorOut to perception.rightSensorIn;
        
        connect perception.envModelOut to controller.envModelIn;
        
        connect controller.leftMotorCmdOut to leftWheel.cmdIn;
        connect controller.rightMotorCmdOut to rightWheel.cmdIn;
        
        state machine OperationalLoop {
            state Sensing;
            state Perceiving;
            state Controlling;
            state Actuating;
            
            transition from Sensing to Perceiving;
            transition from Perceiving to Controlling;
            transition from Controlling to Actuating;
            transition from Actuating to Sensing;
        }
    }
}
