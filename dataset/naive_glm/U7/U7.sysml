package AutonomousDeliverySystem {

    import ScalarValues::*;

    package Units {
        unit kg;
        unit m;
        unit V;
        unit h;
        unit deg;
        unit 'm/s';
        unit '%';
        unit A;
        unit W;
    }

    package ValueTypes {
        value type MassValue :> Real { unit 'kg'; }
        value type DistanceValue :> Real { unit 'm'; }
        value type VoltageValue :> Real { unit 'V'; }
        value type DurationValue :> Real { unit 'h'; }
        value type AngleValue :> Real { unit 'deg'; }
        value type SpeedValue :> Real { unit 'm/s'; }
        value type PercentageValue :> Real { unit '%'; }
        value type CurrentValue :> Real { unit 'A'; }
        value type PowerValue :> Real { unit 'W'; }
    }

    package Items {
        item def Package {
            attribute id : String;
            attribute mass : MassValue;
            attribute destination : String;
        }

        item def SensorData;

        item def LiDARScan :> SensorData {
            attribute range : DistanceValue;
            attribute angularResolution : AngleValue;
        }

        item def CameraImage :> SensorData {
            attribute resolution : String;
        }

        item def GPSFix :> SensorData {
            attribute latitude : Real;
            attribute longitude : Real;
            attribute accuracy : DistanceValue;
        }

        item def IMUData :> SensorData {
            attribute roll : AngleValue;
            attribute pitch : AngleValue;
            attribute yaw : AngleValue;
            attribute angularVelocity : Real;
        }

        item def NavigationPlan {
            attribute waypoints : String[*];
            attribute estimatedDuration : DurationValue;
        }

        item def MotorCommand {
            attribute leftSpeed : SpeedValue;
            attribute rightSpeed : SpeedValue;
        }

        item def FaultReport {
            attribute code : String;
            attribute description : String;
            attribute severity : String;
        }

        item def Power;
        item def ElectricalPower :> Power {
            attribute voltage : VoltageValue;
            attribute current : CurrentValue;
        }

        item def OperatorNotification {
            attribute message : String;
            attribute fault : FaultReport;
        }
    }

    package Ports {
        port def PowerPort {
            out power : Items::ElectricalPower;
        }

        port def PowerSinkPort {
            in power : Items::ElectricalPower;
        }

        port def SensorDataPort {
            out data : Items::SensorData;
        }

        port def SensorDataSinkPort {
            in data : Items::SensorData;
        }

        port def NavigationPlanPort {
            out plan : Items::NavigationPlan;
        }

        port def MotorCommandPort {
            in command : Items::MotorCommand;
        }

        port def PackagePort {
            inout pkg : Items::Package;
        }

        port def OperatorNotifyPort {
            out notification : Items::OperatorNotification;
        }

        port def ChargingPort {
            inout chargePower : Items::ElectricalPower;
        }
    }

    package Requirements {

        requirement def PayloadRequirement {
            doc "The delivery robot shall carry packages up to 25 kg without degradation of performance.";
            subject robot : DeliveryRobot;
            attribute maxPayload : ValueTypes::MassValue = 25 [kg];
            require { robot.cargoCompartment.payload.mass <= maxPayload }
        }

        requirement def ObstacleDetectionRequirement {
            doc "The LiDAR sensor shall detect obstacles up to 5 meters away in a 360-degree field."
            subject lidar : LiDARSensor;
            attribute detectionRange : ValueTypes::DistanceValue = 5 [m];
            require { lidar.maxRange >= detectionRange }
        }

        requirement def PositioningRequirement {
            doc "The GPS module shall provide positioning accuracy within 0.3 meters."
            subject gps : GPSModule;
            attribute requiredAccuracy : ValueTypes::DistanceValue = 0.3 [m];
            require { gps.accuracy <= requiredAccuracy }
        }

        requirement def EnduranceRequirement {
            doc "The robot shall operate for up to 10 hours on a single battery charge."
            subject robot : DeliveryRobot;
            attribute minOperatingTime : ValueTypes::DurationValue = 10 [h];
            require { robot.powerSubsystem.battery.capacity >= minOperatingTime }
        }

        requirement def AutonomousDeliveryRequirement {
            doc "The robot shall transport packages from a pickup point to a destination without human intervention."
            subject robot : DeliveryRobot;
            require { robot.controlSubsystem.autonomous == true }
        }

        requirement def FaultNotificationRequirement {
            doc "Upon entering an error state, the robot shall notify an operator."
            subject robot : DeliveryRobot;
            require { robot.controlSubsystem.notifiesOperatorOnError == true }
        }

        requirement def ChargingRequirement {
            doc "When the battery runs low, the robot shall autonomously navigate to the charging station."
            subject robot : DeliveryRobot;
            require { robot.controlSubsystem.autoReturnToCharge == true }
        }

        requirement def CargoSecurityRequirement {
            doc "The cargo compartment shall feature a locking mechanism and a sensor confirming load/unload events."
            subject cargo : CargoCompartment;
            require { cargo.lockingMechanism.present == true and cargo.loadSensor.present == true }
        }

        requirement def DifferentialDriveRequirement {
            doc "Propulsion shall be provided by two independently controlled electric motors, each connected to a rubber wheel."
            subject drive : DriveSubsystem;
            require { drive.motorCount == 2 and drive.motorsAreIndependent == true }
        }
    }

    package Components {

        abstract part def ElectricalComponent {
            port powerInput : Ports::PowerSinkPort;
            attribute nominalVoltage : ValueTypes::VoltageValue;
        }

        part def LiDARSensor :> ElectricalComponent {
            attribute maxRange : ValueTypes::DistanceValue = 5 [m];
            attribute fieldOfView : ValueTypes::AngleValue = 360 [deg];
            port scanOutput : Ports::SensorDataPort;
            action def Scan {
                out scan : Items::LiDARScan;
            }
            perform Scan;
        }

        part def Camera :> ElectricalComponent {
            attribute facing : String;
            attribute resolution : String;
            port imageOutput : Ports::SensorDataPort;
            action def Capture {
                out image : Items::CameraImage;
            }
            perform Capture;
        }

        part def GPSModule :> ElectricalComponent {
            attribute accuracy : ValueTypes::DistanceValue = 0.3 [m];
            port fixOutput : Ports::SensorDataPort;
            action def AcquireFix {
                out fix : Items::GPSFix;
            }
            perform AcquireFix;
        }

        part def IMU :> ElectricalComponent {
            port imuOutput : Ports::SensorDataPort;
            action def MeasureMotion {
                out data : Items::IMUData;
            }
            perform MeasureMotion;
        }

        part def SensorSuite {
            part lidar : LiDARSensor;
            part frontCamera : Camera { :>> facing = "front"; :>> resolution = "1920x1080"; }
            part rearCamera : Camera { :>> facing = "rear"; :>> resolution = "1920x1080"; }
            part gps : GPSModule;
            part imu : IMU;
        }

        part def NavigationProcessor :> ElectricalComponent {
            port lidarInput : Ports::SensorDataSinkPort;
            port frontCameraInput : Ports::SensorDataSinkPort;
            port rearCameraInput : Ports::SensorDataSinkPort;
            port gpsInput : Ports::SensorDataSinkPort;
            port imuInput : Ports::SensorDataSinkPort;
            port planOutput : Ports::NavigationPlanPort;

            action def FuseSensorData {
                in lidarScan : Items::LiDARScan;
                in frontImage : Items::CameraImage;
                in rearImage : Items::CameraImage;
                in gpsFix : Items::GPSFix;
                in imuData : Items::IMUData;
                out fusedEstimate : Items::SensorData;
            }

            action def PlanPath {
                in estimate : Items::SensorData;
                in destination : String;
                out plan : Items::NavigationPlan;
            }

            action def AvoidObstacles {
                in plan : Items::NavigationPlan;
                in lidarScan : Items::LiDARScan;
                out revisedPlan : Items::NavigationPlan;
            }

            perform FuseSensorData;
            perform PlanPath;
            perform AvoidObstacles;
        }

        part def ElectricMotor :> ElectricalComponent {
            attribute maxTorque : ValueTypes::PowerValue = 150 [W];
            port commandInput : Ports::MotorCommandPort;
            attribute commandedSpeed : ValueTypes::SpeedValue;
            action def Drive {
                in command : Items::MotorCommand;
            }
            perform Drive;
        }

        part def RubberWheel {
            attribute diameter : ValueTypes::DistanceValue = 0.25 [m];
            attribute material : String = "rubber";
        }

        part def DriveSubsystem {
            attribute motorCount : Integer = 2;
            attribute motorsAreIndependent : Boolean = true;
            part leftMotor : ElectricMotor;
            part rightMotor : ElectricMotor;
            part leftWheel : RubberWheel;
            part rightWheel : RubberWheel;
            port leftCommand : Ports::MotorCommandPort;
            port rightCommand : Ports::MotorCommandPort;
            connect leftCommand to leftMotor.commandInput;
            connect rightCommand to rightMotor.commandInput;
        }

        part def LockingMechanism {
            attribute present : Boolean = true;
            attribute locked : Boolean;
            action def Lock;
            action def Unlock;
            perform Lock;
            perform Unlock;
        }

        part def LoadSensor {
            attribute present : Boolean = true;
            attribute packagePresent : Boolean;
            port detectionOutput : Ports::SensorDataPort;
            action def DetectLoad {
                out event : Items::SensorData;
            }
            perform DetectLoad;
        }

        part def CargoCompartment {
            attribute maxPayload : ValueTypes::MassValue = 25 [kg];
            attribute payload : Items::Package;
            part lockingMechanism : LockingMechanism;
            part loadSensor : LoadSensor;
            port packagePort : Ports::PackagePort;
        }

        part def Battery {
            attribute nominalVoltage : ValueTypes::VoltageValue = 48 [V];
            attribute capacity : ValueTypes::DurationValue = 10 [h];
            attribute chargeLevel : ValueTypes::PercentageValue = 100 [%];
            port chargePort : Ports::ChargingPort;
            port powerOutput : Ports::PowerPort;
            action def Discharge {
                out power : Items::ElectricalPower;
            }
            action def Recharge {
                in chargePower : Items::ElectricalPower;
            }
            perform Discharge;
            perform Recharge;
        }

        part def PowerDistributionUnit {
            port mainInput : Ports::PowerSinkPort;
            port motorOutput : Ports::PowerPort;
            port sensorOutput : Ports::PowerPort;
            port controlOutput : Ports::PowerPort;
            action def Distribute {
                in input : Items::ElectricalPower;
                out toMotors : Items::ElectricalPower;
                out toSensors : Items::ElectricalPower;
                out toControl : Items::ElectricalPower;
            }
            perform Distribute;
        }

        part def PowerSubsystem {
            part battery : Battery;
            part distributionUnit : PowerDistributionUnit;
            connect battery.powerOutput to distributionUnit.mainInput;
        }

        part def ControlSubsystem :> ElectricalComponent {
            attribute autonomous : Boolean = true;
            attribute autoReturnToCharge : Boolean = true;
            attribute notifiesOperatorOnError : Boolean = true;
            port navigationPlanInput : Ports::NavigationPlanPort;
            port leftMotorCommand : Ports::MotorCommandPort;
            port rightMotorCommand : Ports::MotorCommandPort;
            port cargoSensorInput : Ports::SensorDataSinkPort;
            port batteryLevelInput : Ports::SensorDataSinkPort;
            port operatorPort : Ports::OperatorNotifyPort;
            port packagePort : Ports::PackagePort;

            action def DirectOperation {
                in plan : Items::NavigationPlan;
                out leftCommand : Items::MotorCommand;
                out rightCommand : Items::MotorCommand;
            }

            action def NotifyOperator {
                in fault : Items::FaultReport;
                out notification : Items::OperatorNotification;
            }

            perform DirectOperation;
            perform NotifyOperator;
        }
    }

    package System {

        part def DeliveryRobot {
            attribute maxPayload : ValueTypes::MassValue = 25 [kg];
            attribute operatingTime : ValueTypes::DurationValue = 10 [h];

            port operatorNotifyPort : Ports::OperatorNotifyPort;
            port chargingPort : Ports::ChargingPort;
            port packagePort : Ports::PackagePort;

            part controlSubsystem : Components::ControlSubsystem;
            part sensorSuite : Components::SensorSuite;
            part navigationProcessor : Components::NavigationProcessor;
            part driveSubsystem : Components::DriveSubsystem;
            part cargoCompartment : Components::CargoCompartment;
            part powerSubsystem : Components::PowerSubsystem;

            // Power distribution
            connect powerSubsystem.distributionUnit.motorOutput to driveSubsystem.leftMotor.powerInput;
            connect powerSubsystem.distributionUnit.motorOutput to driveSubsystem.rightMotor.powerInput;
            connect powerSubsystem.distributionUnit.sensorOutput to sensorSuite.lidar.powerInput;
            connect powerSubsystem.distributionUnit.sensorOutput to sensorSuite.frontCamera.powerInput;
            connect powerSubsystem.distributionUnit.sensorOutput to sensorSuite.rearCamera.powerInput;
            connect powerSubsystem.distributionUnit.sensorOutput to sensorSuite.gps.powerInput;
            connect powerSubsystem.distributionUnit.sensorOutput to sensorSuite.imu.powerInput;
            connect powerSubsystem.distributionUnit.sensorOutput to navigationProcessor.powerInput;
            connect powerSubsystem.distributionUnit.controlOutput to controlSubsystem.powerInput;

            // Sensor data to navigation processor
            connect sensorSuite.lidar.scanOutput to navigationProcessor.lidarInput;
            connect sensorSuite.frontCamera.imageOutput to navigationProcessor.frontCameraInput;
            connect sensorSuite.rearCamera.imageOutput to navigationProcessor.rearCameraInput;
            connect sensorSuite.gps.fixOutput to navigationProcessor.gpsInput;
            connect sensorSuite.imu.imuOutput to navigationProcessor.imuInput;

            // Navigation plan to control
            connect navigationProcessor.planOutput to controlSubsystem.navigationPlanInput;

            // Motor commands
            connect controlSubsystem.leftMotorCommand to driveSubsystem.leftCommand;
            connect controlSubsystem.rightMotorCommand to driveSubsystem.rightCommand;

            // Cargo sensor to control
            connect cargoCompartment.loadSensor.detectionOutput to controlSubsystem.cargoSensorInput;

            // Operator notification
            connect controlSubsystem.operatorPort to operatorNotifyPort;

            // Package interface
            connect cargoCompartment.packagePort to packagePort;

            // Charging interface
            connect powerSubsystem.battery.chargePort to chargingPort;

            satisfy Requirements::PayloadRequirement;
            satisfy Requirements::EnduranceRequirement;
            satisfy Requirements::AutonomousDeliveryRequirement;
            satisfy Requirements::FaultNotificationRequirement;
            satisfy Requirements::ChargingRequirement;

            exhibit state def RobotStates {
                entry;
                state idle;
                state navigating;
                state loading;
                state unloading;
                state returning;
                state charging;
                state error;

                transition from entry to idle;

                transition from idle to loading
                    when cargoCompartment.loadSensor.packagePresent == false
                    and packagePort.pkg != null;

                transition from loading to navigating
                    when cargoCompartment.loadSensor.packagePresent == true
                    and cargoCompartment.lockingMechanism.locked == true;

                transition from navigating to unloading
                    when navigationProcessor.PlanPath.destination == cargoCompartment.payload.destination;

                transition from unloading to returning
                    when cargoCompartment.loadSensor.packagePresent == false;

                transition from returning to charging
                    when powerSubsystem.battery.chargeLevel < 20 [%];

                transition from returning to idle
                    when powerSubsystem.battery.chargeLevel >= 20 [%]
                    and cargoCompartment.loadSensor.packagePresent == false;

                transition from charging to idle
                    when powerSubsystem.battery.chargeLevel >= 100 [%];

                transition from any to error
                    when controlSubsystem.faultDetected == true;

                transition from error to idle
                    when controlSubsystem.faultCleared == true;

                in entry action initialAction;
                in idle action awaitTask;
                in navigating action executeNavigation;
                in loading action secureCargo;
                in unloading action releaseCargo;
                in returning action returnToBase;
                in charging action rechargeBattery;
                in error action reportFault;
            }
        }

        part def ChargingStation {
            attribute outputVoltage : ValueTypes::VoltageValue = 48 [V];
            attribute outputCurrent : ValueTypes::CurrentValue = 20 [A];
            port chargingPort : Ports::ChargingPort;
            part powerSupply : Components::ElectricalComponent {
                :>> nominalVoltage = 48 [V];
                port chargeOutput : Ports::PowerPort;
                action def SupplyCharge {
                    out power : Items::ElectricalPower;
                }
                perform SupplyCharge;
            }
            connect powerSupply.chargeOutput to chargingPort.chargePower;
            action def DockRobot {
                in robot : DeliveryRobot;
            }
            perform DockRobot;
        }

        part def DeliverySystem {
            part robot : DeliveryRobot;
            part station : ChargingStation;
            connect robot.chargingPort to station.chargingPort;
        }
    }
}
