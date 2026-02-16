package 'Geographic Robotics System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def GeographicCoordinate {
		attribute latitude : ISQ::PlaneAngleValue;
		attribute longitude : ISQ::PlaneAngleValue;
		attribute elevation : ISQ::LengthValue;
	}
	
	attribute def GeographicRegion {
		attribute northWest : GeographicCoordinate;
		attribute southEast : GeographicCoordinate;
		attribute regionIdentifier : String;
	}
	
	attribute def Waypoint {
		attribute position : GeographicCoordinate;
		attribute waypointID : String;
		attribute arrivalRadius : ISQ::LengthValue;
	}
	
	attribute def NavigationRoute {
		attribute waypoints : Waypoint[2..*] ordered;
		attribute totalDistance : ISQ::LengthValue;
		attribute estimatedDuration : ISQ::TimeValue;
	}
	
	item def TerrainMap {
		attribute coverageRegion : GeographicRegion;
		attribute resolution : ISQ::LengthValue;
		attribute elevationData : Real[*];
		attribute obstacleLocations : GeographicCoordinate[*];
	}
	
	item def PositionReport {
		attribute currentLocation : GeographicCoordinate;
		attribute timestamp : ISQ::TimeValue;
		attribute positionAccuracy : ISQ::LengthValue;
		attribute heading : ISQ::PlaneAngleValue;
	}
	
	item def NavigationInstruction {
		attribute targetWaypoint : Waypoint;
		attribute commandedSpeed : ISQ::SpeedValue;
		attribute pathType : String;
	}
	
	item def SurveyData {
		attribute samplingLocation : GeographicCoordinate;
		attribute sensorReadings : Real[*];
		attribute dataQuality : Real;
	}
	
	port def PositioningPort {
		out item locationUpdate : PositionReport;
	}
	
	port def CommandPort {
		in item navigationCmd : NavigationInstruction;
		out item statusReport : String;
	}
	
	port def DataPort {
		in item dataRequest : String;
		out item dataResponse : TerrainMap;
	}
	
	port def SurveyPort {
		out item surveyOutput : SurveyData;
	}
	
	part def PositioningSystem {
		port positionOut : PositioningPort;
		
		attribute currentPosition : GeographicCoordinate;
		attribute positionError : ISQ::LengthValue;
		attribute updateRate : ISQ::FrequencyValue;
		
		action def AcquirePosition {
			out location : GeographicCoordinate;
			out accuracy : ISQ::LengthValue;
		}
		
		perform action updatePosition : AcquirePosition;
	}
	
	part def TerrainDatabase {
		port dataInterface : ~DataPort;
		
		attribute storedMaps : TerrainMap[*];
		attribute totalCoverage : ISQ::AreaValue;
		
		action def RetrieveMap {
			in requestedRegion : GeographicRegion;
			out mapData : TerrainMap;
		}
		
		perform action queryMap : RetrieveMap;
	}
	
	part def RouteCalculator {
		port commandInterface : ~CommandPort;
		
		attribute activeRoute : NavigationRoute;
		attribute currentWaypointIndex : Integer;
		attribute routingStrategy : String;
		
		action def PlanRoute {
			in startPoint : GeographicCoordinate;
			in endPoint : GeographicCoordinate;
			in terrain : TerrainMap;
			out calculatedRoute : NavigationRoute;
		}
		
		action def EvaluateProgress {
			in robotPosition : GeographicCoordinate;
			in targetPoint : Waypoint;
			out remainingDistance : ISQ::LengthValue;
			out waypointReached : Boolean;
		}
		
		perform action computeRoute : PlanRoute;
		perform action assessProgress : EvaluateProgress;
	}
	
	part def SurveyInstrument {
		port surveyOut : SurveyPort;
		
		attribute instrumentType : String;
		attribute samplingResolution : ISQ::LengthValue;
		attribute calibrationStatus : String;
		
		action def CollectData {
			in samplingPosition : GeographicCoordinate;
			out measurements : SurveyData;
		}
		
		perform action gatherSurveyData : CollectData;
	}
	
	part def AutonomousRobot {
		attribute robotIdentifier : String;
		attribute operationalMode : String;
		attribute energyLevel : Real;
		attribute maxSpeed : ISQ::SpeedValue;
		
		part positioning : PositioningSystem;
		part navigator : RouteCalculator;
		part surveyor : SurveyInstrument;
		
		connection posToNav connect positioning.positionOut to navigator;
		
		state def RobotOperations {
			entry; then Standby;
			
			state Standby {
				doc /* Robot is idle and awaiting mission assignment. */
			}
			
			state RouteExecution {
				doc /* Robot is actively navigating along planned route. */
			}
			
			state DataCollection {
				doc /* Robot is performing survey operations at waypoint. */
			}
			
			state Returning {
				doc /* Robot is returning to base location. */
			}
			
			transition startMission
				first Standby
				then RouteExecution;
			
			transition arrivedAtWaypoint
				first RouteExecution
				then DataCollection;
			
			transition surveyComplete
				first DataCollection
				then RouteExecution;
			
			transition missionComplete
				first RouteExecution
				then Returning;
			
			transition returnComplete
				first Returning
				then Standby;
		}
		
		perform action executeMission {
			out missionStatus : String;
		}
	}
	
	part def MissionCoordinator {
		attribute coordinationMode : String;
		attribute safetyPerimeter : ISQ::LengthValue;
		attribute missionPriority : Integer;
		
		part mapDatabase : TerrainDatabase;
		
		action def AssignMission {
			in targetRegion : GeographicRegion;
			in availableRobots : AutonomousRobot[*];
			out missionAssignments : NavigationInstruction[*];
		}
		
		action def MonitorProgress {
			in robotLocation : GeographicCoordinate;
			in plannedRoute : NavigationRoute;
			out pathDeviation : ISQ::LengthValue;
			out correctionNeeded : Boolean;
		}
		
		perform action allocateMissions : AssignMission;
		perform action trackRobots : MonitorProgress;
	}
	
	requirement def PositioningAccuracyRequirement {
		doc /* The system shall maintain geographic positioning accuracy within operational tolerance. */
		
		subject robot : AutonomousRobot;
		
		require constraint accuracyLimit {
			robot.positioning.positionError <= 3.0 [m]
		}
	}
	
	requirement def RouteComputationRequirement {
		doc /* The system shall compute navigation routes within acceptable time constraints. */
		
		subject calculator : RouteCalculator;
		
		require constraint computationTime {
			calculator.computeRoute.duration <= 5.0 [s]
		}
	}
	
	requirement def TerrainCoverageRequirement {
		doc /* The terrain database shall maintain map data with adequate resolution and coverage. */
		
		subject database : TerrainDatabase;
		
		require constraint mapResolution {
			database.storedMaps->forAll(map | map.resolution <= 0.5 [m])
		}
		
		require constraint coverageArea {
			database.totalCoverage >= 100.0 [km^2]
		}
	}
	
	requirement def SurveyDataQualityRequirement {
		doc /* Survey instruments shall collect data meeting quality standards. */
		
		subject instrument : SurveyInstrument;
		
		require constraint dataQuality {
			instrument.gatherSurveyData.measurements.dataQuality >= 0.95
		}
	}
	
	requirement <'GEO-SYS-001'> geographicRoboticsSystemMission {
		doc /* The geographic robotics system shall autonomously survey designated regions using coordinated robot operations. */
		
		assume constraint terrainAccessibility {
			doc /* Designated survey regions are accessible and free from prohibited zones. */
		}
		
		assume constraint positioningAvailability {
			doc /* Geographic positioning signals are available throughout operational area. */
		}
		
		require PositioningAccuracyRequirement;
		require RouteComputationRequirement;
		require TerrainCoverageRequirement;
		require SurveyDataQualityRequirement;
	}
	
	part geographicRoboticsSystem {
		doc /* 
		This system enables autonomous geographic survey operations using coordinated robotic platforms.
		
		The primary function is to systematically survey and collect data from designated geographic 
		regions by deploying autonomous robots that navigate using geographic coordinate systems, 
		terrain databases, and intelligent route planning.
		
		The system integrates positioning systems for accurate location tracking, terrain databases 
		for environmental awareness, route calculators for optimal path planning, and survey instruments 
		for data collection. A mission coordinator orchestrates robot deployments, monitors progress, 
		and ensures comprehensive coverage of target regions while maintaining operational safety and 
		efficiency. Robots autonomously navigate between waypoints, collect survey data at designated 
		locations, and adapt to terrain conditions while maintaining continuous position awareness.
		*/
		
		part coordinator : MissionCoordinator;
		part robot1 : AutonomousRobot {
			robotIdentifier = "GEO-R01";
			maxSpeed = 2.5 [m/s];
		}
		part robot2 : AutonomousRobot {
			robotIdentifier = "GEO-R02";
			maxSpeed = 2.0 [m/s];
		}
		
		connection dbToCoordinator connect coordinator.mapDatabase.dataInterface to coordinator;
		connection coordToRobot1 connect coordinator to robot1.navigator.commandInterface;
		connection coordToRobot2 connect coordinator to robot2.navigator.commandInterface;
		
		satisfy geographicRoboticsSystemMission;
		
		perform action autonomousGeographicSurvey {
			in surveyRegion : GeographicRegion;
			out collectedData : SurveyData[*] := ( );
			
			first start;
			then merge surveyLoop;
			
			action retrieveTerrain {
				in region : GeographicRegion;
				out terrain : TerrainMap;
			}
			bind retrieveTerrain = coordinator.mapDatabase.queryMap;
			
			then action planSurveyRoute {
				in area : GeographicRegion;
				in mapData : TerrainMap;
				out route : NavigationRoute;
			}
			bind planSurveyRoute = robot1.navigator.computeRoute;
			
			then action assignRobotMission {
				in targetArea : GeographicRegion;
				out instructions : NavigationInstruction[*];
			}
			bind assignRobotMission = coordinator.allocateMissions;
			
			then action executeNavigation {
				in navInstructions : NavigationInstruction[*];
			}
			
			then action acquireCurrentPosition {
				out position : GeographicCoordinate;
			}
			bind acquireCurrentPosition = robot1.positioning.updatePosition;
			
			then action evaluateRouteProgress {
				in robotPos : GeographicCoordinate;
				in plannedPath : NavigationRoute;
				out deviation : ISQ::LengthValue;
				out needsCorrection : Boolean;
			}
			bind evaluateRouteProgress = coordinator.trackRobots;
			
			then decide;
				if evaluateRouteProgress.needsCorrection then correctPath;
				if not evaluateRouteProgress.needsCorrection then continueNavigation;
			
			action correctPath {
				doc /* Recompute route when deviation exceeds safety threshold. */
			}
			then surveyLoop;
			
			action continueNavigation {
				doc /* Continue along current route. */
			}
			
			then action checkWaypointArrival {
				in currentPos : GeographicCoordinate;
				in targetWaypoint : Waypoint;
				out arrived : Boolean;
			}
			bind checkWaypointArrival = robot1.navigator.assessProgress;
			
			then decide;
				if checkWaypointArrival.arrived then performSurvey;
				if not checkWaypointArrival.arrived then surveyLoop;
			
			action performSurvey {
				in location : GeographicCoordinate;
				out surveyResult : SurveyData;
			}
			bind performSurvey = robot1.surveyor.gatherSurveyData;
			
			then assign collectedData := collectedData->including(performSurvey.surveyResult);
			
			then action advanceToNextWaypoint {
				doc /* Progress to next waypoint in survey route. */
			}
			
			then decide;
				if robot1.navigator.currentWaypointIndex >= robot1.navigator.activeRoute.waypoints->size() then completeSurvey;
				if robot1.navigator.currentWaypointIndex < robot1.navigator.activeRoute.waypoints->size() then surveyLoop;
			
			action completeSurvey {
				doc /* All waypoints surveyed, mission complete. */
			}
			then done;
		}
	}
}
