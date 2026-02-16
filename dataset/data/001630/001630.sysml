package 'Wolf Robotics Automated Welding System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def WeldingCurrent :> ISQ::ElectricCurrentValue;
	attribute def WeldingVoltage :> ISQ::ElectricPotentialValue;
	attribute def WireSpeed :> ISQ::SpeedValue;
	attribute def TravelSpeed :> ISQ::SpeedValue;
	attribute def TorchAngle :> ISQ::PlaneAngleValue;
	attribute def JointPosition :> ISQ::PlaneAngleValue;
	attribute def PathCoordinate {
		attribute x : ISQ::LengthValue;
		attribute y : ISQ::LengthValue;
		attribute z : ISQ::LengthValue;
	}
	attribute def WeldQualityMetric {
		attribute penetrationDepth : ISQ::LengthValue;
		attribute beadWidth : ISQ::LengthValue;
		attribute defectCount : Integer;
	}
	
	item def WeldingWire {
		attribute diameter : ISQ::LengthValue;
		attribute material : String;
	}
	
	item def ShieldingGas {
		attribute flowRate : ISQ::VolumeFlowRateValue;
		attribute composition : String;
	}
	
	item def Workpiece {
		attribute material : String;
		attribute thickness : ISQ::LengthValue;
		attribute geometry : PathCoordinate[*];
	}
	
	port def PowerPort {
		out current : WeldingCurrent;
		out voltage : WeldingVoltage;
	}
	
	port def ControlPort {
		in command : String;
		out status : String;
	}
	
	port def SensorPort {
		out position : PathCoordinate;
		out quality : WeldQualityMetric;
	}
	
	part def WeldingPowerSupply {
		attribute maxCurrent : WeldingCurrent;
		attribute maxVoltage : WeldingVoltage;
		attribute efficiency : Real;
		port powerOut : PowerPort;
	}
	
	part def RoboticArm {
		attribute numberOfJoints : Integer;
		attribute reach : ISQ::LengthValue;
		attribute payloadCapacity : ISQ::MassValue;
		attribute jointPositions : JointPosition[6];
		port controlIn : ControlPort;
		port positionOut : SensorPort;
	}
	
	part def WeldingTorch {
		attribute torchAngle : TorchAngle;
		attribute contactTipDistance : ISQ::LengthValue;
		port powerIn : PowerPort;
		in wire : WeldingWire;
		in gas : ShieldingGas;
	}
	
	part def WireFeedUnit {
		attribute feedRate : WireSpeed;
		attribute spoolCapacity : ISQ::MassValue;
		in wireSupply : WeldingWire;
		out wireFed : WeldingWire;
	}
	
	part def VisionSystem {
		attribute resolution : Integer;
		attribute frameRate : ISQ::FrequencyValue;
		attribute fieldOfView : ISQ::PlaneAngleValue;
		port sensorOut : SensorPort;
	}
	
	part def SystemController {
		attribute processorSpeed : ISQ::FrequencyValue;
		attribute memoryCapacity : Real;
		port controlOut : ControlPort;
		port sensorIn : SensorPort;
	}
	
	action def ScanWorkpiece {
		in workpiece : Workpiece;
		out seamPath : PathCoordinate[*];
		out seamProfile : Real[*];
	}
	
	action def GenerateWeldPath {
		in seamPath : PathCoordinate[*];
		in weldParameters : WeldingCurrent;
		out robotPath : PathCoordinate[*];
		out pathVelocities : TravelSpeed[*];
	}
	
	action def MoveToPosition {
		in targetPosition : PathCoordinate;
		in currentPosition : PathCoordinate;
		out jointCommands : JointPosition[*];
		out positionError : ISQ::LengthValue;
	}
	
	action def InitiateWeld {
		in weldCurrent : WeldingCurrent;
		in weldVoltage : WeldingVoltage;
		in wireSpeed : WireSpeed;
		out arcStable : Boolean;
	}
	
	action def ExecuteWeldPass {
		in pathSegment : PathCoordinate[*];
		in travelSpeed : TravelSpeed;
		in weldCurrent : WeldingCurrent;
		in weldVoltage : WeldingVoltage;
		out weldBead : WeldQualityMetric;
	}
	
	action def MonitorWeldQuality {
		in currentReading : WeldingCurrent;
		in voltageReading : WeldingVoltage;
		in visionData : Real[*];
		out qualityMetric : WeldQualityMetric;
		out defectDetected : Boolean;
	}
	
	action def AdjustWeldParameters {
		in qualityFeedback : WeldQualityMetric;
		in targetQuality : WeldQualityMetric;
		out currentAdjustment : WeldingCurrent;
		out voltageAdjustment : WeldingVoltage;
		out speedAdjustment : TravelSpeed;
	}
	
	action def TerminateWeld {
		in currentCurrent : WeldingCurrent;
		out craterFilled : Boolean;
	}
	
	action def PerformAutomatedWelding {
		in workpiece : Workpiece;
		in targetQuality : WeldQualityMetric;
		in nominalCurrent : WeldingCurrent;
		in nominalVoltage : WeldingVoltage;
		in nominalWireSpeed : WireSpeed;
		out completedWeld : WeldQualityMetric;
		
		first start;
		then action scan : ScanWorkpiece {
			in workpiece = PerformAutomatedWelding::workpiece;
			out seamPath;
			out seamProfile;
		}
		then action generatePath : GenerateWeldPath {
			in seamPath = scan.seamPath;
			in weldParameters = nominalCurrent;
			out robotPath;
			out pathVelocities;
		}
		then merge weldingLoop;
		then action weldingLoop {
			first action moveToStart : MoveToPosition {
				out jointCommands;
				out positionError;
			}
			then decide;
				if moveToStart.positionError > 0.0005[m] then moveToStart;
				if moveToStart.positionError <= 0.0005[m] then startArc;
			action startArc : InitiateWeld {
				in weldCurrent = nominalCurrent;
				in weldVoltage = nominalVoltage;
				in wireSpeed = nominalWireSpeed;
				out arcStable;
			}
			then decide;
				if !startArc.arcStable then startArc;
				if startArc.arcStable then weldPass;
			action weldPass : ExecuteWeldPass {
				in travelSpeed;
				in weldCurrent = nominalCurrent;
				in weldVoltage = nominalVoltage;
				out weldBead;
			}
			then action monitor : MonitorWeldQuality {
				in currentReading = nominalCurrent;
				in voltageReading = nominalVoltage;
				out qualityMetric;
				out defectDetected;
			}
			then decide;
				if monitor.defectDetected then adjust;
				if !monitor.defectDetected then checkComplete;
			action adjust : AdjustWeldParameters {
				in qualityFeedback = monitor.qualityMetric;
				in targetQuality = PerformAutomatedWelding::targetQuality;
				out currentAdjustment;
				out voltageAdjustment;
				out speedAdjustment;
			}
			then weldingLoop;
			action checkComplete {
				then decide;
					if true then stopWeld;
			}
			action stopWeld : TerminateWeld {
				in currentCurrent = nominalCurrent;
				out craterFilled;
			}
			then done;
		}
		then assign completedWeld := weldingLoop.monitor.qualityMetric;
		then done;
	}
	
	part def WolfRoboticsWeldingCell {
		doc /*
		The Wolf Robotics Automated Welding Cell is an integrated robotic system
		designed to perform high-quality, repeatable welding operations on complex
		workpieces. The system combines precision robotic manipulation, adaptive
		welding process control, and real-time vision-based quality monitoring to
		autonomously execute welding tasks with minimal human intervention.
		*/
		
		attribute cellIdentifier : String;
		attribute operatingTemperature : ISQ::ThermodynamicTemperatureValue;
		
		part powerSupply : WeldingPowerSupply {
			attribute maxCurrent = 500[A];
			attribute maxVoltage = 45[V];
			attribute efficiency = 0.92;
		}
		
		part robot : RoboticArm {
			attribute numberOfJoints = 6;
			attribute reach = 2.8[m];
			attribute payloadCapacity = 30[kg];
			perform automatedWelding.moveToStart;
			perform automatedWelding.weldPass;
		}
		
		part torch : WeldingTorch {
			attribute torchAngle = 0.26[rad];
			attribute contactTipDistance = 0.012[m];
			perform automatedWelding.startArc;
			perform automatedWelding.weldPass;
		}
		
		part wireFeed : WireFeedUnit {
			attribute feedRate = 10[m/s];
			attribute spoolCapacity = 15[kg];
		}
		
		part vision : VisionSystem {
			attribute resolution = 1920;
			attribute frameRate = 60[Hz];
			attribute fieldOfView = 0.785[rad];
			perform automatedWelding.scan;
			perform automatedWelding.monitor;
		}
		
		part controller : SystemController {
			attribute processorSpeed = 3.5[GHz];
			attribute memoryCapacity = 16.0;
			perform automatedWelding.generatePath;
			perform automatedWelding.adjust;
		}
		
		perform action automatedWelding[*] ordered references PerformAutomatedWelding;
		
		connect powerSupply.powerOut to torch.powerIn;
		connect controller.controlOut to robot.controlIn;
		connect robot.positionOut to controller.sensorIn;
		connect vision.sensorOut to controller.sensorIn;
		connect wireFeed.wireFed to torch.wire;
		
		exhibit state machine WeldingCellStateMachine {
			initial state Idle;
			state Initializing;
			state Scanning;
			state PathPlanning;
			state Welding;
			state QualityCheck;
			state Adjusting;
			state Completed;
			state Fault;
			state final Shutdown;
			
			transition from Idle to Initializing;
			transition from Initializing to Scanning;
			transition from Scanning to PathPlanning;
			transition from PathPlanning to Welding;
			transition from Welding to QualityCheck;
			transition from QualityCheck to Completed;
			transition from QualityCheck to Adjusting;
			transition from Adjusting to Welding;
			transition from Completed to Idle;
			transition from Fault to Idle;
			transition from Idle to Shutdown;
		}
	}
	
	part wolfWeldingCell : WolfRoboticsWeldingCell {
		attribute cellIdentifier = "WOLF-CELL-001";
		attribute operatingTemperature = 298[K];
	}
	
	requirement def FunctionalRequirement;
	requirement def PerformanceRequirement;
	requirement def QualityRequirement;
	requirement def SafetyRequirement;
	
	requirement <'WR-FR-001'> automatedWeldingCapability : FunctionalRequirement {
		doc /*
		The Wolf Robotics Welding Cell shall autonomously perform welding operations
		by scanning workpieces, generating optimal weld paths, executing welds with
		precise parameter control, and continuously monitoring weld quality with
		adaptive feedback control.
		*/
		subject cell : WolfRoboticsWeldingCell;
		require weldQualityRequirement;
		require positioningAccuracyRequirement;
		require adaptiveControlRequirement;
	}
	
	requirement <'WR-QR-001'> weldQualityRequirement : QualityRequirement {
		doc /*
		The system shall maintain weld quality metrics within specification by
		detecting defects in real-time and adjusting welding parameters dynamically
		to achieve target penetration depth and bead geometry.
		*/
		subject cell : WolfRoboticsWeldingCell;
	}
	
	requirement <'WR-PR-001'> positioningAccuracyRequirement : PerformanceRequirement {
		doc /*
		The robotic arm shall position the welding torch with repeatability better
		than ±0.5 mm to ensure consistent weld placement and quality across multiple
		workpieces.
		*/
		subject robot : RoboticArm;
	}
	
	requirement <'WR-FR-002'> adaptiveControlRequirement : FunctionalRequirement {
		doc /*
		The control system shall adjust welding current, voltage, and travel speed
		in response to real-time quality feedback to compensate for variations in
		workpiece geometry, material properties, and joint fit-up.
		*/
		subject controller : SystemController;
	}
	
	requirement <'WR-SR-001'> arcSafetyRequirement : SafetyRequirement {
		doc /*
		The system shall automatically terminate welding operations and enter a safe
		state within 100 milliseconds upon detection of unsafe arc conditions or
		system faults to prevent equipment damage and ensure operator safety.
		*/
		subject cell : WolfRoboticsWeldingCell;
	}
	
	requirement <'WR-PR-002'> cycleTimeRequirement : PerformanceRequirement {
		doc /*
		The welding cell shall complete a standard automotive bracket weld cycle,
		including scanning, path planning, welding, and quality verification, in
		less than 90 seconds to meet production throughput targets.
		*/
		subject cell : WolfRoboticsWeldingCell;
	}
}
