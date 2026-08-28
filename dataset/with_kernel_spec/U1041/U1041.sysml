package EducationalRobotModel {
    public import ISQ::*;
    public import ScalarValues::*;
    
    package Definitions {
        public import ItemDefinitions::*;
        public import PortDefinitions::*;
        public import SignalDefinitions::*;
        public import InterfaceDefinitions::*;
        public import PartDefinitions::*;
        public import ActionDefinitions::*;
        public import StateDefinitions::*;
        public import RequirementDefinitions::*;
        
        package ItemDefinitions {
            item def ElectricalPower;
            item def SensorData;
            item def ObstacleInfo :> SensorData;
            item def LineInfo :> SensorData;
            item def MotorCommand;
            item def ProgramCode;
            item def StatusMessage;
        }
        
        package PortDefinitions {
            port def PowerPort;
            port def MotorControlPort;
            port def SensorDataPort;
            port def ProgrammingPort;
            port def DisplayPort;
        }
        
        package SignalDefinitions {
            item def StartMission;
            item def StopMission;
            item def EnterProgrammingMode;
            item def ExitProgrammingMode;
            item def ConnectCharger;
            item def DisconnectCharger;
            item def ProgramLoaded;
        }
        
        package InterfaceDefinitions {
            interface def PowerInterface {
                end supplier : PowerPort;
                end consumer : ~PowerPort;
            }
            interface def MotorInterface {
                end controller : MotorControlPort;
                end motor : ~MotorControlPort;
            }
            interface def SensorInterface {
                end sensor : SensorDataPort;
                end controller : ~SensorDataPort;
            }
            interface def ProgrammingInterface {
                end host : ProgrammingPort;
                end robot : ~ProgrammingPort;
            }
            interface def DisplayInterface {
                end controller : DisplayPort;
                end display : ~DisplayPort;
            }
        }
        
        package ActionDefinitions {
            action def ExecuteMission {
                action senseEnvironment;
                action processData;
                action actuateMotors;
                
                first senseEnvironment then processData;
                first processData then actuateMotors;
                first actuateMotors then senseEnvironment;
            }
        }
        
        package StateDefinitions {
            state def RobotStates {
                entry action initial;
                state standby;
                state programming;
                state activeMission;
                state charging;
                
                transition initial then standby;
                transition standby_to_programming
                    first standby
                    accept EnterProgrammingMode
                    then programming;
                transition programming_to_standby
                    first programming
                    accept ProgramLoaded
                    then standby;
                transition standby_to_activeMission
                    first standby
                    accept StartMission
                    then activeMission;
                transition activeMission_to_standby
                    first activeMission
                    accept StopMission
                    then standby;
                transition standby_to_charging
                    first standby
                    accept ConnectCharger
                    then charging;
                transition charging_to_standby
                    first charging
                    accept DisconnectCharger
                    then standby;
            }
        }
        
        package PartDefinitions {
            part def EducationalRobot {
                attribute mass :> ISQ::mass;
                attribute velocity :> ISQ::speed;
                
                port chargingPort : PowerPort;
                port usbPort : ProgrammingPort;
                
                part microcontroller : Microcontroller;
                part batteryPack : BatteryPack;
                part displayModule : DisplayModule;
                
                part leftWheelAssembly : WheelAssembly;
                part rightWheelAssembly : WheelAssembly;
                
                part forwardUltrasonicSensor : UltrasonicSensor;
                part leftUltrasonicSensor : UltrasonicSensor;
                part rightUltrasonicSensor : UltrasonicSensor;
                part lineFollowingSensor : LineFollowingSensor;
                
                perform action executeMission : ExecuteMission;
                exhibit state robotStates : RobotStates;
            }
            
            part def Microcontroller {
                port powerIn : ~PowerPort;
                port leftMotorOut : MotorControlPort;
                port rightMotorOut : MotorControlPort;
                port forwardSensorIn : ~SensorDataPort;
                port leftSensorIn : ~SensorDataPort;
                port rightSensorIn : ~SensorDataPort;
                port lineSensorIn : ~SensorDataPort;
                port displayOut : DisplayPort;
                port programmingIn : ~ProgrammingPort;
            }
            
            part def BatteryPack {
                attribute capacity :> ISQ::energy;
                attribute chargeLevel : ScalarValues::Real;
                port powerOut : PowerPort;
                port chargingIn : ~PowerPort;
            }
            
            part def DisplayModule {
                port powerIn : ~PowerPort;
                port displayIn : ~DisplayPort;
            }
            
            part def WheelAssembly {
                part motor : DCMotor;
                part wheel : Wheel;
            }
            
            part def DCMotor {
                port powerIn : ~PowerPort;
                port controlIn : ~MotorControlPort;
            }
            
            part def Wheel {
                attribute diameter :> ISQ::length;
            }
            
            part def UltrasonicSensor {
                attribute facingDirection : ScalarValues::String;
                port powerIn : ~PowerPort;
                port dataOut : SensorDataPort;
            }
            
            part def LineFollowingSensor {
                port powerIn : ~PowerPort;
                port dataOut : SensorDataPort;
            }
        }
        
        package RequirementDefinitions {
            requirement def EducationalRobotRequirements {
                requirement provideSTEMEducation {
                    subject robot : EducationalRobot;
                    doc /* The robot shall serve as a hands-on platform for teaching STEM concepts. */
                }
                requirement ensureSafety {
                    subject robot : EducationalRobot;
                    doc /* The robot shall be safe for use by students of various skill levels. */
                }
                requirement supportDifferentialDrive {
                    subject robot : EducationalRobot;
                    doc /* The robot shall move using a two-wheeled differential drive system. */
                }
                requirement detectObstacles {
                    subject robot : EducationalRobot;
                    doc /* The robot shall detect obstacles using three ultrasonic sensors. */
                }
                requirement trackLine {
                    subject robot : EducationalRobot;
                    doc /* The robot shall track a line on the floor using a line-following sensor. */
                }
                requirement displayStatus {
                    subject robot : EducationalRobot;
                    doc /* The robot shall provide status updates via a display module. */
                }
            }
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part robot : EducationalRobot {
            connect batteryPack.powerOut to microcontroller.powerIn;
            connect batteryPack.powerOut to displayModule.powerIn;
            connect batteryPack.powerOut to forwardUltrasonicSensor.powerIn;
            connect batteryPack.powerOut to leftUltrasonicSensor.powerIn;
            connect batteryPack.powerOut to rightUltrasonicSensor.powerIn;
            connect batteryPack.powerOut to lineFollowingSensor.powerIn;
            connect batteryPack.powerOut to leftWheelAssembly.motor.powerIn;
            connect batteryPack.powerOut to rightWheelAssembly.motor.powerIn;
            
            connect microcontroller.leftMotorOut to leftWheelAssembly.motor.controlIn;
            connect microcontroller.rightMotorOut to rightWheelAssembly.motor.controlIn;
            
            connect forwardUltrasonicSensor.dataOut to microcontroller.forwardSensorIn;
            connect leftUltrasonicSensor.dataOut to microcontroller.leftSensorIn;
            connect rightUltrasonicSensor.dataOut to microcontroller.rightSensorIn;
            connect lineFollowingSensor.dataOut to microcontroller.lineSensorIn;
            
            connect microcontroller.displayOut to displayModule.displayIn;
            connect usbPort to microcontroller.programmingIn;
            connect chargingPort to batteryPack.chargingIn;
        }
    }
}
