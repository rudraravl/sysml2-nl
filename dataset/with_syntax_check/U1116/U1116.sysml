package 'LaundryFoldingMachineSystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def GarmentCategory;
	attribute def FoldingSequence;
	
	item def LaundryItem {
		attribute category : GarmentCategory;
		attribute width : LengthValue;
		attribute length : LengthValue;
		attribute mass : MassValue;
		attribute isFolded : Boolean;
	}
	
	attribute def GarmentDimensions {
		attribute width : LengthValue;
		attribute length : LengthValue;
	}
	
	port def LaundryInputPort {
		in item unfoldedItem : LaundryItem;
	}
	
	port def LaundryOutputPort {
		out item foldedItem : LaundryItem;
	}
	
	port def SensorPort {
		out attribute dimensions : GarmentDimensions;
		out attribute category : GarmentCategory;
	}
	
	port def ActuatorPort {
		in attribute position : LengthValue;
		in attribute force : ForceValue;
	}
	
	part def VisionSensor {
		port sensorData : SensorPort;
		
		action def ScanGarment {
			in item garment : LaundryItem;
			out dimensions : GarmentDimensions;
			out category : GarmentCategory;
		}
	}
	
	part def FoldingArm {
		port actuatorControl : ActuatorPort;
		attribute maxReach : LengthValue;
		attribute gripStrength : ForceValue;
		
		action def PositionArm {
			in targetPosition : LengthValue;
			out currentPosition : LengthValue;
		}
		
		action def GripItem {
			in gripForce : ForceValue;
			out gripped : Boolean;
		}
		
		action def ReleaseItem;
	}
	
	part def FoldingSurface {
		attribute surfaceWidth : LengthValue;
		attribute surfaceLength : LengthValue;
		attribute temperature : TemperatureValue;
		
		action def AdjustTemperature {
			in targetTemp : TemperatureValue;
			out actualTemp : TemperatureValue;
		}
	}
	
	part def InputConveyor {
		port itemInput : LaundryInputPort;
		attribute speed : SpeedValue;
		
		action def TransportItem {
			in item garment : LaundryItem;
			in conveyorSpeed : SpeedValue;
		}
	}
	
	part def OutputStacker {
		port itemOutput : LaundryOutputPort;
		attribute stackCapacity : Natural;
		attribute currentCount : Natural;
		
		action def StackItem {
			in item foldedGarment : LaundryItem;
		}
	}
	
	part def ProcessController {
		action def AnalyzeGarment {
			in category : GarmentCategory;
			in dimensions : GarmentDimensions;
			out foldingPlan : FoldingSequence;
		}
		
		action def CoordinateArms {
			in plan : FoldingSequence;
			out leftArmCommands : ActuatorPort[*];
			out rightArmCommands : ActuatorPort[*];
		}
	}
	
	action def DetectAndClassify {
		in item incomingItem : LaundryItem;
		out dimensions : GarmentDimensions;
		out category : GarmentCategory;
	}
	
	action def PlaceOnSurface {
		in item garment : LaundryItem;
		in dimensions : GarmentDimensions;
	}
	
	action def PerformFolding {
		in plan : FoldingSequence;
		in item garment : LaundryItem;
		out item foldedGarment : LaundryItem;
	}
	
	action def TransferToOutput {
		in item foldedGarment : LaundryItem;
	}
	
	action def AutomatedFoldingProcess {
		first start;
		then merge awaitItem;
		
		then action detect : DetectAndClassify {
			in item incomingItem;
			out dimensions;
			out category;
		}
		
		then action place : PlaceOnSurface {
			in item garment = detect.incomingItem;
			in dimensions = detect.dimensions;
		}
		
		then action analyze : ProcessController::AnalyzeGarment {
			in category = detect.category;
			in dimensions = detect.dimensions;
			out foldingPlan;
		}
		
		then action fold : PerformFolding {
			in plan = analyze.foldingPlan;
			in item garment = place.garment;
			out item foldedGarment;
		}
		
		then action transfer : TransferToOutput {
			in item foldedGarment = fold.foldedGarment;
		}
		
		then awaitItem;
	}
	
	part def LaundryFoldingMachine {
		doc /* An automated system that receives unfolded laundry items,
		     analyzes their type and dimensions, executes precise folding
		     operations using robotic arms, and outputs neatly folded items
		     ready for storage or delivery. */
		
		part visionSystem : VisionSensor;
		part leftFoldingArm : FoldingArm;
		part rightFoldingArm : FoldingArm;
		part foldingSurface : FoldingSurface;
		part inputConveyor : InputConveyor;
		part outputStacker : OutputStacker;
		part controller : ProcessController;
	}
	
	part laundryFoldingMachine : LaundryFoldingMachine {
		
		perform action foldingCycle[*] ordered references AutomatedFoldingProcess;
		
		part redefines visionSystem : VisionSensor {
			perform foldingCycle.detect;
		}
		
		part redefines leftFoldingArm : FoldingArm {
			perform foldingCycle.fold;
		}
		
		part redefines rightFoldingArm : FoldingArm {
			perform foldingCycle.fold;
		}
		
		part redefines foldingSurface : FoldingSurface {
			perform foldingCycle.place;
		}
		
		part redefines inputConveyor : InputConveyor {
			port laundryInput : LaundryInputPort;
		}
		
		part redefines outputStacker : OutputStacker {
			port laundryOutput : LaundryOutputPort;
			perform foldingCycle.transfer;
		}
		
		part redefines controller : ProcessController {
			perform foldingCycle.analyze;
		}
		
		connect visionSystem.sensorData to controller;
		connect controller to leftFoldingArm.actuatorControl;
		connect controller to rightFoldingArm.actuatorControl;
	}
	
	requirement def FunctionalRequirement;
	requirement def PerformanceRequirement;
	requirement def QualityRequirement;
	
	requirement <'LFM-REQ-001'> primaryFunctionRequirement : FunctionalRequirement {
		doc /* The laundry folding machine shall automatically fold laundry items
		     by receiving unfolded garments, detecting their type and dimensions,
		     determining the appropriate folding pattern, executing coordinated
		     robotic folding motions, and outputting neatly folded items. */
		
		subject machine : LaundryFoldingMachine;
		
		require constraint {
			machine.visionSystem != null and
			machine.leftFoldingArm != null and
			machine.rightFoldingArm != null and
			machine.foldingSurface != null and
			machine.inputConveyor != null and
			machine.outputStacker != null and
			machine.controller != null
		}
	}
	
	requirement <'LFM-REQ-002'> throughputRequirement : PerformanceRequirement {
		doc /* The system shall process a minimum of 15 garments per hour
		     during continuous operation. */
		
		subject machine : LaundryFoldingMachine;
		
		attribute minimumThroughput : Real = 15.0;
	}
	
	requirement <'LFM-REQ-003'> foldQualityRequirement : QualityRequirement {
		doc /* Folded garments shall have edge alignment within 2 cm tolerance
		     and consistent fold patterns for each garment category. */
		
		subject machine : LaundryFoldingMachine;
		
		attribute maxAlignmentError : LengthValue;
	}
	
	requirement <'LFM-REQ-004'> stackingCapacityRequirement : FunctionalRequirement {
		doc /* The output stacker shall accommodate at least 25 folded items
		     before requiring unloading. */
		
		subject stacker : OutputStacker;
		
		require constraint {
			stacker.stackCapacity >= 25
		}
	}
	
	requirement systemMission {
		doc /* The laundry folding machine system shall provide automated
		     folding capability to reduce manual labor and improve consistency
		     in laundry processing operations. */
		
		assume constraint inputAvailability {
			doc /* Unfolded laundry items are continuously available at the input. */
		}
		
		require primaryFunctionRequirement;
		require throughputRequirement;
		require foldQualityRequirement;
		require stackingCapacityRequirement;
	}
}
