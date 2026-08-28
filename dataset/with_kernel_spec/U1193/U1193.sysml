package RoboticVacuumSystem {
    public import ISQ::*;
    public import ScalarValues::*;
    public import Definitions::*;
    
    package Definitions {
        public import PartDefinitions::*;
        public import PortDefinitions::*;
        public import ItemDefinitions::*;
        public import SignalDefinitions::*;
        public import InterfaceDefinitions::*;
        public import ActionDefinitions::*;
        public import StateDefinitions::*;
        public import RequirementDefinitions::*;
        public import AttributeDefinitions::*;
        
        package AttributeDefinitions {
            attribute def BatteryLevel :> ScalarValues::Real {
                doc /* Battery state of charge as a percentage 0..100 */
            }
            attribute def BatteryThreshold :> ScalarValues::Real {
                doc /* Threshold below which the robot returns to dock */
            }
            attribute def DirtLevel :> ScalarValues::Integer {
                doc /* Detected dirt intensity level */
            }
            attribute def DistanceValue :> ISQ::LengthValue;
            attribute def SpeedValue :> ISQ::SpeedValue;
            attribute def RotationalSpeed :> ISQ::AngularVelocityValue;
        }
        
        package SignalDefinitions {
            attribute def ActivateSignal;
            attribute def DeactivateSignal;
            attribute def BatteryLowSignal;
            attribute def BatteryFullSignal;
            attribute def DockReachedSignal;
            attribute def DirtyAreaDetectedSignal {
                attribute dirtLevel : DirtLevel;
            }
            attribute def SpotCleanCompleteSignal;
            attribute def ObstacleDetectedSignal {
                attribute distance : DistanceValue;
            }
            attribute def CliffDetectedSignal;
            attribute def BumperContactSignal;
            attribute def CleaningCompleteSignal;
        }
        
        package ItemDefinitions {
            item def Debris;
            item def Dust;
            item def AirFlow;
        }
        
        package PortDefinitions {
            port def PowerPort {
                out attribute voltage : ISQ::VoltageValue;
                in attribute current : ISQ::CurrentValue;
            }
            port def DockingPort {
                in attribute dockSignal : DockReachedSignal;
                out attribute chargeRequest : BatteryLowSignal;
            }
            port def SensorDataPort {
                out attribute distance : DistanceValue;
                out attribute contactDetected : Boolean;
                out attribute cliffDetected : Boolean;
                out attribute dirtLevel : DirtLevel;
            }
            port def MotorCmdPort {
                out attribute leftWheelSpeed : SpeedValue;
                out attribute rightWheelSpeed : SpeedValue;
                out attribute brushSpeed : RotationalSpeed;
            }
            port def CleaningCmdPort {
                out attribute fanPower : ISQ::PowerValue;
                out attribute mainBrushOn : Boolean;
                out attribute sideBrushOn : Boolean;
            }
        }
        
        package InterfaceDefinitions {
            interface def RobotToDockInterface {
                end robotPort : DockingPort;
                end dockPort : ~DockingPort;
            }
            interface def PowerInterface {
                end sourcePort : PowerPort;
                end sinkPort : ~PowerPort;
            }
        }
        
        package PartDefinitions {
            part def LithiumBattery {
                attribute stateOfCharge : BatteryLevel;
                attribute capacity : ISQ::EnergyValue;
                attribute lowThreshold : BatteryThreshold = 20;
                port powerOut : PowerPort;
                perform action discharge;
                perform action charge;
            }
            
            part def SideBrush {
                attribute radius : ISQ::LengthValue;
                attribute speed : RotationalSpeed;
                port cmdIn : ~CleaningCmdPort;
                perform action sweep {
                    out item debris : Debris;
                }
            }
            
            part def MainBrush {
                attribute width : ISQ::LengthValue;
                attribute speed : RotationalSpeed;
                port cmdIn : ~CleaningCmdPort;
                perform action agitate {
                    out item dust : Dust;
                }
            }
            
            part def SuctionFan {
                attribute power : ISQ::PowerValue;
                port cmdIn : ~CleaningCmdPort;
                perform action suction {
                    in item dust : Dust;
                    in item debris : Debris;
                }
            }
            
            part def DustContainer {
                attribute capacity : ISQ::VolumeValue;
                attribute fillLevel : ISQ::VolumeValue;
                attribute filterEfficiency : ScalarValues::Real;
                perform action collectDebris {
                    in item dust : Dust;
                    in item debris : Debris;
                }
            }
            
            part def DriveWheel {
                attribute diameter : ISQ::LengthValue;
                attribute speed : SpeedValue;
                port cmdIn : ~MotorCmdPort;
                perform action rotate;
            }
            
            part def IRSensor {
                attribute range : ISQ::LengthValue;
                attribute position : String;
                port dataOut : SensorDataPort;
                perform action detectObstacle {
                    out attribute distance : DistanceValue;
                }
            }
            
            part def BumperSensor {
                attribute contactDetected : Boolean;
                port dataOut : SensorDataPort;
                perform action detectContact {
                    out attribute contact : Boolean;
                }
            }
            
            part def CliffSensor {
                attribute threshold : ISQ::LengthValue;
                port dataOut : SensorDataPort;
                perform action detectCliff {
                    out attribute cliff : Boolean;
                }
            }
            
            part def DirtDetectionSensor {
                attribute sensitivity : DirtLevel;
                port dataOut : SensorDataPort;
                perform action detectDirt {
                    out attribute level : DirtLevel;
                }
            }
            
            part def NavigationController {
                port sensorInput : ~SensorDataPort;
                port motorOutput : MotorCmdPort;
                port cleaningOutput : CleaningCmdPort;
                port powerIn : ~PowerPort;
                perform action planPath;
                perform action controlMotors;
                perform action manageCleaning;
                perform action navigateToDock;
            }
            
            part def ChargingDock {
                attribute outputVoltage : ISQ::VoltageValue;
                attribute outputCurrent : ISQ::CurrentValue;
                port chargePort : PowerPort;
                port dockingPort : ~DockingPort;
                perform action provideCharge {
                    out attribute voltage : ISQ::VoltageValue;
                    out attribute current : ISQ::CurrentValue;
                }
                perform action emitDockingSignal;
            }
            
            part def CleaningRobot {
                attribute diameter : ISQ::LengthValue;
                attribute height : ISQ::LengthValue;
                attribute mass : ISQ::MassValue;
                
                part battery : LithiumBattery {
                    redefines stateOfCharge = 100;
                }
                part leftSideBrush : SideBrush;
                part rightSideBrush : SideBrush;
                part mainBrush : MainBrush;
                part suctionFan : SuctionFan;
                part dustContainer : DustContainer;
                part leftDriveWheel : DriveWheel;
                part rightDriveWheel : DriveWheel;
                
                part frontIRSensor : IRSensor {
                    redefines position = "front";
                }
                part leftIRSensor : IRSensor {
                    redefines position = "left";
                }
                part rightIRSensor : IRSensor {
                    redefines position = "right";
                }
                part bumperSensor : BumperSensor;
                part leftCliffSensor : CliffSensor;
                part rightCliffSensor : CliffSensor;
                part dirtSensor : DirtDetectionSensor;
                
                part navController : NavigationController;
                
                port dockingPort : DockingPort;
                port powerIn : ~PowerPort;
                
                connection sensorDataConn1 connect frontIRSensor.dataOut to navController.sensorInput;
                connection sensorDataConn2 connect leftIRSensor.dataOut to navController.sensorInput;
                connection sensorDataConn3 connect rightIRSensor.dataOut to navController.sensorInput;
                connection sensorDataConn4 connect bumperSensor.dataOut to navController.sensorInput;
                connection sensorDataConn5 connect leftCliffSensor.dataOut to navController.sensorInput;
                connection sensorDataConn6 connect rightCliffSensor.dataOut to navController.sensorInput;
                connection sensorDataConn7 connect dirtSensor.dataOut to navController.sensorInput;
                
                connection motorCmdConn1 connect navController.motorOutput to leftDriveWheel.cmdIn;
                connection motorCmdConn2 connect navController.motorOutput to rightDriveWheel.cmdIn;
                
                connection cleaningCmdConn1 connect navController.cleaningOutput to suctionFan.cmdIn;
                connection cleaningCmdConn2 connect navController.cleaningOutput to mainBrush.cmdIn;
                connection cleaningCmdConn3 connect navController.cleaningOutput to leftSideBrush.cmdIn;
                connection cleaningCmdConn4 connect navController.cleaningOutput to rightSideBrush.cmdIn;
                
                connection powerConn connect battery.powerOut to navController.powerIn;
                
                exhibit state robotStates {
                    entry; then idle;
                    
                    state idle {
                        doc /* Robot is at dock, fully charged, waiting for activation. */
                        entry;
                    }
                    
                    transition idle_to_activeCleaning
                        first idle
                        accept ActivateSignal
                        then activeCleaning;
                    
                    state activeCleaning {
                        doc /* Robot systematically navigates and cleans the room. */
                        entry action startCleaningMotors;
                        do action navigateAndClean {
                            in sensorData : SensorDataPort;
                            out motorCmds : MotorCmdPort;
                        }
                        exit action stopCleaningMotors;
                    }
                    
                    transition activeCleaning_to_spotCleaning
                        first activeCleaning
                        accept dirtyArea : DirtyAreaDetectedSignal
                        if dirtyArea.dirtLevel > 50
                        then spotCleaning;
                    
                    state spotCleaning {
                        doc /* Robot focuses on a heavily soiled area with intensive cleaning. */
                        entry action intensifyCleaning;
                        do action focusClean;
                    }
                    
                    transition spotCleaning_to_activeCleaning
                        first spotCleaning
                        accept SpotCleanCompleteSignal
                        then activeCleaning;
                    
                    transition activeCleaning_to_returningToDock
                        first activeCleaning
                        accept BatteryLowSignal
                        if battery.stateOfCharge <= battery.lowThreshold
                        do action stopCleaningMotors
                        then returningToDock;
                    
                    transition spotCleaning_to_returningToDock
                        first spotCleaning
                        accept BatteryLowSignal
                        if battery.stateOfCharge <= battery.lowThreshold
                        then returningToDock;
                    
                    state returningToDock {
                        doc /* Robot navigates back to the charging dock. */
                        entry action planReturnPath;
                        do action navigateToDock;
                    }
                    
                    transition returningToDock_to_charging
                        first returningToDock
                        accept DockReachedSignal
                        then charging;
                    
                    state charging {
                        doc /* Robot is docked and recharging its battery. */
                        entry action startCharging;
                        do action chargeBattery {
                            in attribute voltage : ISQ::VoltageValue;
                            in attribute current : ISQ::CurrentValue;
                        }
                    }
                    
                    transition charging_to_idle
                        first charging
                        accept BatteryFullSignal
                        if battery.stateOfCharge >= 100
                        then idle;
                    
                    transition activeCleaning_to_idle
                        first activeCleaning
                        accept CleaningCompleteSignal
                        then idle;
                    
                    transition activeCleaning_to_idle_deactivate
                        first activeCleaning
                        accept DeactivateSignal
                        then idle;
                }
            }
        }
        
        package ActionDefinitions {
            action def StartCleaningMotors {
                out attribute sideBrushOn : Boolean = true;
                out attribute mainBrushOn : Boolean = true;
                out attribute fanPower : ISQ::PowerValue;
            }
            action def StopCleaningMotors {
                out attribute sideBrushOn : Boolean = false;
                out attribute mainBrushOn : Boolean = false;
                out attribute fanPower : ISQ::PowerValue = 0 [W];
            }
            action def IntensifyCleaning {
                doc /* Increase suction power and brush speed for spot cleaning. */
                out attribute fanPower : ISQ::PowerValue;
                out attribute brushSpeed : RotationalSpeed;
            }
            action def NavigateToDock {
                doc /* Use sensor data to navigate back to the charging dock. */
                in sensorData : SensorDataPort;
                out motorCmds : MotorCmdPort;
            }
            action def ChargeBattery {
                in attribute voltage : ISQ::VoltageValue;
                in attribute current : ISQ::CurrentValue;
            }
        }
        
        package StateDefinitions {
            state def RobotOperationalStates {
                entry; then idle;
                state idle;
                state activeCleaning;
                state spotCleaning;
                state returningToDock;
                state charging;
            }
        }
        
        package RequirementDefinitions {
            requirement def CleaningRequirement {
                doc /* The robot shall clean floor surfaces autonomously. */
                subject robot : CleaningRobot;
            }
            
            requirement def SafetyRequirement {
                doc /* The robot shall not fall down stairs or ledges. */
                subject robot : CleaningRobot;
            }
            
            requirement def AutoRechargeRequirement {
                doc /* The robot shall autonomously return to the charging dock when battery is low. */
                subject robot : CleaningRobot;
                subject dock : ChargingDock;
            }
            
            requirement def ObstacleAvoidanceRequirement {
                doc /* The robot shall detect and avoid obstacles using IR and bumper sensors. */
                subject robot : CleaningRobot;
            }
            
            requirement def DirtDetectionRequirement {
                doc /* The robot shall detect heavily soiled areas and perform spot cleaning. */
                subject robot : CleaningRobot;
            }
        }
    }
    
    package Usages {
        part RoboticVacuumSystem {
            part robot : CleaningRobot;
            part dock : ChargingDock;
            
            connection robotDockInterface connect robot.dockingPort to dock.dockingPort;
            connection powerInterface connect dock.chargePort to robot.powerIn;
            
            satisfy CleaningRequirement by robot;
            satisfy SafetyRequirement by robot;
            satisfy AutoRechargeRequirement by robot, dock;
            satisfy ObstacleAvoidanceRequirement by robot;
            satisfy DirtDetectionRequirement by robot;
        }
    }
}
