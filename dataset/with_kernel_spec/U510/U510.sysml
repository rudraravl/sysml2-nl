package 'Handy Billy System' {
	private import ScalarValues::*;

	item def Gasoline;
	item def Water;

	attribute def Power :> Real { unit 'kW'; }
	attribute def Mass :> Real { unit 'kg'; }
	attribute def Duration :> Real { unit 'h'; }
	attribute def Time :> Real { unit 'min'; }

	attribute def StartSignal;
	attribute def PrimingCompleteSignal;
	attribute def StopSignal;
	attribute def ShutdownCompleteSignal;
	attribute def EngineOverheatSignal;
	attribute def EngineCoolSignal;
	attribute def LowFuelSignal;
	attribute def RefueledSignal;
	attribute def CavitationSignal;
	attribute def CavitationResolvedSignal;

	port def FuelOutPort { out item fuel : Gasoline; }
	port def FuelInPort { in item fuel : Gasoline; }
	port def WaterInPort { in item water : Water; }
	port def WaterOutPort { out item water : Water; }
	port def MechanicalPort;

	flow def FuelFlow {
		ref :>> payload : Gasoline;
		end port supplierPort : FuelOutPort;
		end port consumerPort : FuelInPort;
	}

	flow def WaterFlow {
		ref :>> payload : Water;
		end port supplierPort : WaterOutPort;
		end port consumerPort : WaterInPort;
	}

	interface def FuelInterface {
		end supplierPort : FuelOutPort;
		end consumerPort : FuelInPort;
	}

	interface def WaterInterface {
		end supplierPort : WaterOutPort;
		end consumerPort : WaterInPort;
	}

	interface def MechanicalInterface {
		end supplierPort : MechanicalPort;
		end consumerPort : MechanicalPort;
	}

	part def GalvanizedSteelFrame;

	part def GasolineEngine {
		attribute power : Power = 4;
		port fuelIn : FuelInPort;
		port mechanicalOut : MechanicalPort;
	}

	part def FuelTank {
		attribute capacity : Duration = 2;
		port fuelOut : FuelOutPort;
	}

	part def CentrifugalPump {
		port mechanicalIn : MechanicalPort;
		port waterIn : WaterInPort;
		port waterOut : WaterOutPort;
	}

	part def SuctionHose {
		port waterIn : WaterInPort;
		port waterOut : WaterOutPort;
	}

	part def Strainer {
		port waterOut : WaterOutPort;
	}

	part def DischargeHose {
		port waterIn : WaterInPort;
		port waterOut : WaterOutPort;
	}

	part def Nozzle {
		port waterIn : WaterInPort;
	}

	state def HandyBillyStates;

	state handyBillyStates : HandyBillyStates parallel {
		state operationalStates {
			entry; then idle;
			state idle;
			accept StartSignal then priming;
			state priming;
			accept PrimingCompleteSignal then running;
			state running;
			accept StopSignal then shuttingDown;
			state shuttingDown;
			accept ShutdownCompleteSignal then idle;
		}
		state faultStates {
			entry; then normal;
			state normal;
			accept EngineOverheatSignal then engineOverheating;
			state engineOverheating;
			accept EngineCoolSignal then normal;
			accept LowFuelSignal then lowFuel;
			state lowFuel;
			accept RefueledSignal then normal;
			accept CavitationSignal then pumpCavitation;
			state pumpCavitation;
			accept CavitationResolvedSignal then normal;
		}
	}

	part def HandyBilly {
		attribute totalMass : Mass;
		attribute setupTime : Time;

		part frame : GalvanizedSteelFrame;
		part engine : GasolineEngine;
		part tank : FuelTank;
		part pump : CentrifugalPump;
		part suctionHose : SuctionHose;
		part strainer : Strainer;
		part dischargeHose : DischargeHose;
		part nozzle : Nozzle;

		interface : FuelInterface connect 
			supplierPort ::> tank.fuelOut to 
			consumerPort ::> engine.fuelIn;

		interface : MechanicalInterface connect 
			supplierPort ::> engine.mechanicalOut to 
			consumerPort ::> pump.mechanicalIn;

		interface : WaterInterface connect 
			supplierPort ::> strainer.waterOut to 
			consumerPort ::> suctionHose.waterIn;

		interface : WaterInterface connect 
			supplierPort ::> suctionHose.waterOut to 
			consumerPort ::> pump.waterIn;

		interface : WaterInterface connect 
			supplierPort ::> pump.waterOut to 
			consumerPort ::> dischargeHose.waterIn;

		interface : WaterInterface connect 
			supplierPort ::> dischargeHose.waterOut to 
			consumerPort ::> nozzle.waterIn;

		exhibit handyBillyStates;
	}

	requirement def WeightRequirement {
		doc "The system shall be lightweight enough for two people to carry.";
		subject b : HandyBilly;
		attribute maxWeight : Mass = 50;
		require b.totalMass <= maxWeight;
	}

	requirement def SetupTimeRequirement {
		doc "The system shall be set up and running in under three minutes.";
		subject b : HandyBilly;
		attribute maxSetupTime : Time = 3;
		require b.setupTime <= maxSetupTime;
	}

	requirement def EnginePowerRequirement {
		doc "The engine shall provide at least 4 kW of power.";
		subject e : GasolineEngine;
		attribute requiredPower : Power = 4;
		require e.power >= requiredPower;
	}

	requirement def EnduranceRequirement {
		doc "The fuel tank shall allow for at least two hours of continuous operation.";
		subject t : FuelTank;
		attribute minEndurance : Duration = 2;
		require t.capacity >= minEndurance;
	}

	requirement handBillyWeightReq : WeightRequirement {
		subject :>> b : HandyBilly;
	}

	requirement handBillySetupTimeReq : SetupTimeRequirement {
		subject :>> b : HandyBilly;
	}

	requirement enginePowerReq : EnginePowerRequirement {
		subject :>> e : GasolineEngine;
	}

	requirement fuelTankEnduranceReq : EnduranceRequirement {
		subject :>> t : FuelTank;
	}
}
