package ThreeDPrintingSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def MaterialType;
	attribute def PLAMaterial :> MaterialType;
	attribute def ABSMaterial :> MaterialType;
	attribute def PETGMaterial :> MaterialType;
	
	attribute def PrintCommand;
	attribute def HeatingCommand;
	attribute def MotionCommand;
	attribute def ExtrusionCommand;
	attribute def CoolingCommand;
	
	item def Filament {
		attribute material : MaterialType;
		attribute diameter : LengthValue;
		attribute meltingTemperature : ThermodynamicTemperatureValue;
		attribute remainingMass : MassValue;
	}
	
	item def DigitalModel {
		attribute fileName : String;
		attribute totalLayers : Integer;
		attribute estimatedPrintTime : TimeValue;
		attribute requiredMaterial : MassValue;
	}
	
	item def PrintedObject {
		attribute dimensions : LengthValue[3];
		attribute layerHeight : LengthValue;
		attribute completedLayers : Integer;
		attribute totalMass : MassValue;
	}
	
	port def PowerPort {
		in attribute voltage : ElectricPotentialDifferenceValue;
		in attribute current : ElectricCurrentValue;
	}
	
	port def DataPort {
		in attribute modelData : DigitalModel;
		out attribute printStatus : String;
		out attribute progress : Real;
	}
	
	port def FilamentPort {
		in item filament : Filament;
	}
	
	part def Hotend {
		attribute nozzleTemperature : ThermodynamicTemperatureValue;
		attribute targetTemperature : ThermodynamicTemperatureValue;
		attribute nozzleDiameter : LengthValue;
		
		port powerIn : PowerPort;
		
		action heatNozzle {
			in cmd : HeatingCommand;
			in target : ThermodynamicTemperatureValue;
			inout current : ThermodynamicTemperatureValue;
		}
	}
	
	part def ExtrusionSystem {
		attribute extrusionRate : VolumeFlowRateValue;
		attribute stepperPosition : Real;
		
		port filamentInput : FilamentPort;
		
		action feedFilament {
			in cmd : ExtrusionCommand;
			in rate : VolumeFlowRateValue;
			in filament : Filament;
			out extrudedVolume : VolumeValue;
		}
	}
	
	part def MotionSystem {
		attribute xPosition : LengthValue;
		attribute yPosition : LengthValue;
		attribute zPosition : LengthValue;
		attribute feedRate : SpeedValue;
		
		port powerIn : PowerPort;
		
		action moveToPosition {
			in cmd : MotionCommand;
			in targetX : LengthValue;
			in targetY : LengthValue;
			in targetZ : LengthValue;
			in speed : SpeedValue;
			out newX : LengthValue;
			out newY : LengthValue;
			out newZ : LengthValue;
		}
	}
	
	part def HeatedBed {
		attribute bedTemperature : ThermodynamicTemperatureValue;
		attribute targetBedTemperature : ThermodynamicTemperatureValue;
		attribute surfaceArea : AreaValue;
		
		port powerIn : PowerPort;
		
		action heatBed {
			in target : ThermodynamicTemperatureValue;
			inout current : ThermodynamicTemperatureValue;
		}
	}
	
	part def ControllerBoard {
		attribute firmwareVersion : String;
		attribute processingSpeed : FrequencyValue;
		
		port dataInterface : DataPort;
		port powerIn : PowerPort;
		
		action parseModel {
			in model : DigitalModel;
			out motionCommands : MotionCommand[*] ordered;
			out extrusionCommands : ExtrusionCommand[*] ordered;
			out heatingCommands : HeatingCommand[*] ordered;
		}
		
		action monitorProgress {
			in currentLayer : Integer;
			in totalLayers : Integer;
			out progressPercent : Real;
			out status : String;
		}
	}
	
	part def CoolingFan {
		attribute fanSpeed : FrequencyValue;
		attribute airflowRate : VolumeFlowRateValue;
		
		port powerIn : PowerPort;
		
		action coolPrint {
			in cmd : CoolingCommand;
			in speed : FrequencyValue;
		}
	}
	
	part def FDMPrinter {
		attribute buildVolumeX : LengthValue;
		attribute buildVolumeY : LengthValue;
		attribute buildVolumeZ : LengthValue;
		attribute maxPrintSpeed : SpeedValue;
		
		port mainPower : PowerPort;
		port userInterface : DataPort;
		port materialInput : FilamentPort;
		
		part hotend : Hotend {
			port redefines powerIn = mainPower;
		}
		
		part extruder : ExtrusionSystem {
			port redefines filamentInput = materialInput;
		}
		
		part motion : MotionSystem {
			port redefines powerIn = mainPower;
		}
		
		part bed : HeatedBed {
			port redefines powerIn = mainPower;
		}
		
		part controller : ControllerBoard {
			port redefines dataInterface = userInterface;
			port redefines powerIn = mainPower;
		}
		
		part coolingFan : CoolingFan {
			port redefines powerIn = mainPower;
		}
		
		connection tempConnection connect hotend.nozzleTemperature to extruder.filamentInput;
	}
	
	action def InitializeSystem {
		out systemReady : Boolean;
	}
	
	action def HomeAxes {
		out xHomed : Boolean;
		out yHomed : Boolean;
		out zHomed : Boolean;
	}
	
	action def PreheatComponents {
		in nozzleTarget : ThermodynamicTemperatureValue;
		in bedTarget : ThermodynamicTemperatureValue;
		inout nozzleTemp : ThermodynamicTemperatureValue;
		inout bedTemp : ThermodynamicTemperatureValue;
		out heatingComplete : Boolean;
	}
	
	action def ProcessLayerCommands {
		in layerIndex : Integer;
		in motionCmds : MotionCommand[*] ordered;
		in extrusionCmds : ExtrusionCommand[*] ordered;
		in currentX : LengthValue;
		in currentY : LengthValue;
		in currentZ : LengthValue;
		out finalX : LengthValue;
		out finalY : LengthValue;
		out finalZ : LengthValue;
		out layerComplete : Boolean;
	}
	
	action def FinalizeAndCool {
		in nozzleTemp : ThermodynamicTemperatureValue;
		in bedTemp : ThermodynamicTemperatureValue;
		out coolingComplete : Boolean;
	}
	
	action def RemovePrintedObject {
		out object : PrintedObject;
	}
	
	action def AdditiveManufacturing {
		doc /* 
		The primary function of the 3D printing system is to transform a digital three-dimensional 
		model into a physical object through additive manufacturing. The system operates by heating 
		thermoplastic filament to its melting point and precisely depositing it layer by layer onto 
		a heated build platform. A motion system controls the position of the print head in three 
		dimensions, following programmed toolpaths to construct each cross-sectional layer of the 
		object. This process repeats, with each new layer bonding to the previous one, until the 
		complete three-dimensional form is realized. The system continuously monitors temperatures, 
		positions, and material flow to ensure dimensional accuracy and structural integrity of the 
		final printed part.
		*/
		
		in printJob : PrintCommand;
		in digitalModel : DigitalModel;
		in filamentSpool : Filament;
		out finishedPart : PrintedObject;
		
		private attribute layerCounter : Integer := 0;
		private attribute posX : LengthValue := 0.0[mm];
		private attribute posY : LengthValue := 0.0[mm];
		private attribute posZ : LengthValue := 0.0[mm];
		private attribute nozzleTemp : ThermodynamicTemperatureValue := 298.15[K];
		private attribute bedTemp : ThermodynamicTemperatureValue := 298.15[K];
		private attribute systemStatus : String;
		
		first start;
		
		then action initialize : InitializeSystem {
			out systemReady;
		}
		
		then decide;
			if initialize.systemReady then homeSystem;
			else errorState;
		
		action homeSystem : HomeAxes {
			out xHomed;
			out yHomed;
			out zHomed;
		}
		
		then assign posX := 0.0[mm];
		then assign posY := 0.0[mm];
		then assign posZ := 0.0[mm];
		
		then action preheat : PreheatComponents {
			in nozzleTarget = 483.15[K];
			in bedTarget = 333.15[K];
			inout nozzleTemp = nozzleTemp;
			inout bedTemp = bedTemp;
			out heatingComplete;
		}
		
		then assign nozzleTemp := preheat.nozzleTemp;
		then assign bedTemp := preheat.bedTemp;
		
		then decide;
			if preheat.heatingComplete then startPrinting;
			else errorState;
		
		action startPrinting;
		
		then merge nextLayerCheck;
		
		then decide;
			if layerCounter < digitalModel.totalLayers then printLayer;
			if layerCounter >= digitalModel.totalLayers then finishPrint;
		
		action printLayer : ProcessLayerCommands {
			in layerIndex = layerCounter;
			in motionCmds;
			in extrusionCmds;
			in currentX = posX;
			in currentY = posY;
			in currentZ = posZ;
			out finalX;
			out finalY;
			out finalZ;
			out layerComplete;
		}
		
		then assign posX := printLayer.finalX;
		then assign posY := printLayer.finalY;
		then assign posZ := printLayer.finalZ;
		then assign layerCounter := layerCounter + 1;
		then nextLayerCheck;
		
		action finishPrint : FinalizeAndCool {
			in nozzleTemp = nozzleTemp;
			in bedTemp = bedTemp;
			out coolingComplete;
		}
		
		then action removePart : RemovePrintedObject {
			out object;
		}
		
		then assign finishedPart := removePart.object;
		then done;
		
		action errorState;
		then done;
	}
	
	part printer : FDMPrinter {
		perform action fabricate[*] ordered : AdditiveManufacturing;
		
		part redefines hotend {
			perform fabricate.preheat;
		}
		
		part redefines extruder {
			perform fabricate.printLayer;
		}
		
		part redefines motion {
			perform fabricate.homeSystem;
			perform fabricate.printLayer;
		}
		
		part redefines bed {
			perform fabricate.preheat;
		}
		
		part redefines controller {
			perform fabricate.initialize;
		}
		
		part redefines coolingFan {
			perform fabricate.finishPrint;
		}
		
		satisfy primaryFunction;
		satisfy materialHandling;
		satisfy buildVolume;
		satisfy operationalSafety;
	}
	
	requirement <'3DP-REQ-001'> primaryFunction {
		doc /* 
		The 3D printing system shall fabricate physical three-dimensional objects from digital 
		models by depositing thermoplastic material in successive layers with controlled positioning 
		and temperature management to achieve dimensional accuracy within specified tolerances.
		*/
		
		require constraint layerAccuracy {
			doc /* Layer positioning shall maintain accuracy within ±0.1mm in X and Y axes. */
		}
		
		require constraint verticalResolution {
			doc /* Minimum layer height shall be 0.05mm with maximum layer height of 0.4mm. */
		}
		
		require constraint temperatureStability {
			doc /* Nozzle temperature shall be maintained within ±3K of target during printing. */
		}
	}
	
	requirement <'3DP-REQ-002'> materialHandling {
		doc /* 
		The system shall support multiple thermoplastic materials including PLA, ABS, and PETG 
		with appropriate temperature profiles and extrusion parameters for each material type.
		*/
		
		assume constraint filamentDiameter {
			doc /* Input filament diameter shall be 1.75mm ±0.05mm or 2.85mm ±0.10mm. */
		}
		
		require constraint materialCompatibility {
			doc /* System shall support nozzle temperatures from 453K to 553K. */
		}
	}
	
	requirement <'3DP-REQ-003'> buildVolume {
		doc /* 
		The system shall provide a minimum build volume of 200mm × 200mm × 200mm to accommodate 
		a range of part sizes for prototyping and manufacturing applications.
		*/
	}
	
	requirement <'3DP-REQ-004'> operationalSafety {
		doc /* 
		The system shall incorporate thermal protection, emergency stop capability, and enclosure 
		monitoring to ensure safe operation and prevent hazards from heated components and moving parts.
		*/
		
		require constraint thermalRunaway {
			doc /* System shall detect and respond to thermal runaway conditions within 5 seconds. */
		}
		
		require constraint emergencyStop {
			doc /* Emergency stop shall halt all motion and heating within 1 second of activation. */
		}
	}
}
