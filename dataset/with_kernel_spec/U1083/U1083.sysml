package AutonomousCleaningSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	package Definitions {
		attribute def StartCommand;
		attribute def StopCommand;
		attribute def EmergencyStop;
		attribute def ResumeCommand;

		attribute def Position {
			attribute x : LengthValue;
			attribute y : LengthValue;
		}

		attribute def Area {
			attribute id : String;
		}

		attribute def CleaningTask {
			attribute targetArea : Area;
		}

		attribute def StatusUpdate {
			attribute position : Position;
			attribute batteryLevel : Real;
			attribute taskProgress : Real;
		}

		attribute def CompletionReport {
			attribute areaCleaned : AreaValue;
			attribute duration : TimeValue;
		}

		attribute def ObstacleAlert {
			attribute distance : LengthValue;
		}

		port def CommandPort {
			in startCmd : StartCommand;
			in stopCmd : StopCommand;
			in emergency : EmergencyStop;
			in resumeCmd : ResumeCommand;
			out status : StatusUpdate;
			out report : CompletionReport;
		}

		port def SensorPort {
			out obstacle : ObstacleAlert;
		}

		port def BatteryPort {
			out level : Real;
		}

		port def PowerPort {
			in power : ElectricPotentialValue;
		}

		port def NavigationPort {
			out position : Position;
		}

		action def ScanEnvironment {
			out obstacle : ObstacleAlert;
		}

		action def PlanPath {
			in target : Position;
		}

		action def MoveToTarget {
			in target : Position;
		}

		action def PerformCleaning {
			in area : Area;
			out progress : Real;
		}

		action def CheckBattery {
			out level : Real;
		}

		action def Recharge {
			out level : Real;
		}

		action def DockAtStation;
		action def Undock;
		action def HaltOperations;

		action def GenerateReport {
			out report : CompletionReport;
		}

		action def SendStatus {
			out status : StatusUpdate;
		}

		action def CleaningWorkflow {
			in task : CleaningTask;
			out report : CompletionReport;
			first start;
			then loop action working {
				action check : CheckBattery { out level; }
				then if check.level < 20.0 {
					action returnToBase : MoveToTarget;
				}
				then action scan : ScanEnvironment { out obstacle; }
				then if scan.obstacle.distance < 0.5 [m] {
					action reroute : PlanPath;
				}
				then action clean : PerformCleaning {
					in area = task.targetArea;
					out progress;
				}
			} until working.clean.progress >= 1.0;
			then action genReport : GenerateReport { out report; }
			then done;
		}

		part def NavigationSystem {
			port navOut : NavigationPort;
			perform action planPath : PlanPath;
			perform action moveToTarget : MoveToTarget;
		}

		part def SensorArray {
			port sensorOut : SensorPort;
			perform action scanEnvironment : ScanEnvironment;
		}

		part def CleaningSystem {
			perform action performCleaning : PerformCleaning;
		}

		part def BatterySystem {
			attribute level : Real = 100.0;
			attribute lowThreshold : Real = 20.0;
			attribute fullThreshold : Real = 95.0;
			port battOut : BatteryPort;
			port battIn : PowerPort;
			perform action checkBattery : CheckBattery;
			perform action recharge : Recharge;
		}

		part def ControlSystem {
			port sensorIn : ~SensorPort;
			port batteryIn : ~BatteryPort;
			port navIn : ~NavigationPort;
			perform action sendStatus : SendStatus;
			perform action generateReport : GenerateReport;
		}

		part def ChargingStation {
			port stationOut : ~PowerPort;
		}

		part def ControlCenter {
			port centerCmd : ~CommandPort;
		}

		part def HomeRobot {
			part navigation : NavigationSystem;
			part sensors : SensorArray;
			part cleaner : CleaningSystem;
			part battery : BatterySystem;
			part controller : ControlSystem;
			port robotCmd : CommandPort;
			port robotPower : PowerPort;
			perform action cleaningWorkflow : CleaningWorkflow;

			connect sensors.sensorOut to controller.sensorIn;
			connect battery.battOut to controller.batteryIn;
			connect navigation.navOut to controller.navIn;

			state RobotStates {
				entry; then Standby;
				state Standby {
					entry action dock : DockAtStation;
				}
				accept StartCommand via robotCmd
					then Active;
				state Active {
					entry action undock : Undock;
					do action reportStatus : SendStatus;
				}
				accept ObstacleAlert via sensors.sensorOut
					then Navigating;
				accept when battery.level < battery.lowThreshold
					then Charging;
				accept EmergencyStop via robotCmd
					then Error;
				accept StopCommand via robotCmd
					then Standby;
				state Navigating {
					entry action reroute : PlanPath;
				}
				accept when sensors.scanEnvironment.obstacle.distance >= 0.5 [m]
					then Active;
				accept EmergencyStop via robotCmd
					then Error;
				state Charging {
					entry action dockAtCharger : DockAtStation;
					do action rechargeAction : Recharge;
					exit action undockFromCharger : Undock;
				}
				accept when battery.level >= battery.fullThreshold
					then Standby;
				accept EmergencyStop via robotCmd
					then Error;
				state Error {
					entry action halt : HaltOperations;
				}
				accept ResumeCommand via robotCmd
					then Standby;
			}
		}

		requirement def AutoReturnOnLowBattery {
			doc /* The robot shall automatically return to the charging station when battery level drops below 20 percent. */
			subject robot : HomeRobot;
		}

		requirement def SafeObstacleAvoidance {
			doc /* The robot shall detect obstacles within 0.5 m and reroute to avoid collisions. */
			subject robot : HomeRobot;
		}

		requirement def StatusReporting {
			doc /* The robot shall send status updates including position, battery level, and task progress. */
			subject robot : HomeRobot;
		}

		requirement def CompletionReportReq {
			doc /* The robot shall generate a completion report when a cleaning task is finished. */
			subject robot : HomeRobot;
		}

		requirement def OperationalModesReq {
			doc /* The robot shall operate in Standby, Active, Navigating, Charging, and Error states. */
			subject robot : HomeRobot;
		}
	}

	package Usages {
		private import Definitions::*;

		part homeRobot : HomeRobot;
		part chargingStation : ChargingStation;
		part controlCenter : ControlCenter;

		connect controlCenter.centerCmd to homeRobot.robotCmd;
		connect homeRobot.robotPower to chargingStation.stationOut;

		requirement autoReturn : AutoReturnOnLowBattery {
			subject robot = homeRobot;
		}
		requirement safeAvoid : SafeObstacleAvoidance {
			subject robot = homeRobot;
		}
		requirement statusRep : StatusReporting {
			subject robot = homeRobot;
		}
		requirement completion : CompletionReportReq {
			subject robot = homeRobot;
		}
		requirement opModes : OperationalModesReq {
			subject robot = homeRobot;
		}
	}
}
