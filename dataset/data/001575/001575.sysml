package 'SLAM System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def Timestamp {
		attribute value : Real;
	}
	
	item def Point3D {
		attribute x : LengthValue;
		attribute y : LengthValue;
		attribute z : LengthValue;
	}
	
	item def LaserScanData {
		attribute ranges : LengthValue[*];
		attribute angles : Real[*];
		attribute maxRange : LengthValue;
		attribute timestamp : Timestamp;
	}
	
	item def OdometryData {
		attribute deltaX : LengthValue;
		attribute deltaY : LengthValue;
		attribute deltaTheta : Real;
		attribute timestamp : Timestamp;
	}
	
	item def ImuData {
		attribute linearAccelX : AccelerationValue;
		attribute linearAccelY : AccelerationValue;
		attribute linearAccelZ : AccelerationValue;
		attribute angularVelRoll : AngularVelocityValue;
		attribute angularVelPitch : AngularVelocityValue;
		attribute angularVelYaw : AngularVelocityValue;
		attribute timestamp : Timestamp;
	}
	
	item def Pose2D {
		attribute x : LengthValue;
		attribute y : LengthValue;
		attribute theta : Real;
		attribute covariance : Real[*];
	}
	
	item def MapCell {
		attribute xIndex : Integer;
		attribute yIndex : Integer;
		attribute occupancyProbability : Real;
	}
	
	item def OccupancyGrid {
		attribute resolution : LengthValue;
		attribute width : Integer;
		attribute height : Integer;
		attribute cells : MapCell[*];
		attribute origin : Pose2D;
	}
	
	item def MotionCommand {
		attribute linearVelocity : SpeedValue;
		attribute angularVelocity : AngularVelocityValue;
	}
	
	port def LaserPort {
		out item scanData : LaserScanData;
	}
	
	port def OdometryPort {
		out item odomData : OdometryData;
	}
	
	port def ImuPort {
		out item imuData : ImuData;
	}
	
	port def PosePort {
		out item pose : Pose2D;
	}
	
	port def MapPort {
		out item map : OccupancyGrid;
	}
	
	port def CommandPort {
		out item command : MotionCommand;
	}
	
	part def LaserRangeFinder {
		attribute scanRate : FrequencyValue;
		attribute angularResolution : Real;
		attribute maxRange : LengthValue;
		
		port laserOut : LaserPort;
		
		perform action acquireScan {
			out scan : LaserScanData;
		}
	}
	
	part def WheelEncoder {
		attribute ticksPerRevolution : Integer;
		attribute wheelDiameter : LengthValue;
		
		port encoderOut : OdometryPort;
		
		perform action measureOdometry {
			out odometry : OdometryData;
		}
	}
	
	part def InertialMeasurementUnit {
		attribute sampleRate : FrequencyValue;
		
		port imuOut : ImuPort;
		
		perform action measureImu {
			out imu : ImuData;
		}
	}
	
	part def MotionModel {
		attribute processNoise : Real;
		
		perform action predictPose {
			in currentPose : Pose2D;
			in odometry : OdometryData;
			in deltaTime : TimeValue;
			out predictedPose : Pose2D;
		}
	}
	
	part def ScanMatcher {
		attribute matchingThreshold : Real;
		attribute maxIterations : Integer;
		
		perform action matchScan {
			in predictedPose : Pose2D;
			in laserScan : LaserScanData;
			in referenceMap : OccupancyGrid;
			out correctedPose : Pose2D;
			out matchScore : Real;
		}
	}
	
	part def MapBuilder {
		attribute updateRate : Real;
		
		perform action updateMap {
			in robotPose : Pose2D;
			in laserScan : LaserScanData;
			in existingMap : OccupancyGrid;
			out updatedMap : OccupancyGrid;
		}
	}
	
	part def PoseEstimator {
		attribute convergenceThreshold : Real;
		
		perform action fusePose {
			in motionPrediction : Pose2D;
			in scanMatchResult : Pose2D;
			in imuData : ImuData;
			in matchConfidence : Real;
			out finalPose : Pose2D;
		}
	}
	
	part def PathPlanner {
		attribute planningHorizon : LengthValue;
		attribute safetyMargin : LengthValue;
		
		perform action planMotion {
			in currentPose : Pose2D;
			in targetPose : Pose2D;
			in map : OccupancyGrid;
			out motionCommand : MotionCommand;
		}
	}
	
	action def SLAMCycle {
		in laserInput : LaserScanData;
		in odometryInput : OdometryData;
		in imuInput : ImuData;
		in previousPose : Pose2D;
		in previousMap : OccupancyGrid;
		in deltaTime : TimeValue;
		out currentPose : Pose2D;
		out currentMap : OccupancyGrid;
		
		first start;
		
		then action motionPrediction : MotionModel::predictPose {
			in currentPose = previousPose;
			in odometry = odometryInput;
			in deltaTime = deltaTime;
			out predictedPose;
		}
		
		then action scanMatching : ScanMatcher::matchScan {
			in predictedPose = motionPrediction.predictedPose;
			in laserScan = laserInput;
			in referenceMap = previousMap;
			out correctedPose;
			out matchScore;
		}
		
		then action poseEstimation : PoseEstimator::fusePose {
			in motionPrediction = motionPrediction.predictedPose;
			in scanMatchResult = scanMatching.correctedPose;
			in imuData = imuInput;
			in matchConfidence = scanMatching.matchScore;
			out finalPose;
		}
		
		then action mapUpdate : MapBuilder::updateMap {
			in robotPose = poseEstimation.finalPose;
			in laserScan = laserInput;
			in existingMap = previousMap;
			out updatedMap;
		}
		
		then assign currentPose := poseEstimation.finalPose;
		then assign currentMap := mapUpdate.updatedMap;
		then done;
	}
	
	part def SLAMSystem {
		attribute maxAllowedPoseError : LengthValue;
		attribute minConsistencyThreshold : Real;
		attribute maxCycleTime : TimeValue;
		
		port poseOut : PosePort;
		port mapOut : MapPort;
		port commandOut : CommandPort;
		
		part laser : LaserRangeFinder {
			attribute :>> scanRate = 10.0 [Hz];
			attribute :>> angularResolution = 0.25;
			attribute :>> maxRange = 30.0 [m];
		}
		
		part encoders : WheelEncoder {
			attribute :>> ticksPerRevolution = 2048;
			attribute :>> wheelDiameter = 0.15 [m];
		}
		
		part imu : InertialMeasurementUnit {
			attribute :>> sampleRate = 100.0 [Hz];
		}
		
		part motionModel : MotionModel {
			attribute :>> processNoise = 0.01;
		}
		
		part scanMatcher : ScanMatcher {
			attribute :>> matchingThreshold = 0.85;
			attribute :>> maxIterations = 50;
		}
		
		part mapBuilder : MapBuilder {
			attribute :>> updateRate = 1.0;
		}
		
		part poseEstimator : PoseEstimator {
			attribute :>> convergenceThreshold = 0.001;
		}
		
		part planner : PathPlanner {
			attribute :>> planningHorizon = 5.0 [m];
			attribute :>> safetyMargin = 0.3 [m];
		}
		
		private attribute storedPose : Pose2D;
		private attribute storedMap : OccupancyGrid;
		
		connection sensorConnections {
			connect laser.laserOut to slamProcessor;
			connect encoders.encoderOut to slamProcessor;
			connect imu.imuOut to slamProcessor;
		}
		
		part slamProcessor {
			perform action executeSLAM[*] ordered {
				first start;
				then merge continueSLAM;
				
				then action slamIteration : SLAMCycle {
					in laserInput = laser.laserOut.scanData;
					in odometryInput = encoders.encoderOut.odomData;
					in imuInput = imu.imuOut.imuData;
					in previousPose = storedPose;
					in previousMap = storedMap;
					in deltaTime;
					out currentPose;
					out currentMap;
				}
				
				then assign storedPose := slamIteration.currentPose;
				then assign storedMap := slamIteration.currentMap;
				
				then action publishResults {
					assign poseOut.pose := slamIteration.currentPose;
					assign mapOut.map := slamIteration.currentMap;
				}
				
				then action generateMotion : PathPlanner::planMotion {
					in currentPose = slamIteration.currentPose;
					in targetPose;
					in map = slamIteration.currentMap;
					out motionCommand;
				}
				
				then assign commandOut.command := generateMotion.motionCommand;
				then continueSLAM;
			}
		}
		
		exhibit state slamStateMachine {
			entry; then Initializing;
			
			state Initializing {
				entry action initializePose;
				entry action initializeMap;
			}
			then Mapping;
			
			state Mapping {
				do action executeSLAMCycle;
			}
			then Localized;
			
			state Localized {
				do action trackPose;
			}
		}
	}
	
	requirement def SLAMAccuracyRequirement {
		doc /* The SLAM system shall maintain pose estimation accuracy within specified bounds. */
		
		subject slamSystem : SLAMSystem;
		
		require constraint {
			slamSystem.maxAllowedPoseError <= 0.1 [m]
		}
	}
	
	requirement def MappingConsistencyRequirement {
		doc /* The SLAM system shall produce spatially consistent maps with high fidelity. */
		
		subject slamSystem : SLAMSystem;
		
		require constraint {
			slamSystem.minConsistencyThreshold >= 0.9
		}
	}
	
	requirement def RealTimePerformanceRequirement {
		doc /* The SLAM system shall process sensor data and update pose and map in real-time. */
		
		subject slamSystem : SLAMSystem;
		
		require constraint {
			slamSystem.maxCycleTime <= 0.1 [s]
		}
	}
	
	requirement def SLAMSystemRequirement {
		doc /* The SLAM system shall autonomously build a map of an unknown environment 
		       while simultaneously tracking its own location within that map using sensor fusion. */
		
		require SLAMAccuracyRequirement;
		require MappingConsistencyRequirement;
		require RealTimePerformanceRequirement;
	}
	
	part autonomousRobot : SLAMSystem {
		attribute :>> maxAllowedPoseError = 0.1 [m];
		attribute :>> minConsistencyThreshold = 0.9;
		attribute :>> maxCycleTime = 0.1 [s];
		
		satisfy SLAMSystemRequirement;
	}
}
