package 'Robotic Mapping System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def Pose2D {
		attribute x : LengthValue;
		attribute y : LengthValue;
		attribute heading : PlaneAngleValue;
	}
	
	attribute def LaserScanData {
		attribute timestamp : TimeValue;
		attribute ranges : LengthValue[*];
		attribute intensities : Real[*];
		attribute angleMin : PlaneAngleValue;
		attribute angleMax : PlaneAngleValue;
		attribute angleIncrement : PlaneAngleValue;
	}
	
	attribute def OccupancyGridData {
		attribute resolution : LengthValue;
		attribute width : Real;
		attribute height : Real;
		attribute originX : LengthValue;
		attribute originY : LengthValue;
		attribute cellData : Real[*];
	}
	
	attribute def MotionCommand {
		attribute linearVelocity : SpeedValue;
		attribute angularVelocity : AngularVelocityValue;
	}
	
	item def EnvironmentMap {
		attribute occupancyGrid : OccupancyGridData;
		attribute coverage : Real;
		attribute lastUpdated : TimeValue;
	}
	
	port def LaserScanPort {
		out scanData : LaserScanData;
	}
	
	port def OdometryPort {
		out poseEstimate : Pose2D;
	}
	
	port def MotionCommandPort {
		in velocityCmd : MotionCommand;
	}
	
	port def MapDataPort {
		out mapData : EnvironmentMap;
	}
	
	part def LaserRangeFinder {
		attribute scanRate : FrequencyValue;
		attribute maxRange : LengthValue;
		attribute angularResolution : PlaneAngleValue;
		port laserOutput : LaserScanPort;
	}
	
	part def WheelEncoder {
		attribute ticksPerRevolution : Real;
		attribute wheelDiameter : LengthValue;
	}
	
	part def OdometryEstimator {
		attribute currentPose : Pose2D;
		part leftEncoder : WheelEncoder;
		part rightEncoder : WheelEncoder;
		port odometryOutput : OdometryPort;
	}
	
	part def LocalizationProcessor {
		attribute estimatedPose : Pose2D;
		attribute poseCovariance : Real[*];
		
		action estimateRobotPose {
			in laserData : LaserScanData;
			in odometryData : Pose2D;
			in referenceMap : OccupancyGridData;
			out refinedPose : Pose2D;
		}
	}
	
	part def MappingProcessor {
		attribute environmentMap : OccupancyGridData;
		attribute mappedArea : AreaValue;
		
		action updateOccupancyGrid {
			in robotPose : Pose2D;
			in laserScan : LaserScanData;
			in existingGrid : OccupancyGridData;
			out updatedGrid : OccupancyGridData;
		}
		
		action integrateObservation {
			in scanPoint : LengthValue;
			in scanAngle : PlaneAngleValue;
			in sensorPose : Pose2D;
			out gridCellUpdate : Real;
		}
	}
	
	part def ExplorationPlanner {
		attribute explorationFrontiers : Pose2D[*];
		
		action identifyUnexploredRegions {
			in currentMap : OccupancyGridData;
			in robotPosition : Pose2D;
			out frontierCandidates : Pose2D[*];
		}
		
		action selectNextGoal {
			in frontiers : Pose2D[*];
			in currentPose : Pose2D;
			out targetPose : Pose2D;
		}
		
		action generateMotionPlan {
			in start : Pose2D;
			in goal : Pose2D;
			in obstacleMap : OccupancyGridData;
			out velocityCommand : MotionCommand;
		}
	}
	
	part def MotionExecutor {
		attribute maxLinearSpeed : SpeedValue;
		attribute maxAngularSpeed : AngularVelocityValue;
		port commandInput : MotionCommandPort;
		
		action executeVelocityCommand {
			in desiredVelocity : MotionCommand;
			out actualVelocity : MotionCommand;
		}
	}
	
	action def SLAMIteration {
		in sensorObservation : LaserScanData;
		in odometryReading : Pose2D;
		in previousMap : OccupancyGridData;
		in previousPose : Pose2D;
		out correctedPose : Pose2D;
		out updatedMap : OccupancyGridData;
	}
	
	action def AutonomousExploration {
		in currentMapState : OccupancyGridData;
		in currentPoseState : Pose2D;
		out navigationCommand : MotionCommand;
		out explorationFinished : Boolean;
	}
	
	action def AutonomousMappingMission {
		first start;
		then action initializeSystem {
			action createEmptyMap {
				out initialGrid : OccupancyGridData;
			}
			action setInitialPose {
				out startingPose : Pose2D;
			}
		}
		then merge mainMappingLoop;
		
		action mainMappingLoop {
			action captureSensorData {
				out laserMeasurement : LaserScanData;
				out odometryMeasurement : Pose2D;
			}
			then action executeSLAM : SLAMIteration {
				in sensorObservation = captureSensorData.laserMeasurement;
				in odometryReading = captureSensorData.odometryMeasurement;
				in previousMap;
				in previousPose;
				out correctedPose : Pose2D;
				out updatedMap : OccupancyGridData;
			}
			then action assessCoverage {
				in currentGrid = executeSLAM.updatedMap;
				out exploredPercentage : Real;
				out mappingComplete : Boolean;
			}
			then decide;
				if assessCoverage.mappingComplete then finalizeMission;
				if !assessCoverage.mappingComplete then continueExploring;
			
			action continueExploring : AutonomousExploration {
				in currentMapState = executeSLAM.updatedMap;
				in currentPoseState = executeSLAM.correctedPose;
				out navigationCommand : MotionCommand;
				out explorationFinished : Boolean;
			}
			then action driveRobot {
				in command = continueExploring.navigationCommand;
			}
			then mainMappingLoop;
			
			action finalizeMission {
				in completedMap : OccupancyGridData;
				out finalEnvironmentMap : EnvironmentMap;
			}
			then done;
		}
	}
	
	part def RoboticMappingSystem {
		doc /*
		 * An autonomous robotic system that explores unknown environments
		 * and constructs accurate spatial maps using simultaneous localization
		 * and mapping (SLAM) techniques. The system integrates laser range
		 * sensing with odometry to build occupancy grid representations while
		 * maintaining precise position estimates.
		 */
		
		attribute systemState : String;
		attribute totalMappedArea : AreaValue;
		
		port mapPublisher : MapDataPort;
		
		part laser : LaserRangeFinder {
			attribute :>> scanRate = 10.0[Hz];
			attribute :>> maxRange = 30.0[m];
			attribute :>> angularResolution = 0.25['°'];
		}
		
		part odometry : OdometryEstimator {
			part :>> leftEncoder {
				attribute :>> ticksPerRevolution = 2048.0;
				attribute :>> wheelDiameter = 0.15[m];
			}
			part :>> rightEncoder {
				attribute :>> ticksPerRevolution = 2048.0;
				attribute :>> wheelDiameter = 0.15[m];
			}
		}
		
		part localization : LocalizationProcessor {
			perform action estimateRobotPose;
		}
		
		part mapping : MappingProcessor {
			perform action updateOccupancyGrid;
			perform action integrateObservation;
		}
		
		part planner : ExplorationPlanner {
			perform action identifyUnexploredRegions;
			perform action selectNextGoal;
			perform action generateMotionPlan;
		}
		
		part motion : MotionExecutor {
			attribute :>> maxLinearSpeed = 0.8[m/s];
			attribute :>> maxAngularSpeed = 1.5[rad/s];
			perform action executeVelocityCommand;
		}
		
		connection laserToLocalization connect laser.laserOutput to localization;
		connection laserToMapping connect laser.laserOutput to mapping;
		connection odometryToLocalization connect odometry.odometryOutput to localization;
		connection localizationToMapping connect localization to mapping;
		connection mappingToPlanner connect mapping to planner;
		connection localizationToPlanner connect localization to planner;
		connection plannerToMotion connect planner to motion.commandInput;
		connection motionToOdometry connect motion to odometry;
		
		perform action autonomousMappingMission : AutonomousMappingMission;
	}
	
	requirement <'REQ-001'> mappingAccuracyRequirement {
		doc /*
		 * The robotic mapping system shall produce occupancy grid maps
		 * with spatial accuracy within 3% of true obstacle positions
		 * across the mapped environment.
		 */
		
		subject mappingSystem : RoboticMappingSystem;
		
		require constraint {
			mappingSystem.mapping.environmentMap.resolution <= 0.05[m]
		}
	}
	
	requirement <'REQ-002'> explorationEfficiencyRequirement {
		doc /*
		 * The system shall achieve at least 95% coverage of all accessible
		 * areas within the operational range of its sensors during autonomous
		 * exploration missions.
		 */
		
		subject mappingSystem : RoboticMappingSystem;
	}
	
	requirement <'REQ-003'> realTimePerformanceRequirement {
		doc /*
		 * The SLAM processing pipeline shall complete localization and
		 * mapping updates within 100 milliseconds per sensor scan to
		 * maintain real-time operation at 10Hz.
		 */
		
		subject mappingSystem : RoboticMappingSystem;
		
		require constraint {
			mappingSystem.laser.scanRate >= 10.0[Hz]
		}
	}
	
	requirement <'REQ-004'> navigationSafetyRequirement {
		doc /*
		 * The system shall maintain a minimum clearance of 0.3 meters
		 * from detected obstacles during autonomous navigation to ensure
		 * collision-free operation.
		 */
		
		subject mappingSystem : RoboticMappingSystem;
	}
	
	requirement systemMissionRequirement {
		doc /*
		 * The robotic mapping system shall autonomously explore and map
		 * unknown indoor and outdoor environments by integrating laser
		 * range sensing with wheel odometry, producing accurate occupancy
		 * grid representations while maintaining continuous localization.
		 */
		
		require mappingAccuracyRequirement;
		require explorationEfficiencyRequirement;
		require realTimePerformanceRequirement;
		require navigationSafetyRequirement;
	}
}
