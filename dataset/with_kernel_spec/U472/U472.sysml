package 'Manual Beer Engine' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	item def Beer {
		attribute temperature :> ISQ::thermodynamicTemperature;
		attribute carbonationLevel : Real;
		attribute volume :> ISQ::volume;
	}

	port def BeerPort {
		out item beer : Beer;
	}

	part def Cask {
		port beerOutPort : BeerPort;
		item caskBeer : Beer;
		attribute cellarTemperature :> ISQ::thermodynamicTemperature
			= 285.15 * SI::kelvin;
		attribute internalPressure :> ISQ::pressure
			= 101325 * SI::pascal;
	}

	part def BeerLine {
		port beerInPort : ~BeerPort;
		port beerOutPort : BeerPort;
	}

	part def Handle {
		attribute isPulled : Boolean = false;
		attribute isResting : Boolean = true;
		attribute strokePosition :> ISQ::length;
		attribute appliedForce :> ISQ::force;
	}

	part def Piston {
		attribute position :> ISQ::length;
	}

	part def CheckValve {
		port beerInPort : ~BeerPort;
		port beerOutPort : BeerPort;
		attribute isOpen : Boolean = false;
	}

	part def Cylinder {
		port inletPort : ~BeerPort;
		port outletPort : BeerPort;
		item chamberBeer : Beer;
		attribute chamberVolume :> ISQ::volume;
		attribute strokeVolume :> ISQ::volume;
		part piston : Piston;
		part inletValve : CheckValve;
		part outletValve : CheckValve;
	}

	action def DrawBeer {
		in beerIn : Beer;
		out chamberBeer : Beer;
	}

	action def DispenseBeer {
		in chamberBeer : Beer;
		out beerOut : Beer;
	}

	state machine def PumpCycle {
		state Idle;
		state Pulling;
		state Pushing;
		transition Idle -> Pulling when handle.isPulled;
		transition Pulling -> Pushing when !handle.isPulled;
		transition Pushing -> Idle when handle.isResting;
	}

	part def PumpAssembly {
		port beerInPort : ~BeerPort;
		port beerOutPort : BeerPort;
		part handle : Handle;
		part cylinder : Cylinder;

		bind beerInPort = cylinder.inletPort;
		bind beerOutPort = cylinder.outletPort;

		perform state machine pumpCycle : PumpCycle;
	}

	part def DispensingTap {
		port beerInPort : ~BeerPort;
		port beerOutPort : BeerPort;
	}

	part def Glass {
		port beerInPort : ~BeerPort;
		item servedBeer : Beer;
		attribute capacity :> ISQ::volume;
		attribute fillLevel :> ISQ::volume;
	}

	calc def StrokesForPint {
		in pintVolume :> ISQ::volume;
		in strokeVolume :> ISQ::volume;
		return : Real = pintVolume / strokeVolume;
	}

	requirement def PreserveCarbonation {
		requirement {
			/* The system shall dispense beer without using pressurized gas. */
		}
	}

	requirement def ConsistentStrokeVolume {
		attribute halfPintVolume :> ISQ::volume;
		requirement {
			/* Each complete pull-and-push cycle shall dispense a consistent half-pint volume. */
		}
	}

	requirement def TwoStrokesPerPint {
		attribute pintVolume :> ISQ::volume;
		requirement {
			/* Pouring a full pint shall require exactly two complete strokes of the handle. */
		}
	}

	requirement def CellarConditions {
		attribute targetTemperature :> ISQ::thermodynamicTemperature
			= 285.15 * SI::kelvin;
		attribute maxPressure :> ISQ::pressure
			= 101325 * SI::pascal;
		requirement {
			/* The cask shall maintain beer at cellar temperature and near-atmospheric pressure. */
		}
	}

	part def BeerEngine {
		part cask : Cask;
		part supplyLine : BeerLine;
		part pump : PumpAssembly;
		part deliveryLine : BeerLine;
		part tap : DispensingTap;
		part glass : Glass;

		flow of beer : Beer
			from cask.beerOutPort.beer to supplyLine.beerInPort.beer;
		flow of beer : Beer
			from supplyLine.beerOutPort.beer to pump.beerInPort.beer;
		flow of beer : Beer
			from pump.beerOutPort.beer to deliveryLine.beerInPort.beer;
		flow of beer : Beer
			from deliveryLine.beerOutPort.beer to tap.beerInPort.beer;
		flow of beer : Beer
			from tap.beerOutPort.beer to glass.beerInPort.beer;
	}

	requirement preserveCarbonation : PreserveCarbonation;
	requirement consistentStrokeVolume : ConsistentStrokeVolume;
	requirement twoStrokesPerPint : TwoStrokesPerPint;
	requirement cellarConditions : CellarConditions;

	part beerEngine : BeerEngine {
		satisfy preserveCarbonation;
		satisfy consistentStrokeVolume;
		satisfy twoStrokesPerPint;
		satisfy cellarConditions;
	}
}
