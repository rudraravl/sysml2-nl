package EducationalRoboticsSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ProgramInstruction;
    attribute def SensorData;
    attribute def MotorCommand;
    attribute def StudentLevel;
    attribute def MissionType;
    
    attribute def Distance :> ISQ::LengthValue;
    attribute def Angle :> ISQ::AngleValue;
    attribute def Velocity :> ISQ::SpeedValue;
    attribute def BatteryCharge :> ISQ::DimensionOneValue;
    attribute def Voltage :> ISQ::ElectricPotentialValue;
    attribute def Current :> ISQ::ElectricCurrentValue;
    
    port def PowerPort {
        attribute voltage : Voltage;
        attribute current : Current;
    }
    
    port def DataBusPort {
        in attribute commandsIn : ProgramInstruction[*];
        out attribute dataOut : SensorData[*];
    }
    
    port def SensorOutputPort {
        out attribute reading : SensorData;
    }
    
    port def MotorInputPort {
        in attribute command : MotorCommand;
    }
    
    item def BatteryPack {
        attribute capacity : ISQ::EnergyValue;
        attribute chargeLevel : BatteryCharge;
        port powerOutput : PowerPort;
    }
    
    part def UltrasonicSensor {
        attribute maxRange : Distance;
        attribute minRange : Distance;
        port sensorOut : SensorOutputPort;
        port powerIn : PowerPort;
        
        action measureDistance {
            out distance : Distance;
        }
    }
    
    part def LineFollowingSensor {
        attribute detectedColor : String;
        port sensorOut : SensorOutputPort;
        port powerIn : PowerPort;
        
        action detectLine {
            out linePosition : Real;
        }
    }
    
    part def DCMotor {
        attribute maxSpeed : Velocity;
        attribute currentSpeed : Velocity;
        port motorControl : MotorInputPort;
        port powerIn : PowerPort;
        
        action setSpeed {
            in command : MotorCommand;
            out actualSpeed : Velocity;
        }
    }
    
    part def WheelAssembly {
        attribute diameter : Distance;
        attribute rotationAngle : Angle;
        part motor : DCMotor;
        
        action rotate {
            in speed : Velocity;
        }
    }
    
    part def Microcontroller {
        attribute clockFrequency : ISQ::FrequencyValue;
        attribute memorySize : ISQ::InformationValue;
        port dataBus : DataBusPort;
        port powerIn : PowerPort;
        
        action processProgram {
            in program : ProgramInstruction[*];
            in sensorInputs : SensorData[*];
            out motorOutputs : MotorCommand[*];
        }
    }
    
    part def DisplayModule {
        attribute screenActive : Boolean;
        port dataConnection : DataBusPort;
        port powerIn : PowerPort;
        
        action showStatus {
            in statusMessage : String;
        }
        
        action loadProgram {
            out program : ProgramInstruction[*];
        }
    }
    
    action def NavigateAroundObstacle {
        in obstacleDistance : Distance;
        in currentSpeed : Velocity;
        out avoidanceCommand : MotorCommand;
    }
    
    action def FollowLineTrack {
        in linePosition : Real;
        out steeringCommand : MotorCommand;
    }
    
    action def ExecuteEducationalMission {
        in mission : MissionType;
        in studentSkillLevel : StudentLevel;
        out success : Boolean;
        
        first start;
        then action initializeSensors;
        then merge missionLoop;
        
        action missionLoop {
            action readEnvironment {
                action scanObstacles;
                action detectPath;
            }
            then action computeResponse;
            then action actuateMotors;
            then decide;
                if success then complete;
                else missionLoop;
        }
        
        action complete {
            action displayCompletion;
        }
        then done;
    }
    
    state def RobotOperationalStates {
        entry; then standby;
        
        state standby;
        state programmingMode;
        state executingMission {
            state sensingEnvironment;
            state computingActions;
            state movingRobot;
            
            transition sense_to_compute
                first sensingEnvironment then computingActions;
            
            transition compute_to_move
                first computingActions then movingRobot;
            
            transition move_to_sense
                first movingRobot then sensingEnvironment;
        }
        state chargingBattery;
        
        transition standby_to_programming
            first standby then programmingMode;
        
        transition programming_to_executing
            first programmingMode then executingMission;
        
        transition executing_to_standby
            first executingMission then standby;
        
        transition any_to_charging
            first standby then chargingBattery;
        
        transition charging_to_standby
            first chargingBattery then standby;
    }
    
    part def EducationalRobot {
        attribute robotIdentifier : String;
        attribute operationalMode : String;
        
        part battery : BatteryPack {
            attribute :>> capacity = 7200.0 [SI::J];
            attribute :>> chargeLevel = 100.0;
        }
        
        part mainController : Microcontroller {
            attribute :>> clockFrequency = 16.0e6 [SI::Hz];
            attribute :>> memorySize = 32.0e3;
        }
        
        part userDisplay : DisplayModule {
            attribute :>> screenActive = true;
        }
        
        part frontSensor : UltrasonicSensor {
            attribute :>> maxRange = 4.0 [SI::m];
            attribute :>> minRange = 0.02 [SI::m];
        }
        
        part leftSensor : UltrasonicSensor {
            attribute :>> maxRange = 2.0 [SI::m];
            attribute :>> minRange = 0.02 [SI::m];
        }
        
        part rightSensor : UltrasonicSensor {
            attribute :>> maxRange = 2.0 [SI::m];
            attribute :>> minRange = 0.02 [SI::m];
        }
        
        part lineSensor : LineFollowingSensor;
        
        part leftWheelAssembly : WheelAssembly {
            attribute :>> diameter = 0.065 [SI::m];
            part :>> motor {
                attribute :>> maxSpeed = 1.0 [SI::'m/s'];
            }
        }
        
        part rightWheelAssembly : WheelAssembly {
            attribute :>> diameter = 0.065 [SI::m];
            part :>> motor {
                attribute :>> maxSpeed = 1.0 [SI::'m/s'];
            }
        }
        
        connection batteryToPower : PowerPort connect
            battery.powerOutput to mainController.powerIn;
        
        connection powerToDisplay : PowerPort connect
            battery.powerOutput to userDisplay.powerIn;
        
        connection powerToFrontSensor : PowerPort connect
            battery.powerOutput to frontSensor.powerIn;
        
        connection powerToLeftSensor : PowerPort connect
            battery.powerOutput to leftSensor.powerIn;
        
        connection powerToRightSensor : PowerPort connect
            battery.powerOutput to rightSensor.powerIn;
        
        connection powerToLineSensor : PowerPort connect
            battery.powerOutput to lineSensor.powerIn;
        
        connection powerToLeftMotor : PowerPort connect
            battery.powerOutput to leftWheelAssembly.motor.powerIn;
        
        connection powerToRightMotor : PowerPort connect
            battery.powerOutput to rightWheelAssembly.motor.powerIn;
        
        perform action teachSTEM {
            doc /* 
                Primary Function: The educational robot provides an interactive 
                platform for students to learn programming, robotics, and 
                problem-solving through hands-on experimentation. Students program 
                the robot to complete missions such as navigating mazes, following 
                lines, avoiding obstacles, and executing custom behaviors, thereby 
                developing computational thinking and engineering skills.
            */
            
            first start;
            then action powerUp {
                action initializeSystems;
                then action runSelfTest;
                then action calibrateAllSensors;
            }
            then merge operationalCycle;
            
            action operationalCycle {
                action awaitStudentInput {
                    accept studentProgram : ProgramInstruction;
                }
                
                then action loadStudentCode {
                    out programData : ProgramInstruction[*];
                }
                
                then action validateCode {
                    in programCode : ProgramInstruction[*];
                    out isValidProgram : Boolean;
                }
                
                then decide;
                    if validateCode.isValidProgram then runMission;
                    else showError;
                
                action runMission {
                    action scanSurroundings {
                        action frontScan;
                        action leftScan;
                        action rightScan;
                        action pathScan;
                    }
                    
                    then action planMovement {
                        in programInput : ProgramInstruction[*];
                    }
                    
                    then action executeMovement {
                        action leftWheelAction;
                        action rightWheelAction;
                    }
                    
                    then action evaluateProgress {
                        out missionCompleted : Boolean;
                    }
                    
                    then decide;
                        if evaluateProgress.missionCompleted then celebrateSuccess;
                        else scanSurroundings;
                    
                    action celebrateSuccess {
                        action announceSuccess;
                    }
                }
                
                then operationalCycle;
                
                action showError {
                    action displayErrorMessage;
                }
                
                then operationalCycle;
            }
        }
    }
    
    requirement def LearningObjective {
        doc /* 
            The robot shall enable students to learn fundamental programming 
            concepts, robotics principles, and computational thinking through 
            practical, hands-on activities suitable for various educational levels.
        */
        
        require constraint multiLevelSupport {
            doc /* 
                Support programming interfaces for beginner, intermediate, 
                and advanced student skill levels.
            */
        }
    }
    
    requirement def SafetyStandard {
        doc /* 
            The robot shall operate safely in classroom environments with 
            students of all ages, preventing injury and property damage.
        */
    }
    
    requirement def UsabilityStandard {
        doc /* 
            The robot shall be intuitive to program and operate for students 
            with varying technical backgrounds and experience levels.
        */
    }
    
    requirement def ReliabilityStandard {
        doc /* 
            The robot shall operate continuously throughout typical classroom 
            sessions without hardware or software failures.
        */
    }
    
    requirement educationalRobotMissionRequirement {
        doc /* 
            The educational robotics system shall provide an engaging, safe, 
            and effective platform for teaching STEM concepts through 
            interactive programming and robotics activities.
        */
        
        subject robotSystem : EducationalRobot;
        
        assume constraint studentMotivation {
            doc /* 
                Students are engaged and motivated to learn through 
                interactive challenges and immediate feedback from the robot.
            */
        }
        
        require learningGoal : LearningObjective;
        require safetyCompliance : SafetyStandard;
        require userExperience : UsabilityStandard;
        require systemReliability : ReliabilityStandard;
    }
}
