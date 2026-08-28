package 'Autonomous Robot SLAM System' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	package Definitions {
		item def LaserScan {
			attribute ranges : LengthValue[*];
			attribute angles : PlaneAngleValue[*];
			attribute timestamp : TimeValue;
		}
		item def Odometry {
			attribute linearDistance : LengthValue;
			attribute angularDistance : PlaneAngleValue;
			attribute timestamp : TimeValue;
		}
		item def IMUData {
			attribute linearAcceleration : AccelerationValue;
			attribute angularVelocity : AngularVelocityValue;
			attribute timestamp : TimeValue;
		}
		item def Pose {
			attribute x : LengthValue;
			attribute y : LengthValue;
			attribute theta : PlaneAngleValue;
		}
		item def OccupancyGrid {
			attribute resolution : LengthValue;
			attribute width : Integer;
			attribute height : Integer;
			attribute probabilities : Real[*];
			attribute originX : LengthValue;
			attribute originY : LengthValue;
		}
		item def MotionCommand {
			attribute linearVelocity : SpeedValue;
			attribute angularVelocity : AngularVelocityValue;
		}

		port def LaserScanPort {
			out item scan : LaserScan;
		}
		port def OdometryPort {
			out item odom : Odometry;
		}
		port def IMUPort {
			out item imuData : IMUData;
		}
		port def PosePort {
			out item pose : Pose;
		}
		port def MapPort {
			out item map : OccupancyGrid;
		}
		port def CommandPort {
			out item command : MotionCommand;
		}
		port def TargetPort {
			in item target : Pose;
		}

		part def LaserRangeFinder {
			port scanOut : LaserScanPort;
		}
		part def WheelEncoders {
			port odomOut : OdometryPort;
		}
		part def IMU {
			port imuOut : IMUPort;
		}

		action def PredictMotion {
			in odom : Odometry;
			in previousPose : Pose;
			out predictedPose : Pose;
		}
		action def MatchScan {
			in scan : LaserScan;
			in map : OccupancyGrid;
			in predictedPose : Pose;
			out matchedPose : Pose;
		}
		action def FusePose {
			in predictedPose : Pose;
			in matchedPose : Pose;
			in imuData : IMUData;
			out estimatedPose : Pose;
		}
		action def UpdateMap {
			in scan : LaserScan;
			in pose : Pose;
			in currentMap : OccupancyGrid;
			out updatedMap : OccupancyGrid;
		}
		action def PlanPath {
			in currentPose : Pose;
			in map : OccupancyGrid;
			in target : Pose;
			out command : MotionCommand;
		}

		part def MotionModel {
			port odomIn : ~OdometryPort;
			port poseOut : PosePort;
		}
		part def ScanMatcher {
			port scanIn : ~LaserScanPort;
			port mapIn : ~MapPort;
			port predictedPoseIn : ~PosePort;
			port poseOut : PosePort;
		}
		part def PoseEstimator {
			port predictedPoseIn : ~PosePort;
			port matchedPoseIn : ~PosePort;
			port imuIn : ~IMUPort;
			port poseOut : PosePort;
		}
		part def MapBuilder {
			port scanIn : ~LaserScanPort;
			port poseIn : ~PosePort;
			port mapOut : MapPort;
		}
		part def PathPlanner {
			port poseIn : ~PosePort;
			port mapIn : ~MapPort;
			port targetIn : ~TargetPort;
			port commandOut : CommandPort;
		}

		state def RobotOperationStates {
			state Initializing;
			state ActiveMappingAndLocalization;
			transition init_to_active from Initializing to ActiveMappingAndLocalization when true;
			transition active_loop from ActiveMappingAndLocalization to ActiveMappingAndLocalization when true;
		}

		part def AutonomousRobot {
			port commandOut : CommandPort;
			port targetIn : TargetPort;

			part lidar : LaserRangeFinder;
			part encoders : WheelEncoders;
			part imu : IMU;

			part motionModel : MotionModel;
			part scanMatcher : ScanMatcher;
			part poseEstimator : PoseEstimator;
			part mapBuilder : MapBuilder;
			part pathPlanner : PathPlanner;

			flow of odom : Odometry
				from encoders.odomOut.odom to motionModel.odomIn.odom;
			flow of scanToMatcher : LaserScan
				from lidar.scanOut.scan to scanMatcher.scanIn.scan;
			flow of scanToMapBuilder : LaserScan
				from lidar.scanOut.scan to mapBuilder.scanIn.scan;
			flow of imuData : IMUData
				from imu.imuOut.imuData to poseEstimator.imuIn.imuData;

			flow of predictedPoseToEstimator : Pose
				from motionModel.poseOut.pose to poseEstimator.predictedPoseIn.pose;
			flow of predictedPoseToMatcher : Pose
				from motionModel.poseOut.pose to scanMatcher.predictedPoseIn.pose;
			flow of matchedPose : Pose
				from scanMatcher.poseOut.pose to poseEstimator.matchedPoseIn.pose;

			flow of estimatedPoseToMap : Pose
				from poseEstimator.poseOut.pose to mapBuilder.poseIn.pose;
			flow of estimatedPoseToPlanner : Pose
				from poseEstimator.poseOut.pose to pathPlanner.poseIn.pose;

			flow of mapToMatcher : OccupancyGrid
				from mapBuilder.mapOut.map to scanMatcher.mapIn.map;
			flow of mapToPlanner : OccupancyGrid
				from mapBuilder.mapOut.map to pathPlanner.mapIn.map;

			flow of command : MotionCommand
				from pathPlanner.commandOut.command to commandOut.command;

			exhibit state operationStates : RobotOperationStates;
		}
	}

	package Requirements {
		requirement def SLAMCapability {
			subject robot : Definitions::AutonomousRobot;
			doc /* The robot shall simultaneously localize and map its environment using LIDAR, wheel encoders, and IMU data. */
		}
		requirement def LocalizationAccuracy {
			doc /* The robot shall estimate its pose with position accuracy of at least 0.1 m and orientation accuracy of at least 1 deg. */
			attribute requiredPositionAccuracy : LengthValue = 0.1 [m];
			attribute requiredOrientationAccuracy : PlaneAngleValue = 1.0 [deg];
		}
		requirement def MapUpdateRate {
			doc /* The system shall update the occupancy grid map at a minimum frequency of 10 Hz. */
			attribute minUpdateFrequency : FrequencyValue = 10.0 [Hz];
		}
		requirement def ObstacleDetectionRange {
			doc /* The LIDAR shall detect obstacles within a range of 0.1 to 30 m with a resolution of at least 0.05 m. */
			attribute minRange : LengthValue = 0.1 [m];
			attribute maxRange : LengthValue = 30.0 [m];
			attribute rangeResolution : LengthValue = 0.05 [m];
		}
	}

	package Usages {
		private import Definitions::*;
		private import Requirements::*;

		part robotSystem : AutonomousRobot;

		satisfy SLAMCapability by robotSystem;
		satisfy LocalizationAccuracy by robotSystem;
		satisfy MapUpdateRate by robotSystem;
		satisfy ObstacleDetectionRange by robotSystem;
	}
}
