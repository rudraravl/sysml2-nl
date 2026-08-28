package AutonomousGeographicSurveySystem {
    private import ScalarValues::*;
    
    value def LengthValue :> Real;
    value def TimeValue :> Real;
    value def AngleValue :> Real;
    value def SpeedValue :> Real;
    value def PercentageValue :> Real;
    
    item def Coordinate {
        attribute latitude : AngleValue;
        attribute longitude : AngleValue;
    }
    
    item def Waypoint {
        attribute id : Integer;
        attribute coordinate : Coordinate;
        attribute altitude : LengthValue;
        attribute surveyAction : String;
    }
    
    item def Route {
        attribute waypoints : Waypoint[1..*] ordered;
    }
    
    item def Obstacle {
        attribute coordinate : Coordinate;
        attribute radius : LengthValue;
        attribute description : String;
    }
    
    item def TerrainMap {
        attribute regionId : String;
        attribute elevationData : LengthValue[*] ordered;
        item obstacles : Obstacle[0..*];
    }
    
    item def NavigationInstruction {
        attribute missionId : String;
        attribute route : Route;
    }
    
    item def ProgressReport {
        attribute robotId : String;
        attribute currentCoordinate : Coordinate;
        attribute currentHeading : AngleValue;
        attribute currentAltitude : LengthValue;
        attribute batteryLevel : PercentageValue;
        attribute status : String;
    }
    
    item def SurveyData {
        attribute timestamp : TimeValue;
        attribute coordinate : Coordinate;
        attribute altitude : LengthValue;
        attribute sensorReading : Real;
        attribute dataType : String;
    }
    
    item def MissionRequest {
        attribute regionId : String;
    }
    
    item def MissionComplete {
        attribute missionId : String;
    }
    
    item def WaypointReached {
        attribute waypointId : Integer;
    }
    
    item def RouteComplete {
        attribute missionId : String;
    }
    
    item def BaseReached {
        attribute robotId : String;
    }
    
    item def SurveyNeeded {
        attribute waypointId : Integer;
    }
    
    part def MissionCoordinator {
        port robotCommPort {
            out item instruction : NavigationInstruction;
            in item report : ProgressReport;
            in item collectedData : SurveyData[*];
        }
        
        part terrainDatabase {
            item maps : TerrainMap[1..*];
        }
        
        action planMission {
            in attribute regionId : String;
            out item instruction : NavigationInstruction;
            
            first start;
            then action retrieveMap {
                in attribute regionId;
                out item map : TerrainMap;
            }
            then action generateRoute {
                in item map : TerrainMap;
                out item route : Route;
            }
            then action assignRobot {
                in item route : Route;
                out item instruction : NavigationInstruction;
            }
            then done;
        }
        
        action monitorProgress {
            in item report : ProgressReport;
            out attribute adjustmentNeeded : Boolean;
            
            first start;
            then action evaluateStatus {
                in item report : ProgressReport;
                out attribute onTrack : Boolean;
            }
            then action issueCorrection {
                in attribute onTrack : Boolean;
                out item instruction : NavigationInstruction;
            }
            then done;
        }
        
        state coordinatorState {
            state idle;
            state planning {
                do action planMission;
            }
            state monitoring {
                do action monitorProgress;
            }
            
            transition first idle
                accept missionRequest : MissionRequest
                then planning;
            
            transition first planning
                accept missionComplete : MissionComplete
                then monitoring;
            
            transition first monitoring
                accept missionComplete : MissionComplete
                then idle;
        }
    }
    
    part def SurveyInstrument {
        attribute instrumentType : String;
        port surveyDataPort {
            out item data : SurveyData;
        }
        action captureData {
            in attribute coordinate : Coordinate;
            in attribute altitude : LengthValue;
            out item data : SurveyData;
            
            first start;
            then action activateSensor;
            then action captureReading {
                out attribute sensorReading : Real;
            }
            then action packageData {
                in attribute coordinate;
                in attribute altitude;
                in attribute sensorReading;
                out item data;
            }
            then done;
        }
    }
    
    part def Camera :> SurveyInstrument {
        :>> instrumentType = "Camera";
    }
    
    part def LidarScanner :> SurveyInstrument {
        :>> instrumentType = "LiDAR";
    }
    
    part def AtmosphericSensor :> SurveyInstrument {
        :>> instrumentType = "AtmosphericSensor";
    }
    
    part def PositioningSystem {
        port dataPort {
            out attribute coordinate : Coordinate;
            out attribute heading : AngleValue;
            out attribute altitude : LengthValue;
        }
        action trackPosition {
            out attribute coordinate : Coordinate;
            out attribute heading : AngleValue;
            out attribute altitude : LengthValue;
            
            first start;
            then action readGPS {
                out attribute coordinate;
            }
            then action readCompass {
                out attribute heading;
            }
            then action readAltimeter {
                out attribute altitude;
            }
            then done;
        }
    }
    
    part def RouteCalculator {
        port instructionPort {
            in item instruction : NavigationInstruction;
        }
        port positionPort {
            in attribute coordinate : Coordinate;
            in attribute heading : AngleValue;
            in attribute altitude : LengthValue;
        }
        port controlPort {
            out attribute targetHeading : AngleValue;
            out attribute targetSpeed : SpeedValue;
            out attribute waypointReached : Boolean;
            out attribute routeComplete : Boolean;
        }
        
        action navigateToWaypoint {
            in item instruction : NavigationInstruction;
            in attribute currentCoordinate : Coordinate;
            in attribute currentHeading : AngleValue;
            out attribute targetHeading : AngleValue;
            out attribute targetSpeed : SpeedValue;
            out attribute waypointReached : Boolean;
            
            first start;
            then action extractNextWaypoint {
                in item instruction;
                out attribute targetCoordinate : Coordinate;
            }
            then action calculateBearing {
                in attribute currentCoordinate;
                in attribute targetCoordinate : Coordinate;
                out attribute targetHeading;
            }
            then action setSpeed {
                out attribute targetSpeed;
            }
            then action checkArrival {
                in attribute currentCoordinate;
                in attribute targetCoordinate;
                out attribute waypointReached;
            }
            then done;
        }
        
        action evaluateProgress {
            in attribute coordinate : Coordinate;
            in item instruction : NavigationInstruction;
            out attribute waypointReached : Boolean;
            out attribute routeComplete : Boolean;
        }
    }
    
    part def PropulsionUnit {
        port drivePort {
            in attribute targetHeading : AngleValue;
            in attribute targetSpeed : SpeedValue;
        }
        action drive {
            in attribute targetHeading;
            in attribute targetSpeed;
        }
    }
    
    part def AutonomousRobot {
        port coordinatorCommPort {
            in item instruction : NavigationInstruction;
            out item report : ProgressReport;
            out item collectedData : SurveyData[*];
        }
        
        part positioningSystem : PositioningSystem;
        part routeCalculator : RouteCalculator;
        part surveyInstrument : SurveyInstrument;
        part propulsionUnit : PropulsionUnit;
        
        action navigate;
        action collect;
        action returnToBase;
        
        connect positioningSystem.dataPort to routeCalculator.positionPort;
        connect coordinatorCommPort to routeCalculator.instructionPort;
        connect routeCalculator.controlPort to propulsionUnit.drivePort;
        
        state robotState {
            state standby;
            state routeExecution {
                do action navigate;
            }
            state dataCollection {
                do action collect;
            }
            state returning {
                do action returnToBase;
            }
            
            transition first standby
                accept instruction : NavigationInstruction via coordinatorCommPort
                then routeExecution;
            
            transition first routeExecution
                accept waypointReached : WaypointReached
                then dataCollection;
            
            transition first dataCollection
                accept surveyComplete : SurveyData
                then routeExecution;
            
            transition first routeExecution
                accept routeComplete : RouteComplete
                then returning;
            
            transition first returning
                accept baseReached : BaseReached
                then standby;
        }
    }
    
    part surveySystem {
        part coordinator : MissionCoordinator;
        part robots : AutonomousRobot[1..*];
        
        connect coordinator.robotCommPort to robots.coordinatorCommPort;
    }
    
    requirement def PositioningAccuracy {
        doc /* The positioning system shall provide location accuracy within 2 meters. */
        attribute requiredAccuracy : LengthValue = 2.0;
        attribute actualAccuracy : LengthValue;
        assert constraint { actualAccuracy <= requiredAccuracy }
    }
    
    requirement def RoutePlanningSpeed {
        doc /* The mission coordinator shall plan a route within 30 seconds. */
        attribute maxPlanningTime : TimeValue = 30.0;
        attribute actualPlanningTime : TimeValue;
        assert constraint { actualPlanningTime <= maxPlanningTime }
    }
    
    requirement def DataCollectionReliability {
        doc /* The survey instrument shall successfully collect data at each waypoint with at least 99% success rate. */
        attribute minSuccessRate : PercentageValue = 99.0;
        attribute actualSuccessRate : PercentageValue;
        assert constraint { actualSuccessRate >= minSuccessRate }
    }
    
    requirement def AutonomousOperation {
        doc /* The system shall operate without direct human intervention for complete missions. */
        attribute humanInterventionCount : Natural = 0;
        assert constraint { humanInterventionCount == 0 }
    }
    
    part coordinatorInstance : MissionCoordinator {
        satisfy RoutePlanningSpeed by planMission;
        satisfy AutonomousOperation by coordinatorState;
    }
    
    part robotInstance : AutonomousRobot {
        satisfy PositioningAccuracy by positioningSystem;
        satisfy DataCollectionReliability by surveyInstrument;
        satisfy AutonomousOperation by robotState;
    }
}
