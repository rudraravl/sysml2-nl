package 'Foam Pumping Subsystem' {
	private import ScalarValues::*;
	
	attribute def PressureValue :> Real;
	attribute def FlowRateValue :> Real;
	attribute def VoltageValue :> Real;
	attribute def CurrentValue :> Real;
	attribute def RotationalSpeedValue :> Real;
	
	item def Foam;
	item def ElectricPower;
	
	attribute def SystemStartCommand;
	attribute def SystemStopCommand;
	attribute def PumpStartCommand;
	attribute def PumpStopCommand;
	
	action def Prime;
	action def Accelerate;
	action def ProvidePumping;
	action def SafeShutdown;
	action def ReduceSpeed;
	action def AdjustInlet;
	action def ControlLoop;
	
	part def FoamReservoir {
		port foamOutPort { out foam : Foam; }
		port foamInPort { in foam : Foam; }
	}
	
	part def DischargeManifold {
		port foamInPort { in foam : Foam; }
		port foamOutPorts { out foam : Foam[0..*]; }
	}
	
	part def ReliefValve {
		port inletPort { in foam : Foam; }
		port outletPort { out foam : Foam; }
		attribute crackingPressure : PressureValue = 5000.0;
		attribute inletPressure : PressureValue = 0.0;
		state valveStates {
			entry; then closed;
			state closed;
			accept when inletPressure > crackingPressure then open;
			state open;
			accept when inletPressure <= crackingPressure then closed;
		}
	}
	
	part def PressureSensor {
		port sensingPort { in foam : Foam; }
		port dataOutPort { out pressure : PressureValue; }
	}
	
	part def FlowSensor {
		port sensingPort { in foam : Foam; }
		port dataOutPort { out flowRate : FlowRateValue; }
	}
	
	part def PowerSupply {
		port powerOutPort1 { out power : ElectricPower; }
		port powerOutPort2 { out power : ElectricPower; }
		attribute voltage : VoltageValue = 480.0;
		attribute maxCurrent : CurrentValue = 100.0;
	}
	
	part def FoamPump {
		port foamInPort { in foam : Foam; }
		port foamOutPort { out foam : Foam; }
		port powerPort { in power : ElectricPower; }
		port controlInPort { in command : RotationalSpeedValue; }
		
		attribute targetSpeed : RotationalSpeedValue = 1500.0;
		attribute currentSpeed : RotationalSpeedValue = 0.0;
		attribute currentPressure : PressureValue = 0.0;
		attribute currentFlowRate : FlowRateValue = 0.0;
		attribute maxPressure : PressureValue = 5000.0;
		attribute minFlowRate : FlowRateValue = 0.01;
		
		state pumpStates {
			entry; then off;
			state off;
			accept PumpStartCommand then priming;
			state priming {
				do Prime;
			}
			accept when currentSpeed > 0.0 then accelerating;
			state accelerating {
				do Accelerate;
			}
			accept when currentSpeed >= targetSpeed then running;
			state running {
				do ProvidePumping;
			}
			accept when currentPressure > maxPressure then overPressureProtection;
			accept when currentFlowRate < minFlowRate then cavitationProtection;
			accept PumpStopCommand then shuttingDown;
			state overPressureProtection {
				do ReduceSpeed;
			}
			accept when currentPressure <= maxPressure then running;
			state cavitationProtection {
				do AdjustInlet;
			}
			accept when currentFlowRate >= minFlowRate then running;
			state shuttingDown {
				do SafeShutdown;
			}
			accept when currentSpeed == 0.0 then off;
		}
	}
	
	part def PumpController {
		port pressureInPort { in pressure : PressureValue; }
		port flowInPort { in flowRate : FlowRateValue; }
		port controlOutPort { out command : RotationalSpeedValue; }
		port powerPort { in power : ElectricPower; }
		port systemPort { in start : SystemStartCommand; in stop : SystemStopCommand; }
		ref pumpRef : FoamPump;
		
		attribute targetPressure : PressureValue = 4000.0;
		attribute targetFlowRate : FlowRateValue = 0.5;
		attribute measuredPressure : PressureValue = 0.0;
		attribute measuredFlowRate : FlowRateValue = 0.0;
		
		state controllerStates {
			entry; then standby;
			state standby;
			accept SystemStartCommand 
				do send new PumpStartCommand() to pumpRef
				then active;
			state active {
				do ControlLoop;
			}
			accept SystemStopCommand 
				do send new PumpStopCommand() to pumpRef
				then standby;
		}
	}
	
	part def FoamPumpingSystem {
		part reservoir : FoamReservoir;
		part pump : FoamPump;
		part manifold : DischargeManifold;
		part reliefValve : ReliefValve;
		part pressureSensor : PressureSensor;
		part flowSensor : FlowSensor;
		part controller : PumpController;
		part powerSupply : PowerSupply;
		
		bind controller.pumpRef = pump;
		
		flow foamFlow of Foam from reservoir.foamOutPort.foam to pump.foamInPort.foam;
		flow pressurizedFoamFlow of Foam from pump.foamOutPort.foam to manifold.foamInPort.foam;
		flow reliefInFlow of Foam from pump.foamOutPort.foam to reliefValve.inletPort.foam;
		flow reliefOutFlow of Foam from reliefValve.outletPort.foam to reservoir.foamInPort.foam;
		flow pressureSensingFlow of Foam from pump.foamOutPort.foam to pressureSensor.sensingPort.foam;
		flow flowSensingFlow of Foam from pump.foamOutPort.foam to flowSensor.sensingPort.foam;
		flow pressureDataFlow of PressureValue from pressureSensor.dataOutPort.pressure to controller.pressureInPort.pressure;
		flow flowDataFlow of FlowRateValue from flowSensor.dataOutPort.flowRate to controller.flowInPort.flowRate;
		flow controlFlow of RotationalSpeedValue from controller.controlOutPort.command to pump.controlInPort.command;
		flow powerToController of ElectricPower from powerSupply.powerOutPort1.power to controller.powerPort.power;
		flow powerToPump of ElectricPower from powerSupply.powerOutPort2.power to pump.powerPort.power;
	}
	
	requirement def MaintainTargetPressure {
		doc /* The system shall maintain discharge pressure within ±5% of the target value. */
	}
	requirement def MaintainTargetFlow {
		doc /* The system shall maintain foam flow rate within ±3% of the target value. */
	}
	requirement def OverPressureSafety {
		doc /* The relief valve shall automatically open to vent fluid if pressure exceeds 500 kPa, and the controller shall actively monitor for over-pressure. */
	}
}
