package OpenSourceRoboticsSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def Hertz :> Real;
    attribute def Meters :> Real;
    attribute def MetersPerSecond :> Real;
    attribute def RadiansPerSecond :> Real;
    attribute def MilliampereHours :> Real;
    attribute def Volts :> Real;
    attribute def Watts :> Real;
    
    item def LaserScanData {
        attribute ranges : Real[360];
        attribute intensities : Real[360];
        attribute angleMin : Real;
        attribute angleMax : Real;
        attribute angleIncrement : Real;
        attribute timeIncrement : Real;
        attribute scanTime : Real;
        attribute rangeMin : Meters;
        attribute rangeMax : Meters;
    }
    
    item def OdometryData {
        attribute positionX : Meters;
        attribute positionY : Meters;
        attribute positionZ : Meters;
        attribute orientationX : Real;
        attribute orientationY : Real;
        attribute orientationZ : Real;
        attribute orientationW : Real;
        attribute linearVelocityX : MetersPerSecond;
        attribute linearVelocityY : MetersPerSecond;
        attribute angularVelocityZ : RadiansPerSecond;
    }
    
    item def TwistCommand {
        attribute linearX : MetersPerSecond;
        attribute linearY : MetersPerSecond;
        attribute linearZ : MetersPerSecond;
        attribute angularX : RadiansPerSecond;
        attribute angularY : RadiansPerSecond;
        attribute angularZ : RadiansPerSecond;
    }
    
    item def BatteryState {
        attribute voltage : Volts;
        attribute current : Real;
        attribute charge : MilliampereHours;
        attribute capacity : MilliampereHours;
        attribute designCapacity : MilliampereHours;
        attribute percentage : Real;
        attribute powerSupplyStatus : Real;
    }
    
    item def MapData {
        attribute resolution : Meters;
        attribute width : Real;
        attribute height : Real;
        attribute originX : Meters;
        attribute originY : Meters;
        attribute data : Real[*];
    }
    
    port def LaserScanPort {
        out item scanData : LaserScanData;
    }
    
    port def OdometryPort {
        out item odomData : OdometryData;
    }
    
    port def VelocityCommandPort {
        in item velocityCmd : TwistCommand;
    }
    
    port def BatteryStatusPort {
        out item batteryStatus : BatteryState;
    }
    
    port def MapPort {
        out item mapData : MapData;
    }
    
    port def PowerSupplyPort {
        out item powerFlow : Watts;
    }
    
    part def LidarSensor {
        attribute scanFrequency : Hertz = 10.0;
        attribute fieldOfView : Real = 360.0;
        attribute maxRange : Meters = 12.0;
        attribute minRange : Meters = 0.12;
        attribute angularResolution : Real = 1.0;
        
        port laserOut : LaserScanPort;
        port powerIn : PowerSupplyPort;
        
        action performLaserScan {
            out scanResult : LaserScanData;
        }
    }
    
    part def WheelEncoder {
        attribute ticksPerRevolution : Real = 4096.0;
        attribute wheelDiameter : Meters = 0.066;
        
        port encoderOut : OdometryPort;
        port powerIn : PowerSupplyPort;
        
        action measureWheelRotation {
            out encoderTicks : Real;
        }
    }
    
    part def MotorDriver {
        attribute maxVoltage : Volts = 12.0;
        attribute maxCurrent : Real = 5.0;
        attribute maxSpeed : RadiansPerSecond = 10.0;
        
        port cmdIn : VelocityCommandPort;
        port powerIn : PowerSupplyPort;
        
        action executeVelocityCommand {
            in cmd : TwistCommand;
            out motorPWM : Real;
        }
    }
    
    part def BatteryPack {
        attribute nominalVoltage : Volts = 11.1;
        attribute capacity : MilliampereHours = 5200.0;
        attribute cellCount : Real = 3.0;
        attribute currentCharge : MilliampereHours = 5200.0;
        
        port batteryOut : BatteryStatusPort;
        port powerOut : PowerSupplyPort;
        
        state batteryLifecycle {
            entry; then charged;
            
            state charged;
            transition charged_to_discharging
                first charged
                accept at when currentCharge < capacity
                then discharging;
            
            state discharging;
            transition discharging_to_low
                first discharging
                accept at when currentCharge < 1560.0
                then lowBattery;
            
            state lowBattery;
            transition low_to_critical
                first lowBattery
                accept at when currentCharge < 520.0
                then criticalBattery;
            
            state criticalBattery;
        }
    }
    
    part def ComputeModule {
        attribute processorCores : Real = 4.0;
        attribute ramGB : Real = 4.0;
        attribute operatingSystem : String = "Ubuntu 20.04";
        attribute middleware : String = "ROS 2 Foxy";
        
        port sensorDataIn : LaserScanPort;
        port odomDataIn : OdometryPort;
        port velocityCmdOut : VelocityCommandPort;
        port mapDataOut : MapPort;
        port batteryStatusIn : BatteryStatusPort;
        port powerIn : PowerSupplyPort;
        
        action def ProcessSensorData {
            in laserData : LaserScanData;
            in odomData : OdometryData;
            out processedData : MapData;
        }
        
        action def PlanPath {
            in currentMap : MapData;
            in currentPose : OdometryData;
            in goalPose : OdometryData;
            out plannedPath : OdometryData[*];
        }
        
        action def GenerateVelocityCommand {
            in plannedPath : OdometryData[*];
            in currentPose : OdometryData;
            out velocityCommand : TwistCommand;
        }
        
        action autonomousNavigationCycle {
            first start;
            then merge navigationLoop;
            then action processSensors : ProcessSensorData;
            then action planPath : PlanPath {
                in currentMap = processSensors.processedData;
            }
            then action generateCmd : GenerateVelocityCommand {
                in plannedPath = planPath.plannedPath;
            }
            then action checkBatteryLevel;
            then decide;
                if checkBatteryLevel.batteryOk then navigationLoop;
                if not checkBatteryLevel.batteryOk then emergencyStop;
            action emergencyStop;
            then done;
        }
    }
    
    part def MobileBase {
        attribute wheelBase : Meters = 0.23;
        attribute wheelRadius : Meters = 0.033;
        attribute maxLinearVelocity : MetersPerSecond = 0.7;
        attribute maxAngularVelocity : RadiansPerSecond = 1.8;
        
        part leftMotor : MotorDriver;
        part rightMotor : MotorDriver;
        part leftEncoder : WheelEncoder;
        part rightEncoder : WheelEncoder;
        
        port cmdIn : VelocityCommandPort;
        port odomOut : OdometryPort;
        port powerIn : PowerSupplyPort;
        
        action differentialDriveControl {
            in twistCmd : TwistCommand;
            out leftWheelVel : RadiansPerSecond;
            out rightWheelVel : RadiansPerSecond;
        }
    }
    
    part def AutonomousMobileRobot {
        doc /* 
         * An open-source autonomous mobile robot platform designed for 
         * research and education. The robot performs simultaneous 
         * localization and mapping (SLAM) to navigate autonomously in 
         * unknown environments while avoiding obstacles.
         */
        
        attribute totalMass : Real = 2.5;
        attribute maxPayload : Real = 1.0;
        attribute operatingTime : Real = 120.0;
        
        part lidar : LidarSensor;
        part computer : ComputeModule;
        part mobileBase : MobileBase;
        part battery : BatteryPack;
        
        connect lidar.laserOut to computer.sensorDataIn;
        connect mobileBase.odomOut to computer.odomDataIn;
        connect computer.velocityCmdOut to mobileBase.cmdIn;
        connect battery.batteryOut to computer.batteryStatusIn;
        
        connect battery.powerOut to lidar.powerIn;
        connect battery.powerOut to computer.powerIn;
        connect battery.powerOut to mobileBase.powerIn;
        
        state operationalMode {
            entry; then initializing;
            
            state initializing;
            transition init_to_ready
                first initializing
                then ready;
            
            state ready;
            transition ready_to_navigating
                first ready
                then navigating;
            
            state navigating {
                entry perform computer.autonomousNavigationCycle;
            }
            transition navigating_to_obstacle
                first navigating
                then obstacleAvoidance;
            
            state obstacleAvoidance;
            transition obstacle_to_navigating
                first obstacleAvoidance
                then navigating;
            
            transition navigating_to_lowPower
                first navigating
                accept at when battery.currentCharge < 1560.0
                then lowPowerMode;
            
            state lowPowerMode;
            transition lowPower_to_shutdown
                first lowPowerMode
                accept at when battery.currentCharge < 520.0
                then shutdown;
            
            state shutdown;
        }
        
        perform action autonomousOperation {
            first start;
            then merge operationCycle;
            then action acquireSensorData {
                out laserScan : LaserScanData;
                out odometry : OdometryData;
            }
            then action buildMap {
                in laserScan : LaserScanData = acquireSensorData.laserScan;
                in odometry : OdometryData = acquireSensorData.odometry;
                out updatedMap : MapData;
            }
            then action planMotion {
                in currentMap : MapData = buildMap.updatedMap;
                in currentPose : OdometryData = acquireSensorData.odometry;
                out motionCommand : TwistCommand;
            }
            then action executeMotion {
                in command : TwistCommand = planMotion.motionCommand;
            }
            then action monitorBattery {
                out batteryLevel : Real;
            }
            then decide;
                if monitorBattery.batteryLevel > 30.0 then operationCycle;
                if monitorBattery.batteryLevel <= 30.0 then returnToBase;
            action returnToBase;
            then done;
        }
    }
    
    requirement <'REQ-OSR-001'> autonomousNavigationCapability {
        doc /* 
         * The robot shall autonomously navigate in unknown indoor 
         * environments using SLAM techniques to build a map and 
         * localize itself simultaneously.
         */
        subject robot : AutonomousMobileRobot;
    }
    
    requirement <'REQ-OSR-002'> obstacleDetectionAndAvoidance {
        doc /* 
         * The robot shall detect obstacles within its operational 
         * range and plan collision-free paths to navigate around them.
         */
        subject robot : AutonomousMobileRobot;
    }
    
    requirement <'REQ-OSR-003'> lidarSensingRange {
        doc /* 
         * The LIDAR sensor shall provide 360-degree scanning with 
         * a maximum range of at least 12 meters for environment 
         * perception.
         */
        subject lidar : LidarSensor;
        assert constraint {
            lidar.maxRange >= 12.0
        }
    }
    
    requirement <'REQ-OSR-004'> batteryOperatingTime {
        doc /* 
         * The robot shall operate continuously for at least 2 hours 
         * on a single battery charge under normal navigation conditions.
         */
        subject battery : BatteryPack;
        assert constraint {
            battery.capacity >= 5000.0
        }
    }
    
    requirement <'REQ-OSR-005'> maximumVelocity {
        doc /* 
         * The robot shall achieve a maximum linear velocity of at 
         * least 0.7 m/s for efficient navigation.
         */
        subject base : MobileBase;
        assert constraint {
            base.maxLinearVelocity >= 0.7
        }
    }
    
    requirement <'REQ-OSR-006'> openSourceMiddleware {
        doc /* 
         * The robot shall utilize open-source ROS 2 middleware for 
         * all software components to ensure community compatibility 
         * and extensibility.
         */
        subject compute : ComputeModule;
        assert constraint {
            compute.middleware == "ROS 2 Foxy"
        }
    }
    
    requirement <'REQ-OSR-007'> payloadCapacity {
        doc /* 
         * The robot shall support a payload capacity of at least 
         * 1.0 kg while maintaining navigation performance.
         */
        subject robot : AutonomousMobileRobot;
        assert constraint {
            robot.maxPayload >= 1.0
        }
    }
    
    requirement <'REQ-OSR-008'> lowBatteryHandling {
        doc /* 
         * The robot shall detect low battery conditions and 
         * autonomously return to a charging station when battery 
         * level falls below 30%.
         */
        subject robot : AutonomousMobileRobot;
    }
    
    part robotSystem : AutonomousMobileRobot {
        part :>> lidar {
            attribute :>> scanFrequency = 10.0;
            attribute :>> maxRange = 12.0;
        }
        
        part :>> battery {
            attribute :>> capacity = 5200.0;
            attribute :>> nominalVoltage = 11.1;
        }
        
        part :>> mobileBase {
            attribute :>> maxLinearVelocity = 0.7;
            attribute :>> maxAngularVelocity = 1.8;
        }
        
        part :>> computer {
            attribute :>> middleware = "ROS 2 Foxy";
        }
    }
    
    satisfy autonomousNavigationCapability by robotSystem;
    satisfy obstacleDetectionAndAvoidance by robotSystem;
    satisfy lidarSensingRange by robotSystem.lidar;
    satisfy batteryOperatingTime by robotSystem.battery;
    satisfy maximumVelocity by robotSystem.mobileBase;
    satisfy openSourceMiddleware by robotSystem.computer;
    satisfy payloadCapacity by robotSystem;
    satisfy lowBatteryHandling by robotSystem;
}
