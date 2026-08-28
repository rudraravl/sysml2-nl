package 'Intelligent Water Delivery System' {
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;

	/* ---- Value types ---- */
	attribute def Volume :> Real { unit = "gal"; }
	attribute def Energy :> Real { unit = "Wh"; }
	attribute def Power :> Real { unit = "W"; }
	attribute def FlowRate :> Real { unit = "gal/min"; }
	attribute def Efficiency :> Real { unit = "gal/Wh"; }
	attribute def PumpSpeed :> Real { unit = "rpm"; }

	/* ---- Item definitions ---- */
	item def Water {
		attribute volume : Volume;
	}
	item def PowerReading {
		attribute power : Power;
		attribute energyConsumed : Energy;
	}
	item def FlowReading {
		attribute volume : Volume;
		attribute flowRate : FlowRate;
	}
	item def EfficiencyValue {
		attribute efficiency : Efficiency;
	}
	item def SpeedCommand {
		attribute targetSpeed : PumpSpeed;
	}

	/* ---- Port definitions ---- */
	port def WaterOutPort {
		out item water : Water;
	}
	port def WaterInPort {
		in item water : Water;
	}
	port def PowerOutPort {
		out item powerReading : PowerReading;
	}
	port def PowerInPort {
		in item powerReading : PowerReading;
	}
	port def FlowOutPort {
		out item flowReading : FlowReading;
	}
	port def FlowInPort {
		in item flowReading : FlowReading;
	}
	port def EfficiencyOutPort {
		out item efficiencyValue : EfficiencyValue;
	}
	port def EfficiencyInPort {
		in item efficiencyValue : EfficiencyValue;
	}
	port def CommandOutPort {
		out item speedCommand : SpeedCommand;
	}
	port def CommandInPort {
		in item speedCommand : SpeedCommand;
	}

	/* ---- Action definitions ---- */
	action def PumpWater {
		in waterIn : Water;
		in speed : PumpSpeed;
		out waterOut : Water;
		out powerOut : PowerReading;
	}
	action def AnalyzeEfficiency {
		in powerReading : PowerReading;
		in flowReading : FlowReading;
		out efficiencyValue : EfficiencyValue;
	}
	action def Measure {
		out powerReading : PowerReading;
		out flowReading : FlowReading;
	}
	action def AdjustSpeed {
		in currentEfficiency : Efficiency;
		out speedCommand : SpeedCommand;
	}
	action def MaintainSpeed {
		out speedCommand : SpeedCommand;
	}
	action def ControlLoop {
		in targetEfficiency : Efficiency;
		loop action cycle {
			first action measure : Measure {
				out powerReading : PowerReading;
				out flowReading : FlowReading;
			}
			then action analyze : AnalyzeEfficiency {
				in powerReading = measure.powerReading;
				in flowReading = measure.flowReading;
				out efficiencyValue : EfficiencyValue;
			}
			then decide;
			if analyze.efficiencyValue.efficiency < targetEfficiency then adjust;
			else maintain;
			action adjust : AdjustSpeed {
				in currentEfficiency = analyze.efficiencyValue.efficiency;
				out speedCommand : SpeedCommand;
			}
			action maintain : MaintainSpeed {
				out speedCommand : SpeedCommand;
			}
		}
	}

	/* ---- Part definitions ---- */
	part def WaterReservoir {
		port waterOutPort : WaterOutPort;
		item storedWater : Water {
			attribute volume : Volume;
		}
	}
	part def PumpUnit {
		port waterInPort : WaterInPort;
		port waterOutPort : WaterOutPort;
		port powerOutPort : PowerOutPort;
		port commandInPort : CommandInPort;
		attribute currentSpeed : PumpSpeed;
		perform action pumpWater : PumpWater {
			in waterIn = waterInPort.water;
			in speed = commandInPort.speedCommand.targetSpeed;
			out waterOut = waterOutPort.water;
			out powerOut = powerOutPort.powerReading;
		}
	}
	part def EnergyMonitor {
		port powerInPort : PowerInPort;
		port powerOutPort : PowerOutPort;
	}
	part def FlowMonitor {
		port waterInPort : WaterInPort;
		port flowOutPort : FlowOutPort;
	}
	part def EfficiencyAnalyzer {
		port powerInPort : PowerInPort;
		port flowInPort : FlowInPort;
		port efficiencyOutPort : EfficiencyOutPort;
		attribute currentEfficiency : Efficiency;
		perform action analyze : AnalyzeEfficiency {
			in powerReading = powerInPort.powerReading;
			in flowReading = flowInPort.flowReading;
			out efficiencyValue = efficiencyOutPort.efficiencyValue;
		}
	}
	part def SystemController {
		port efficiencyInPort : EfficiencyInPort;
		port commandOutPort : CommandOutPort;
		attribute targetEfficiency : Efficiency = 3.0;
		perform action controlLoop : ControlLoop {
			in targetEfficiency = targetEfficiency;
		}
	}
	part def DistributionNetwork {
		port waterInPort : WaterInPort;
	}

	/* ---- Requirement definitions ---- */
	requirement def MaximizeWaterPerEnergy {
		doc "The system shall maximize the volume of water delivered (in gallons) for every unit of electrical energy it uses (in watt-hours).";
		attribute targetEfficiency : Efficiency;
	}

	/* ---- System assembly ---- */
	part waterDeliverySystem {
		satisfy req : MaximizeWaterPerEnergy;

		part reservoir : WaterReservoir;
		part pump : PumpUnit;
		part energyMonitor : EnergyMonitor;
		part flowMonitor : FlowMonitor;
		part efficiencyAnalyzer : EfficiencyAnalyzer;
		part controller : SystemController;
		part distribution : DistributionNetwork;

		/* Water flows */
		flow of water : Water
			from reservoir.waterOutPort.water to pump.waterInPort.water;

		flow of water : Water
			from pump.waterOutPort.water to distribution.waterInPort.water;

		flow of water : Water
			from pump.waterOutPort.water to flowMonitor.waterInPort.water;

		/* Power monitoring flows */
		flow of powerReading : PowerReading
			from pump.powerOutPort.powerReading to energyMonitor.powerInPort.powerReading;

		flow of powerReading : PowerReading
			from energyMonitor.powerOutPort.powerReading to efficiencyAnalyzer.powerInPort.powerReading;

		/* Flow data to analyzer */
		flow of flowReading : FlowReading
			from flowMonitor.flowOutPort.flowReading to efficiencyAnalyzer.flowInPort.flowReading;

		/* Efficiency feedback */
		flow of efficiencyValue : EfficiencyValue
			from efficiencyAnalyzer.efficiencyOutPort.efficiencyValue to controller.efficiencyInPort.efficiencyValue;

		/* Speed command to pump */
		flow of speedCommand : SpeedCommand
			from controller.commandOutPort.speedCommand to pump.commandInPort.speedCommand;
	}
}
