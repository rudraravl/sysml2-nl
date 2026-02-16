package 'Wave Soldering System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ConveyorSpeed :> ISQ::SpeedValue;
	attribute def SolderTemperature :> ISQ::TemperatureValue;
	attribute def FluxDensity :> Real;
	attribute def WaveHeight :> ISQ::LengthValue;
	attribute def PreheatingTemperature :> ISQ::TemperatureValue;
	attribute def DwellTime :> ISQ::TimeValue;
	
	item def PCB {
		attribute boardID : String;
		attribute hasComponents : Boolean;
		attribute isFluxed : Boolean := false;
		attribute isPreheated : Boolean := false;
		attribute isSoldered : Boolean := false;
		attribute qualityPassed : Boolean := false;
		attribute componentCount : Integer;
	}
	
	item def SolderAlloy {
		attribute composition : String;
		attribute meltingPoint : SolderTemperature;
		attribute tinContent : Real;
		attribute leadContent : Real;
	}
	
	item def Flux {
		attribute density : FluxDensity;
		attribute activationTemp : PreheatingTemperature;
		attribute fluxType : String;
	}
	
	port def BoardInputPort {
		in board : PCB;
	}
	
	port def BoardOutputPort {
		out board : PCB;
	}
	
	port def PowerPort {
		in power : ISQ::PowerValue;
	}
	
	part def ConveyorBelt {
		attribute speed : ConveyorSpeed;
		attribute beltWidth : ISQ::LengthValue;
		port input : BoardInputPort;
		port output : BoardOutputPort;
		port electrical : PowerPort;
	}
	
	part def FluxingUnit {
		attribute fluxDensity : FluxDensity;
		attribute applicationMethod : String;
		port input : BoardInputPort;
		port output : BoardOutputPort;
		part fluxReservoir {
			attribute capacity : ISQ::VolumeValue;
			attribute currentLevel : ISQ::VolumeValue;
		}
		part sprayNozzles {
			attribute nozzleCount : Integer;
			attribute flowRate : Real;
		}
	}
	
	part def PreheatingZone {
		attribute preheatingTemp : PreheatingTemperature;
		attribute zoneLength : ISQ::LengthValue;
		attribute numberOfZones : Integer;
		port input : BoardInputPort;
		port output : BoardOutputPort;
		port electrical : PowerPort;
		part heatingElements {
			attribute elementPower : ISQ::PowerValue;
			attribute elementCount : Integer;
		}
		part temperatureSensors {
			attribute sensorCount : Integer;
			attribute accuracy : Real;
		}
	}
	
	part def WaveSolderingUnit {
		attribute solderTemp : SolderTemperature;
		attribute waveHeight : WaveHeight;
		attribute waveAngle : Real;
		attribute contactTime : DwellTime;
		port input : BoardInputPort;
		port output : BoardOutputPort;
		port electrical : PowerPort;
		
		part solderPot {
			attribute capacity : ISQ::VolumeValue;
			attribute currentTemp : SolderTemperature;
			attribute currentLevel : ISQ::VolumeValue;
		}
		
		part waveGenerator {
			attribute pumpSpeed : ISQ::SpeedValue;
			attribute waveProfile : String;
			attribute motorPower : ISQ::PowerValue;
		}
		
		part heatingSystem {
			attribute heaterPower : ISQ::PowerValue;
			attribute controlAccuracy : Real;
		}
	}
	
	part def CoolingZone {
		attribute coolingRate : Real;
		attribute ambientTemp : ISQ::TemperatureValue;
		attribute zoneLength : ISQ::LengthValue;
		port input : BoardInputPort;
		port output : BoardOutputPort;
		
		part coolingFans {
			attribute fanCount : Integer;
			attribute airflowRate : Real;
		}
	}
	
	part def InspectionStation {
		attribute inspectionCriteria : String;
		attribute rejectionRate : Real;
		port input : BoardInputPort;
		port acceptOutput : BoardOutputPort;
		port rejectOutput : BoardOutputPort;
		
		part visionSystem {
			attribute cameraCount : Integer;
			attribute resolution : String;
		}
		
		part qualityController {
			attribute processingSpeed : Real;
		}
	}
	
	action def ApplyFluxAction {
		in pcb : PCB;
		in flux : Flux;
		in density : FluxDensity;
		out fluxedPCB : PCB;
	}
	
	action def PreheatAction {
		in pcb : PCB;
		in temperature : PreheatingTemperature;
		in dwellTime : DwellTime;
		out preheatedPCB : PCB;
	}
	
	action def SolderAction {
		in pcb : PCB;
		in solder : SolderAlloy;
		in waveHeight : WaveHeight;
		in temperature : SolderTemperature;
		in contactTime : DwellTime;
		out solderedPCB : PCB;
	}
	
	action def CoolAction {
		in pcb : PCB;
		in coolingRate : Real;
		out cooledPCB : PCB;
	}
	
	action def InspectAction {
		in pcb : PCB;
		out qualityPassed : Boolean;
		out finalPCB : PCB;
	}
	
	action def WaveSolderingProcess {
		in inputBoard : PCB;
		in fluxMaterial : Flux;
		in solderMaterial : SolderAlloy;
		in processSpeed : ConveyorSpeed;
		in processTemp : SolderTemperature;
		in waveParams : WaveHeight;
		out outputBoard : PCB;
		out qualityResult : Boolean;
		
		first start;
		
		then action loadBoard {
			in board = inputBoard;
			out loadedBoard : PCB;
		}
		
		then action fluxing : ApplyFluxAction {
			in pcb = loadBoard.loadedBoard;
			in flux = fluxMaterial;
			in density : FluxDensity;
			out fluxedPCB : PCB;
		}
		
		then action preheating : PreheatAction {
			in pcb = fluxing.fluxedPCB;
			in temperature : PreheatingTemperature;
			in dwellTime : DwellTime;
			out preheatedPCB : PCB;
		}
		
		then action soldering : SolderAction {
			in pcb = preheating.preheatedPCB;
			in solder = solderMaterial;
			in waveHeight = waveParams;
			in temperature = processTemp;
			in contactTime : DwellTime;
			out solderedPCB : PCB;
		}
		
		then action cooling : CoolAction {
			in pcb = soldering.solderedPCB;
			in coolingRate : Real;
			out cooledPCB : PCB;
		}
		
		then action inspection : InspectAction {
			in pcb = cooling.cooledPCB;
			out qualityPassed : Boolean;
			out finalPCB : PCB;
		}
		
		then decide;
			if inspection.qualityPassed then acceptBoard;
			if not inspection.qualityPassed then rejectBoard;
		
		action acceptBoard {
			in board = inspection.finalPCB;
			out accepted : PCB;
		}
		then merge complete;
		
		action rejectBoard {
			in board = inspection.finalPCB;
			out rejected : PCB;
		}
		then merge complete;
		
		merge complete;
		then assign outputBoard := inspection.finalPCB;
		then assign qualityResult := inspection.qualityPassed;
		then done;
	}
	
	attribute def WarmupCommand;
	attribute def TemperatureReached;
	attribute def ProcessBoard;
	attribute def BoardComplete;
	attribute def FaultDetected;
	attribute def FaultCleared;
	attribute def ShutdownCommand;
	attribute def CooldownComplete;
	
	state def SystemStates {
		entry; then idle;
		
		state idle;
		transition warmup
			first idle
			accept WarmupCommand
			then preheating;
		
		state preheating;
		transition ready
			first preheating
			accept TemperatureReached
			then operational;
		
		state operational;
		transition process
			first operational
			accept ProcessBoard
			then processing;
		transition shutdown
			first operational
			accept ShutdownCommand
			then shuttingDown;
		
		state processing;
		transition complete
			first processing
			accept BoardComplete
			then operational;
		transition fault
			first processing
			accept FaultDetected
			then faulted;
		
		state faulted;
		transition recover
			first faulted
			accept FaultCleared
			then operational;
		
		state shuttingDown;
		transition off
			first shuttingDown
			accept CooldownComplete
			then idle;
	}
	
	part waveSolderingSystem {
		attribute systemSpeed : ConveyorSpeed;
		attribute operatingTemp : SolderTemperature;
		attribute targetWaveHeight : WaveHeight;
		attribute throughputRate : Real;
		
		perform action processBoards[*] ordered {
			in inputBoard : PCB;
			in fluxMaterial : Flux;
			in solderMaterial : SolderAlloy;
			in processSpeed : ConveyorSpeed;
			in processTemp : SolderTemperature;
			in waveParams : WaveHeight;
			out outputBoard : PCB;
			out qualityResult : Boolean;
		}
		
		part conveyor : ConveyorBelt {
			attribute speed = waveSolderingSystem.systemSpeed;
			attribute beltWidth = 300.0[mm];
		}
		
		part fluxer : FluxingUnit {
			attribute fluxDensity = 0.85;
			attribute applicationMethod = "spray";
		}
		
		part preheater : PreheatingZone {
			attribute preheatingTemp = 373.15[K];
			attribute zoneLength = 600.0[mm];
			attribute numberOfZones = 3;
		}
		
		part solderingUnit : WaveSolderingUnit {
			attribute solderTemp = waveSolderingSystem.operatingTemp;
			attribute waveHeight = waveSolderingSystem.targetWaveHeight;
			attribute waveAngle = 7.0;
			attribute contactTime = 3.0[s];
		}
		
		part cooler : CoolingZone {
			attribute coolingRate = 2.5;
			attribute ambientTemp = 298.15[K];
			attribute zoneLength = 800.0[mm];
		}
		
		part inspector : InspectionStation {
			attribute inspectionCriteria = "IPC-A-610";
			attribute rejectionRate = 0.02;
		}
		
		connect conveyor.output to fluxer.input;
		connect fluxer.output to preheater.input;
		connect preheater.output to solderingUnit.input;
		connect solderingUnit.output to cooler.input;
		connect cooler.output to inspector.input;
	}
	
	requirement def PrimaryFunctionRequirement {
		doc /* The wave soldering system shall create reliable electrical and mechanical connections 
		       between through-hole component leads and PCB pads by passing the board over a molten 
		       solder wave, ensuring complete wetting and joint formation. */
		
		subject system : waveSolderingSystem;
	}
	
	requirement def SolderingQualityRequirement {
		doc /* All solder joints shall meet IPC-A-610 Class 2 standards with proper wetting, 
		       no bridging, and complete hole fill. */
		
		subject board : PCB;
		
		require constraint {
			board.isSoldered and board.qualityPassed
		}
	}
	
	requirement def TemperatureControlRequirement {
		doc /* The solder wave temperature shall be maintained at 250°C ±5°C during operation. */
		
		subject unit : WaveSolderingUnit;
		
		require constraint {
			unit.solderTemp >= 518.15[K] and unit.solderTemp <= 528.15[K]
		}
	}
	
	requirement def ThroughputRequirement {
		doc /* The system shall process at least 1.2 meters of PCB per minute at nominal speed. */
		
		subject system : waveSolderingSystem;
		
		require constraint {
			system.systemSpeed >= 0.02[m/s]
		}
	}
	
	requirement def PreheatingRequirement {
		doc /* PCBs shall be preheated to 100°C ±10°C before entering the solder wave 
		       to prevent thermal shock and ensure proper flux activation. */
		
		subject zone : PreheatingZone;
		
		require constraint {
			zone.preheatingTemp >= 363.15[K] and zone.preheatingTemp <= 383.15[K]
		}
	}
	
	requirement def FluxApplicationRequirement {
		doc /* Flux shall be uniformly applied to all solder surfaces with density 
		       between 0.8 and 0.9 g/cm². */
		
		subject fluxer : FluxingUnit;
		
		require constraint {
			fluxer.fluxDensity >= 0.8 and fluxer.fluxDensity <= 0.9
		}
	}
	
	requirement systemRequirements {
		doc /* The wave soldering system shall produce high-quality solder joints meeting 
		       industry standards while maintaining specified throughput and process control. */
		
		subject system : waveSolderingSystem;
		
		require PrimaryFunctionRequirement;
		require SolderingQualityRequirement;
		require TemperatureControlRequirement;
		require ThroughputRequirement;
		require PreheatingRequirement;
		require FluxApplicationRequirement;
	}
}
