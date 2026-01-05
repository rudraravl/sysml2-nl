package 'Robotic Painting System' {
	private import ScalarValues::*;
	private import SI::*;

	enum def PaintColor {
		enum red;
		enum blue;
		enum white;
		enum black;
		enum silver;
	}

	enum def SurfaceFinish {
		enum glossy;
		enum matte;
		enum satin;
	}

	attribute def PaintThickness {
		attribute num : Real;
		attribute mRef : String default "mm";
	}

	attribute def SprayPressure {
		attribute num : Real;
		attribute mRef : String default "kPa";
	}

	attribute def FlowRate {
		attribute num : Real;
		attribute mRef : String default "L/min";
	}

	item def Paint {
		attribute color : PaintColor;
		attribute viscosity : Real;
		attribute volumeNum : Real;
		attribute volumeUnit : String;
	}

	item def Workpiece {
		attribute surfaceAreaNum : Real;
		attribute surfaceAreaUnit : String;
		attribute isPainted : Boolean default false;
		attribute appliedThickness : PaintThickness;
		attribute finish : SurfaceFinish;
	}

	item def RobotCommand {
		attribute commandType : String;
		attribute targetPositionX : Real;
		attribute targetPositionY : Real;
		attribute targetPositionZ : Real;
	}

	item def QualityReport {
		attribute coveragePercent : Real;
		attribute thicknessUniform : Boolean;
		attribute defectCount : Integer;
	}

	item def SystemReadySignal;
	item def PositionReachedSignal;
	item def SprayCompleteSignal;
	item def InspectionPassSignal;
	item def InspectionFailSignal;
	item def CleaningCompleteSignal;
	item def ResetSignal;

	port def PaintSupplyPort {
		out item paintFlow : Paint;
		attribute flowRate : FlowRate;
	}

	port def WorkpieceInputPort {
		in item workpieceIn : Workpiece;
	}

	port def WorkpieceOutputPort {
		out item workpieceOut : Workpiece;
	}

	port def ControlCommandPort {
		in item command : RobotCommand;
	}

	port def StatusReportPort {
		out item status : QualityReport;
	}

	action def PositionRobotArm {
		in targetWorkpiece : Workpiece;
		in sprayDistanceNum : Real;
		out armPositionX : Real;
		out armPositionY : Real;
		out armPositionZ : Real;
	}

	action def ApplyPaintCoat {
		in workpiece : Workpiece;
		in paint : Paint;
		in sprayPressure : SprayPressure;
		in targetThickness : PaintThickness;
		out paintedWorkpiece : Workpiece;
	}

	action def InspectPaintQuality {
		in workpiece : Workpiece;
		out qualityReport : QualityReport;
	}

	action def CleanSpraySystem {
		in nozzleCondition : Boolean;
		out systemClean : Boolean;
	}

	state def PaintRobotStates {
		entry; then standby;

		state standby;

		state initializing;

		state positioning;

		state spraying;

		state inspecting;

		state cleaning;

		state complete;

		transition standby_to_initializing
			first standby
			accept RobotCommand
			then initializing;

		transition initializing_to_positioning
			first initializing
			accept SystemReadySignal
			then positioning;

		transition positioning_to_spraying
			first positioning
			accept PositionReachedSignal
			then spraying;

		transition spraying_to_inspecting
			first spraying
			accept SprayCompleteSignal
			then inspecting;

		transition inspecting_to_cleaning
			first inspecting
			accept InspectionPassSignal
			then cleaning;

		transition inspecting_to_spraying
			first inspecting
			accept InspectionFailSignal
			then spraying;

		transition cleaning_to_complete
			first cleaning
			accept CleaningCompleteSignal
			then complete;

		transition complete_to_standby
			first complete
			accept ResetSignal
			then standby;
	}

	part def SprayNozzle {
		attribute nozzleDiameterNum : Real;
		attribute nozzleDiameterUnit : String;
		attribute sprayAngle : Real;
		attribute maxPressure : SprayPressure;

		perform action sprayPaint : ApplyPaintCoat;
	}

	part def RoboticArm {
		attribute reachRadiusNum : Real;
		attribute reachRadiusUnit : String;
		attribute degreesOfFreedom : Integer;
		attribute positionAccuracyNum : Real;
		attribute positionAccuracyUnit : String;
		attribute maxSpeed : Real;

		perform action positionArm : PositionRobotArm;
	}

	part def VisionSystem {
		attribute cameraResolution : Integer;
		attribute inspectionAccuracy : Real;

		perform action inspectQuality : InspectPaintQuality;
	}

	part def PaintReservoir {
		attribute capacityNum : Real;
		attribute capacityUnit : String;
		attribute currentLevelNum : Real;
		attribute currentLevelUnit : String;
		attribute operatingPressure : SprayPressure;

		part storedPaint : Paint[1..*];
	}

	part def PaintRobot {
		attribute robotID : String;
		attribute maxWorkpieceSizeNum : Real;
		attribute maxWorkpieceSizeUnit : String;

		port paintSupply : PaintSupplyPort;
		port workpieceInput : WorkpieceInputPort;
		port workpieceOutput : WorkpieceOutputPort;
		port controlCommand : ControlCommandPort;
		port statusPort : StatusReportPort;

		part sprayNozzle : SprayNozzle {
			:>> nozzleDiameterNum = 1.2;
			:>> nozzleDiameterUnit = "mm";
			:>> sprayAngle = 45.0;
			:>> maxPressure {
				:>> num = 400.0;
				:>> mRef = "kPa";
			}
		}

		part roboticArm : RoboticArm {
			:>> reachRadiusNum = 1.8;
			:>> reachRadiusUnit = "m";
			:>> degreesOfFreedom = 6;
			:>> positionAccuracyNum = 0.1;
			:>> positionAccuracyUnit = "mm";
			:>> maxSpeed = 2.5;
		}

		part visionSystem : VisionSystem {
			:>> cameraResolution = 4096;
			:>> inspectionAccuracy = 0.99;
		}

		ref part paintReservoir : PaintReservoir;

		exhibit state robotStates : PaintRobotStates;
		perform action paintingTask : PaintingTask;
	}

	part def ConveyorBelt {
		attribute beltSpeed : Real;
		attribute beltLengthNum : Real;
		attribute beltLengthUnit : String;

		port workpieceIn : WorkpieceInputPort;
		port workpieceOut : WorkpieceOutputPort;

		perform action transportWorkpiece : TransportWorkpiece;
	}

	part def SystemController {
		attribute controlMode : String;

		port robotControl : ControlCommandPort;
		port qualityMonitor : StatusReportPort;

		perform action coordinateOperations : CoordinateOperations;
	}

	action def PaintingTask {
		in rawWorkpiece : Workpiece;
		in paintMaterial : Paint;
		out finishedWorkpiece : Workpiece;

		first start;

		then action positionArm : PositionRobotArm {
			in targetWorkpiece = PaintingTask::rawWorkpiece;
			in sprayDistanceNum = 0.3;
			out armPositionX;
			out armPositionY;
			out armPositionZ;
		}

		then action applyFirstCoat : ApplyPaintCoat {
			in workpiece = PaintingTask::rawWorkpiece;
			in paint = PaintingTask::paintMaterial;
			in sprayPressure {
				:>> num = 350.0;
				:>> mRef = "kPa";
			}
			in targetThickness {
				:>> num = 0.08;
				:>> mRef = "mm";
			}
			out paintedWorkpiece;
		}

		then action inspectFirstCoat : InspectPaintQuality {
			in workpiece = applyFirstCoat.paintedWorkpiece;
			out qualityReport;
		}

		then decide;
			if inspectFirstCoat.qualityReport.coveragePercent < 95.0 then applyFirstCoat;
			if inspectFirstCoat.qualityReport.coveragePercent >= 95.0 then applySecondCoat;

		action applySecondCoat : ApplyPaintCoat {
			in workpiece = applyFirstCoat.paintedWorkpiece;
			in paint = PaintingTask::paintMaterial;
			in sprayPressure {
				:>> num = 320.0;
				:>> mRef = "kPa";
			}
			in targetThickness {
				:>> num = 0.05;
				:>> mRef = "mm";
			}
			out paintedWorkpiece;
		}

		then action finalInspection : InspectPaintQuality {
			in workpiece = applySecondCoat.paintedWorkpiece;
			out qualityReport;
		}

		then action cleanSystem : CleanSpraySystem {
			in nozzleCondition = true;
			out systemClean;
		}

		then action finalizeWorkpiece {
			in workpiece = applySecondCoat.paintedWorkpiece;
			out :>> finishedWorkpiece = workpiece {
				redefines isPainted = true;
				redefines appliedThickness {
					:>> num = 0.13;
					:>> mRef = "mm";
				}
			}
		}

		then done;
	}

	action def TransportWorkpiece {
		in workpiece : Workpiece;
		out movedWorkpiece : Workpiece;
	}

	action def CoordinateOperations {
		ref part robot : PaintRobot;
		ref part conveyor : ConveyorBelt;
	}

	requirement def PaintCoverageRequirement {
		doc /* The painted surface must achieve minimum 95% coverage. */

		subject paintedSurface : Workpiece;

		require constraint {
			paintedSurface.isPainted == true
		}
	}

	requirement def PaintThicknessRequirement {
		doc /* Paint thickness must be between 0.05mm and 0.20mm. */

		subject paintedSurface : Workpiece;

		require constraint {
			paintedSurface.appliedThickness.num >= 0.05 and
			paintedSurface.appliedThickness.num <= 0.20
		}
	}

	requirement def SystemProductivityRequirement {
		doc /* The system must process at least 15 workpieces per hour. */

		subject system : RoboticPaintingSystem;

		attribute requiredThroughput : Real = 15.0;
	}

	requirement def PrimaryTaskRequirement {
		doc /* The robotic system shall perform its primary task using a Paint robot. */

		subject system : RoboticPaintingSystem;
	}

	part def RoboticPaintingSystem {
		attribute systemID : String;
		attribute operatingHours : Real;

		part paintRobot : PaintRobot {
			:>> robotID = "PR-2024-001";
			:>> maxWorkpieceSizeNum = 4.0;
			:>> maxWorkpieceSizeUnit = "m^2";
		}

		part paintReservoir : PaintReservoir {
			:>> capacityNum = 200.0;
			:>> capacityUnit = "L";
			:>> currentLevelNum = 150.0;
			:>> currentLevelUnit = "L";
			:>> operatingPressure {
				:>> num = 380.0;
				:>> mRef = "kPa";
			}

			part redPaint : Paint {
				:>> color = PaintColor::red;
				:>> viscosity = 90.0;
				:>> volumeNum = 50.0;
				:>> volumeUnit = "L";
			}

			part whitePaint : Paint {
				:>> color = PaintColor::white;
				:>> viscosity = 85.0;
				:>> volumeNum = 50.0;
				:>> volumeUnit = "L";
			}

			part silverPaint : Paint {
				:>> color = PaintColor::silver;
				:>> viscosity = 88.0;
				:>> volumeNum = 50.0;
				:>> volumeUnit = "L";
			}
		}

		part inputConveyor : ConveyorBelt {
			:>> beltSpeed = 0.15;
			:>> beltLengthNum = 6.0;
			:>> beltLengthUnit = "m";
		}

		part outputConveyor : ConveyorBelt {
			:>> beltSpeed = 0.15;
			:>> beltLengthNum = 6.0;
			:>> beltLengthUnit = "m";
		}

		part systemController : SystemController {
			:>> controlMode = "automatic";
		}

		connect paintReservoir to paintRobot.paintReservoir;
		connect inputConveyor.workpieceOut to paintRobot.workpieceInput;
		connect paintRobot.workpieceOutput to outputConveyor.workpieceIn;
		connect systemController.robotControl to paintRobot.controlCommand;
		connect paintRobot.statusPort to systemController.qualityMonitor;

		perform action primaryTask : PaintingTask;

		allocate primaryTask to paintRobot {
			allocate primaryTask.positionArm to paintRobot.roboticArm.positionArm;
			allocate primaryTask.applyFirstCoat to paintRobot.sprayNozzle.sprayPaint;
			allocate primaryTask.applySecondCoat to paintRobot.sprayNozzle.sprayPaint;
			allocate primaryTask.inspectFirstCoat to paintRobot.visionSystem.inspectQuality;
			allocate primaryTask.finalInspection to paintRobot.visionSystem.inspectQuality;
		}

		satisfy coverageReq : PaintCoverageRequirement by paintRobot;
		satisfy thicknessReq : PaintThicknessRequirement by paintRobot;
		satisfy productivityReq : SystemProductivityRequirement by RoboticPaintingSystem;
		satisfy primaryTaskReq : PrimaryTaskRequirement by RoboticPaintingSystem;
	}

	part productionCell : RoboticPaintingSystem {
		:>> systemID = "RPS-Manufacturing-Cell-A1";
		:>> operatingHours = 16.0;
	}
}
