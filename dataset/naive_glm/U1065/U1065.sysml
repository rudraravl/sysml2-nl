package AutonomousSurveySystem {
    import ScalarValues::*;
    import ISQ::*;
    
    // Value types
    value def Distance :> Real { unit "m"; }
    value def Angle :> Real { unit "deg"; }
    value def Speed :> Real { unit "m/s"; }
    value def Time :> Real { unit "s"; }
    value def Accuracy :> Real { unit "m"; }
    
    item def GeographicCoordinate {
        attribute latitude : Angle;
        attribute longitude : Angle;
        attribute altitude : Distance;
    }
    
    item def Waypoint {
        attribute location : GeographicCoordinate;
        attribute sequenceNumber : Integer;
    }
    
    item def Route {
        attribute waypoints : Waypoint[0..*] ordered;
    }
    
    item def TerrainMap {
        attribute regionId : String;
        attribute elevationData : Real[0..*];
        attribute knownObstacles : GeographicCoordinate[0..*];
    }
    
    item def SurveyData {
        attribute timestamp : Time;
        attribute location : GeographicCoordinate;
        attribute payload : Real[0..*];
    }
    
    item def MissionPlan {
        attribute targetArea : String;
        attribute route : Route;
    }
    
    // Ports
    port def CoordinationPort {
        out attribute missionPlan : MissionPlan;
        in attribute robotStatus : String;
        in attribute surveyData : SurveyData;
    }
    
    port def NavigationPort {
        out attribute currentLocation : GeographicCoordinate;
        out attribute heading : Angle;
        out attribute speed : Speed;
    }
    
    port def CommandPort {
        out attribute targetWaypoint : Waypoint;
        out attribute collectData : Boolean;
    }
    
    // Requirements
    requirement def PositioningAccuracyRequirement {
        doc "The positioning system must provide location data with an accuracy of at least 2 meters."
        attribute maxError : Accuracy = 2 [m];
        subject positioningSystem : PositioningSystem;
        require positioningSystem.positionError <= maxError;
    }
    
    requirement def RoutePlanningSpeedRequirement {
        doc "The mission coordinator must plan a route within 5 seconds."
        attribute maxPlanningTime : Time = 5 [s];
        subject missionCoordinator : MissionCoordinator;
        require missionCoordinator.planningTime <= maxPlanningTime;
    }
    
    requirement def DataCollectionReliabilityRequirement {
        doc "The survey instrument must successfully collect data at each waypoint."
        subject surveyInstrument : SurveyInstrument;
        require surveyInstrument.collectionSuccessRate >= 0.99;
    }
    
    // Parts
    part def PositioningSystem {
        port navigationOut : NavigationPort;
        attribute positionError : Accuracy;
        attribute currentLocation : GeographicCoordinate;
        attribute heading : Angle;
        attribute speed : Speed;
        
        exhibit state PositioningBehavior {
            entry; then Tracking;
            state Tracking;
        }
    }
    
    part def RouteCalculator {
        port navigationIn : NavigationPort;
        port commandOut : CommandPort;
        attribute currentRoute : Route;
        attribute nextWaypointIndex : Integer;
        attribute arrivedAtWaypoint : Boolean;
        
        exhibit state NavigationBehavior {
            entry; then Idle;
            state Idle;
            state Navigating;
            state Arrived;
            
            transition from Idle to Navigating when currentRoute.waypoints->size() > 0;
            transition from Navigating to Arrived when arrivedAtWaypoint == true;
            transition from Arrived to Navigating when commandOut.collectData == false;
        }
    }
    
    part def SurveyInstrument {
        port commandIn : CommandPort;
        attribute collectedData : SurveyData[0..*];
        attribute collectionSuccessRate : Real;
        
        exhibit state InstrumentBehavior {
            entry; then Off;
            state Off;
            state Collecting;
            
            transition from Off to Collecting when commandIn.collectData == true;
            transition from Collecting to Off when commandIn.collectData == false;
        }
    }
    
    part def AutonomousRobot {
        port coordination : CoordinationPort;
        
        part positioningSystem : PositioningSystem;
        part routeCalculator : RouteCalculator;
        part surveyInstrument : SurveyInstrument;
        
        connection connectPositioningToRoute connect positioningSystem.navigationOut to routeCalculator.navigationIn;
        connection connectRouteToInstrument connect routeCalculator.commandOut to surveyInstrument.commandIn;
        
        attribute baseLocation : GeographicCoordinate;
        attribute missionComplete : Boolean;
        
        exhibit state RobotMissionStateMachine {
            entry; then Standby;
            
            state Standby;
            state RouteExecution;
            state DataCollection;
            state Returning;
            
            transition from Standby to RouteExecution when coordination.missionPlan != null;
            transition from RouteExecution to DataCollection when routeCalculator.arrivedAtWaypoint == true;
            transition from DataCollection to RouteExecution when surveyInstrument.commandIn.collectData == false;
            transition from RouteExecution to Returning when missionComplete == true;
            transition from Returning to Standby when positioningSystem.currentLocation == baseLocation;
        }
    }
    
    part def TerrainDatabase {
        attribute maps : TerrainMap[0..*];
        
        action def RetrieveMap(in regionId : String, out map : TerrainMap);
    }
    
    part def MissionCoordinator {
        port coordination : CoordinationPort[0..*];
        
        part terrainDatabase : TerrainDatabase;
        
        attribute planningTime : Time;
        attribute missionRequested : Boolean;
        attribute missionPlanGenerated : Boolean;
        attribute allRobotsReturned : Boolean;
        
        action def PlanMission(in targetArea : String, out missionPlan : MissionPlan);
        
        exhibit state CoordinatorBehavior {
            entry; then Idle;
            state Idle;
            state Planning;
            state Monitoring;
            
            transition from Idle to Planning when missionRequested == true;
            transition from Planning to Monitoring when missionPlanGenerated == true;
            transition from Monitoring to Idle when allRobotsReturned == true;
        }
    }
    
    part def SurveySystem {
        part missionCoordinator : MissionCoordinator;
        part robots : AutonomousRobot[1..*];
        
        requirement posAccReq : PositioningAccuracyRequirement;
        requirement routePlanReq : RoutePlanningSpeedRequirement;
        requirement dataColReq : DataCollectionReliabilityRequirement;
        
        connection connectCoordinatorToRobots connect missionCoordinator.coordination to robots.coordination;
    }
}
