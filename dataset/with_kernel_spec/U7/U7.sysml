package AutonomousDeliverySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    item def ElectricPower;
    item def Data;
    item def Package {
        attribute mass : MassValue;
    }

    port def PowerPort {
        out item power : ElectricPower;
    }
    port def DataPort {
        out item data : Data;
    }
    port def ControlPort {
        in item command : Data;
    }
    port def AlertPort {
        out item alert : Data;
    }
    port def MechanicalCoupling;

    attribute def SigStartNavigation;
    attribute def SigArriveAtPickup;
    attribute def SigArriveAtDestination;
    attribute def SigLowBattery;
    attribute def SigFault;
    attribute def SigLoadComplete;
    attribute def SigUnloadComplete;
    attribute def SigArriveAtBase;
    attribute def SigChargeComplete;
    attribute def SigReset;

    action def FuseSensorData {
        in lidarData : Data;
        in cameraData : Data;
        in gpsData : Data;
        in imuData : Data;
        out pathPlan : Data;
    }
    action def PlanPath {
        out path : Data;
    }
    action def AvoidObstacle {
        out maneuver : Data;
    }
    action def NavigateToPickup;
    action def NavigateToDestination;
    action def LoadPackage;
    action def UnloadPackage;
    action def ReturnToBase;
    action def ChargeBattery;
    action def NotifyOperator;

    part def RubberWheel {
        port mechanicalIn : ~MechanicalCoupling;
        attribute diameter : LengthValue = 0.3 [m];
    }

    part def ElectricMotor {
        port powerIn : ~PowerPort;
        port controlIn : ControlPort;
        port mechanicalOut : MechanicalCoupling;
    }

    part def LiDARSensor {
        port powerIn : ~PowerPort;
        port dataOut : DataPort;
        attribute detectionRange : LengthValue = 5.0 [m];
        attribute scanAngle : PlaneAngleValue = 360.0 [degree];
    }

    part def Camera {
        port powerIn : ~PowerPort;
        port dataOut : DataPort;
        attribute resolution : String = "1080p";
    }

    part def GPSModule {
        port powerIn : ~PowerPort;
        port dataOut : DataPort;
        attribute accuracy : LengthValue = 0.3 [m];
    }

    part def IMU {
        port powerIn : ~PowerPort;
        port dataOut : DataPort;
    }

    part def NavigationProcessor {
        port powerIn : ~PowerPort;
        port lidarIn : ~DataPort;
        port cameraIn : ~DataPort;
        port gpsIn : ~DataPort;
        port imuIn : ~DataPort;
        port pathOut : DataPort;
        perform action fuseSensorData : FuseSensorData;
        perform action planPath : PlanPath;
        perform action avoidObstacle : AvoidObstacle;
    }

    part def Battery {
        port powerOut : PowerPort;
        port chargeIn : ~PowerPort;
        port statusOut : DataPort;
        attribute voltage : ElectricPotentialDifferenceValue = 48 [V];
        attribute runtime : TimeValue = 10 [h];
        attribute stateOfCharge : Real = 1.0;
    }

    part def PowerDistributionUnit {
        port powerIn : ~PowerPort;
        port motorPowerOut : PowerPort;
        port sensorPowerOut : PowerPort;
        port controlPowerOut : PowerPort;
        port navPowerOut : PowerPort;
        port cargoPowerOut : PowerPort;
    }

    part def LockingMechanism {
        port controlIn : ControlPort;
    }

    part def PackageSensor {
        port dataOut : DataPort;
    }

    part def CargoCompartment {
        port powerIn : ~PowerPort;
        port lockControlIn : ControlPort;
        port cargoStatusOut : DataPort;
        attribute maxPayload : MassValue = 25 [kg];
        item loadedPackage : Package[0..1];
        part lockingMechanism : LockingMechanism;
        part packageSensor : PackageSensor;
        connect packageSensor.dataOut to cargoStatusOut;
    }

    part def ControlSubsystem {
        port powerIn : ~PowerPort;
        port navDataIn : ~DataPort;
        port motorCmdOut : ~ControlPort;
        port cargoStatusIn : ~DataPort;
        port powerStatusIn : ~DataPort;
        port cargoControlOut : ~ControlPort;
        port operatorAlertOut : AlertPort;

        state robotStates {
            entry; then idle;
            state idle;
            transition idle_navigating
                first idle
                accept SigStartNavigation
                do action navigateToPickup : NavigateToPickup {}
                then navigating;
            state navigating;
            transition navigating_loading
                first navigating
                accept SigArriveAtPickup
                do action loadPackage : LoadPackage {}
                then loading;
            transition navigating_unloading
                first navigating
                accept SigArriveAtDestination
                do action unloadPackage : UnloadPackage {}
                then unloading;
            transition navigating_returning
                first navigating
                accept SigLowBattery
                do action returnToBase : ReturnToBase {}
                then returningToBase;
            transition navigating_error
                first navigating
                accept SigFault
                do action notifyOperator : NotifyOperator {}
                then error;
            state loading;
            transition loading_navigating
                first loading
                accept SigLoadComplete
                do action navigateToDestination : NavigateToDestination {}
                then navigating;
            state unloading;
            transition unloading_returning
                first unloading
                accept SigUnloadComplete
                do action returnToBase : ReturnToBase {}
                then returningToBase;
            state returningToBase;
            transition returning_charging
                first returningToBase
                accept SigArriveAtBase
                do action chargeBattery : ChargeBattery {}
                then charging;
            state charging;
            transition charging_idle
                first charging
                accept SigChargeComplete
                then idle;
            state error;
            transition error_idle
                first error
                accept SigReset
                then idle;
        }
    }

    part def DeliveryRobot {
        attribute maxPayload : MassValue = 25 [kg];
        port chargingPort : ~PowerPort;
        port operatorPort : ~AlertPort;

        part controlSubsystem : ControlSubsystem;
        part navigationProcessor : NavigationProcessor;

        part sensorSuite {
            port powerIn : ~PowerPort;
            part lidar : LiDARSensor;
            part frontCamera : Camera;
            part rearCamera : Camera;
            part gps : GPSModule;
            part imu : IMU;
            connect powerIn to lidar.powerIn;
            connect powerIn to frontCamera.powerIn;
            connect powerIn to rearCamera.powerIn;
            connect powerIn to gps.powerIn;
            connect powerIn to imu.powerIn;
        }

        part driveSubsystem {
            port cmdIn : ControlPort;
            port powerIn : ~PowerPort;
            part leftMotor : ElectricMotor;
            part rightMotor : ElectricMotor;
            part leftWheel : RubberWheel;
            part rightWheel : RubberWheel;
            connect cmdIn to leftMotor.controlIn;
            connect cmdIn to rightMotor.controlIn;
            connect powerIn to leftMotor.powerIn;
            connect powerIn to rightMotor.powerIn;
            connect leftMotor.mechanicalOut to leftWheel.mechanicalIn;
            connect rightMotor.mechanicalOut to rightWheel.mechanicalIn;
        }

        part cargoCompartment : CargoCompartment;

        part powerSubsystem {
            port chargeIn : ~PowerPort;
            port statusOut : DataPort;
            port motorPowerOut : PowerPort;
            port sensorPowerOut : PowerPort;
            port controlPowerOut : PowerPort;
            port navPowerOut : PowerPort;
            port cargoPowerOut : PowerPort;

            part mainBattery : Battery;
            part pdu : PowerDistributionUnit;
            connect mainBattery.powerOut to pdu.powerIn;
            connect mainBattery.chargeIn to chargeIn;
            connect mainBattery.statusOut to statusOut;
            connect pdu.motorPowerOut to motorPowerOut;
            connect pdu.sensorPowerOut to sensorPowerOut;
            connect pdu.controlPowerOut to controlPowerOut;
            connect pdu.navPowerOut to navPowerOut;
            connect pdu.cargoPowerOut to cargoPowerOut;
        }

        connect powerSubsystem.chargeIn to chargingPort;
        connect powerSubsystem.statusOut to controlSubsystem.powerStatusIn;
        connect powerSubsystem.motorPowerOut to driveSubsystem.powerIn;
        connect powerSubsystem.sensorPowerOut to sensorSuite.powerIn;
        connect powerSubsystem.controlPowerOut to controlSubsystem.powerIn;
        connect powerSubsystem.navPowerOut to navigationProcessor.powerIn;
        connect powerSubsystem.cargoPowerOut to cargoCompartment.powerIn;

        connect sensorSuite.lidar.dataOut to navigationProcessor.lidarIn;
        connect sensorSuite.frontCamera.dataOut to navigationProcessor.cameraIn;
        connect sensorSuite.rearCamera.dataOut to navigationProcessor.cameraIn;
        connect sensorSuite.gps.dataOut to navigationProcessor.gpsIn;
        connect sensorSuite.imu.dataOut to navigationProcessor.imuIn;

        connect navigationProcessor.pathOut to controlSubsystem.navDataIn;
        connect controlSubsystem.motorCmdOut to driveSubsystem.cmdIn;

        connect cargoCompartment.cargoStatusOut to controlSubsystem.cargoStatusIn;
        connect controlSubsystem.cargoControlOut to cargoCompartment.lockControlIn;

        connect controlSubsystem.operatorAlertOut to operatorPort;
    }

    part def ChargingStation {
        port robotChargePort : PowerPort;
        attribute inputVoltage : ElectricPotentialDifferenceValue = 230 [V];
        part chargingPad {
            port powerOut : PowerPort;
        }
        part stationController;
        connect chargingPad.powerOut to robotChargePort;
    }

    requirement def PayloadRequirement {
        doc /* The robot shall carry packages up to 25 kg. */
        subject robot : DeliveryRobot;
        constraint { robot.maxPayload >= 25 [SI::kg] }
    }

    requirement def NavigationAccuracyRequirement {
        doc /* The GPS shall provide positioning accuracy within 0.3 meters. */
        subject gps : GPSModule;
        constraint { gps.accuracy <= 0.3 [SI::m] }
    }

    requirement def ObstacleDetectionRequirement {
        doc /* The LiDAR shall detect obstacles up to 5 meters away with 360-degree coverage. */
        subject lidar : LiDARSensor;
        constraint { lidar.detectionRange >= 5.0 [SI::m] }
        constraint { lidar.scanAngle >= 360.0 [SI::degree] }
    }

    requirement def BatteryLifeRequirement {
        doc /* The robot shall operate for up to 10 hours on a single charge. */
        subject battery : Battery;
        constraint { battery.runtime >= 10 [SI::h] }
    }

    requirement def BatteryVoltageRequirement {
        doc /* The main battery shall be 48V. */
        subject battery : Battery;
        constraint { battery.voltage == 48 [SI::V] }
    }

    part deliverySystemContext {
        part deliveryRobot : DeliveryRobot;
        part chargingStation : ChargingStation;
        connect chargingStation.robotChargePort to deliveryRobot.chargingPort;

        requirement payloadReq : PayloadRequirement { :>> robot = deliveryRobot; }
        requirement navAccReq : NavigationAccuracyRequirement { :>> gps = deliveryRobot.sensorSuite.gps; }
        requirement obstacleReq : ObstacleDetectionRequirement { :>> lidar = deliveryRobot.sensorSuite.lidar; }
        requirement batteryLifeReq : BatteryLifeRequirement { :>> battery = deliveryRobot.powerSubsystem.mainBattery; }
        requirement batteryVoltReq : BatteryVoltageRequirement { :>> battery = deliveryRobot.powerSubsystem.mainBattery; }
    }
}
