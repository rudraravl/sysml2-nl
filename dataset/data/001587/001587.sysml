package 'Starship Autonomous Delivery Robot System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def GPSCoordinate {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute altitude : LengthValue;
    }
    
    attribute def Waypoint {
        attribute location : GPSCoordinate;
        attribute timestamp : Real;
    }
    
    attribute def DeliveryRoute {
        attribute waypoints : Waypoint[*] ordered;
        attribute totalDistance : LengthValue;
        attribute estimatedDuration : TimeValue;
    }
    
    attribute def ObstacleInfo {
        attribute distance : LengthValue;
        attribute azimuth : Real;
        attribute classification : ScalarValues::String;
        attribute velocity : SpeedValue;
    }
    
    item def DeliveryPackage {
        attribute mass : MassValue;
        attribute volume : VolumeValue;
        attribute recipientID : ScalarValues::String;
        attribute secureCode : ScalarValues::String;
    }
    
    attribute def BatteryStatus {
        attribute chargeLevel : Real;
        attribute voltage : Real;
        attribute current : Real;
        attribute temperature : TemperatureValue;
    }
    
    attribute def NavigationCommand {
        attribute targetWaypoint : Waypoint;
        attribute desiredSpeed : SpeedValue;
        attribute steeringAngle : Real;
    }
    
    port def SensorDataPort {
        out obstacleData : ObstacleInfo[*];
        out currentLocation : GPSCoordinate;
        out batteryStatus : BatteryStatus;
    }
    
    port def MotionControlPort {
        in navCommand : NavigationCommand;
        out actualSpeed : SpeedValue;
        out actualPosition : GPSCoordinate;
    }
    
    port def CargoManagementPort {
        in packageItem : DeliveryPackage;
        out cargoSecured : ScalarValues::Boolean;
        out unlockRequest : ScalarValues::String;
    }
    
    port def CommunicationPort {
        in deliveryOrder : ScalarValues::String;
        out statusUpdate : ScalarValues::String;
        out telemetry : Real[*];
    }
    
    part def LidarSensor {
        attribute scanRate : FrequencyValue;
        attribute maxRange : LengthValue;
        attribute angularResolution : Real;
        attribute pointsPerScan : ScalarValues::Integer;
        port sensorOut : SensorDataPort;
    }
    
    part def CameraArray {
        attribute numberOfCameras : ScalarValues::Integer;
        attribute resolution : ScalarValues::Integer[2];
        attribute frameRate : FrequencyValue;
        attribute fieldOfView : Real;
        port imageOut : SensorDataPort;
    }
    
    part def UltrasonicSensors {
        attribute numberOfSensors : ScalarValues::Integer;
        attribute detectionRange : LengthValue;
        attribute beamWidth : Real;
        port proximityOut : SensorDataPort;
    }
    
    part def GPSReceiver {
        attribute accuracy : LengthValue;
        attribute updateRate : FrequencyValue;
        port positionOut : SensorDataPort;
    }
    
    part def IMU {
        attribute gyroRange : Real;
        attribute accelRange : Real;
        attribute sampleRate : FrequencyValue;
        port motionOut : SensorDataPort;
    }
    
    part def PerceptionSystem {
        port lidarIn : SensorDataPort;
        port cameraIn : SensorDataPort;
        port ultrasonicIn : SensorDataPort;
        port fusedDataOut : SensorDataPort;
        
        part lidar : LidarSensor;
        part cameras : CameraArray;
        part ultrasonics : UltrasonicSensors;
        
        connect lidar.sensorOut to lidarIn;
        connect cameras.imageOut to cameraIn;
        connect ultrasonics.proximityOut to ultrasonicIn;
    }
    
    part def LocalizationSystem {
        port gpsIn : SensorDataPort;
        port imuIn : SensorDataPort;
        port locationOut : SensorDataPort;
        
        part gps : GPSReceiver;
        part imu : IMU;
        
        attribute estimatedPosition : GPSCoordinate;
        attribute positionCovariance : Real[9];
        
        connect gps.positionOut to gpsIn;
        connect imu.motionOut to imuIn;
    }
    
    part def PathPlanningSystem {
        port obstacleIn : SensorDataPort;
        port locationIn : SensorDataPort;
        
        attribute currentRoute : DeliveryRoute;
        attribute replanningThreshold : LengthValue;
    }
    
    part def MotionController {
        port commandIn : MotionControlPort;
        
        attribute pidGains : Real[3];
        attribute maxAcceleration : Real;
        attribute maxDeceleration : Real;
    }
    
    part def DriveSystem {
        port motionOut : MotionControlPort;
        
        attribute numberOfWheels : ScalarValues::Integer;
        attribute wheelDiameter : LengthValue;
        attribute maxTorque : ISQ::TorqueValue;
        attribute gearRatio : Real;
        
        part motors[6];
        part wheels[6];
    }
    
    part def SecureCargoCompartment {
        port cargoPort : CargoManagementPort;
        
        attribute internalVolume : VolumeValue;
        attribute maxPayload : MassValue;
        attribute isLocked : ScalarValues::Boolean;
        attribute temperatureControlled : ScalarValues::Boolean;
        attribute currentTemperature : TemperatureValue;
    }
    
    part def CommunicationModule {
        port commPort : CommunicationPort;
        
        attribute networkType : ScalarValues::String;
        attribute bandwidth : Real;
        attribute encryptionStandard : ScalarValues::String;
        attribute cloudConnected : ScalarValues::Boolean;
    }
    
    part def PowerManagementSystem {
        attribute batteryCapacity : ISQ::EnergyValue;
        attribute currentCharge : ISQ::EnergyValue;
        attribute solarPanelArea : ISQ::AreaValue;
        attribute powerConsumption : PowerValue;
    }
    
    action def SenseEnvironment {
        in sensorInputs : ObstacleInfo[*];
        out environmentModel : ObstacleInfo[*];
        out safetyStatus : ScalarValues::Boolean;
    }
    
    action def LocalizeRobot {
        in gpsData : GPSCoordinate;
        in imuData : Real[*];
        in mapData : Real[*];
        out estimatedPose : GPSCoordinate;
        out poseConfidence : Real;
    }
    
    action def PlanPath {
        in startLocation : GPSCoordinate;
        in goalLocation : GPSCoordinate;
        in obstacles : ObstacleInfo[*];
        out plannedRoute : DeliveryRoute;
        out routeFeasible : ScalarValues::Boolean;
    }
    
    action def ExecuteMotion {
        in route : DeliveryRoute;
        in currentPose : GPSCoordinate;
        in currentSpeed : SpeedValue;
        out motorCommands : NavigationCommand;
    }
    
    action def AvoidObstacle {
        in obstacleData : ObstacleInfo;
        in currentVelocity : SpeedValue;
        out evasiveManeuver : NavigationCommand;
        out emergencyStop : ScalarValues::Boolean;
    }
    
    action def SecureCargo {
        in packageItem : DeliveryPackage;
        out locked : ScalarValues::Boolean;
        out storageConfirmed : ScalarValues::Boolean;
    }
    
    action def ReleaseCargo {
        in authCode : ScalarValues::String;
        in expectedCode : ScalarValues::String;
        out unlocked : ScalarValues::Boolean;
        out cargoReleased : ScalarValues::Boolean;
    }
    
    action def AutonomousDeliveryMission {
        in deliveryOrder : ScalarValues::String;
        in pickupLocation : GPSCoordinate;
        in deliveryLocation : GPSCoordinate;
        in packageData : DeliveryPackage;
        out missionComplete : ScalarValues::Boolean;
        out missionStatus : ScalarValues::String;
        
        private attribute currentPosition : GPSCoordinate;
        private attribute currentSpeed : SpeedValue;
        private attribute routeToPickup : DeliveryRoute;
        private attribute routeToDelivery : DeliveryRoute;
        private attribute cargoLoaded : ScalarValues::Boolean := false;
        private attribute obstacles : ObstacleInfo[*];
        
        first start;
        
        then action planPickupRoute : PlanPath {
            in startLocation = currentPosition;
            in goalLocation = pickupLocation;
            in obstacles = AutonomousDeliveryMission::obstacles;
            out plannedRoute;
            out routeFeasible;
        }
        
        then assign routeToPickup := planPickupRoute.plannedRoute;
        
        then action navigateToPickup {
            action sense : SenseEnvironment {
                in sensorInputs;
                out environmentModel;
                out safetyStatus;
            }
            
            then assign obstacles := sense.environmentModel;
            
            then action localize : LocalizeRobot {
                in gpsData;
                in imuData;
                in mapData;
                out estimatedPose;
                out poseConfidence;
            }
            
            then assign currentPosition := localize.estimatedPose;
            
            then decide;
                if sense.safetyStatus == false then action avoid : AvoidObstacle {
                    in obstacleData;
                    in currentVelocity = currentSpeed;
                    out evasiveManeuver;
                    out emergencyStop;
                }
                if sense.safetyStatus == true then action move : ExecuteMotion {
                    in route = routeToPickup;
                    in currentPose = currentPosition;
                    in currentSpeed = AutonomousDeliveryMission::currentSpeed;
                    out motorCommands;
                }
        }
        
        then action loadPackage : SecureCargo {
            in packageItem = packageData;
            out locked;
            out storageConfirmed;
        }
        
        then assign cargoLoaded := loadPackage.storageConfirmed;
        
        then action planDeliveryRoute : PlanPath {
            in startLocation = pickupLocation;
            in goalLocation = deliveryLocation;
            in obstacles = AutonomousDeliveryMission::obstacles;
            out plannedRoute;
            out routeFeasible;
        }
        
        then assign routeToDelivery := planDeliveryRoute.plannedRoute;
        
        then action navigateToDelivery {
            action senseDelivery : SenseEnvironment {
                in sensorInputs;
                out environmentModel;
                out safetyStatus;
            }
            
            then assign obstacles := senseDelivery.environmentModel;
            
            then action localizeDelivery : LocalizeRobot {
                in gpsData;
                in imuData;
                in mapData;
                out estimatedPose;
                out poseConfidence;
            }
            
            then assign currentPosition := localizeDelivery.estimatedPose;
            
            then decide;
                if senseDelivery.safetyStatus == false then action avoidDelivery : AvoidObstacle {
                    in obstacleData;
                    in currentVelocity = currentSpeed;
                    out evasiveManeuver;
                    out emergencyStop;
                }
                if senseDelivery.safetyStatus == true then action moveDelivery : ExecuteMotion {
                    in route = routeToDelivery;
                    in currentPose = currentPosition;
                    in currentSpeed = AutonomousDeliveryMission::currentSpeed;
                    out motorCommands;
                }
        }
        
        then action unloadPackage : ReleaseCargo {
            in authCode;
            in expectedCode = packageData.secureCode;
            out unlocked;
            out cargoReleased;
        }
        
        then assign missionComplete := unloadPackage.cargoReleased;
        
        then done;
    }
    
    state def RobotOperationalStates {
        entry; then idle;
        
        state idle;
        
        transition idle_to_planning
            first idle
            accept newDeliveryOrder
            then planningRoute;
        
        state planningRoute;
        
        transition planning_to_navigatingPickup
            first planningRoute
            accept routeComputed
            then navigatingToPickup;
        
        state navigatingToPickup;
        
        transition navigatingPickup_to_loading
            first navigatingToPickup
            accept reachedPickup
            then loadingCargo;
        
        state loadingCargo;
        
        transition loading_to_navigatingDelivery
            first loadingCargo
            accept cargoSecured
            then navigatingToDelivery;
        
        state navigatingToDelivery;
        
        transition navigatingDelivery_to_delivering
            first navigatingToDelivery
            accept reachedDelivery
            then deliveringCargo;
        
        state deliveringCargo;
        
        transition delivering_to_idle
            first deliveringCargo
            accept cargoReleased
            then idle;
        
        state obstacleAvoidance;
        
        transition any_to_obstacleAvoidance
            accept criticalObstacleDetected
            then obstacleAvoidance;
        
        transition obstacleAvoidance_to_previous
            first obstacleAvoidance
            accept pathClear
            then navigatingToPickup;
        
        state charging;
        
        transition any_to_charging
            accept lowBattery
            then charging;
        
        transition charging_to_idle
            first charging
            accept fullyCharged
            then idle;
    }
    
    part starshipDeliveryRobot {
        attribute robotID : ScalarValues::String;
        attribute maxPayloadCapacity : MassValue;
        attribute batteryCapacity : ISQ::EnergyValue;
        attribute autonomousRange : LengthValue;
        attribute maxSpeed : SpeedValue;
        attribute operatingTemperatureRange : TemperatureValue[2];
        
        perform action deliveryMission[*] ordered : AutonomousDeliveryMission;
        exhibit state operationalState : RobotOperationalStates;
        
        part perception : PerceptionSystem;
        
        part localization : LocalizationSystem;
        
        part pathPlanner : PathPlanningSystem;
        
        part motionControl : MotionController;
        
        part driveSystem : DriveSystem;
        
        part cargoCompartment : SecureCargoCompartment;
        
        part communication : CommunicationModule;
        
        part powerSystem : PowerManagementSystem;
        
        connect perception.fusedDataOut to pathPlanner.obstacleIn;
        connect localization.locationOut to pathPlanner.locationIn;
    }
    
    requirement def SafetyRequirement {
        doc /* The delivery robot shall operate safely in pedestrian environments, 
                detecting and avoiding obstacles to prevent collisions. */
        
        subject robot : starshipDeliveryRobot;
        
        require constraint {
            robot.perception.lidar.maxRange >= 10.0[m]
        }
        
        require constraint {
            robot.maxSpeed <= 6.4[km/h]
        }
        
        require constraint {
            robot.perception.cameras.numberOfCameras >= 6
        }
    }
    
    requirement def PayloadRequirement {
        doc /* The delivery robot shall transport packages up to the specified 
                maximum payload capacity while maintaining stability and performance. */
        
        subject robot : starshipDeliveryRobot;
        
        require constraint {
            robot.cargoCompartment.maxPayload >= 9.0[kg]
        }
        
        require constraint {
            robot.cargoCompartment.internalVolume >= 0.056[m^3]
        }
    }
    
    requirement def RangeRequirement {
        doc /* The delivery robot shall complete deliveries within the specified 
                autonomous operating range on a single battery charge. */
        
        subject robot : starshipDeliveryRobot;
        
        require constraint {
            robot.autonomousRange >= 6.0[km]
        }
        
        require constraint {
            robot.batteryCapacity >= 400.0[W*h]
        }
    }
    
    requirement def AutonomyRequirement {
        doc /* The delivery robot shall navigate autonomously using onboard sensors 
                and computing, without requiring remote human control during normal operation. */
        
        subject robot : starshipDeliveryRobot;
        
        require constraint {
            robot.localization.gps.accuracy <= 2.0[m]
        }
    }
    
    requirement def SecurityRequirement {
        doc /* The delivery robot shall secure cargo during transport and release 
                only upon proper authentication at the delivery destination. */
        
        subject robot : starshipDeliveryRobot;
        
        require constraint {
            robot.cargoCompartment.isLocked == true
        }
    }
    
    requirement <'STAR-MAIN-001'> autonomousDeliveryCapability {
        doc /* The Starship delivery robot shall autonomously navigate from pickup 
                to delivery location, avoiding obstacles, securing cargo, and completing 
                deliveries safely in urban pedestrian environments. */
        
        subject robot : starshipDeliveryRobot;
        
        assume constraint validDeliveryRequest {
            doc /* A valid delivery request with authenticated pickup and delivery 
                    locations is provided through the communication system. */
        }
        
        require safetyReq : SafetyRequirement;
        require payloadReq : PayloadRequirement;
        require rangeReq : RangeRequirement;
        require autonomyReq : AutonomyRequirement;
        require securityReq : SecurityRequirement;
        
        require constraint successfulMission {
            robot.deliveryMission.missionComplete == true
        }
    }
}
