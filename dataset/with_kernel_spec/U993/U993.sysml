package AUVSystem {
    private import ISQ::*;
    private import ScalarValues::*;
    
    attribute def GPSFix {
        attribute latitude : Real;
        attribute longitude : Real;
    }
    
    attribute def OrientationData {
        attribute roll : PlaneAngleValue;
        attribute pitch : PlaneAngleValue;
        attribute yaw : PlaneAngleValue;
    }
    
    attribute def Velocity3D {
        attribute x : SpeedValue;
        attribute y : SpeedValue;
        attribute z : SpeedValue;
    }
    
    attribute def PositionFix {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute depth : LengthValue;
        attribute heading : PlaneAngleValue;
        attribute speed : SpeedValue;
    }
    
    attribute def NavigationReading {
        attribute position : PositionFix;
        attribute orientation : OrientationData;
        attribute velocity : Velocity3D;
    }
    
    attribute def Waypoint {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute targetDepth : LengthValue;
        attribute targetSpeed : SpeedValue;
    }
    
    attribute def MissionPlan {
        attribute name : String;
        attribute waypoints : Waypoint[1..*];
    }
    
    attribute def ThrustCommand {
        attribute forwardThrust : Real;
        attribute verticalThrust : Real;
        attribute lateralThrust : Real;
        attribute yawMoment : Real;
    }
    
    attribute def PayloadCommand {
        attribute operation : String;
        attribute targetDepth : LengthValue;
    }
    
    attribute def SurveyData {
        attribute conductivity : Real;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute pressure : PressureValue;
        attribute depth : LengthValue;
        attribute image : String;
        attribute sonarMap : String;
    }
    
    attribute def SigStartMission;
    attribute def SigTargetDepthReached;
    attribute def SigWaypointReached;
    attribute def SigSurveyComplete;
    attribute def SigMissionComplete;
    attribute def SigEmergencyDetected;
    attribute def SigSurfaceReached;
    attribute def SigBatteryLow;
    
    part def BatteryPack {
        port powerOut {
            out attribute power : PowerValue;
        }
        port statusOut {
            out attribute chargeLevel : Real;
        }
        attribute chargeLevel : Real = 100.0;
    }
    
    part def PropulsionSystem {
        port powerIn {
            in attribute power : PowerValue;
        }
        port commandIn {
            in attribute command : ThrustCommand;
        }
        part forwardThruster;
        part verticalThruster;
        part lateralThruster;
        perform action applyThrust {
            in attribute command : ThrustCommand;
            first start;
            then action setForwardThrust;
            then action setVerticalThrust;
            then action setLateralThrust;
            then done;
        }
    }
    
    part def MissionController {
        port powerIn {
            in attribute power : PowerValue;
        }
        port powerStatusIn {
            in attribute chargeLevel : Real;
        }
        port navDataIn {
            in attribute navData : NavigationReading;
        }
        port propulsionCommandOut {
            out attribute command : ThrustCommand;
        }
        port payloadCommandOut {
            out attribute command : PayloadCommand;
        }
        port surveyDataIn {
            in attribute data : SurveyData;
        }
        port communicationDataOut {
            out attribute data : SurveyData;
        }
        attribute missionPlan : MissionPlan;
        attribute currentPosition : PositionFix;
        
        state auvStates {
            entry; then standby;
            state standby;
            state descending;
            state transiting;
            state surveying;
            state ascending;
            state emergencyAscent;
            
            transition standby_descending
                first standby
                accept SigStartMission
                then descending;
            transition descending_transiting
                first descending
                accept SigTargetDepthReached
                then transiting;
            transition transiting_surveying
                first transiting
                accept SigWaypointReached
                then surveying;
            transition transiting_ascending
                first transiting
                accept SigMissionComplete
                then ascending;
            transition transiting_emergency
                first transiting
                accept SigEmergencyDetected
                then emergencyAscent;
            transition surveying_transiting
                first surveying
                accept SigSurveyComplete
                then transiting;
            transition surveying_ascending
                first surveying
                accept SigMissionComplete
                then ascending;
            transition surveying_emergency
                first surveying
                accept SigEmergencyDetected
                then emergencyAscent;
            transition ascending_standby
                first ascending
                accept SigSurfaceReached
                then standby;
            transition ascending_emergency
                first ascending
                accept SigEmergencyDetected
                then emergencyAscent;
            transition emergency_standby
                first emergencyAscent
                accept SigSurfaceReached
                then standby;
        }
        
        perform action executeMission {
            in attribute plan : MissionPlan;
            out attribute command : ThrustCommand;
            first start;
            then action loadNextWaypoint;
            then action computeThrustCommand;
            then action issueThrustCommand;
            then done;
        }
    }
    
    part def NavigationSystem {
        port powerIn {
            in attribute power : PowerValue;
        }
        port navOut {
            out attribute navData : NavigationReading;
        }
        
        part gpsReceiver {
            port dataOut {
                out attribute fix : GPSFix;
            }
        }
        part inertialMeasurementUnit {
            port dataOut {
                out attribute orientation : OrientationData;
            }
        }
        part depthSensor {
            port dataOut {
                out attribute depth : LengthValue;
            }
        }
        part dopplerSonar {
            port dataOut {
                out attribute velocity : Velocity3D;
            }
        }
        
        perform action computeNavigation {
            in attribute fix : GPSFix;
            in attribute orientation : OrientationData;
            in attribute depth : LengthValue;
            in attribute velocity : Velocity3D;
            out attribute navData : NavigationReading;
            first start;
            then action mergeSensorData;
            then action estimatePosition;
            then done;
        }
    }
    
    part def SensorPayload {
        port powerIn {
            in attribute power : PowerValue;
        }
        port commandIn {
            in attribute command : PayloadCommand;
        }
        port dataOut {
            out attribute data : SurveyData;
        }
        part ctdSensor;
        part camera;
        part sonarSystem;
        perform action collectSurveyData {
            in attribute command : PayloadCommand;
            out attribute data : SurveyData;
            first start;
            then action collectCTD;
            then action captureImage;
            then action runSonar;
            then done;
        }
    }
    
    part def CommunicationSystem {
        port powerIn {
            in attribute power : PowerValue;
        }
        port dataIn {
            in attribute data : SurveyData;
        }
        part acousticModem;
        part satelliteTransceiver;
        perform action transmitData {
            in attribute data : SurveyData;
            first start;
            then action selectLink;
            then action sendData;
            then done;
        }
    }
    
    part auv {
        part hull {
            attribute material : String;
            attribute maxDepth : LengthValue;
        }
        part batteryPack : BatteryPack;
        part propulsionSystem : PropulsionSystem;
        part missionController : MissionController;
        part navigationSystem : NavigationSystem;
        part sensorPayload : SensorPayload;
        part communicationSystem : CommunicationSystem;
        
        connect batteryPack.powerOut to propulsionSystem.powerIn;
        connect batteryPack.powerOut to missionController.powerIn;
        connect batteryPack.powerOut to navigationSystem.powerIn;
        connect batteryPack.powerOut to sensorPayload.powerIn;
        connect batteryPack.powerOut to communicationSystem.powerIn;
        connect batteryPack.statusOut to missionController.powerStatusIn;
        connect missionController.propulsionCommandOut to propulsionSystem.commandIn;
        connect missionController.payloadCommandOut to sensorPayload.commandIn;
        connect navigationSystem.navOut to missionController.navDataIn;
        connect sensorPayload.dataOut to missionController.surveyDataIn;
        connect missionController.communicationDataOut to communicationSystem.dataIn;
    }
    
    requirement def AutonomousOperation {
        attribute minEndurance : DurationValue;
        attribute maxOperatingDepth : LengthValue;
        attribute minSurveySpeed : SpeedValue;
    }
    requirement autonomousOperationReq : AutonomousOperation;
}
