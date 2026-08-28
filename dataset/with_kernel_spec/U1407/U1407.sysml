package 'Espresso Machine System' {
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;

	item def Water;
	item def CoffeeBeans;
	item def CoffeeGrounds;
	item def Espresso;
	item def Steam;

	item def PowerOnSignal;
	item def PowerOffSignal;
	item def BrewStartSignal;
	item def TargetTempReachedSignal;
	item def GrindCompleteSignal;
	item def BrewCompleteSignal;

	attribute def Temperature :> Real;
	attribute def Pressure :> Real;
	attribute def Volume :> Real;
	attribute def Duration :> Real;

	port def WaterOutPort {
		out item water : Water;
	}
	port def WaterInPort {
		in item water : Water;
	}
	port def BeansInPort {
		in item beans : CoffeeBeans;
	}
	port def GroundsOutPort {
		out item grounds : CoffeeGrounds;
	}
	port def GroundsInPort {
		in item grounds : CoffeeGrounds;
	}
	port def EspressoOutPort {
		out item espresso : Espresso;
	}
	port def SteamOutPort {
		out item steam : Steam;
	}
	port def SteamInPort {
		in item steam : Steam;
	}
	port def ControlOutPort {
		out item powerOn : PowerOnSignal;
		out item powerOff : PowerOffSignal;
		out item brewStart : BrewStartSignal;
	}
	port def ControlInPort {
		in item powerOn : PowerOnSignal;
		in item powerOff : PowerOffSignal;
		in item brewStart : BrewStartSignal;
	}
	port def StatusOutPort {
		out item targetTempReached : TargetTempReachedSignal;
		out item grindComplete : GrindCompleteSignal;
		out item brewComplete : BrewCompleteSignal;
	}
	port def StatusInPort {
		in item targetTempReached : TargetTempReachedSignal;
		in item grindComplete : GrindCompleteSignal;
		in item brewComplete : BrewCompleteSignal;
	}

	part def WaterReservoir {
		port waterIn : WaterInPort;
		port waterOut : WaterOutPort;
		attribute capacity : Volume = 2000.0;
		attribute currentLevel : Volume;
	}
	part def Pump {
		port waterIn : WaterInPort;
		port waterOut : WaterOutPort;
		attribute targetPressure : Pressure = 9.0;
	}
	part def Boiler {
		port waterIn : WaterInPort;
		port hotWaterOut : WaterOutPort;
		port steamOut : SteamOutPort;
		attribute targetTemp : Temperature = 93.0;
		attribute currentTemp : Temperature;
	}
	part def Grinder {
		port beansIn : BeansInPort;
		port groundsOut : GroundsOutPort;
		attribute finenessLevel : Real;
	}
	part def Portafilter {
		port groundsIn : GroundsInPort;
		item grounds : CoffeeGrounds;
	}
	part def GroupHead {
		port hotWaterIn : WaterInPort;
		port espressoOut : EspressoOutPort;
		part portafilter : Portafilter;
	}
	part def SteamWand {
		port steamIn : SteamInPort;
		port steamOut : SteamOutPort;
	}
	part def ControlPanel {
		port controlOut : ControlOutPort;
		port statusIn : StatusInPort;
		attribute desiredVolume : Volume;
	}

	action def DrawWater {
		in inWater : Water;
		out outWater : Water;
	}
	action def PressurizeWater {
		in inWater : Water;
		out outWater : Water;
	}
	action def HeatWater {
		in inWater : Water;
		out outHotWater : Water;
		out outSteam : Steam;
	}
	action def GrindBeans {
		in inBeans : CoffeeBeans;
		out outGrounds : CoffeeGrounds;
	}
	action def BrewEspresso {
		in inHotWater : Water;
		in inGrounds : CoffeeGrounds;
		out outEspresso : Espresso;
	}
	action def FrothMilk {
		in inSteam : Steam;
	}

	state def EspressoMachineStates {
		entry; then off;

		state off;
		transition off_to_warmup
			first off
			accept PowerOnSignal
			then warmup;

		state warmup;
		transition warmup_to_ready
			first warmup
			accept TargetTempReachedSignal
			then ready;

		state ready;
		transition ready_to_grinding
			first ready
			accept BrewStartSignal
			then grinding;

		state grinding;
		transition grinding_to_brewing
			first grinding
			accept GrindCompleteSignal
			then brewing;

		state brewing;
		transition brewing_to_dispensing
			first brewing
			accept BrewCompleteSignal
			then dispensing;

		state dispensing;
		transition dispensing_to_ready
			first dispensing
			then ready;

		transition ready_to_off
			first ready
			accept PowerOffSignal
			then off;
	}

	requirement def TempControlReq {
		doc /* The boiler must maintain water temperature at 93°C ± 2°C during extraction. */
		attribute targetTemp : Temperature = 93.0;
	}
	requirement def PressureControlReq {
		doc /* The pump must deliver water at 9 bar pressure to the group head. */
		attribute targetPressure : Pressure = 9.0;
	}
	requirement def BrewTimeReq {
		doc /* The extraction phase must last between 25 and 30 seconds. */
		attribute minDuration : Duration = 25.0;
		attribute maxDuration : Duration = 30.0;
	}

	part def EspressoMachine {
		port waterIn : WaterInPort;
		port beansIn : BeansInPort;
		port espressoOut : EspressoOutPort;
		port steamOut : SteamOutPort;
		port controlIn : ControlInPort;
		port statusIn : StatusInPort;

		requirement tempControl : TempControlReq;
		requirement pressureControl : PressureControlReq;
		requirement brewTime : BrewTimeReq;

		part reservoir : WaterReservoir {
			perform action drawWater : DrawWater {
				in inWater = waterIn.water;
				out outWater = waterOut.water;
			}
		}
		part pump : Pump {
			perform action pressurizeWater : PressurizeWater {
				in inWater = waterIn.water;
				out outWater = waterOut.water;
			}
			satisfies pressureControl;
		}
		part boiler : Boiler {
			perform action heatWater : HeatWater {
				in inWater = waterIn.water;
				out outHotWater = hotWaterOut.water;
				out outSteam = steamOut.steam;
			}
			satisfies tempControl;
		}
		part grinder : Grinder {
			perform action grindBeans : GrindBeans {
				in inBeans = beansIn.beans;
				out outGrounds = groundsOut.grounds;
			}
		}
		part groupHead : GroupHead {
			perform action brewEspresso : BrewEspresso {
				in inHotWater = hotWaterIn.water;
				in inGrounds = portafilter.grounds;
				out outEspresso = espressoOut.espresso;
			}
			satisfies brewTime;
		}
		part steamWand : SteamWand {
			perform action frothMilk : FrothMilk {
				in inSteam = steamIn.steam;
			}
		}
		part controlPanel : ControlPanel;

		flow of Water from waterIn.water to reservoir.waterIn.water;
		flow of Water from reservoir.waterOut.water to pump.waterIn.water;
		flow of Water from pump.waterOut.water to boiler.waterIn.water;
		flow of Water from boiler.hotWaterOut.water to groupHead.hotWaterIn.water;
		flow of CoffeeBeans from beansIn.beans to grinder.beansIn.beans;
		flow of CoffeeGrounds from grinder.groundsOut.grounds to groupHead.portafilter.groundsIn.grounds;
		flow of Espresso from groupHead.espressoOut.espresso to espressoOut.espresso;
		flow of Steam from boiler.steamOut.steam to steamWand.steamIn.steam;
		flow of Steam from steamWand.steamOut.steam to steamOut.steam;

		exhibit EspressoMachineStates;
	}

	part espressoMachine : EspressoMachine;
}
