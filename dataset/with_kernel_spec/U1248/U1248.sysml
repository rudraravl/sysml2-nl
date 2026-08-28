package AutonomousUAVSystem {
    attribute def MissionStartSignal;
    attribute def AltitudeReachedSignal;
    attribute def WaypointReachedSignal;
    attribute def WaypointsCompleteSignal;
    attribute def SurveillanceCompleteSignal;
    attribute def AtBaseSignal;
    attribute def LandedSignal;
    attribute def LowBatteryAlert;
    attribute def EmergencyLandingCompleteSignal;
    attribute def SigManualMode;
    attribute def SigAutoMode;

    item def Electricity;
    item def GpsData {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute altitude : Real;
    }
    item def ImuData {
        attribute roll : Real;
        attribute pitch : Real;
        attribute yaw : Real;
    }
    item def LidarData {
        attribute ranges : Real[0..*];
    }
    item def Imagery;
    item def RouteData;
    item def TelemetryData {
        attribute batteryStatus : Real;
        attribute position : GpsData;
        attribute imuOrientation : ImuData;
    }
    item def NavigationCommand;

    item def Waypoint {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute altitude : Real;
        attribute speed : Real;
    }

    item def MissionPlan {
        attribute waypoints : Waypoint[0..*];
    }

    enum def FlightMode {
        autonomous;
        manual;
        returnToBase;
    }

    port def PowerPort {
        out electricity : Electricity;
    }
    port def GpsDataPort {
        out gpsData : GpsData;
    }
    port def ImuDataPort {
        out imuData : ImuData;
    }
    port def LidarDataPort {
        out lidarData : LidarData;
    }
    port def CameraDataPort {
        out imagery : Imagery;
    }
    port def RoutePort {
        out routeData : RouteData;
    }
    port def PropulsionCmdPort {
        out throttle : Real;
        out controlSurfaces : Real;
    }
    port def TelemetryPort {
        out telemetry : TelemetryData;
    }
    port def NavCmdPort {
        out navCmd : NavigationCommand;
    }
    port def MissionPlanPort {
        out missionPlan : MissionPlan;
    }
    port def GroundLinkPort {
        in command : NavigationCommand;
        in missionPlan : MissionPlan;
        out telemetry : TelemetryData;
        out cameraFeed : Imagery;
    }
    port def ShaftPort;

    action def PerformPreFlightChecks;
    action def ExecuteTakeoff;
    action def NavigateToWaypoint;
    action def AvoidObstacles;
    action def CaptureSurveillanceData;
    action def ExecuteReturnToBase;
    action def ExecuteLanding;
    action def ExecuteEmergencyLanding;

    state def UAVLifecycle {
        entry; then preFlight;
        state preFlight;
        accept MissionStartSignal then takeoff;
        accept LowBatteryAlert then emergency;
        state takeoff;
        accept AltitudeReachedSignal then transit;
        accept LowBatteryAlert then emergency;
        state transit;
        accept WaypointReachedSignal then surveillance;
        accept WaypointsCompleteSignal then returnToBase;
        accept LowBatteryAlert then emergency;
        state surveillance;
        accept SurveillanceCompleteSignal then transit;
        accept WaypointsCompleteSignal then returnToBase;
        accept LowBatteryAlert then emergency;
        state returnToBase;
        accept AtBaseSignal then landing;
        accept LowBatteryAlert then emergency;
        state landing;
        accept LandedSignal then done;
        state done;
        state emergency;
        accept EmergencyLandingCompleteSignal then done;
    }

    state def FlightModeStates {
        entry; then autonomous;
        state autonomous;
        accept SigManualMode then manual;
        accept LowBatteryAlert then returnToBaseMode;
        state manual;
        accept SigAutoMode then autonomous;
        state returnToBaseMode;
    }

    part def Battery {
        attribute chargeLevel : Real;
        port powerOut : PowerPort;
    }

    part def PowerManagement {
        port powerIn : ~PowerPort;
        port powerOut : PowerPort;
        perform action monitorBattery {
            out attribute status : Real;
            first start;
            then action readBatteryLevel;
            then done;
        }
    }

    part def PowerSystem {
        port powerOut : PowerPort;
        part battery : Battery;
        part powerManagement : PowerManagement;
        connect battery.powerOut to powerManagement.powerIn;
        bind powerOut = powerManagement.powerOut;
    }

    part def Motor {
        port powerIn : ~PowerPort;
        port cmdIn : ~PropulsionCmdPort;
        port shaft : ShaftPort;
    }

    part def Propeller {
        port shaft : ~ShaftPort;
    }

    part def PropulsionSystem {
        port powerIn : ~PowerPort;
        port cmdPort : ~PropulsionCmdPort;
        part motor : Motor;
        part propeller : Propeller;
        bind powerIn = motor.powerIn;
        bind cmdPort = motor.cmdIn;
        connect motor.shaft to propeller.shaft;
    }

    part def GPS {
        port powerIn : ~PowerPort;
        port dataOut : GpsDataPort;
    }

    part def IMU {
        port powerIn : ~PowerPort;
        port dataOut : ImuDataPort;
    }

    part def Camera {
        port powerIn : ~PowerPort;
        port dataOut : CameraDataPort;
    }

    part def LIDAR {
        port powerIn : ~PowerPort;
        port dataOut : LidarDataPort;
    }

    part def SensorSuite {
        port powerIn : ~PowerPort;
        port gpsOut : GpsDataPort;
        port imuOut : ImuDataPort;
        port lidarOut : LidarDataPort;
        port cameraOut : CameraDataPort;
        part gps : GPS;
        part imu : IMU;
        part camera : Camera;
        part lidar : LIDAR;
        bind powerIn = gps.powerIn;
        bind powerIn = imu.powerIn;
        bind powerIn = camera.powerIn;
        bind powerIn = lidar.powerIn;
        bind gpsOut = gps.dataOut;
        bind imuOut = imu.dataOut;
        bind lidarOut = lidar.dataOut;
        bind cameraOut = camera.dataOut;
    }

    part def FlightController {
        port powerIn : ~PowerPort;
        port imuIn : ~ImuDataPort;
        port lidarIn : ~LidarDataPort;
        port routeIn : ~RoutePort;
        port propulsionCmdOut : PropulsionCmdPort;
        port telemetryOut : TelemetryPort;
        port navCmdOut : NavCmdPort;
        port cmdIn : ~NavCmdPort;
        attribute currentMode : FlightMode;
        exhibit state flightModes : FlightModeStates;
    }

    part def NavigationSystem {
        port powerIn : ~PowerPort;
        port gpsIn : ~GpsDataPort;
        port missionPlanIn : ~MissionPlanPort;
        port routeOut : RoutePort;
        port navCmdIn : ~NavCmdPort;
        attribute currentPlan : MissionPlan;
        perform action computeRoute {
            in attribute missionPlan : MissionPlan;
            in attribute currentPosition : GpsData;
            out attribute route : RouteData;
            first start;
            then action planPath;
            then done;
        }
    }

    part def CommunicationSystem {
        port powerIn : ~PowerPort;
        port telemetryIn : ~TelemetryPort;
        port cameraFeedIn : ~CameraDataPort;
        port cmdOut : NavCmdPort;
        port missionPlanOut : MissionPlanPort;
        port groundLink : GroundLinkPort;
        bind groundLink.command = cmdOut.navCmd;
        bind groundLink.missionPlan = missionPlanOut.missionPlan;
        bind telemetryIn.telemetry = groundLink.telemetry;
        bind cameraFeedIn.imagery = groundLink.cameraFeed;
    }

    part def UnmannedVehicle {
        part powerSystem : PowerSystem;
        part propulsionSystem : PropulsionSystem;
        part sensorSuite : SensorSuite;
        part flightController : FlightController;
        part navigationSystem : NavigationSystem;
        part communicationSystem : CommunicationSystem;

        connect powerSystem.powerOut to propulsionSystem.powerIn;
        connect powerSystem.powerOut to sensorSuite.powerIn;
        connect powerSystem.powerOut to flightController.powerIn;
        connect powerSystem.powerOut to navigationSystem.powerIn;
        connect powerSystem.powerOut to communicationSystem.powerIn;

        connect flightController.propulsionCmdOut to propulsionSystem.cmdPort;
        connect sensorSuite.gpsOut to navigationSystem.gpsIn;
        connect sensorSuite.imuOut to flightController.imuIn;
        connect sensorSuite.lidarOut to flightController.lidarIn;
        connect sensorSuite.cameraOut to communicationSystem.cameraFeedIn;
        connect navigationSystem.routeOut to flightController.routeIn;
        connect flightController.navCmdOut to navigationSystem.navCmdIn;
        connect flightController.telemetryOut to communicationSystem.telemetryIn;
        connect communicationSystem.cmdOut to flightController.cmdIn;
        connect communicationSystem.missionPlanOut to navigationSystem.missionPlanIn;

        exhibit state uavLifecycle : UAVLifecycle;
    }

    part def GroundControlStation {
        port uavLink : ~GroundLinkPort;
        part missionPlanner {
            port missionPlanOut : MissionPlanPort;
        }
        part telemetryMonitor {
            port telemetryIn : ~TelemetryPort;
            port cameraIn : ~CameraDataPort;
        }
        part operatorInterface {
            port cmdOut : NavCmdPort;
        }
        bind uavLink.missionPlan = missionPlanner.missionPlanOut.missionPlan;
        bind uavLink.command = operatorInterface.cmdOut.navCmd;
        bind telemetryMonitor.telemetryIn.telemetry = uavLink.telemetry;
        bind telemetryMonitor.cameraIn.imagery = uavLink.cameraFeed;
    }

    requirement def AutonomousMissionExecution {
        doc /* The UAV shall execute pre-planned missions without continuous human intervention. */
        subject uav : UnmannedVehicle;
    }
    requirement def ObstacleAvoidanceRequirement {
        doc /* The UAV shall detect and avoid obstacles during transit using LIDAR. */
        subject uav : UnmannedVehicle;
    }
    requirement def EmergencyLandingRequirement {
        doc /* The UAV shall perform an emergency landing upon critical failure or low battery. */
        subject uav : UnmannedVehicle;
    }
    requirement def TelemetryReportingRequirement {
        doc /* The UAV shall transmit telemetry data to the ground control station continuously. */
        subject uav : UnmannedVehicle;
    }
    requirement def SurveillanceDataCollection {
        doc /* The UAV shall collect imagery and sensor data at each waypoint during surveillance. */
        subject uav : UnmannedVehicle;
    }

    part uavSystem {
        part uav : UnmannedVehicle;
        part gcs : GroundControlStation;

        interface uavGcsLink connect uav.communicationSystem.groundLink to gcs.uavLink {
            flow telemetryDownlink of TelemetryData
                from uav.communicationSystem.groundLink.telemetry to gcs.uavLink.telemetry;
            flow cameraDownlink of Imagery
                from uav.communicationSystem.groundLink.cameraFeed to gcs.uavLink.cameraFeed;
            flow commandUplink of NavigationCommand
                from gcs.uavLink.command to uav.communicationSystem.groundLink.command;
            flow missionPlanUplink of MissionPlan
                from gcs.uavLink.missionPlan to uav.communicationSystem.groundLink.missionPlan;
        }

        requirement req_AutonomousMission : AutonomousMissionExecution {
            subject :>> uav = uav;
        }
        requirement req_ObstacleAvoidance : ObstacleAvoidanceRequirement {
            subject :>> uav = uav;
        }
        requirement req_EmergencyLanding : EmergencyLandingRequirement {
            subject :>> uav = uav;
        }
        requirement req_TelemetryReporting : TelemetryReportingRequirement {
            subject :>> uav = uav;
        }
        requirement req_Surveillance : SurveillanceDataCollection {
            subject :>> uav = uav;
        }
    }
}
