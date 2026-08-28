package AmazonScoutDeliveryRobot {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        attribute def MassValue :> Real;
        attribute def LengthValue :> Real;
        attribute def SpeedValue :> Real;
        attribute def AccelerationValue :> Real;
        attribute def ForceValue :> Real;
        attribute def TorqueValue :> Real;
        attribute def PowerValue :> Real;
        attribute def EnergyValue :> Real;
        attribute def TemperatureValue :> Real;
        attribute def AngleValue :> Real;
        attribute def StateOfChargeValue :> Real;
        attribute def LockedValue :> Boolean;
        
        attribute def SigMissionReceived;
        attribute def SigPackageLoaded;
        attribute def SigStartNavigation;
        attribute def SigDestinationReached;
        attribute def SigCustomerAuthenticated;
        attribute def SigPackageRetrieved;
        attribute def SigDeliveryConfirmed;
        attribute def SigNextMission;
        attribute def SigReturnToDepot;
        attribute def SigDepotReached;
        attribute def SigLowBattery;
        attribute def SigCriticalBattery;
        attribute def SigChargeStart;
        attribute def SigChargeComplete;
        attribute def SigEmergencyStop;
        
        item def PositionValue {
            attribute x : LengthValue;
            attribute y : LengthValue;
            attribute z : LengthValue;
        }
        
        item def MapData {
            attribute resolution : LengthValue;
            attribute obstacleCount : Integer;
        }
        
        item def RouteData {
            attribute waypointCount : Integer;
            attribute totalDistance : LengthValue;
        }
        
        item def Package {
            attribute mass : MassValue;
            attribute length : LengthValue;
            attribute width : LengthValue;
            attribute height : LengthValue;
            attribute targetTemperature : TemperatureValue;
        }
        
        port def DriveCommandOutPort {
            out attribute speedCmd : SpeedValue;
            out attribute torqueCmd : TorqueValue;
        }
        port def DriveCommandInPort {
            in attribute speedCmd : SpeedValue;
            in attribute torqueCmd : TorqueValue;
        }
        port def BrakeCommandOutPort {
            out attribute brakeForce : ForceValue;
        }
        port def BrakeCommandInPort {
            in attribute brakeForce : ForceValue;
        }
        port def SteeringCommandOutPort {
            out attribute steerAngle : AngleValue;
        }
        port def SteeringCommandInPort {
            in attribute steerAngle : AngleValue;
        }
        port def PowerSupplyOutPort {
            out attribute electricalPower : PowerValue;
            out attribute stateOfCharge : StateOfChargeValue;
        }
        port def PowerSupplyInPort {
            in attribute electricalPower : PowerValue;
            in attribute stateOfCharge : StateOfChargeValue;
        }
        port def LockControlOutPort {
            out attribute lockCmd : LockedValue;
        }
        port def LockControlInPort {
            in attribute lockCmd : LockedValue;
        }
        port def SensorDataOutPort {
            out attribute obstacleDistance : LengthValue;
            out attribute obstacleBearing : AngleValue;
        }
        port def SensorDataInPort {
            in attribute obstacleDistance : LengthValue;
            in attribute obstacleBearing : AngleValue;
        }
        port def PositionDataOutPort {
            out attribute latitude : Real;
            out attribute longitude : Real;
            out attribute altitude : LengthValue;
        }
        port def PositionDataInPort {
            in attribute latitude : Real;
            in attribute longitude : Real;
            in attribute altitude : LengthValue;
        }
        port def ImuDataOutPort {
            out attribute orientation : AngleValue;
            out attribute angularVelocity : Real;
            out attribute linearAcceleration : AccelerationValue;
        }
        port def ImuDataInPort {
            in attribute orientation : AngleValue;
            in attribute angularVelocity : Real;
            in attribute linearAcceleration : AccelerationValue;
        }
        port def CameraDataOutPort {
            out attribute imageData : Integer;
        }
        port def CameraDataInPort {
            in attribute imageData : Integer;
        }
        port def CommInPort {
            in attribute missionId : Integer;
            in attribute destinationLat : Real;
            in attribute destinationLon : Real;
        }
        port def CommOutPort {
            out attribute deliveryStatus : String;
        }
        
        action def ReadLidarData {
            out attribute obstacleDistance : LengthValue;
            out attribute obstacleBearing : AngleValue;
            first start;
            then done;
        }
        action def CaptureImage {
            out attribute imageData : Integer;
            first start;
            then done;
        }
        action def AcquireGpsPosition {
            out attribute latitude : Real;
            out attribute longitude : Real;
            out attribute altitude : LengthValue;
            first start;
            then done;
        }
        action def AcquireImuData {
            out attribute orientation : AngleValue;
            out attribute angularVelocity : Real;
            out attribute linearAcceleration : AccelerationValue;
            first start;
            then done;
        }
        action def BuildMap {
            in attribute obstacleDistance : LengthValue;
            in attribute obstacleBearing : AngleValue;
            in attribute imageData : Integer;
            out attribute currentMap : MapData;
            first start;
            then done;
        }
        action def PlanRoute {
            in attribute currentMap : MapData;
            in attribute destinationLat : Real;
            in attribute destinationLon : Real;
            out attribute currentRoute : RouteData;
            first start;
            then done;
        }
        action def NavigateToDestination {
            in attribute currentRoute : RouteData;
            in attribute obstacleDistance : LengthValue;
            in attribute obstacleBearing : AngleValue;
            out attribute speedCmd : SpeedValue;
            out attribute torqueCmd : TorqueValue;
            out attribute steerAngle : AngleValue;
            out attribute brakeForce : ForceValue;
            first start;
            then done;
        }
        action def AuthenticateCustomer {
            out attribute authResult : Boolean;
            first start;
            then done;
        }
        action def UnlockCargo {
            in attribute authResult : Boolean;
            out attribute lockCmd : LockedValue;
            first start;
            then done;
        }
        action def ConfirmDelivery {
            out attribute deliveryStatus : String;
            first start;
            then done;
        }
        action def MaintainTemperature {
            in attribute setPoint : TemperatureValue;
            out attribute currentTemp : TemperatureValue;
            first start;
            then done;
        }
        action def MonitorBattery {
            out attribute stateOfCharge : StateOfChargeValue;
            first start;
            then done;
        }
        
        part def LidarSensor {
            attribute scanRange : LengthValue;
            port obstacleOut : SensorDataOutPort;
            port powerIn : PowerSupplyInPort;
            perform action readLidar : ReadLidarData;
        }
        
        part def CameraSensor {
            attribute fieldOfView : AngleValue;
            port imageOut : CameraDataOutPort;
            port powerIn : PowerSupplyInPort;
            perform action captureImage : CaptureImage;
        }
        
        part def GpsReceiver {
            port positionOut : PositionDataOutPort;
            port powerIn : PowerSupplyInPort;
            perform action acquirePosition : AcquireGpsPosition;
        }
        
        part def InertialMeasurementUnit {
            port imuOut : ImuDataOutPort;
            port powerIn : PowerSupplyInPort;
            perform action acquireImuData : AcquireImuData;
        }
        
        part def PerceptionSystem {
            part frontLidar : LidarSensor {
                :>> scanRange = 10.0 [m];
            }
            part rearLidar : LidarSensor {
                :>> scanRange = 10.0 [m];
            }
            part frontCamera : CameraSensor {
                :>> fieldOfView = 120.0 [deg];
            }
            part leftSideCamera : CameraSensor {
                :>> fieldOfView = 90.0 [deg];
            }
            part rightSideCamera : CameraSensor {
                :>> fieldOfView = 90.0 [deg];
            }
            part gps : GpsReceiver;
            part imu : InertialMeasurementUnit;
            port obstacleDataOut : SensorDataOutPort;
            port positionDataOut : PositionDataOutPort;
            port imuDataOut : ImuDataOutPort;
            port cameraDataOut : CameraDataOutPort;
            port powerIn : PowerSupplyInPort;
            connect powerIn to frontLidar.powerIn;
            connect powerIn to rearLidar.powerIn;
            connect powerIn to frontCamera.powerIn;
            connect powerIn to leftSideCamera.powerIn;
            connect powerIn to rightSideCamera.powerIn;
            connect powerIn to gps.powerIn;
            connect powerIn to imu.powerIn;
            connect frontLidar.obstacleOut to obstacleDataOut;
            connect rearLidar.obstacleOut to obstacleDataOut;
            connect frontCamera.imageOut to cameraDataOut;
            connect leftSideCamera.imageOut to cameraDataOut;
            connect rightSideCamera.imageOut to cameraDataOut;
            connect gps.positionOut to positionDataOut;
            connect imu.imuOut to imuDataOut;
        }
        
        part def MapBuilder;
        part def RoutePlanner;
        part def ObstacleAvoidanceModule;
        part def MissionManager;
        
        part def AutonomyController {
            part mapBuilder : MapBuilder;
            part routePlanner : RoutePlanner;
            part obstacleAvoidance : ObstacleAvoidanceModule;
            part missionManager : MissionManager;
            port sensorDataIn : SensorDataInPort;
            port positionDataIn : PositionDataInPort;
            port imuDataIn : ImuDataInPort;
            port cameraDataIn : CameraDataInPort;
            port driveCmdOut : DriveCommandOutPort;
            port brakeCmdOut : BrakeCommandOutPort;
            port steerCmdOut : SteeringCommandOutPort;
            port lockCmdOut : LockControlOutPort;
            port powerIn : PowerSupplyInPort;
            port commIn : CommInPort;
            port commOut : CommOutPort;
            attribute currentMap : MapData;
            attribute currentRoute : RouteData;
            perform action buildMap : BuildMap;
            perform action planRoute : PlanRoute;
            perform action navigateToDestination : NavigateToDestination;
            perform action authenticateCustomer : AuthenticateCustomer;
            perform action unlockCargo : UnlockCargo;
            perform action confirmDelivery : ConfirmDelivery;
            exhibit state autonomousOperationStates {
                entry; then standby;
                state standby;
                transition standby_mapping first standby accept SigMissionReceived then mapping;
                state mapping;
                transition mapping_navigating first mapping accept SigStartNavigation then navigating;
                state navigating;
                transition navigating_authenticating first navigating accept SigDestinationReached then authenticating;
                state authenticating;
                transition authenticating_unlocking first authenticating accept SigCustomerAuthenticated then unlocking;
                state unlocking;
                transition unlocking_confirmed first unlocking accept SigPackageRetrieved then confirmed;
                state confirmed;
                transition confirmed_standby first confirmed accept SigDeliveryConfirmed then standby;
                transition confirmed_returning first confirmed accept SigReturnToDepot then returning;
                state returning;
                transition returning_standby first returning accept SigDepotReached then standby;
                transition standby_emergency first standby accept SigEmergencyStop then emergencyStop;
                transition navigating_emergency first navigating accept SigEmergencyStop then emergencyStop;
                state emergencyStop;
            }
        }
        
        part def ElectricDriveMotor {
            port commandIn : DriveCommandInPort;
            port powerIn : PowerSupplyInPort;
            attribute ratedPower : PowerValue;
        }
        
        part def SteeringActuator {
            port commandIn : SteeringCommandInPort;
            port powerIn : PowerSupplyInPort;
        }
        
        part def BrakeSystem {
            port commandIn : BrakeCommandInPort;
            port powerIn : PowerSupplyInPort;
        }
        
        part def Wheel {
            attribute diameter : LengthValue;
        }
        
        part def MobilitySystem {
            part leftDriveMotor : ElectricDriveMotor {
                :>> ratedPower = 150.0 [W];
            }
            part rightDriveMotor : ElectricDriveMotor {
                :>> ratedPower = 150.0 [W];
            }
            part steeringActuator : SteeringActuator;
            part serviceBrake : BrakeSystem;
            part wheels[6] : Wheel {
                :>> diameter = 0.25 [m];
            }
            port driveCmdIn : DriveCommandInPort;
            port brakeCmdIn : BrakeCommandInPort;
            port steerCmdIn : SteeringCommandInPort;
            port powerIn : PowerSupplyInPort;
            connect driveCmdIn to leftDriveMotor.commandIn;
            connect driveCmdIn to rightDriveMotor.commandIn;
            connect brakeCmdIn to serviceBrake.commandIn;
            connect steerCmdIn to steeringActuator.commandIn;
            connect powerIn to leftDriveMotor.powerIn;
            connect powerIn to rightDriveMotor.powerIn;
            connect powerIn to steeringActuator.powerIn;
            connect powerIn to serviceBrake.powerIn;
        }
        
        part def BatteryPack {
            attribute capacity : EnergyValue;
            attribute currentCharge : StateOfChargeValue;
            port powerOut : PowerSupplyOutPort;
            port chargeIn : PowerSupplyInPort;
            perform action monitorBattery : MonitorBattery;
            exhibit state batteryState {
                entry; then discharging;
                state discharging;
                transition discharging_charging first discharging accept SigChargeStart then charging;
                state charging;
                transition charging_discharging first charging accept SigChargeComplete then discharging;
                state low;
                transition discharging_low first discharging accept SigLowBattery then low;
                transition low_charging first low accept SigChargeStart then charging;
                state critical;
                transition low_critical first low accept SigCriticalBattery then critical;
                transition critical_charging first critical accept SigChargeStart then charging;
            }
        }
        
        part def TemperatureControlUnit {
            port powerIn : PowerSupplyInPort;
            attribute setPoint : TemperatureValue;
            perform action maintainTemperature : MaintainTemperature;
        }
        
        part def CargoDoorLock {
            port control : LockControlInPort;
            port powerIn : PowerSupplyInPort;
            attribute lockedStatus : LockedValue;
        }
        
        part def CargoCompartment {
            attribute internalTemperature : TemperatureValue;
            attribute locked : LockedValue;
            part temperatureControl : TemperatureControlUnit;
            part doorLock : CargoDoorLock;
            ref item shipment : Package;
            port lockControl : LockControlInPort;
            port powerIn : PowerSupplyInPort;
            connect lockControl to doorLock.control;
            connect powerIn to temperatureControl.powerIn;
            connect powerIn to doorLock.powerIn;
            exhibit state lockState {
                entry; then locked;
                state locked;
                transition locked_unlocked first locked accept SigCustomerAuthenticated then unlocked;
                state unlocked;
                transition unlocked_locked first unlocked accept SigPackageRetrieved then locked;
            }
        }
        
        part def CommunicationSystem {
            part radioReceiver;
            part radioTransmitter;
            part antenna;
            port missionOut : CommInPort;
            port statusIn : CommOutPort;
            port powerIn : PowerSupplyInPort;
        }
        
        part def ScoutRobot {
            attribute grossMass : MassValue;
            attribute maxSpeed : SpeedValue;
            attribute range : LengthValue;
            attribute batteryCharge : StateOfChargeValue;
            
            part perceptionSystem : PerceptionSystem;
            part autonomyController : AutonomyController;
            part mobilitySystem : MobilitySystem;
            part batteryPack : BatteryPack;
            part cargoCompartment : CargoCompartment;
            part communicationSystem : CommunicationSystem;
            
            connect batteryPack.powerOut to perceptionSystem.powerIn;
            connect batteryPack.powerOut to autonomyController.powerIn;
            connect batteryPack.powerOut to mobilitySystem.powerIn;
            connect batteryPack.powerOut to cargoCompartment.powerIn;
            connect batteryPack.powerOut to communicationSystem.powerIn;
            
            connect perceptionSystem.obstacleDataOut to autonomyController.sensorDataIn;
            connect perceptionSystem.positionDataOut to autonomyController.positionDataIn;
            connect perceptionSystem.imuDataOut to autonomyController.imuDataIn;
            connect perceptionSystem.cameraDataOut to autonomyController.cameraDataIn;
            
            connect autonomyController.driveCmdOut to mobilitySystem.driveCmdIn;
            connect autonomyController.brakeCmdOut to mobilitySystem.brakeCmdIn;
            connect autonomyController.steerCmdOut to mobilitySystem.steerCmdIn;
            connect autonomyController.lockCmdOut to cargoCompartment.lockControl;
            connect communicationSystem.missionOut to autonomyController.commIn;
            connect autonomyController.commOut to communicationSystem.statusIn;
            
            exhibit state deliveryStates {
                entry; then atDepot;
                state atDepot;
                transition atDepot_missionAccepted first atDepot accept SigMissionReceived then packageLoaded;
                state packageLoaded;
                transition packageLoaded_enRoute first packageLoaded accept SigPackageLoaded then enRoute;
                state enRoute;
                transition enRoute_arrived first enRoute accept SigDestinationReached then authenticatingCustomer;
                state authenticatingCustomer;
                transition authenticatingCustomer_cargoUnlocked first authenticatingCustomer accept SigCustomerAuthenticated then cargoUnlocked;
                state cargoUnlocked;
                transition cargoUnlocked_deliveryConfirmed first cargoUnlocked accept SigPackageRetrieved then deliveryConfirmed;
                state deliveryConfirmed;
                transition deliveryConfirmed_returning first deliveryConfirmed accept SigReturnToDepot then returningToDepot;
                transition deliveryConfirmed_next first deliveryConfirmed accept SigNextMission then atDepot;
                state returningToDepot;
                transition returningToDepot_atDepot first returningToDepot accept SigDepotReached then atDepot;
                transition enRoute_returning first enRoute accept SigReturnToDepot then returningToDepot;
                transition atDepot_emergency first atDepot accept SigEmergencyStop then emergencyStop;
                transition enRoute_emergency first enRoute accept SigEmergencyStop then emergencyStop;
                state emergencyStop;
            }
        }
        
        requirement def DeliveryRangeRequirement {
            doc /* The Scout shall complete a typical residential delivery route on a single battery charge. */
            attribute minimumRange : LengthValue;
        }
        
        requirement def ObstacleDetectionRequirement {
            doc /* The Scout shall provide 360-degree obstacle detection using front and rear lidar sensors. */
            attribute minimumDetectionRange : LengthValue;
        }
        
        requirement def CargoSecurityRequirement {
            doc /* The cargo compartment shall remain locked during transit and unlock only after customer authentication. */
            attribute lockedDuringTransit : LockedValue;
        }
        
        requirement def SafeNavigationRequirement {
            doc /* The Scout shall navigate sidewalks and pedestrian areas safely, stopping for obstacles within 5 meters. */
            attribute minimumStoppingDistance : LengthValue;
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part amazonScout : ScoutRobot {
            :>> grossMass = 45.0 [kg];
            :>> maxSpeed = 1.5 [m/s];
            :>> range = 24.0 [km];
            :>> batteryCharge = 100.0;
            
            :>> batteryPack.capacity = 1.2 [kWh];
            :>> batteryPack.currentCharge = 100.0;
            :>> cargoCompartment.internalTemperature = 20.0 [degC];
            :>> cargoCompartment.locked = true;
        }
        
        requirement deliveryRange : DeliveryRangeRequirement {
            :>> minimumRange = 20.0 [km];
        }
        requirement obstacleDetection : ObstacleDetectionRequirement {
            :>> minimumDetectionRange = 10.0 [m];
        }
        requirement cargoSecurity : CargoSecurityRequirement {
            :>> lockedDuringTransit = true;
        }
        requirement safeNavigation : SafeNavigationRequirement {
            :>> minimumStoppingDistance = 1.0 [m];
        }
    }
}
