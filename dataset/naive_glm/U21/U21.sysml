package InsectoidRobotModel {
    import ScalarValues::*;
    
    package Units {
        attribute def LengthValue :> Real;
        attribute def MassValue :> Real;
        attribute def TimeValue :> Real;
        attribute def AngleValue :> Real;
        attribute def AngularVelocityValue :> Real;
        attribute def VelocityValue :> Real;
        attribute def ForceValue :> Real;
        attribute def TorqueValue :> Real;
        attribute def VoltageValue :> Real;
        attribute def CurrentValue :> Real;
        attribute def EnergyValue :> Real;
        attribute def PowerValue :> Real;
        attribute def TemperatureValue :> Real;
        attribute def PressureValue :> Real;
        attribute def FrequencyValue :> Real;
        attribute def DataRateValue :> Real;
        
        unit m of LengthValue;
        unit kg of MassValue;
        unit s of TimeValue;
        unit rad of AngleValue;
        unit deg of AngleValue;
        unit rad_per_s of AngularVelocityValue;
        unit deg_per_s of AngularVelocityValue;
        unit m_per_s of VelocityValue;
        unit N of ForceValue;
        unit Nm of TorqueValue;
        unit V of VoltageValue;
        unit A of CurrentValue;
        unit Wh of EnergyValue;
        unit W of PowerValue;
        unit degC of TemperatureValue;
        unit Pa of PressureValue;
        unit Hz of FrequencyValue;
        unit GHz of FrequencyValue;
        unit Mbps of DataRateValue;
    }
    
    package ValueTypes {
        import Units::*;
        attribute def Distance :> LengthValue;
        attribute def Mass :> MassValue;
        attribute def Duration :> TimeValue;
        attribute def Angle :> AngleValue;
        attribute def AngularVelocity :> AngularVelocityValue;
        attribute def Speed :> VelocityValue;
        attribute def Force :> ForceValue;
        attribute def Torque :> TorqueValue;
        attribute def Voltage :> VoltageValue;
        attribute def Current :> CurrentValue;
        attribute def Energy :> EnergyValue;
        attribute def Power :> PowerValue;
        attribute def Temperature :> TemperatureValue;
        attribute def Pressure :> PressureValue;
        attribute def Frequency :> FrequencyValue;
        attribute def DataRate :> DataRateValue;
        attribute def Percentage :> Real;
    }
    
    package Items {
        import ValueTypes::*;
        item def Position3D {
            attribute x : Distance;
            attribute y : Distance;
            attribute z : Distance;
        }
        item def Orientation3D {
            attribute roll : Angle;
            attribute pitch : Angle;
            attribute yaw : Angle;
        }
        item def Pose3D {
            attribute position : Position3D;
            attribute orientation : Orientation3D;
        }
        item def Obstacle {
            attribute pose : Pose3D;
            attribute radius : Distance;
        }
        item def TargetObject {
            attribute pose : Pose3D;
            attribute mass : Mass;
            attribute detected : Boolean;
        }
        item def TerrainMap {
            attribute resolution : Distance;
            attribute origin : Position3D;
            attribute obstacleCount : Integer;
        }
        item def PointCloud {
            attribute count : Integer;
            attribute rangeMax : Distance;
        }
        item def ImageData {
            attribute widthPixels : Integer;
            attribute heightPixels : Integer;
            attribute timestamp : Duration;
        }
        item def ImuData {
            attribute accelerationX : Real;
            attribute accelerationY : Real;
            attribute accelerationZ : Real;
            attribute gyroX : AngularVelocity;
            attribute gyroY : AngularVelocity;
            attribute gyroZ : AngularVelocity;
        }
        item def ProximityReading {
            attribute distance : Distance;
            attribute detected : Boolean;
        }
        item def SensorFrame {
            attribute frontProx : ProximityReading;
            attribute sideLeftProx : ProximityReading;
            attribute sideRightProx : ProximityReading;
            attribute lidarCloud : PointCloud;
            attribute image : ImageData;
            attribute imu : ImuData;
        }
        item def JointCommand {
            attribute jointId : Integer;
            attribute targetAngle : Angle;
            attribute torqueLimit : Torque;
        }
        item def LegCommandSet {
            attribute legId : Integer;
            attribute coxaCmd : JointCommand;
            attribute femurCmd : JointCommand;
            attribute tibiaCmd : JointCommand;
            attribute gaitName : String;
        }
        item def ArmCommand {
            attribute baseAngle : Angle;
            attribute shoulderAngle : Angle;
            attribute elbowAngle : Angle;
            attribute wristAngle : Angle;
            attribute gripperPressure : Pressure;
            attribute gripperOpen : Boolean;
        }
        item def PowerFrame {
            attribute voltage : Voltage;
            attribute current : Current;
            attribute power : Power;
        }
        item def Telemetry {
            attribute pose : Pose3D;
            attribute batterySoc : Percentage;
            attribute gaitActive : String;
            attribute missionState : String;
            attribute timestamp : Duration;
        }
        item def MissionCommand {
            attribute targetLocation : Position3D;
            attribute returnLocation : Position3D;
            attribute objectMass : Mass;
            attribute priority : Integer;
        }
    }
    
    package Ports {
        import ValueTypes::*;
        import Items::*;
        port def PowerPort {
            attribute voltage : Voltage;
            attribute current : Current;
            attribute maxDraw : Power;
            in power : PowerFrame;
        }
        port def ProximityDataPort {
            attribute rate : Frequency;
            out reading : ProximityReading;
        }
        port def LidarDataPort {
            attribute rate : Frequency;
            out cloud : PointCloud;
        }
        port def CameraDataPort {
            attribute rate : Frequency;
            out image : ImageData;
        }
        port def ImuDataPort {
            attribute rate : Frequency;
            out imuData : ImuData;
        }
        port def CommandPort {
            attribute rate : Frequency;
            in legCommands : LegCommandSet;
            in armCommands : ArmCommand;
        }
        port def TelemetryOutPort {
            attribute rate : Frequency;
            out telemetry : Telemetry;
        }
        port def MissionLinkPort {
            in missionCommand : MissionCommand;
            out telemetry : Telemetry;
            attribute commRange : Distance;
        }
    }
    
    package Requirements {
        import ValueTypes::*;
        import Items::*;
        requirement def MissionRequirement {
            doc "Autonomous insectoid robot shall execute complex pick-and-place and material transport missions in challenging environments.";
        }
        requirement def LocomotionRequirement :> MissionRequirement {
            doc "Six insectoid legs, each with coxa, femur, and tibia segments driven by individual actuators.";
            attribute legCount : Integer = 6;
            attribute segmentsPerLeg : Integer = 3;
            attribute supportedGaits : String = "tripod, wave";
        }
        requirement def GaitAdaptationRequirement :> MissionRequirement {
            doc "Tripod gait for flat surfaces; wave gait for climbing or inclines.";
        }
        requirement def PerceptionRequirement :> MissionRequirement {
            doc "Front and side proximity, LiDAR, high-resolution camera, and IMU.";
        }
        requirement def ManipulatorRequirement :> MissionRequirement {
            doc "Multi-jointed manipulator arm with a force-sensing gripper.";
        }
        requirement def EnduranceRequirement :> MissionRequirement {
            doc "High-capacity rechargeable battery providing approximately two hours of operation.";
            attribute minEndurance : Duration = 7200 [s];
        }
        requirement def PowerDistributionRequirement :> MissionRequirement {
            doc "Central PDU manages energy flow to all subsystems.";
        }
        requirement def AutonomyRequirement :> MissionRequirement {
            doc "Onboard control computer performs continuous sense-plan-act cycle.";
        }
        requirement def NavigationMissionRequirement :> MissionRequirement {
            doc "Navigate to target object, grasp it, transport to return location, release it.";
        }
        requirement def ObstacleAvoidanceRequirement :> MissionRequirement {
            doc "Continuously scan for and avoid obstacles during navigation.";
        }
        requirement def RemoteControlRequirement :> MissionRequirement {
            doc "Remote control station for mission planning and monitoring.";
        }
    }
    
    package Sensors {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;
        part def Sensor {
            attribute name : String;
            attribute powerConsumption : Power;
            attribute samplingRate : Frequency;
            attribute operational : Boolean;
            port powerIn : PowerPort;
        }
        part def ProximitySensor :> Sensor {
            attribute maxRange : Distance;
            attribute minRange : Distance;
            attribute resolution : Distance;
            attribute lastReading : ProximityReading;
            port dataOut : ProximityDataPort;
            action read {
                out reading : ProximityReading;
            }
        }
        part def LidarUnit :> Sensor {
            attribute rangeMax : Distance;
            attribute angularResolution : Angle;
            attribute scanRate : Frequency;
            attribute lastCloud : PointCloud;
            port dataOut : LidarDataPort;
            action scan {
                out cloud : PointCloud;
            }
        }
        part def Camera :> Sensor {
            attribute resolutionWidth : Integer;
            attribute resolutionHeight : Integer;
            attribute fieldOfView : Angle;
            attribute lastFrame : ImageData;
            port dataOut : CameraDataPort;
            action capture {
                out image : ImageData;
            }
        }
        part def Imu :> Sensor {
            attribute gyroRange : AngularVelocity;
            attribute accelRange : Real;
            attribute lastImu : ImuData;
            port dataOut : ImuDataPort;
            action sample {
                out imuData : ImuData;
            }
        }
    }
    
    package Locomotion {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;
        part def JointActuator {
            attribute name : String;
            attribute maxTorque : Torque;
            attribute maxAngle : Angle;
            attribute currentAngle : Angle;
            attribute maxSpeed : AngularVelocity;
            port powerIn : PowerPort;
            port commandIn : CommandPort;
            action drive {
                in targetAngle : Angle;
                in torqueLimit : Torque;
            }
        }
        part def LegSegment {
            attribute name : String;
            attribute length : Distance;
            attribute mass : Mass;
            part actuator : JointActuator;
        }
        part def Leg {
            attribute legId : Integer;
            attribute mountPose : Pose3D;
            attribute forwardRange : Angle;
            part coxa : LegSegment {
                attribute name := "coxa";
                attribute length := 0.05 [m];
                attribute mass := 0.04 [kg];
            }
            part femur : LegSegment {
                attribute name := "femur";
                attribute length := 0.10 [m];
                attribute mass := 0.08 [kg];
            }
            part tibia : LegSegment {
                attribute name := "tibia";
                attribute length := 0.15 [m];
                attribute mass := 0.06 [kg];
            }
            port powerIn : PowerPort;
            port commandIn : CommandPort;
        }
        part def LocomotionSystem {
            attribute gaitName : String := "tripod";
            attribute terrainIsFlat : Boolean;
            attribute tripodSpeed : Speed := 0.5 [m_per_s];
            attribute waveSpeed : Speed := 0.15 [m_per_s];
            attribute currentSpeed : Speed;
            part leg1 : Leg { attribute legId := 1; }
            part leg2 : Leg { attribute legId := 2; }
            part leg3 : Leg { attribute legId := 3; }
            part leg4 : Leg { attribute legId := 4; }
            part leg5 : Leg { attribute legId := 5; }
            part leg6 : Leg { attribute legId := 6; }
            port powerIn : PowerPort;
            port commandIn : CommandPort;
            port telemetryOut : TelemetryOutPort;
            state machine gaitState {
                state Idle;
                state TripodGait;
                state WaveGait;
                state GaitTransition;
                transition initGait from Idle to TripodGait;
                transition requestWave from TripodGait to GaitTransition when not terrainIsFlat;
                transition requestTripod from WaveGait to GaitTransition when terrainIsFlat;
                transition enterTripod from GaitTransition to TripodGait when terrainIsFlat;
                transition enterWave from GaitTransition to WaveGait when not terrainIsFlat;
            }
            action step {
                in targetPose : Pose3D;
                in gaitRequest : String;
                out leg1Cmd : LegCommandSet;
                out leg2Cmd : LegCommandSet;
                out leg3Cmd : LegCommandSet;
                out leg4Cmd : LegCommandSet;
                out leg5Cmd : LegCommandSet;
                out leg6Cmd : LegCommandSet;
            }
        }
    }
    
    package Manipulator {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;
        part def ForceSensor {
            attribute name : String;
            attribute maxLoad : Force;
            attribute currentLoad : Force;
            attribute samplingRate : Frequency;
            port powerIn : PowerPort;
            action measure {
                out load : Force;
            }
        }
        part def ArmJoint {
            attribute jointId : Integer;
            attribute name : String;
            attribute maxTorque : Torque;
            attribute maxAngle : Angle;
            attribute currentAngle : Angle;
            attribute length : Distance;
            port powerIn : PowerPort;
            port commandIn : CommandPort;
            action drive {
                in targetAngle : Angle;
                in torqueLimit : Torque;
            }
        }
        part def Gripper {
            attribute maxForce : Force;
            attribute currentForce : Force;
            attribute targetPressure : Pressure;
            attribute gripperOpen : Boolean;
            part forceSensor : ForceSensor {
                attribute name := "gripperForceSensor";
                attribute maxLoad := 50 [N];
                attribute samplingRate := 100 [Hz];
            }
            port powerIn : PowerPort;
            port commandIn : CommandPort;
            state machine gripperState {
                state Open;
                state Closing;
                state Grasping;
                state Releasing;
                transition startClose from Open to Closing;
                transition makeContact from Closing to Grasping when forceSensor.currentLoad >= targetPressure;
                transition beginRelease from Grasping to Releasing;
                transition fullyOpen from Releasing to Open;
            }
        }
        part def ManipulatorArm {
            attribute name : String;
            attribute reach : Distance;
            attribute payload : Mass;
            part baseJoint : ArmJoint {
                attribute jointId := 0;
                attribute name := "base";
                attribute maxTorque := 5.0 [Nm];
                attribute length := 0.0 [m];
            }
            part shoulderJoint : ArmJoint {
                attribute jointId := 1;
                attribute name := "shoulder";
                attribute maxTorque := 4.0 [Nm];
                attribute length := 0.15 [m];
            }
            part elbowJoint : ArmJoint {
                attribute jointId := 2;
                attribute name := "elbow";
                attribute maxTorque := 3.0 [Nm];
                attribute length := 0.15 [m];
            }
            part wristJoint : ArmJoint {
                attribute jointId := 3;
                attribute name := "wrist";
                attribute maxTorque := 2.0 [Nm];
                attribute length := 0.10 [m];
            }
            part gripper : Gripper {
                attribute maxForce := 30 [N];
                attribute targetPressure := 5 [Pa];
            }
            port powerIn : PowerPort;
            port commandIn : CommandPort;
            port telemetryOut : TelemetryOutPort;
            action positionAndGrasp {
                in targetPose : Pose3D;
                in targetPressure : Pressure;
                action approachObject {
                    in pose : Pose3D;
                }
                action alignGripper {
                    in pose : Pose3D;
                }
                action closeGripper {
                    in pressure : Pressure;
                }
                flow targetPose to approachObject.pose;
                flow targetPose to alignGripper.pose;
                flow targetPressure to closeGripper.pressure;
            }
        }
    }
    
    package Power {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;
        part def Battery {
            attribute capacityWh : Energy;
            attribute nominalVoltage : Voltage;
            attribute currentCharge : Energy;
            attribute stateOfCharge : Percentage;
            attribute temperature : Temperature;
            port powerOut : PowerPort;
            state machine batteryState {
                state Discharging;
                state Low;
                state Critical;
                state Depleted;
                transition toLow from Discharging to Low when stateOfCharge < 0.2;
                transition toCritical from Low to Critical when stateOfCharge < 0.05;
                transition toDepleted from Critical to Depleted when stateOfCharge <= 0.0;
            }
            action consume {
                out draw : PowerFrame;
            }
        }
        part def PowerDistributionUnit {
            attribute name : String;
            attribute totalBudget : Power;
            attribute efficiency : Percentage;
            attribute legsAllocation : Power;
            attribute sensorsAllocation : Power;
            attribute manipulatorAllocation : Power;
            attribute computerAllocation : Power;
            port powerIn : PowerPort;
            port legsOut : PowerPort;
            port sensorsOut : PowerPort;
            port manipulatorOut : PowerPort;
            port computerOut : PowerPort;
            action distribute {
                in mainPower : PowerFrame;
                out legsPower : PowerFrame;
                out sensorsPower : PowerFrame;
                out manipulatorPower : PowerFrame;
                out computerPower : PowerFrame;
            }
        }
    }
    
    package Control {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;
        part def ControlComputer {
            attribute name : String;
            attribute clockSpeed : Frequency;
            attribute memoryGB : Real;
            attribute sensePlanActPeriod : Duration;
            attribute mapReady : Boolean;
            attribute distanceToTarget : Distance;
            attribute distanceToReturn : Distance;
            attribute distanceToHome : Distance;
            attribute armDeployed : Boolean;
            attribute gripperClosed : Boolean;
            attribute gripperOpen : Boolean;
            port powerIn : PowerPort;
            port frontProxIn : ProximityDataPort;
            port sideProxLeftIn : ProximityDataPort;
            port sideProxRightIn : ProximityDataPort;
            port lidarIn : LidarDataPort;
            port cameraIn : CameraDataPort;
            port imuIn : ImuDataPort;
            port legsCommandOut : CommandPort;
            port armCommandOut : CommandPort;
            port telemetryOut : TelemetryOutPort;
            port missionLink : MissionLinkPort;
            state machine missionState {
                state Boot;
                state Idle;
                state Scanning;
                state Navigating;
                state ApproachingTarget;
                state GraspingObject;
                state Transporting;
                state ReleasingObject;
                state ReturningHome;
                state Shutdown;
                transition bootComplete from Boot to Idle;
                transition startMission from Idle to Scanning;
                transition scanComplete from Scanning to Navigating when mapReady;
                transition reachTargetZone from Navigating to ApproachingTarget when distanceToTarget < 0.5 [m];
                transition deployArm from ApproachingTarget to GraspingObject when armDeployed;
                transition objectGrasped from GraspingObject to Transporting when gripperClosed;
                transition reachDropZone from Transporting to ReleasingObject when distanceToReturn < 0.5 [m];
                transition objectReleased from ReleasingObject to ReturningHome when gripperOpen;
                transition backAtHome from ReturningHome to Idle when distanceToHome < 0.5 [m];
                transition powerOff from Idle to Shutdown;
            }
            action sensePlanAct {
                in sensorFrame : SensorFrame;
                in mission : MissionCommand;
                out legCmds : LegCommandSet;
                out armCmds : ArmCommand;
                out telemetry : Telemetry;
                out selectedGait : String;
                action sense {
                    in raw : SensorFrame;
                    out terrainMap : TerrainMap;
                    out imu : ImuData;
                    out image : ImageData;
                    out frontProx : ProximityReading;
                    out sideLeftProx : ProximityReading;
                    out sideRightProx : ProximityReading;
                }
                action plan {
                    in terrainMap : TerrainMap;
                    in imu : ImuData;
                    in frontProx : ProximityReading;
                    in sideLeftProx : ProximityReading;
                    in sideRightProx : ProximityReading;
                    in mission : MissionCommand;
                    out legCmds : LegCommandSet;
                    out armCmds : ArmCommand;
                    out gaitName : String;
                }
                action act {
                    in legCmds : LegCommandSet;
                    in armCmds : ArmCommand;
                }
                action report {
                    in imu : ImuData;
                    in gaitName : String;
                    out telemetry : Telemetry;
                }
                flow sensorFrame to sense.raw;
                flow sense.terrainMap to plan.terrainMap;
                flow sense.imu to plan.imu;
                flow sense.frontProx to plan.frontProx;
                flow sense.sideLeftProx to plan.sideLeftProx;
                flow sense.sideRightProx to plan.sideRightProx;
                flow mission to plan.mission;
                flow plan.legCmds to act.legCmds;
                flow plan.armCmds to act.armCmds;
                flow sense.imu to report.imu;
                flow plan.gaitName to report.gaitName;
                flow plan.legCmds to legCmds;
                flow plan.armCmds to armCmds;
                flow plan.gaitName to selectedGait;
                flow report.telemetry to telemetry;
            }
        }
    }
    
    package RemoteControlStation {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;
        part def ControlStation {
            attribute name : String;
            attribute commRange : Distance;
            attribute operatorInterface : String;
            port missionLink : MissionLinkPort;
            state machine stationState {
                state Offline;
                state Standby;
                state Planning;
                state Monitoring;
                state Fault;
                transition powerOn from Offline to Standby;
                transition beginPlan from Standby to Planning;
                transition deployPlan from Planning to Monitoring;
                transition faultDetected from Monitoring to Fault;
                transition recoverFault from Fault to Standby;
                transition stopMission from Monitoring to Standby;
            }
            action planMission {
                in operatorInput : String;
                out command : MissionCommand;
            }
            action monitor {
                in telemetry : Telemetry;
            }
        }
    }
    
    package Robot {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;
        import Sensors::*;
        import Locomotion::*;
        import Manipulator::*;
        import Power::*;
        import Control::*;
        part def InsectoidRobot {
            attribute name : String := "Hexapod";
            attribute totalMass : Mass;
            attribute maxSpeed : Speed;
            attribute operatingTempMin : Temperature;
            attribute operatingTempMax : Temperature;
            part battery : Battery {
                attribute capacityWh := 200 [Wh];
                attribute nominalVoltage := 24 [V];
                attribute currentCharge := 200 [Wh];
                attribute stateOfCharge := 1.0;
                attribute temperature := 25 [degC];
            }
            part pdu : PowerDistributionUnit {
                attribute name := "PDU";
                attribute totalBudget := 80 [W];
                attribute efficiency := 0.95;
                attribute legsAllocation := 40 [W];
                attribute sensorsAllocation := 15 [W];
                attribute manipulatorAllocation := 15 [W];
                attribute computerAllocation := 10 [W];
            }
            part locomotion : LocomotionSystem {
                attribute gaitName := "tripod";
                attribute terrainIsFlat := true;
                attribute tripodSpeed := 0.5 [m_per_s];
                attribute waveSpeed := 0.15 [m_per_s];
            }
            part frontProx : ProximitySensor {
                attribute name := "frontProx";
                attribute maxRange := 1.0 [m];
                attribute minRange := 0.02 [m];
                attribute resolution := 0.01 [m];
                attribute powerConsumption := 0.5 [W];
                attribute samplingRate := 50 [Hz];
            }
            part sideProxLeft : ProximitySensor {
                attribute name := "sideProxLeft";
                attribute maxRange := 0.8 [m];
                attribute minRange := 0.02 [m];
                attribute resolution := 0.01 [m];
                attribute powerConsumption := 0.5 [W];
                attribute samplingRate := 50 [Hz];
            }
            part sideProxRight : ProximitySensor {
                attribute name := "sideProxRight";
                attribute maxRange := 0.8 [m];
                attribute minRange := 0.02 [m];
                attribute resolution := 0.01 [m];
                attribute powerConsumption := 0.5 [W];
                attribute samplingRate := 50 [Hz];
            }
            part lidar : LidarUnit {
                attribute name := "lidar";
                attribute rangeMax := 12.0 [m];
                attribute angularResolution := 0.5 [deg];
                attribute scanRate := 10 [Hz];
                attribute powerConsumption := 8 [W];
                attribute samplingRate := 10 [Hz];
            }
            part camera : Camera {
                attribute name := "camera";
                attribute resolutionWidth := 1920;
                attribute resolutionHeight := 1080;
                attribute fieldOfView := 1.05 [rad];
                attribute powerConsumption := 4 [W];
                attribute samplingRate := 30 [Hz];
            }
            part imu : Imu {
                attribute name := "imu";
                attribute gyroRange := 8.7 [rad_per_s];
                attribute accelRange := 4.0;
                attribute powerConsumption := 0.2 [W];
                attribute samplingRate := 200 [Hz];
            }
            part manipulator : ManipulatorArm {
                attribute name := "manipulatorArm";
                attribute reach := 0.5 [m];
                attribute payload := 0.5 [kg];
            }
            part computer : ControlComputer {
                attribute name := "onboardComputer";
                attribute clockSpeed := 1.8 [GHz];
                attribute memoryGB := 8;
                attribute sensePlanActPeriod := 0.1 [s];
                attribute mapReady := false;
                attribute distanceToTarget := 100 [m];
                attribute distanceToReturn := 100 [m];
                attribute distanceToHome := 100 [m];
                attribute armDeployed := false;
                attribute gripperClosed := false;
                attribute gripperOpen := true;
            }
            port missionLink : MissionLinkPort {
                attribute commRange := 500 [m];
            }
            connection batteryToPdu connect battery.powerOut to pdu.powerIn;
            connection pduToLocomotion connect pdu.legsOut to locomotion.powerIn;
            connection pduToFrontProx connect pdu.sensorsOut to frontProx.powerIn;
            connection pduToSideProxLeft connect pdu.sensorsOut to sideProxLeft.powerIn;
            connection pduToSideProxRight connect pdu.sensorsOut to sideProxRight.powerIn;
            connection pduToLidar connect pdu.sensorsOut to lidar.powerIn;
            connection pduToCamera connect pdu.sensorsOut to camera.powerIn;
            connection pduToImu connect pdu.sensorsOut to imu.powerIn;
            connection pduToManipulator connect pdu.manipulatorOut to manipulator.powerIn;
            connection pduToComputer connect pdu.computerOut to computer.powerIn;
            connection frontProxToComputer connect frontProx.dataOut to computer.frontProxIn;
            connection leftProxToComputer connect sideProxLeft.dataOut to computer.sideProxLeftIn;
            connection rightProxToComputer connect sideProxRight.dataOut to computer.sideProxRightIn;
            connection lidarToComputer connect lidar.dataOut to computer.lidarIn;
            connection cameraToComputer connect camera.dataOut to computer.cameraIn;
            connection imuToComputer connect imu.dataOut to computer.imuIn;
            connection legsCmd connect computer.legsCommandOut to locomotion.commandIn;
            connection armCmd connect computer.armCommandOut to manipulator.commandIn;
            connection telemetryToMissionLink connect computer.telemetryOut to missionLink;
        }
    }
    
    package System {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;
        import Robot::*;
        import RemoteControlStation::*;
        import Requirements::*;
        part def InsectoidRobotSystem {
            attribute systemName : String := "InsectoidRobotSystem";
            part robot : InsectoidRobot {
                attribute totalMass := 6.0 [kg];
                attribute maxSpeed := 0.5 [m_per_s];
                attribute operatingTempMin := -10 [degC];
                attribute operatingTempMax := 50 [degC];
            }
            part station : ControlStation {
                attribute name := "GroundStation";
                attribute commRange := 500 [m];
                attribute operatorInterface := "GUI";
            }
            connection robotStationLink connect robot.missionLink to station.missionLink;
            satisfy MissionRequirement;
            satisfy LocomotionRequirement;
            satisfy GaitAdaptationRequirement;
            satisfy PerceptionRequirement;
            satisfy ManipulatorRequirement;
            satisfy EnduranceRequirement;
            satisfy PowerDistributionRequirement;
            satisfy AutonomyRequirement;
            satisfy NavigationMissionRequirement;
            satisfy ObstacleAvoidanceRequirement;
            satisfy RemoteControlRequirement;
        }
    }
}
