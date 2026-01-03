package 'Autonomous Warehouse Robot System' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def BatteryChargeLevel :> Real;
    attribute def LoadStatus;
    attribute def NavigationState;
    attribute def DockingCommand;
    attribute def PickupCommand;
    attribute def DeliveryCommand;

    item def Coordinates {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute heading : Real;
    }

    item def Waypoint {
        attribute position : Coordinates;
        attribute waypointID : String;
    }

    item def Package {
        attribute mass : MassValue;
        attribute dimensions : LengthValue[3];
        attribute packageID : String;
    }

    enum def RobotMode {
        idle;
        navigating;
        loading;
        unloading;
        charging;
        error;
    }

    port def PowerSupplyPort {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }

    port def CommunicationPort {
        in commands : String;
        out status : String;
    }

    port def SensorPort {
        out obstacleDistance : LengthValue;
        out currentPosition : Coordinates;
    }

    port def ActuatorPort {
        in velocityCommand : SpeedValue;
        in liftCommand : LengthValue;
    }

    part def BatteryPack {
        attribute capacity : EnergyValue;
        attribute currentCharge : BatteryChargeLevel;
        attribute nominalVoltage : ElectricPotentialValue;
        port powerOutput : PowerSupplyPort;

        action def DischargeBattery {
            in powerDraw : PowerValue;
            in duration : TimeValue;
            out remainingCharge : BatteryChargeLevel;
        }

        action def ChargeBattery {
            in chargingPower : PowerValue;
            in duration : TimeValue;
            out newCharge : BatteryChargeLevel;
        }
    }

    part def LaserRangeFinder {
        attribute maxRange : LengthValue;
        attribute scanRate : FrequencyValue;
        port sensorData : SensorPort;
        port power : ~PowerSupplyPort;

        action def ScanEnvironment {
            out obstacles : LengthValue[*];
            out scanComplete : Boolean;
        }
    }

    part def Odometry {
        attribute wheelDiameter : LengthValue;
        attribute encoderResolution : Integer;
        port positionData : SensorPort;
        port power : ~PowerSupplyPort;

        action def UpdatePosition {
            in leftWheelRotation : Real;
            in rightWheelRotation : Real;
            out newPosition : Coordinates;
        }
    }

    part def DriveSystem {
        attribute maxSpeed : SpeedValue;
        attribute wheelBase : LengthValue;
        port actuatorControl : ~ActuatorPort;
        port power : ~PowerSupplyPort;

        action def ExecuteMotion {
            in targetVelocity : SpeedValue;
            in targetHeading : Real;
            out actualVelocity : SpeedValue;
            out actualHeading : Real;
        }
    }

    part def LiftMechanism {
        attribute maxLiftHeight : LengthValue;
        attribute maxPayload : MassValue;
        attribute currentHeight : LengthValue;
        attribute isLoaded : Boolean;
        port liftControl : ~ActuatorPort;
        port power : ~PowerSupplyPort;

        action def RaisePlatform {
            in targetHeight : LengthValue;
            out currentHeight : LengthValue;
        }

        action def LowerPlatform {
            in targetHeight : LengthValue;
            out currentHeight : LengthValue;
        }

        state def LiftStates {
            entry; then lowered;

            state lowered {
                entry assign currentHeight := 0.0[m];
            }
            transition lowered_to_raising
                first lowered
                accept liftCommand : LengthValue
                then raising;

            state raising {
                do action raisePlatform : RaisePlatform {
                    in targetHeight : LengthValue;
                    out currentHeight : LengthValue;
                }
            }
            transition raising_to_raised
                first raising
                if currentHeight >= maxLiftHeight
                then raised;

            state raised;
            transition raised_to_lowering
                first raised
                accept liftCommand : LengthValue
                then lowering;

            state lowering {
                do action lowerPlatform : LowerPlatform {
                    in targetHeight : LengthValue;
                    out currentHeight : LengthValue;
                }
            }
            transition lowering_to_lowered
                first lowering
                if currentHeight <= 0.0[m]
                then lowered;
        }
    }

    part def PathPlanner {
        attribute currentPath : Waypoint[*];

        action def ComputePath {
            in startPosition : Coordinates;
            in goalPosition : Coordinates;
            in obstacleMap : LengthValue[*];
            out plannedPath : Waypoint[*];
            out pathValid : Boolean;
        }

        action def UpdatePath {
            in currentPosition : Coordinates;
            in newObstacles : LengthValue[*];
            out revisedPath : Waypoint[*];
        }
    }

    part def MissionController {
        attribute currentMode : RobotMode;
        attribute assignedTask : String;
        attribute batteryLevel : BatteryChargeLevel;
        attribute arrivedAtPickup : Boolean;
        attribute arrivedAtDelivery : Boolean;
        port communication : CommunicationPort;

        state def MissionStateMachine {
            entry; then idle;

            state idle {
                entry assign currentMode := RobotMode::idle;
            }
            transition idle_to_navigating
                first idle
                accept PickupCommand
                then navigating;

            state navigating {
                entry assign currentMode := RobotMode::navigating;
                do action navigate {
                    action planRoute : PathPlanner::ComputePath;
                    then action followPath : DriveSystem::ExecuteMotion;
                    then action updateOdometry : Odometry::UpdatePosition;
                }
            }
            transition navigating_to_loading
                first navigating
                if arrivedAtPickup
                then loading;
            transition navigating_to_unloading
                first navigating
                if arrivedAtDelivery
                then unloading;

            state loading {
                entry assign currentMode := RobotMode::loading;
                do action loadPackage {
                    action raiseLift : LiftMechanism::RaisePlatform;
                    then action secureLoad;
                    then action lowerLift : LiftMechanism::LowerPlatform;
                }
            }
            transition loading_to_navigating
                first loading
                accept DeliveryCommand
                then navigating;

            state unloading {
                entry assign currentMode := RobotMode::unloading;
                do action unloadPackage {
                    action raiseLift : LiftMechanism::RaisePlatform;
                    then action releaseLoad;
                    then action lowerLift : LiftMechanism::LowerPlatform;
                }
            }
            transition unloading_to_idle
                first unloading
                then idle;

            state charging {
                entry assign currentMode := RobotMode::charging;
                do action recharge : BatteryPack::ChargeBattery;
            }
            transition idle_to_charging
                first idle
                if batteryLevel < 20.0
                then charging;
            transition charging_to_idle
                first charging
                if batteryLevel >= 95.0
                then idle;

            state error {
                entry assign currentMode := RobotMode::error;
            }
        }
    }

    part warehouseRobot : WarehouseRobot {
        part battery : BatteryPack {
            :>> capacity = 3600000.0[J];
            :>> currentCharge = 100.0;
            :>> nominalVoltage = 48.0[V];
        }

        part lidar : LaserRangeFinder {
            :>> maxRange = 30.0[m];
            :>> scanRate = 10.0[Hz];
        }

        part odometer : Odometry {
            :>> wheelDiameter = 0.2[m];
            :>> encoderResolution = 2048;
        }

        part driveSystem : DriveSystem {
            :>> maxSpeed = 3.0[m/s];
            :>> wheelBase = 0.6[m];
        }

        part liftMech : LiftMechanism {
            :>> maxLiftHeight = 0.5[m];
            :>> maxPayload = 100.0[kg];
            :>> currentHeight = 0.0[m];
            :>> isLoaded = false;
        }

        part pathPlanner : PathPlanner;

        part missionCtrl : MissionController {
            :>> currentMode = RobotMode::idle;
        }

        connect battery.powerOutput to lidar.power;
        connect battery.powerOutput to odometer.power;
        connect battery.powerOutput to driveSystem.power;
        connect battery.powerOutput to liftMech.power;

        perform action executeWarehouseOperations {
            first start;
            then action initializeSystems {
                action powerUpSensors;
                then action calibrateOdometry;
                then action testLift;
                then action establishCommunication;
            }
            then merge operationLoop;
            then action operationCycle {
                action receiveTask;
                then action planMission : PathPlanner::ComputePath {
                    in startPosition = odometer.positionData.currentPosition;
                    in goalPosition;
                    in obstacleMap = lidar.sensorData.obstacleDistance;
                    out plannedPath;
                    out pathValid;
                }
                then decide;
                    if pathValid then executeNavigation;
                    if not pathValid then replanPath;
                action executeNavigation : DriveSystem::ExecuteMotion {
                    in targetVelocity;
                    in targetHeading;
                    out actualVelocity;
                    out actualHeading;
                }
                then action monitorProgress {
                    action scanForObstacles : LaserRangeFinder::ScanEnvironment;
                    then action trackPosition : Odometry::UpdatePosition;
                }
                then decide;
                    if destinationReached then performTask;
                    if obstacleDetected then avoidObstacle;
                    if batteryLow then returnToCharger;
                    else operationLoop;
                action performTask {
                    decide;
                        if taskType == "pickup" then pickupPackage;
                        if taskType == "delivery" then deliverPackage;
                    action pickupPackage {
                        action alignWithShelf;
                        then action liftLoad;
                        then action confirmPickup;
                    }
                    action deliverPackage {
                        action alignWithStation;
                        then action lowerLoad;
                        then action confirmDelivery;
                    }
                }
                then operationLoop;
                action replanPath : PathPlanner::UpdatePath;
                then operationLoop;
                action avoidObstacle : PathPlanner::UpdatePath;
                then operationLoop;
                action returnToCharger {
                    action navigateToChargingStation : PathPlanner::ComputePath;
                    then action dockWithCharger;
                    then action chargeUntilFull : BatteryPack::ChargeBattery;
                }
                then operationLoop;
            }
            then operationLoop;
            then done;
        }
    }

    part def WarehouseRobot;

    requirement def AutonomyRequirement {
        doc /* The robot shall operate autonomously without human intervention during normal operations. */
        subject robot : WarehouseRobot;
    }

    requirement def NavigationAccuracyRequirement {
        doc /* The robot shall navigate to target locations with position accuracy within 5 cm. */
        subject robot : WarehouseRobot;
        require constraint {
            doc /* Position error shall not exceed 0.05 meters. */
        }
    }

    requirement def PayloadCapacityRequirement {
        doc /* The robot shall safely transport packages up to 100 kg. */
        subject lift : LiftMechanism;
        require constraint {
            lift.maxPayload >= 100.0[kg]
        }
    }

    requirement def BatteryEnduranceRequirement {
        doc /* The robot shall operate continuously for at least 8 hours on a single charge. */
        subject battery : BatteryPack;
        require constraint {
            battery.capacity >= 3600000.0[J]
        }
    }

    requirement def SafetyRequirement {
        doc /* The robot shall detect and avoid obstacles to prevent collisions. */
        subject robot : WarehouseRobot;
    }

    requirement warehouseRobotMissionRequirement {
        doc /* The autonomous warehouse robot shall transport packages from pickup locations 
               to delivery destinations within a warehouse environment, navigating safely 
               around obstacles and other robots while maintaining operational efficiency. */

        assume constraint warehouseEnvironment {
            doc /* The warehouse has a structured layout with defined pathways and charging stations. */
        }

        assume constraint packageSpecifications {
            doc /* Packages are within specified mass and dimension limits. */
        }

        require autonomyReq : AutonomyRequirement;
        require navigationReq : NavigationAccuracyRequirement;
        require payloadReq : PayloadCapacityRequirement;
        require batteryReq : BatteryEnduranceRequirement;
        require safetyReq : SafetyRequirement;
    }

    action def AutonomousPackageTransport {
        in pickupLocation : Coordinates;
        in deliveryLocation : Coordinates;
        in packageToTransport : Package;
        out transportSuccess : Boolean;
        out finalPosition : Coordinates;

        action navigateToPickup : PathPlanner::ComputePath {
            in startPosition;
            in goalPosition = pickupLocation;
            out plannedPath;
        }
        flow navigateToPickup.plannedPath to moveToPickup.path;

        action moveToPickup : DriveSystem::ExecuteMotion;
        flow moveToPickup.actualVelocity to loadPackage.currentVelocity;

        action loadPackage {
            in currentVelocity : SpeedValue;
            action positionUnderShelf;
            then action raiseLift;
            then action securePackage;
            then action lowerLift;
        }
        flow loadPackage to navigateToDelivery;

        action navigateToDelivery : PathPlanner::ComputePath {
            in startPosition = pickupLocation;
            in goalPosition = deliveryLocation;
            out plannedPath;
        }
        flow navigateToDelivery.plannedPath to moveToDelivery.path;

        action moveToDelivery : DriveSystem::ExecuteMotion;
        flow moveToDelivery.actualVelocity to unloadPackage.currentVelocity;

        action unloadPackage {
            in currentVelocity : SpeedValue;
            action positionAtStation;
            then action raiseLift;
            then action releasePackage;
            then action lowerLift;
        }
        flow unloadPackage to confirmCompletion;

        action confirmCompletion {
            action verifyDelivery;
            then action updateStatus;
            then assign transportSuccess := true;
        }
    }
}
