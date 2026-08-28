package WarehouseAutonomousRobot {
    public import ISQ::*;
    public import ScalarValues::*;
    public import ItemDefinitions::*;
    public import PortDefinitions::*;
    public import ActionDefinitions::*;
    public import PartDefinitions::*;
    public import RequirementDefinitions::*;

    package ItemDefinitions {
        public import ISQ::*;
        public import ScalarValues::*;

        item def Position {
            attribute x :> ISQ::length;
            attribute y :> ISQ::length;
        }
        item def Package {
            attribute id : ScalarValues::String;
            attribute weight :> ISQ::mass;
            attribute height :> ISQ::length;
        }
        item def TaskCommand {
            ref pickupLocation : Position;
            ref dropoffLocation : Position;
            ref pkg : Package;
        }
        item def ObstacleData {
            attribute distance :> ISQ::length;
            attribute bearing :> ISQ::planeAngle;
        }
        item def OdometryData {
            ref position : Position;
            attribute heading :> ISQ::planeAngle;
            attribute linearVelocity :> ISQ::speed;
        }
        item def DriveCommand {
            attribute linearVelocity :> ISQ::speed;
            attribute angularVelocity :> ISQ::planeAngle;
        }
        item def LiftCommand {
            attribute targetHeight :> ISQ::length;
            attribute operationType : ScalarValues::String;
        }
        item def PathData {
            ref waypoints : Position[0..*];
            attribute estimatedDistance :> ISQ::length;
        }
        item def BatteryStatus {
            attribute currentCharge :> ISQ::energy;
            attribute voltage :> ISQ::electricPotential;
        }
        item def ChargingCommand;
        item def Power {
            attribute voltage :> ISQ::electricPotential;
            attribute current :> ISQ::electricCurrent;
        }
        item def ArrivalSignal {
            attribute destinationType : ScalarValues::String;
        }
        item def LiftCompleteSignal;
        item def LowBatterySignal;
        item def BatteryFullSignal;
    }

    package PortDefinitions {
        import ItemDefinitions::*;

        port def TaskCmdPort {
            in taskCmd : TaskCommand;
        }
        port def ObstacleDataPort {
            out obstacleData : ObstacleData;
        }
        port def OdometryDataPort {
            out odometryData : OdometryData;
        }
        port def PathDataPort {
            in pathRequest : Position;
            out plannedPath : PathData;
        }
        port def DriveCmdPort {
            in driveCmd : DriveCommand;
        }
        port def LiftCmdPort {
            in liftCmd : LiftCommand;
            out liftComplete : LiftCompleteSignal;
        }
        port def BatteryStatusPort {
            out batteryStatus : BatteryStatus;
        }
        port def RobotChargingPort {
            out chargingCmd : ChargingCommand;
            in chargingPower : Power;
        }
        port def ChargerChargingPort {
            in chargingCmd : ChargingCommand;
            out chargingPower : Power;
        }
        port def PowerPort {
            in power : Power;
        }
        port def PowerOutPort {
            out power : Power;
        }
        port def MissionStatusPort {
            out arrival : ArrivalSignal;
            out liftComplete : LiftCompleteSignal;
        }
    }

    package ActionDefinitions {
        import ItemDefinitions::*;
        import ISQ::*;

        action def Move {
            in cmd : DriveCommand;
        }
        action def Raise {
            in targetHeight :> ISQ::length;
        }
        action def Lower {
            in targetHeight :> ISQ::length;
        }
        action def Scan {
            out data : ObstacleData;
        }
        action def ComputePosition {
            out odom : OdometryData;
        }
        action def PlanPath {
            in currentPos : Position;
            in obstacles : ObstacleData[0..*];
            out path : PathData;
        }
        action def ManageMission;
        action def SupplyPower;
        action def ReceiveCharge;
        action def ProvideCharge;
    }

    package PartDefinitions {
        import PortDefinitions::*;
        import ActionDefinitions::*;
        import ItemDefinitions::*;
        import ISQ::*;

        part def DriveSystem {
            port driveCmdPort : DriveCmdPort;
            port powerPort : PowerPort;
            perform action move;
        }
        part def BatteryPack {
            attribute capacity :> ISQ::energy;
            attribute lowThreshold :> ISQ::energy;
            port batteryStatusPort : BatteryStatusPort;
            port chargingPort : RobotChargingPort;
            port powerOutPort : PowerOutPort;
            perform action supplyPower;
            perform action receiveCharge;
        }
        part def LiftMechanism {
            attribute maxPayload :> ISQ::mass;
            attribute maxHeight :> ISQ::length;
            port liftCmdPort : LiftCmdPort;
            port powerPort : PowerPort;
            perform action raise;
            perform action lower;
        }
        part def LidarSensor {
            attribute scanRange :> ISQ::length;
            port obstacleDataPort : ObstacleDataPort;
            port powerPort : PowerPort;
            perform action scan;
        }
        part def OdometrySystem {
            port odometryDataPort : OdometryDataPort;
            port powerPort : PowerPort;
            perform action computePosition;
        }
        part def PathPlanner {
            port odometryDataPort : OdometryDataPort;
            port obstacleDataPort : ObstacleDataPort;
            port pathDataPort : PathDataPort;
            port powerPort : PowerPort;
            perform action planPath;
        }
        part def MissionController {
            port taskCmdPort : TaskCmdPort;
            port pathDataPort : PathDataPort;
            port driveCmdPort : DriveCmdPort;
            port liftCmdPort : LiftCmdPort;
            port batteryStatusPort : BatteryStatusPort;
            port missionStatusPort : MissionStatusPort;
            port powerPort : PowerPort;
            perform action manageMission;
        }
        part def ChargingStation {
            port chargingPort : ChargerChargingPort;
            perform action provideCharge;
        }

        part def MobilePlatform {
            attribute maxSpeed :> ISQ::speed;
            port taskCmdPort : TaskCmdPort;
            port chargingPort : RobotChargingPort;

            part driveSystem : DriveSystem;
            part batteryPack : BatteryPack;
            part liftMechanism : LiftMechanism;
            part lidar : LidarSensor;
            part odometry : OdometrySystem;
            part pathPlanner : PathPlanner;
            part missionController : MissionController;

            bind taskCmdPort = missionController.taskCmdPort;
            bind chargingPort = batteryPack.chargingPort;

            flow powerToDrive of Power
                from batteryPack.powerOutPort.power to driveSystem.powerPort.power;
            flow powerToLift of Power
                from batteryPack.powerOutPort.power to liftMechanism.powerPort.power;
            flow powerToLidar of Power
                from batteryPack.powerOutPort.power to lidar.powerPort.power;
            flow powerToOdometry of Power
                from batteryPack.powerOutPort.power to odometry.powerPort.power;
            flow powerToPlanner of Power
                from batteryPack.powerOutPort.power to pathPlanner.powerPort.power;
            flow powerToController of Power
                from batteryPack.powerOutPort.power to missionController.powerPort.power;

            flow batteryStatusFlow of BatteryStatus
                from batteryPack.batteryStatusPort.batteryStatus to missionController.batteryStatusPort.batteryStatus;
            flow obstacleFlow of ObstacleData
                from lidar.obstacleDataPort.obstacleData to pathPlanner.obstacleDataPort.obstacleData;
            flow odometryFlow of OdometryData
                from odometry.odometryDataPort.odometryData to pathPlanner.odometryDataPort.odometryData;
            flow pathRequestFlow of Position
                from missionController.pathDataPort.pathRequest to pathPlanner.pathDataPort.pathRequest;
            flow pathFlow of PathData
                from pathPlanner.pathDataPort.plannedPath to missionController.pathDataPort.plannedPath;
            flow driveCmdFlow of DriveCommand
                from missionController.driveCmdPort.driveCmd to driveSystem.driveCmdPort.driveCmd;
            flow liftCmdFlow of LiftCommand
                from missionController.liftCmdPort.liftCmd to liftMechanism.liftCmdPort.liftCmd;
            flow liftCompleteFlow of LiftCompleteSignal
                from liftMechanism.liftCmdPort.liftComplete to missionController.liftCmdPort.liftComplete;

            exhibit state robotModes {
                entry action initial;
                state idle;
                state navigating;
                state loading;
                state unloading;
                state charging;

                transition initial then idle;

                transition idle_to_navigating
                    first idle
                    accept taskCmd : TaskCommand via taskCmdPort
                    then navigating;
                transition navigating_to_loading
                    first navigating
                    accept arrival : ArrivalSignal via missionController.missionStatusPort
                    if arrival.destinationType == "pickup"
                    then loading;
                transition loading_to_navigating
                    first loading
                    accept liftDone : LiftCompleteSignal via missionController.missionStatusPort
                    then navigating;
                transition navigating_to_unloading
                    first navigating
                    accept arrival2 : ArrivalSignal via missionController.missionStatusPort
                    if arrival2.destinationType == "dropoff"
                    then unloading;
                transition unloading_to_idle
                    first unloading
                    accept liftDone2 : LiftCompleteSignal via missionController.missionStatusPort
                    then idle;
                transition idle_to_charging
                    first idle
                    accept lowBattery : LowBatterySignal
                    then charging;
                transition navigating_to_charging
                    first navigating
                    accept lowBattery2 : LowBatterySignal
                    then charging;
                transition loading_to_charging
                    first loading
                    accept lowBattery3 : LowBatterySignal
                    then charging;
                transition unloading_to_charging
                    first unloading
                    accept lowBattery4 : LowBatterySignal
                    then charging;
                transition charging_to_idle
                    first charging
                    accept batteryFull : BatteryFullSignal
                    then idle;
            }
        }
    }

    package RequirementDefinitions {
        import PartDefinitions::*;
        import ISQ::*;

        requirement def PayloadRequirement {
            doc /* The lift mechanism must support packages up to 50 kg and 1.5 m. */
            subject lift : LiftMechanism;
            constraint { lift.maxPayload >= 50 [kg] }
            constraint { lift.maxHeight >= 1.5 [m] }
        }
        requirement def AutonomyRequirement {
            doc /* The robot must autonomously recharge when battery is low. */
            subject robot : MobilePlatform;
        }
        requirement def SafetyRequirement {
            doc /* The robot must detect and avoid obstacles. */
            subject robot : MobilePlatform;
            constraint { robot.lidar.scanRange >= 5 [m] }
        }
    }

    package Usage {
        import PartDefinitions::*;
        import ItemDefinitions::*;
        import RequirementDefinitions::*;

        part warehouseRobot : MobilePlatform;
        part chargingStation : ChargingStation;

        interface robotToCharger connect warehouseRobot.chargingPort to chargingStation.chargingPort {
            flow chargingCmdFlow of ChargingCommand
                from warehouseRobot.chargingPort.chargingCmd to chargingStation.chargingPort.chargingCmd;
            flow chargingPowerFlow of Power
                from chargingStation.chargingPort.chargingPower to warehouseRobot.chargingPort.chargingPower;
        }

        requirement payloadReq : PayloadRequirement {
            subject :>> lift = warehouseRobot.liftMechanism;
        }
        requirement autonomyReq : AutonomyRequirement {
            subject :>> robot = warehouseRobot;
        }
        requirement safetyReq : SafetyRequirement {
            subject :>> robot = warehouseRobot;
        }
    }
}
