package PoolCleanerModel {

    import ScalarValues::*;

    package Units {
        unit volt;
        unit ampere;
        unit watt;
        unit watt_hour;
        unit percent;
        unit liter_per_minute;
        unit radian_per_second;
        unit meter_per_second;
        unit gram_per_liter;
        unit degree_celsius;
        unit meter;
        unit gram;
        unit liter;
        unit pascal;
        unit radian;
        unit second;
        unit square_meter;
        unit hertz;

        value def Voltage :> Real { unit volt; }
        value def Current :> Real { unit ampere; }
        value def Power :> Real { unit watt; }
        value def Energy :> Real { unit watt_hour; }
        value def ChargeLevel :> Real { unit percent; }
        value def FlowRate :> Real { unit liter_per_minute; }
        value def AngularVelocity :> Real { unit radian_per_second; }
        value def LinearVelocity :> Real { unit meter_per_second; }
        value def DebrisConcentration :> Real { unit gram_per_liter; }
        value def Temperature :> Real { unit degree_celsius; }
        value def Distance :> Real { unit meter; }
        value def Mass :> Real { unit gram; }
        value def Volume :> Real { unit liter; }
        value def Pressure :> Real { unit pascal; }
        value def Angle :> Real { unit radian; }
        value def Duration :> Real { unit second; }
        value def Area :> Real { unit square_meter; }
        value def Frequency :> Real { unit hertz; }
    }

    package Items {
        import Units::*;

        item def ElectricalPower {
            attribute voltage : Voltage;
            attribute current : Current;
        }

        item def Debris {
            attribute particleSize : Distance;
            attribute mass : Mass;
        }

        item def PoolWater {
            attribute temperature : Temperature;
            attribute debrisConcentration : DebrisConcentration;
        }

        item def CleanWater;

        item def ControlCommand {
            attribute commandType : String;
            attribute parameter : Real;
        }

        item def SensorReading {
            attribute distance : Distance;
            attribute obstacleDetected : Boolean;
        }
    }

    package Interfaces {
        import Items::*;

        interface def PowerInterface {
            flow power : ElectricalPower;
        }

        interface def HydraulicInterface {
            in dirtyWater : PoolWater;
            out cleanWater : CleanWater;
        }

        interface def SensorInterface {
            out reading : SensorReading;
        }

        interface def ControlInterface {
            in command : ControlCommand;
        }
    }

    package Components {
        import Units::*;
        import Items::*;
        import Interfaces::*;

        part def BatterySystem {
            attribute capacity : Energy = 100 [watt_hour];
            attribute currentCharge : ChargeLevel = 100 [percent];
            attribute nominalVoltage : Voltage = 12 [volt];
            attribute lowThreshold : ChargeLevel = 20 [percent];
            attribute isLow : Boolean;

            port powerOut : PowerInterface;
            port rechargeIn : PowerInterface;

            action def DischargeAction {
                in rate : Power;
            }

            action def RechargeAction {
                in rate : Power;
            }

            action def SignalLowBatteryAction;

            state def BatteryStates {
                entry; then Charged;
                state Charged {
                    do discharge;
                }
                state Low {
                    do signalLowBattery;
                }
                state Charging {
                    do recharge;
                }
                transition from Charged to Low
                    when currentCharge < lowThreshold;
                transition from Low to Charging
                    when docked;
                transition from Charging to Charged
                    when currentCharge >= 100 [percent];
            }

            exhibit BatteryStates;
        }

        part def Wheel {
            attribute radius : Distance = 0.05 [meter];
            attribute speed : AngularVelocity;
        }

        part def MotorDrive {
            port powerIn : PowerInterface;
            port controlIn : ControlInterface;

            part leftWheel : Wheel;
            part rightWheel : Wheel;

            attribute linearVelocity : LinearVelocity;
            attribute heading : Angle;
            attribute isMoving : Boolean;

            action def DriveAction {
                in leftSpeed : AngularVelocity;
                in rightSpeed : AngularVelocity;
            }

            action def StopAction;

            action def TurnAction {
                in turnAngle : Angle;
            }
        }

        part def BrushAssembly {
            port powerIn : PowerInterface;
            port controlIn : ControlInterface;

            attribute brushSpeed : AngularVelocity;
            attribute isRotating : Boolean;
            attribute maxSpeed : AngularVelocity = 5 [radian_per_second];

            action def RotateAction {
                in speed : AngularVelocity;
            }

            action def StopBrushAction;
        }

        part def HydraulicPump {
            port powerIn : PowerInterface;
            port controlIn : ControlInterface;
            port waterIntake : HydraulicInterface;
            port waterOutput : HydraulicInterface;

            attribute flowRate : FlowRate;
            attribute suctionPressure : Pressure;
            attribute isRunning : Boolean;
            attribute maxFlowRate : FlowRate = 50 [liter_per_minute];

            action def PumpAction {
                in rate : FlowRate;
            }

            action def StopPumpAction;
        }

        part def DebrisFilter {
            attribute capacity : Mass = 500 [gram];
            attribute currentLoad : Mass;
            attribute isFull : Boolean;
            attribute filtrationEfficiency : Real = 0.95;

            port dirtyWaterIn : HydraulicInterface;
            port cleanWaterOut : HydraulicInterface;

            action def FilterAction {
                in water : PoolWater;
                out cleanWater : CleanWater;
                out debris : Debris;
            }

            action def SignalFilterFullAction;

            state def FilterStates {
                entry; then Active;
                state Active {
                    do filterWater;
                }
                state Full {
                    do signalFilterFull;
                }
                transition from Active to Full
                    when currentLoad >= capacity;
            }

            exhibit FilterStates;
        }

        part def ProximitySensor {
            port dataOut : SensorInterface;

            attribute range : Distance = 0.5 [meter];
            attribute detectedDistance : Distance;
            attribute obstacleDetected : Boolean;
            attribute scanRate : Frequency = 10 [hertz];

            action def ScanAction {
                out reading : SensorReading;
            }
        }

        part def NavigationController {
            port powerIn : PowerInterface;
            port sensorDataIn : SensorInterface;
            port motorControlOut : ControlInterface;
            port brushControlOut : ControlInterface;
            port pumpControlOut : ControlInterface;

            attribute cleaningPath : String;
            attribute areaCovered : Area;
            attribute targetX : Distance;
            attribute targetY : Distance;
            attribute currentX : Distance;
            attribute currentY : Distance;
            attribute batteryLowSignal : Boolean;
            attribute filterFullSignal : Boolean;

            action def PlanPathAction {
                out path : String;
            }

            action def TrackCoverageAction {
                in x : Distance;
                in y : Distance;
            }

            action def AvoidObstacleAction {
                in reading : SensorReading;
            }

            action def NavigateToDockAction;

            state def NavigationStates {
                entry; then Cleaning;
                state Cleaning {
                    do planAndExecute;
                }
                state Avoiding {
                    do avoidObstacle;
                }
                state ReturningToDock {
                    do navigateToDock;
                }
                transition from Cleaning to Avoiding
                    when obstacleDetected;
                transition from Avoiding to Cleaning
                    when not obstacleDetected;
                transition from Cleaning to ReturningToDock
                    when batteryLowSignal or filterFullSignal;
                transition from Avoiding to ReturningToDock
                    when batteryLowSignal or filterFullSignal;
            }

            exhibit NavigationStates;
        }

        part def DockingStation {
            port rechargePort : PowerInterface;

            attribute isDocked : Boolean;
            attribute chargeRate : Power = 25 [watt];

            action def RechargeRobotAction {
                out power : ElectricalPower;
            }

            action def CleanFilterAction;
        }
    }

    package System {
        import Components::*;
        import Units::*;
        import Items::*;
        import Interfaces::*;

        part def PoolCleaner {
            part battery : BatterySystem;
            part motorDrive : MotorDrive;
            part brushAssembly : BrushAssembly;
            part hydraulicPump : HydraulicPump;
            part debrisFilter : DebrisFilter;
            part frontSensor : ProximitySensor;
            part leftSensor : ProximitySensor;
            part rightSensor : ProximitySensor;
            part rearSensor : ProximitySensor;
            part navigationController : NavigationController;

            port dockPort : PowerInterface;

            attribute startCommand : Boolean;
            attribute docked : Boolean;
            attribute batteryLow : Boolean;
            attribute filterFull : Boolean;
            attribute batteryCharged : Boolean;
            attribute filterCleaned : Boolean;

            connection powerToMotor connect battery.powerOut to motorDrive.powerIn;
            connection powerToBrush connect battery.powerOut to brushAssembly.powerIn;
            connection powerToPump connect battery.powerOut to hydraulicPump.powerIn;
            connection powerToNav connect battery.powerOut to navigationController.powerIn;

            connection rechargeLink connect dockPort to battery.rechargeIn;

            connection hydraulicFlow connect hydraulicPump.waterOutput to debrisFilter.dirtyWaterIn;

            connection frontSensorLink connect frontSensor.dataOut to navigationController.sensorDataIn;
            connection leftSensorLink connect leftSensor.dataOut to navigationController.sensorDataIn;
            connection rightSensorLink connect rightSensor.dataOut to navigationController.sensorDataIn;
            connection rearSensorLink connect rearSensor.dataOut to navigationController.sensorDataIn;

            connection motorControlLink connect navigationController.motorControlOut to motorDrive.controlIn;
            connection brushControlLink connect navigationController.brushControlOut to brushAssembly.controlIn;
            connection pumpControlLink connect navigationController.pumpControlOut to hydraulicPump.controlIn;

            action def CoordinateCleaningAction {
                in brushCommand : ControlCommand;
                in pumpCommand : ControlCommand;
                in motorCommand : ControlCommand;
            }

            action def ReturnToDockAction;
            action def RechargeAndMaintainAction;
            action def WaitAction;

            state def OperationalStates {
                entry; then Idle;
                state Idle {
                    do wait;
                }
                state Cleaning {
                    do coordinateCleaning;
                }
                state ReturningToDock {
                    do returnToDock;
                }
                state Docked {
                    do rechargeAndMaintain;
                }
                transition from Idle to Cleaning
                    when startCommand;
                transition from Cleaning to ReturningToDock
                    when batteryLow or filterFull;
                transition from ReturningToDock to Docked
                    when docked;
                transition from Docked to Idle
                    when batteryCharged and filterCleaned;
            }

            exhibit OperationalStates;
        }

        part def PoolCleaningSystem {
            part cleaner : PoolCleaner;
            part dock : DockingStation;

            connection dockConnection connect dock.rechargePort to cleaner.dockPort;
        }
    }

    package Requirements {
        import System::*;
        import Components::*;
        import Units::*;

        requirement def AutonomousCleaningRequirement {
            doc /* The pool cleaner shall autonomously clean swimming pool floors and walls without human intervention. */;
            subject cleaner : PoolCleaner;
        }

        requirement def PowerManagementRequirement {
            doc /* The battery system shall provide electrical power to all components and be rechargeable at a docking station. */;
            subject battery : BatterySystem;
            constraint { battery.capacity > 50 [watt_hour] }
        }

        requirement def LowBatteryReturnRequirement {
            doc /* The cleaner shall stop cleaning and return to the docking station when battery charge falls below 20 percent. */;
            subject cleaner : PoolCleaner;
            constraint { cleaner.battery.currentCharge < 20 [percent] }
        }

        requirement def ScrubbingRequirement {
            doc /* The brush assembly shall rotate bristles to scrub pool surfaces and dislodge debris. */;
            subject brush : BrushAssembly;
            constraint { brush.maxSpeed > 2 [radian_per_second] }
        }

        requirement def SuctionRequirement {
            doc /* The hydraulic pump shall create suction to pull dirty water through an intake port. */;
            subject pump : HydraulicPump;
            constraint { pump.maxFlowRate > 20 [liter_per_minute] }
        }

        requirement def FiltrationRequirement {
            doc /* The debris filter shall capture debris particles and return clean filtered water to the pool. */;
            subject filter : DebrisFilter;
            constraint { filter.filtrationEfficiency > 0.9 }
        }

        requirement def FilterFullReturnRequirement {
            doc /* The cleaner shall stop cleaning and return to the docking station when the debris filter is full. */;
            subject cleaner : PoolCleaner;
            constraint { cleaner.debrisFilter.currentLoad >= cleaner.debrisFilter.capacity }
        }

        requirement def ObstacleAvoidanceRequirement {
            doc /* The cleaner shall detect obstacles and walls using proximity sensors and avoid collisions. */;
            subject cleaner : PoolCleaner;
            constraint { cleaner.frontSensor.range > 0.2 [meter] }
        }

        requirement def PathPlanningRequirement {
            doc /* The navigation controller shall calculate an efficient cleaning path and track areas already cleaned. */;
            subject controller : NavigationController;
        }

        requirement def PoolCleanerRequirementSet {
            subject cleaner : PoolCleaner;

            requirement autonomousCleaning : AutonomousCleaningRequirement;
            requirement powerManagement : PowerManagementRequirement;
            requirement lowBatteryReturn : LowBatteryReturnRequirement;
            requirement scrubbing : ScrubbingRequirement;
            requirement suction : SuctionRequirement;
            requirement filtration : FiltrationRequirement;
            requirement filterFullReturn : FilterFullReturnRequirement;
            requirement obstacleAvoidance : ObstacleAvoidanceRequirement;
            requirement pathPlanning : PathPlanningRequirement;
        }

        satisfy AutonomousCleaningRequirement by PoolCleaningSystem::cleaner;
        satisfy PowerManagementRequirement by PoolCleaner::battery;
        satisfy LowBatteryReturnRequirement by PoolCleaningSystem::cleaner;
        satisfy ScrubbingRequirement by PoolCleaner::brushAssembly;
        satisfy SuctionRequirement by PoolCleaner::hydraulicPump;
        satisfy FiltrationRequirement by PoolCleaner::debrisFilter;
        satisfy FilterFullReturnRequirement by PoolCleaningSystem::cleaner;
        satisfy ObstacleAvoidanceRequirement by PoolCleaningSystem::cleaner;
        satisfy PathPlanningRequirement by PoolCleaner::navigationController;
    }
}
