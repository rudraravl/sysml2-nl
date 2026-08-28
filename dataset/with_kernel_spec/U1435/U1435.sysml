package 'Automated Irrigation System' {
	private import ScalarValues::*;
	private import ISQ::*;

	attribute def MoisturePercentage :> Real;
	attribute def FlowRateValue :> Real;
	attribute def PressureValue :> Real;

	item def Water {
		attribute flowRate : FlowRateValue;
		attribute pressure : PressureValue;
	}
	item def MoistureReading {
		attribute value : MoisturePercentage;
	}
	item def ValveCommand;
	item def OpenValveCmd :> ValveCommand;
	item def PartialValveCmd :> ValveCommand;
	item def CloseValveCmd :> ValveCommand;
	item def PumpCommand;
	item def StartPumpCmd :> PumpCommand;
	item def StopPumpCmd :> PumpCommand;

	part def WaterReservoir {
		port waterOutPort {
			out water : Water;
		}
	}

	part def WaterPump {
		port pumpCmdInPort {
			in pumpCmd : PumpCommand;
		}
		port waterInPort {
			in water : Water;
		}
		port waterOutPort {
			out water : Water;
		}
		exhibit state pumpStates {
			entry; then off;
			state off;
			accept StartPumpCmd via pumpCmdInPort then on;
			state on;
			accept StopPumpCmd via pumpCmdInPort then off;
		}
	}

	part def ControlValve {
		port valveCmdInPort {
			in valveCmd : ValveCommand;
		}
		port waterInPort {
			in water : Water;
		}
		port waterOutPort {
			out water : Water;
		}
		exhibit state valveStates {
			entry; then closed;
			state closed;
			accept OpenValveCmd via valveCmdInPort then fullyOpen;
			accept PartialValveCmd via valveCmdInPort then partiallyOpen;
			state partiallyOpen;
			accept CloseValveCmd via valveCmdInPort then closed;
			accept OpenValveCmd via valveCmdInPort then fullyOpen;
			state fullyOpen;
			accept CloseValveCmd via valveCmdInPort then closed;
			accept PartialValveCmd via valveCmdInPort then partiallyOpen;
		}
	}

	part def SprinklerHead {
		attribute sprayPattern : String;
		port waterInPort {
			in water : Water;
		}
	}

	part def MoistureSensor {
		attribute zoneId : String;
		attribute currentMoisture : MoisturePercentage = 50.0;
		port moistureOutPort {
			out moisture : MoistureReading;
		}
	}

	part def IrrigationController {
		attribute minThreshold : MoisturePercentage = 30.0;
		attribute targetThreshold : MoisturePercentage = 60.0;

		port moistureInPort {
			in moisture : MoistureReading;
		}
		port valveCmdOutPort {
			out valveCmd : ValveCommand;
		}
		port pumpCmdOutPort {
			out pumpCmd : PumpCommand;
		}

		action startWatering {
			send new OpenValveCmd() to valveCmdOutPort;
			send new StartPumpCmd() to pumpCmdOutPort;
		}
		action stopWatering {
			send new CloseValveCmd() to valveCmdOutPort;
			send new StopPumpCmd() to pumpCmdOutPort;
		}

		exhibit state controllerStates {
			entry; then monitoring;
			state monitoring;
			accept m : MoistureReading via moistureInPort
				if m.value < minThreshold
				do startWatering
				then watering;
			state watering;
			accept m : MoistureReading via moistureInPort
				if m.value >= targetThreshold
				do stopWatering
				then monitoring;
		}
	}

	part def IrrigationSystem {
		part controller : IrrigationController;
		part reservoir : WaterReservoir;
		part pump : WaterPump;
		part valve : ControlValve;
		part sprinkler1 : SprinklerHead { attribute sprayPattern = "180"; }
		part sprinkler2 : SprinklerHead { attribute sprayPattern = "180"; }
		part sprinkler3 : SprinklerHead { attribute sprayPattern = "360"; }
		part sprinkler4 : SprinklerHead { attribute sprayPattern = "360"; }
		part sensor1 : MoistureSensor { attribute zoneId = "zone1"; attribute currentMoisture = 25.0; }
		part sensor2 : MoistureSensor { attribute zoneId = "zone2"; attribute currentMoisture = 35.0; }
		part sensor3 : MoistureSensor { attribute zoneId = "zone3"; attribute currentMoisture = 55.0; }
		part sensor4 : MoistureSensor { attribute zoneId = "zone4"; attribute currentMoisture = 45.0; }

		flow waterFlow1 of Water from reservoir.waterOutPort.water to pump.waterInPort.water;
		flow waterFlow2 of Water from pump.waterOutPort.water to valve.waterInPort.water;
		flow waterFlow3 of Water from valve.waterOutPort.water to sprinkler1.waterInPort.water;
		flow waterFlow4 of Water from valve.waterOutPort.water to sprinkler2.waterInPort.water;
		flow waterFlow5 of Water from valve.waterOutPort.water to sprinkler3.waterInPort.water;
		flow waterFlow6 of Water from valve.waterOutPort.water to sprinkler4.waterInPort.water;

		flow moistureFlow1 of MoistureReading from sensor1.moistureOutPort.moisture to controller.moistureInPort.moisture;
		flow moistureFlow2 of MoistureReading from sensor2.moistureOutPort.moisture to controller.moistureInPort.moisture;
		flow moistureFlow3 of MoistureReading from sensor3.moistureOutPort.moisture to controller.moistureInPort.moisture;
		flow moistureFlow4 of MoistureReading from sensor4.moistureOutPort.moisture to controller.moistureInPort.moisture;

		flow valveCmdFlow of ValveCommand from controller.valveCmdOutPort.valveCmd to valve.valveCmdInPort.valveCmd;
		flow pumpCmdFlow of PumpCommand from controller.pumpCmdOutPort.pumpCmd to pump.pumpCmdInPort.pumpCmd;
	}

	requirement def MaintainSoilMoisture {
		subject irrigationSystem : IrrigationSystem;
		attribute minMoisture : MoisturePercentage = 30.0;
		attribute maxMoisture : MoisturePercentage = 60.0;
		text "The system shall maintain soil moisture between the minimum threshold and target level, preventing overwatering and conserving water.";
		require irrigationSystem.controller.minThreshold == minMoisture;
		require irrigationSystem.controller.targetThreshold == maxMoisture;
	}

	requirement def AutomatedOperation {
		subject irrigationSystem : IrrigationSystem;
		text "The system shall operate automatically without manual intervention, initiating and terminating watering cycles based on sensor data.";
	}

	requirement def WaterConservation {
		subject irrigationSystem : IrrigationSystem;
		text "The system shall use water only when soil moisture drops below the minimum threshold and stop watering once the target level is reached.";
	}

	part irrigationSystem : IrrigationSystem;

	satisfy MaintainSoilMoisture by irrigationSystem.controller;
	satisfy AutomatedOperation by irrigationSystem.controller;
	satisfy WaterConservation by irrigationSystem.controller;
}
