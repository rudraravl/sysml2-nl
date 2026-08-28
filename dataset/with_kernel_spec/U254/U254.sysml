package 'Reusable Ice Pack Model' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;
	private import ScalarValues::String;

	item def Heat {
		attribute energy : Real;
	}

	part def CoolantGel {
		attribute mass : MassValue;
		attribute latentHeatOfFusion : Real;
		attribute specificHeatSolid : Real;
		attribute specificHeatLiquid : Real;
		attribute meltingPoint : TemperatureValue = 273.15 [K];
		attribute temperature : TemperatureValue;
		attribute phase : String;
		port heatIn : HeatSinkPort;
	}

	part def PolyethylenePouch {
		attribute maxVolume : VolumeValue;
		attribute isLeakProof : Boolean = true;
		attribute isFlexible : Boolean = true;
		attribute material : String = "Polyethylene";
		port gelContainer : HeatSinkPort;
	}

	part def InsulationLayer {
		attribute thermalResistance : Real;
		attribute thickness : LengthValue;
		attribute material : String;
		port heatIn : HeatSinkPort;
		port heatOut : HeatFlowPort;
	}

	port def HeatFlowPort {
		out item heat : Heat;
	}

	port def HeatSinkPort {
		in item heat : Heat;
	}

	action def AbsorbHeat {
		in heatInput : Heat;
		in gel : CoolantGel;
		out temperatureDelta : TemperatureValue;
	}

	part def IcePack {
		port thermalInterface : HeatSinkPort;
		attribute ambientTemperature : TemperatureValue;
		attribute elapsedTime : DurationValue;

		part insulation : InsulationLayer {
			attribute thermalResistance : Real = 5.0;
			attribute thickness : LengthValue = 0.01 [m];
			attribute material : String = "Foam";
		}

		part pouch : PolyethylenePouch {
			attribute maxVolume : VolumeValue = 0.0005 [m**3];
		}

		part coolantGel : CoolantGel {
			attribute mass : MassValue = 0.5 [kg];
			attribute latentHeatOfFusion : Real = 334000;
			attribute specificHeatSolid : Real = 2100;
			attribute specificHeatLiquid : Real = 4186;
			attribute meltingPoint : TemperatureValue = 273.15 [K];
			attribute temperature : TemperatureValue = 263.15 [K];
			attribute phase : String = "frozen";
		}

		flow of heat : Heat
			from thermalInterface to insulation.heatIn;

		flow of heat : Heat
			from insulation.heatOut to pouch.gelContainer;

		flow of heat : Heat
			from pouch.gelContainer to coolantGel.heatIn;

		state def IcePackLifecycle {
			in pack : IcePack;
			entry; then frozen;
			state frozen {
				entry assign pack.coolantGel.phase := "frozen";
			}
			accept when pack.coolantGel.temperature >= pack.coolantGel.meltingPoint
				then melting;
			state melting {
				entry assign pack.coolantGel.phase := "melting";
				do absorbHeat : AbsorbHeat {
					in heatInput = pack.thermalInterface.heat;
					in gel = pack.coolantGel;
				}
			}
			accept when pack.coolantGel.temperature > pack.coolantGel.meltingPoint
				then liquid;
			state liquid {
				entry assign pack.coolantGel.phase := "liquid";
			}
		}

		state lifecycle : IcePackLifecycle {
			in pack = self;
		}
	}

	requirement def CoolingRequirement {
		doc /* The ice pack shall remain below 4C (277.15 K) for at least three hours. */
		subject icePack : IcePack;
		attribute maxTemperature : TemperatureValue = 277.15 [K];
		attribute minDuration : DurationValue = 3 [h];
	}

	part IcePackSystem {
		part icePack : IcePack {
			attribute ambientTemperature : TemperatureValue = 298.15 [K];
			attribute elapsedTime : DurationValue = 0 [h];
		}
		part environment {
			attribute temperature : TemperatureValue = 298.15 [K];
			port thermalOutput : HeatFlowPort;
		}
		flow of heat : Heat
			from environment.thermalOutput to icePack.thermalInterface;
		satisfy CoolingRequirement by icePack;
	}
}
