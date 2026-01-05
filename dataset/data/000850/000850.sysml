package BeerEngineSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import NumericalFunctions::*;
	
	attribute def VolumeValue :> ISQ::VolumeValue;
	attribute def PressureValue :> ISQ::PressureValue;
	attribute def TemperatureValue :> ISQ::TemperatureValue;
	attribute def ForceValue :> ISQ::ForceValue;
	attribute def LengthValue :> ISQ::LengthValue;
	
	item def Beer {
		attribute volume : VolumeValue;
		attribute temperature : TemperatureValue;
	}
	
	item def HandlePullCommand;
	item def HandleReleaseCommand;
	item def PressureReading {
		attribute pressure : PressureValue;
	}
	
	port def FluidPort {
		attribute pressure : PressureValue;
	}
	
	port def MechanicalPort;
	
	interface def FluidConnection {
		end source : FluidPort;
		end destination : FluidPort;
	}
	
	part def Cask {
		doc /* Container holding conditioned beer at cellar temperature under atmospheric pressure. */
		attribute capacity : VolumeValue;
		attribute currentVolume : VolumeValue;
		attribute beerTemperature : TemperatureValue;
		attribute internalPressure : PressureValue;
		port outlet : FluidPort;
		
		assert constraint {
			currentVolume >= 0 [L] and currentVolume <= capacity
		}
	}
	
	part def CheckValve {
		doc /* One-way valve allowing flow in single direction when pressure differential exceeds threshold. */
		attribute crackingPressure : PressureValue;
		attribute isOpen : Boolean;
		port inlet : FluidPort;
		port outlet : FluidPort;
	}
	
	part def PumpCylinder {
		doc /* Reciprocating cylinder that draws and expels beer through valve action. */
		attribute strokeVolume : VolumeValue;
		attribute pistonPosition : LengthValue;
		attribute cylinderDiameter : LengthValue;
		port inlet : FluidPort;
		port outlet : FluidPort;
		port handleConnection : MechanicalPort;
		
		part inletValve : CheckValve {
			attribute :>> crackingPressure = 0.5 [kPa];
			port :>> inlet;
			port :>> outlet;
		}
		
		part outletValve : CheckValve {
			attribute :>> crackingPressure = 0.3 [kPa];
			port :>> inlet;
			port :>> outlet;
		}
		
		state pumpCycle {
			entry; then idle;
			
			state idle;
			accept handlePull : HandlePullCommand;
			then drawingStroke;
			
			state drawingStroke {
				doc /* Piston moves up, creating vacuum that opens inlet valve and draws beer from cask. */
				entry; then do drawBeer;
			}
			accept handleRelease : HandleReleaseCommand;
			then dispensingStroke;
			
			state dispensingStroke {
				doc /* Piston moves down, pressurizing chamber to open outlet valve and expel beer. */
				entry; then do dispenseBeer;
			}
			then idle;
		}
		
		action drawBeer {
			doc /* Draw beer from cask into cylinder chamber. */
		}
		
		action dispenseBeer {
			doc /* Expel beer from cylinder to tap outlet. */
		}
	}
	
	part def PumpHandle {
		doc /* Manual lever operated by bartender to actuate pump cylinder. */
		attribute handleLength : LengthValue;
		attribute currentAngle : Real;
		port mechanicalOutput : MechanicalPort;
		
		event occurrence pulled;
		event occurrence released;
	}
	
	part def Tap {
		doc /* Outlet spout where beer is dispensed into serving vessel. */
		attribute isOpen : Boolean;
		port inlet : FluidPort;
	}
	
	part def BeerLine {
		doc /* Tubing connecting components in beer delivery path. */
		attribute length : LengthValue;
		attribute diameter : LengthValue;
		port p1 : FluidPort;
		port p2 : FluidPort;
	}
	
	action def MonitorCaskPressure {
		in caskPressure : PressureValue;
		out reading : PressureReading;
	}
	
	action def OperatePump {
		in strokeVolume : VolumeValue;
		in strokeCount : Integer;
		out dispensedVolume : VolumeValue;
	}
	
	action def ServeBeer {
		doc /* Complete action sequence to dispense beer from cask to serving vessel. */
		in requestedVolume : VolumeValue;
		out actualVolume : VolumeValue;
		
		first start;
		then merge continueServing;
		
		then action monitorPressure : MonitorCaskPressure {
			in caskPressure : PressureValue;
			out reading : PressureReading;
		}
		
		then action pumpStroke : OperatePump {
			in strokeVolume : VolumeValue;
			in strokeCount = 1;
			out dispensedVolume : VolumeValue;
		}
		
		then decide;
			if pumpStroke.dispensedVolume < requestedVolume then continueServing;
			if pumpStroke.dispensedVolume >= requestedVolume then complete;
		
		action complete;
		then done;
	}
	
	part def BeerEngine {
		doc /* Manual beer dispensing system using hand-operated pump to draw conditioned beer from cask. */
		
		attribute operatingTemperature : TemperatureValue;
		attribute totalDispensedVolume : VolumeValue;
		
		part cask : Cask {
			attribute :>> capacity = 40.9 [L];
			attribute :>> currentVolume = 35.0 [L];
			attribute :>> beerTemperature = 285.15 [K];
			attribute :>> internalPressure = 101.325 [kPa];
			port :>> outlet;
		}
		
		part caskLine : BeerLine {
			attribute :>> length = 0.5 [m];
			attribute :>> diameter = 0.01 [m];
			port :>> p1;
			port :>> p2;
		}
		
		part pump : PumpCylinder {
			attribute :>> strokeVolume = 0.284 [L];
			attribute :>> cylinderDiameter = 0.05 [m];
			port :>> inlet;
			port :>> outlet;
			port :>> handleConnection;
		}
		
		part handle : PumpHandle {
			attribute :>> handleLength = 0.3 [m];
			attribute :>> currentAngle = 0.0;
			port :>> mechanicalOutput;
		}
		
		part dispenseLine : BeerLine {
			attribute :>> length = 0.2 [m];
			attribute :>> diameter = 0.008 [m];
			port :>> p1;
			port :>> p2;
		}
		
		part tap : Tap {
			attribute :>> isOpen = true;
			port :>> inlet;
		}
		
		interface caskToPump : FluidConnection
			connect cask.outlet to caskLine.p1;
		
		interface lineToPumpInlet : FluidConnection
			connect caskLine.p2 to pump.inlet;
		
		interface pumpToDispenseLine : FluidConnection
			connect pump.outlet to dispenseLine.p1;
		
		interface lineToTap : FluidConnection
			connect dispenseLine.p2 to tap.inlet;
		
		connection handleToPump
			connect handle.mechanicalOutput to pump.handleConnection;
		
		perform action serveBeer : ServeBeer {
			in requestedVolume : VolumeValue;
			out actualVolume : VolumeValue;
		}
	}
	
	constraint def VolumeConstraint {
		in actual : VolumeValue;
		in target : VolumeValue;
		in tolerance : Real;
		abs(actual - target) <= target * tolerance
	}
	
	constraint def PressureRangeConstraint {
		in pressure : PressureValue;
		in minPressure : PressureValue;
		in maxPressure : PressureValue;
		pressure >= minPressure and pressure <= maxPressure
	}
	
	requirement def <'BE-REQ-001'> PrimaryFunctionRequirement {
		doc /* The beer engine shall dispense conditioned beer from a cask to a serving vessel 
		     through manual operation of a hand pump, maintaining beer quality and temperature. */
		subject engine : BeerEngine;
		
		attribute dispensedVolume : VolumeValue;
		attribute sourceVolume : VolumeValue;
		
		require constraint {
			dispensedVolume > 0 [L] and dispensedVolume <= sourceVolume
		}
	}
	
	requirement def <'BE-REQ-002'> StrokeVolumeRequirement {
		doc /* Each complete pump stroke shall dispense a consistent volume of beer 
		     within specified tolerance. */
		subject pump : PumpCylinder;
		
		attribute actualStrokeVolume : VolumeValue;
		attribute targetStrokeVolume : VolumeValue = 0.284 [L];
		attribute tolerance : Real = 0.05;
		
		require constraint volumeAccuracy : VolumeConstraint {
			in actual = actualStrokeVolume;
			in target = targetStrokeVolume;
			in tolerance = tolerance;
		}
	}
	
	requirement def <'BE-REQ-003'> TemperatureMaintenanceRequirement {
		doc /* The system shall maintain beer temperature within cellar temperature range 
		     during dispensing operation. */
		subject engine : BeerEngine;
		
		attribute beerTemperature : TemperatureValue;
		
		require constraint {
			beerTemperature >= 283.15 [K] and beerTemperature <= 287.15 [K]
		}
	}
	
	requirement def <'BE-REQ-004'> PressureOperatingRequirement {
		doc /* The system shall operate within safe pressure limits to prevent 
		     over-carbonation or component damage. */
		subject cask : Cask;
		
		require constraint pressureRange : PressureRangeConstraint {
			in pressure = cask.internalPressure;
			in minPressure = 95.0 [kPa];
			in maxPressure = 110.0 [kPa];
		}
	}
	
	part traditionalBeerEngine : BeerEngine {
		attribute :>> operatingTemperature = 285.15 [K];
		attribute :>> totalDispensedVolume = 0.0 [L];
		
		satisfy requirement primaryFunction : PrimaryFunctionRequirement {
			subject engine = traditionalBeerEngine;
			attribute :>> dispensedVolume = traditionalBeerEngine.totalDispensedVolume;
			attribute :>> sourceVolume = traditionalBeerEngine.cask.currentVolume;
		}
		
		satisfy requirement strokeVolume : StrokeVolumeRequirement {
			subject pump = traditionalBeerEngine.pump;
			attribute :>> actualStrokeVolume = traditionalBeerEngine.pump.strokeVolume;
		}
		
		satisfy requirement temperatureMaintenance : TemperatureMaintenanceRequirement {
			subject engine = traditionalBeerEngine;
			attribute :>> beerTemperature = traditionalBeerEngine.cask.beerTemperature;
		}
		
		satisfy requirement pressureOperation : PressureOperatingRequirement {
			subject cask = traditionalBeerEngine.cask;
		}
	}
	
	occurrence def SinglePintDispense {
		doc /* Sequence of events to dispense one pint of beer using the beer engine. */
		ref part engine : traditionalBeerEngine;
		
		message pullHandle1 of HandlePullCommand
			from engine.handle.pulled to engine.pump.handleConnection;
		then message releaseHandle1 of HandleReleaseCommand
			from engine.handle.released to engine.pump.handleConnection;
		then message pullHandle2 of HandlePullCommand
			from engine.handle.pulled to engine.pump.handleConnection;
		then message releaseHandle2 of HandleReleaseCommand
			from engine.handle.released to engine.pump.handleConnection;
	}
}
