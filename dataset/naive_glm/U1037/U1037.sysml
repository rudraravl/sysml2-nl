package CleaningRobotSystem {

    package Units {
        unit m;
        unit s;
        unit kg;
        unit L;
        unit W;
        unit Wh;
        unit V;
        unit A;
        unit Pa;
        unit rpm;
        unit percent;
        unit sqm;
        unit m_per_s;
    }

    package ValueTypes {
        value type ChargeLevel :> Real {
            unit percent;
            constraint { self >= 0 and self <= 100; }
        }
        value type PowerValue :> Real { unit W; }
        value type EnergyValue :> Real { unit Wh; }
        value type VoltageValue :> Real { unit V; }
        value type CurrentValue :> Real { unit A; }
        value type DistanceValue :> Real { unit m; }
        value type SpeedValue :> Real { unit m_per_s; }
        value type AreaValue :> Real { unit sqm; }
        value type TimeValue :> Real { unit s; }
        value type SuctionForceValue :> Real { unit Pa; }
        value type BrushRateValue :> Real { unit rpm; }
        value type WeightValue :> Real { unit kg; }
        value type VolumeValue :> Real { unit L; }
        value type AngleValue :> Real;
    }

    package Enumerations {
        enum FloorType { hardwood; tile; carpet; }
        enum CleaningTaskType { vacuum; mop; dust; }
        enum RobotOperationalState { standby; navigating; performing; returning; charging; }
        enum DockingStatus { undocked; docked; }
        enum CleaningToolState { inactive; active; }
        enum PowerSubstate { discharging; lowWarning; recharging; full; }
        enum NavSubstate { idle; scanning; planning; moving; homing; }
    }

    package Items {
        item def TaskCommand {
            attribute taskType : CleaningTaskType;
            attribute targetArea : AreaValue;
            attribute floorType : FloorType;
            attribute startTime : TimeValue;
        }
        item def StatusUpdate {
            attribute state : RobotOperationalState;
            attribute batteryLevel : ChargeLevel;
            attribute areaCleaned : AreaValue;
            attribute timeElapsed : TimeValue;
        }
        item def ObstacleData {
            attribute distance : DistanceValue;
            attribute bearing : AngleValue;
            attribute detected : Boolean;
        }
        item def PositionData {
            attribute x : DistanceValue;
            attribute y : DistanceValue;
            attribute heading : AngleValue;
        }
        item def PathPlan {
            attribute waypoints : PositionData[*];
            attribute estimatedDistance : DistanceValue;
            attribute estimatedTime : TimeValue;
        }
        item def CleaningResult {
            attribute areaCleaned : AreaValue;
            attribute taskType : CleaningTaskType;
            attribute successful : Boolean;
            attribute duration : TimeValue;
        }
        item def PowerFlow {
            attribute voltage : VoltageValue;
            attribute current : CurrentValue;
            attribute power : PowerValue;
            attribute charging : Boolean;
        }
        item def BatteryStatus {
            attribute level : ChargeLevel;
            attribute voltage : VoltageValue;
            attribute charging : Boolean;
            attribute remainingRuntime : TimeValue;
        }
    }

    package Ports {
        port def CommandPort {
            in command : TaskCommand;
            out status : StatusUpdate;
        }
        port def NavPort {
            in pathPlan : PathPlan;
            in homeCommand : Boolean;
            out position : PositionData;
            out obstacles : ObstacleData;
            out arrived : Boolean;
        }
        port def CleanPort {
            in taskType : CleaningTaskType;
            in floorType : FloorType;
            in start : Boolean;
            in stop : Boolean;
            out result : CleaningResult;
        }
        port def PowerPort {
            out status : BatteryStatus;
            in requestCharge : Boolean;
            out chargeComplete : Boolean;
        }
        port def DockPort {
            in power : PowerFlow;
            out docked : Boolean;
        }
        port def SensorPort {
            out obstacles : ObstacleData;
            out position : PositionData;
        }
        port def MotorPort {
            in velocity : SpeedValue;
            in heading : AngleValue;
        }
    }

    package Connections {
        connection def DockingConnection {
            end stationSide : ~DockPort;
            end robotSide : DockPort;
        }
        connection def CommandLink {
            end source : CommandPort;
            end target : CommandPort;
        }
    }

    package Requirements {
        req def SystemRequirement {
            doc /* The cleaning system shall autonomously clean hardwood, tile, and carpet floors. */
            attribute supportedFloorTypes : FloorType[3] = (hardwood, tile, carpet);
            attribute supportedTasks : CleaningTaskType[3] = (vacuum, mop, dust);
        }
        req def BatteryLifeRequirement {
            doc /* The robot battery shall provide at least 60 minutes of cleaning operation per full charge. */
            attribute minRuntime : TimeValue = 3600;
        }
        req def ChargingTimeRequirement {
            doc /* The robot shall recharge to full battery within 4 hours when docked. */
            attribute maxChargeTime : TimeValue = 14400;
        }
        req def NavigationRequirement {
            doc /* The navigation module shall avoid obstacles and plan efficient paths. */
            attribute detectionRange : DistanceValue = 5;
        }
        req def CleaningRequirement {
            doc /* The cleaning module shall support vacuuming, mopping, and dusting on each floor type. */
        }
        req def LowBatteryReturnRequirement {
            doc /* The robot shall automatically return to charging station when battery falls below 20 percent. */
            attribute threshold : ChargeLevel = 20;
        }
        req def StateMachineRequirement {
            doc /* The robot shall cycle through standby, navigating, performing, returning, and charging states. */
            attribute requiredStates : RobotOperationalState[5] = (standby, navigating, performing, returning, charging);
        }
        req def DockingRequirement {
            doc /* The charging station shall reliably dock and recharge the robot. */
        }
    }

    package ChargingStation {
        part def DockingMechanism {
            attribute status : DockingStatus = undocked;
            action def engageDock {
                out docked : Boolean;
            }
            action def releaseDock {
                out docked : Boolean;
            }
            action def detectDock {
                out detected : Boolean;
            }
            state dockMechanismState {
                state released;
                state engaged;
                transition from released to engaged when status == docked;
                transition from engaged to released when status == undocked;
            }
        }

        part def PowerSupply {
            port powerOut : ~DockPort;
            attribute outputVoltage : VoltageValue = 24;
            attribute outputCurrent : CurrentValue = 2;
            attribute maxPower : PowerValue = 48;
            action def supplyPower {
                out power : PowerFlow;
            }
            action def stopSupply {
                out power : PowerFlow;
            }
            state supplyState {
                state idle;
                state supplying;
                transition from idle to supplying when powerOut.docked;
                transition from supplying to idle when not powerOut.docked;
            }
        }

        part def ChargingStation {
            port stationPort : ~DockPort;
            part powerSupply : PowerSupply;
            part dockingMechanism : DockingMechanism;
            attribute stationPosition : PositionData;
            attribute outputVoltage : VoltageValue = 24;
            attribute outputCurrent : CurrentValue = 2;

            connection powerLink {
                from powerSupply.powerOut to stationPort;
            }

            action def greetRobot {
                /* Signals docking mechanism to engage */
            }
            action def releaseRobot {
                /* Releases docking mechanism */
            }

            state stationState {
                state awaiting;
                state docked;
                state charging;
                state releasing;
                transition from awaiting to docked when stationPort.docked;
                transition from docked to charging when powerSupply.supplyState.supplying;
                transition from charging to releasing when not stationPort.docked;
                transition from releasing to awaiting when dockingMechanism.status == undocked;
            }

            satisfy SystemRequirement;
            satisfy DockingRequirement;
            satisfy ChargingTimeRequirement;
        }
    }

    package Robot {

        part def ControlModule {
            port commandPort : CommandPort;
            port navCmdOut : ~NavPort;
            port cleanCmdOut : ~CleanPort;
            port powerQueryPort : ~PowerPort;
            port statusOut : CommandPort;

            attribute currentCommand : TaskCommand;
            attribute currentState : RobotOperationalState = standby;
            attribute taskComplete : Boolean = false;
            attribute commandReceived : Boolean = false;

            action def receiveCommand {
                in command : TaskCommand;
                out acknowledged : Boolean;
            }
            action def dispatchTasks {
                /* Routes commands to navigation, cleaning, and power sub-modules. */
            }
            action def emitStatus {
                out status : StatusUpdate;
            }
            action def markComplete {
                out complete : Boolean;
            }
            action def abortTask {
                /* Halts current task and triggers return. */
            }

            state controlState {
                state waiting;
                state dispatching;
                state monitoring;
                state aborting;
                transition from waiting to dispatching when commandReceived;
                transition from dispatching to monitoring do dispatchTasks;
                transition from monitoring to waiting when taskComplete;
                transition from monitoring to aborting when powerQueryPort.status.level <= 20;
                transition from aborting to waiting when taskComplete;
            }
        }

        part def ObstacleSensor {
            port sensorOut : SensorPort;
            attribute range : DistanceValue = 5;
            action def scan {
                out obstacles : ObstacleData;
            }
            action def calibrate {
                /* Calibrates sensor baseline. */
            }
        }

        part def PositionSensor {
            port sensorOut : SensorPort;
            action def localize {
                out position : PositionData;
            }
            action def resetOrigin {
                /* Resets reference frame to dock. */
            }
        }

        part def DriveMotor {
            port motorIn : MotorPort;
            attribute maxSpeed : SpeedValue = 0.5;
            action def move {
                in velocity : SpeedValue;
                in heading : AngleValue;
            }
            action def stop {
                /* Halts motor motion. */
            }
            action def rotate {
                in angle : AngleValue;
            }
        }

        part def PathPlanner {
            action def planPath {
                in start : PositionData;
                in goal : PositionData;
                in obstacles : ObstacleData[*];
                out plan : PathPlan;
            }
            action def planHomePath {
                in start : PositionData;
                in station : PositionData;
                out plan : PathPlan;
            }
            action def replan {
                in obstacle : ObstacleData;
                out plan : PathPlan;
            }
        }

        part def NavigationModule {
            port navPort : NavPort;
            part obstacleSensor : ObstacleSensor;
            part positionSensor : PositionSensor;
            part driveMotor : DriveMotor;
            part pathPlanner : PathPlanner;

            attribute currentPlan : PathPlan;
            attribute stationPosition : PositionData;
            attribute goalPosition : PositionData;
            attribute arrived : Boolean = false;
            attribute homeCommand : Boolean = false;
            attribute planReady : Boolean = false;
            attribute obstaclesDetected : Boolean = false;
            attribute pathPlanReceived : Boolean = false;

            action def detectObstacles {
                out obstacles : ObstacleData;
            }
            action def avoidObstacle {
                in obstacle : ObstacleData;
                out revisedPlan : PathPlan;
            }
            action def navigateTo {
                in goal : PositionData;
            }
            action def returnToBase {
                /* Computes and follows path back to station. */
            }
            action def updatePosition {
                out position : PositionData;
            }

            connection sensorToPlanner {
                from obstacleSensor.sensorOut to pathPlanner.planPath.obstacles;
            }
            connection positionToPlanner {
                from positionSensor.sensorOut to pathPlanner.planPath.start;
            }
            connection plannerToMotor {
                from pathPlanner.planPath.plan to driveMotor.motorIn;
            }

            state navState {
                state idle;
                state scanning;
                state planning;
                state moving;
                state homing;
                transition from idle to scanning when pathPlanReceived;
                transition from scanning to planning when obstaclesDetected;
                transition from planning to moving when planReady;
                transition from moving to homing when homeCommand;
                transition from homing to idle when arrived;
            }

            satisfy NavigationRequirement;
        }

        part def VacuumUnit {
            port vacuumIn : CleanPort;
            attribute suction : SuctionForceValue = 2000;
            attribute dustBinCapacity : VolumeValue = 0.5;
            attribute dustBinLevel : VolumeValue = 0;
            action def vacuum {
                in floorType : FloorType;
                out collected : VolumeValue;
            }
            action def clearBin {
                /* Empties dust bin into station receptacle. */
            }
            action def adjustSuction {
                in floorType : FloorType;
                out suction : SuctionForceValue;
            }
        }

        part def BrushAssembly {
            port brushIn : CleanPort;
            attribute brushRate : BrushRateValue = 1500;
            action def rotate {
                in rate : BrushRateValue;
            }
            action def agitate {
                /* Agitates carpet fibers to lift debris. */
            }
            action def stopBrushes {
                /* Halts brush rotation. */
            }
        }

        part def MopSystem {
            port mopIn : CleanPort;
            attribute waterTankCapacity : VolumeValue = 0.3;
            attribute remainingWater : VolumeValue = 0.3;
            action def mop {
                in floorType : FloorType;
                out waterUsed : VolumeValue;
            }
            action def refill {
                /* Refills water tank from station reservoir. */
            }
            action def dispenseWater {
                in rate : VolumeValue;
            }
        }

        part def DustingTool {
            port dustIn : CleanPort;
            action def dust {
                in floorType : FloorType;
            }
            action def extend {
                /* Extends dusting wand. */
            }
            action def retract {
                /* Retracts dusting wand. */
            }
        }

        part def CleaningModule {
            port cleanPort : CleanPort;
            part vacuum : VacuumUnit;
            part brushes : BrushAssembly;
            part mop : MopSystem;
            part duster : DustingTool;

            attribute currentTask : CleaningTaskType;
            attribute currentFloor : FloorType;
            attribute toolState : CleaningToolState = inactive;
            attribute startSignal : Boolean = false;
            attribute stopSignal : Boolean = false;
            attribute areaCleaned : AreaValue = 0;

            action def startVacuum {
                in floorType : FloorType;
            }
            action def startMop {
                in floorType : FloorType;
            }
            action def startDust {
                in floorType : FloorType;
            }
            action def stopAll {
                out result : CleaningResult;
            }
            action def reportProgress {
                out area : AreaValue;
            }

            connection vacuumControl {
                from cleanPort to vacuum.vacuumIn;
            }
            connection brushControl {
                from cleanPort to brushes.brushIn;
            }
            connection mopControl {
                from cleanPort to mop.mopIn;
            }
            connection dustControl {
                from cleanPort to duster.dustIn;
            }

            state cleaningState {
                state inactive;
                state vacuuming;
                state mopping;
                state dusting;
                transition from inactive to vacuuming when startSignal and currentTask == vacuum;
                transition from inactive to mopping when startSignal and currentTask == mop;
                transition from inactive to dusting when startSignal and currentTask == dust;
                transition from vacuuming to inactive when stopSignal;
                transition from mopping to inactive when stopSignal;
                transition from dusting to inactive when stopSignal;
            }

            satisfy CleaningRequirement;
        }

        part def Battery {
            port batteryOut : PowerPort;
            attribute capacity : EnergyValue = 50;
            attribute currentLevel : ChargeLevel = 100;
            attribute nominalVoltage : VoltageValue = 14.4;
            attribute lowThreshold : ChargeLevel = 20;
            attribute fullThreshold : ChargeLevel = 95;
            attribute cycleCount : Integer = 0;

            action def discharge {
                out power : PowerFlow;
            }
            action def charge {
                in power : PowerFlow;
                out level : ChargeLevel;
            }
            action def estimateRemaining {
                out runtime : TimeValue;
            }
            action def reportHealth {
                out status : BatteryStatus;
            }
        }

        part def ChargingController {
            port chargePort : DockPort;
            port monitorOut : PowerPort;
            attribute regulatedVoltage : VoltageValue = 14.4;
            attribute regulatedCurrent : CurrentValue = 2;
            attribute temperatureLimit : AngleValue = 80;

            action def regulateCharge {
                in inputPower : PowerFlow;
                out regulatedPower : PowerFlow;
            }
            action def stopCharge {
                /* Halts charging process when full or fault. */
            }
            action def monitorTemperature {
                out safe : Boolean;
            }
        }

        part def PowerModule {
            port powerPort : PowerPort;
            port dockPort : DockPort;
            part battery : Battery;
            part chargeController : ChargingController;

            attribute lowThreshold : ChargeLevel = 20;
            attribute fullThreshold : ChargeLevel = 95;
            attribute batteryLow : Boolean = false;
            attribute batteryFull : Boolean = false;
            attribute chargingActive : Boolean = false;

            action def monitorBattery {
                out status : BatteryStatus;
            }
            action def startRecharge {
                in power : PowerFlow;
            }
            action def stopRecharge {
                /* Halts charging process. */
            }
            action def requestReturn {
                out returnNeeded : Boolean;
            }

            connection batteryToMonitor {
                from battery.batteryOut to powerPort;
            }
            connection dockToController {
                from dockPort to chargeController.chargePort;
            }
            connection controllerToMonitor {
                from chargeController.monitorOut to powerPort;
            }

            state powerState {
                state discharging;
                state lowWarning;
                state recharging;
                state full;
                transition from discharging to lowWarning when battery.currentLevel <= lowThreshold;
                transition from lowWarning to recharging when dockPort.power;
                transition from recharging to full when battery.currentLevel >= fullThreshold;
                transition from full to discharging when not dockPort.docked;
            }

            satisfy BatteryLifeRequirement;
            satisfy ChargingTimeRequirement;
            satisfy LowBatteryReturnRequirement;
        }

        part def CleaningRobot {
            port userCommandPort : CommandPort;
            port dockingPort : DockPort;

            part control : ControlModule;
            part navigation : NavigationModule;
            part cleaning : CleaningModule;
            part power : PowerModule;

            attribute operationalState : RobotOperationalState = standby;
            attribute stationPosition : PositionData;
            attribute commandReceived : Boolean = false;
            attribute arrived : Boolean = false;
            attribute taskComplete : Boolean = false;
            attribute docked : Boolean = false;
            attribute batteryLow : Boolean = false;
            attribute batteryFull : Boolean = false;

            action def updateStatus {
                in state : RobotOperationalState;
                out status : StatusUpdate;
            }
            action def startNavigation {
                out pathPlan : PathPlan;
            }
            action def monitorObstacles {
                out obstacles : ObstacleData;
            }
            action def startCleaning {
                in taskType : CleaningTaskType;
                in floorType : FloorType;
            }
            action def monitorBattery {
                out status : BatteryStatus;
            }
            action def planReturnPath {
                out plan : PathPlan;
            }
            action def navigateToBase {
                /* Drives robot along homing path to station. */
            }
            action def startCharging {
                in power : PowerFlow;
            }
            action def monitorCharge {
                out level : ChargeLevel;
            }
            action def reportFullCharge {
                out status : StatusUpdate;
            }
            action def acknowledgeCommand {
                in command : TaskCommand;
                out received : Boolean;
            }

            connection userToControl {
                from userCommandPort to control.commandPort;
            }
            connection controlToNav {
                from control.navCmdOut to navigation.navPort;
            }
            connection controlToCleaning {
                from control.cleanCmdOut to cleaning.cleanPort;
            }
            connection controlToPower {
                from control.powerQueryPort to power.powerPort;
            }
            connection powerToDock {
                from power.dockPort to dockingPort;
            }

            state robotState {
                state standby {
                    entry {
                        action updateStatus(state = standby);
                    }
                }
                state navigating {
                    entry {
                        action startNavigation;
                    }
                    do {
                        action monitorObstacles;
                    }
                }
                state performing {
                    entry {
                        action startCleaning;
                    }
                    do {
                        action monitorBattery;
                    }
                }
                state returning {
                    entry {
                        action planReturnPath;
                    }
                    do {
                        action navigateToBase;
                    }
                }
                state charging {
                    entry {
                        action startCharging;
                    }
                    do {
                        action monitorCharge;
                    }
                    exit {
                        action reportFullCharge;
                    }
                }

                transition from standby to navigating when commandReceived;
                transition from navigating to performing when arrived;
                transition from performing to returning when taskComplete;
                transition from performing to returning when batteryLow;
                transition from navigating to returning when batteryLow;
                transition from returning to charging when docked;
                transition from charging to standby when batteryFull;
            }

            satisfy SystemRequirement;
            satisfy StateMachineRequirement;
            satisfy BatteryLifeRequirement;
            satisfy LowBatteryReturnRequirement;
        }
    }

    package System {
        part def CleaningSystem {
            part robot : CleaningRobot;
            part station : ChargingStation::ChargingStation;

            connection dockingLink : DockingConnection {
                end stationSide :>> station.stationPort;
                end robotSide :>> robot.dockingPort;
            }

            attribute totalCleaningArea : AreaValue;
            attribute stationLocation : PositionData;

            action def initiateCleaningSession {
                in command : TaskCommand;
                out status : StatusUpdate;
            }
            action def terminateCleaningSession {
                out summary : StatusUpdate;
            }

            state systemState {
                state idle;
                state active;
                state maintenance;
                transition from idle to active when robot.commandReceived;
                transition from active to idle when robot.taskComplete;
                transition from active to maintenance when robot.batteryLow;
                transition from maintenance to idle when robot.batteryFull;
            }

            satisfy SystemRequirement;
        }
    }
}
