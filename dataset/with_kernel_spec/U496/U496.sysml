package 'Hydraulic Energy Storage System' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		attribute def PressureValue :> Real { unit = "Pa"; }
		attribute def FlowRateValue :> Real { unit = "m3/s"; }
		attribute def TorqueValue :> Real { unit = "N*m"; }
		attribute def SpeedValue :> Real { unit = "rad/s"; }
		attribute def PowerValue :> Real { unit = "W"; }
		attribute def LengthValue :> Real { unit = "m"; }
		attribute def AreaValue :> Real { unit = "m2"; }
		attribute def DensityValue :> Real { unit = "kg/m3"; }

		item def Fluid {
			attribute pressure : PressureValue;
			attribute velocity : SpeedValue;
			attribute density : DensityValue;
		}

		attribute def StartSignal;
		attribute def StopSignal;
		attribute def HighPressureAlert;
		attribute def OverloadAlert;
		attribute def ReadySignal;

		port def FluidPort {
			out item fluid : Fluid;
		}

		port def MechanicalPort {
			out torque : TorqueValue;
			out speed : SpeedValue;
		}

		port def ElectricalPort {
			out power : PowerValue;
		}

		port def ControlPort {
			out start : StartSignal;
			out stop : StopSignal;
			out ready : ReadySignal;
		}

		port def AlertPort {
			out highPressure : HighPressureAlert;
			out overload : OverloadAlert;
		}

		port def PressureReadingPort {
			out pressure : PressureValue;
		}

		port def FlowReadingPort {
			out flowRate : FlowRateValue;
		}

		part def Reservoir {
			port fluidOut : FluidPort;
			port fluidIn : ~FluidPort;
			attribute elevation : LengthValue;
			item storedFluid : Fluid;
		}

		part def ElectricMotor {
			port electricIn : ~ElectricalPort;
			port mechanicalOut : MechanicalPort;
			port controlIn : ~ControlPort;
		}

		part def Impeller {
			attribute bladeCount : Integer;
			attribute bladeAngle : Real;
			attribute diameter : LengthValue;
			attribute inletArea : AreaValue;
		}

		part def Volute {
			attribute shape : String = "snail";
			attribute inletArea : AreaValue;
			attribute outletArea : AreaValue;
		}

		part def CentrifugalPump {
			port fluidIn : ~FluidPort;
			port fluidOut : FluidPort;
			port mechanicalIn : ~MechanicalPort;
			port controlIn : ~ControlPort;
			part impeller : Impeller;
			part volute : Volute;
		}

		part def Runner {
			attribute bladeCount : Integer;
			attribute bladeAngle : Real;
			attribute diameter : LengthValue;
			attribute inletArea : AreaValue;
		}

		part def DraftTube {
			port fluidIn : ~FluidPort;
			port fluidOut : FluidPort;
			attribute inletArea : AreaValue;
			attribute outletArea : AreaValue;
		}

		part def HydraulicTurbine {
			port fluidIn : ~FluidPort;
			port fluidOut : FluidPort;
			port mechanicalOut : MechanicalPort;
			port controlIn : ~ControlPort;
			part runner : Runner;
			part draftTube : DraftTube;
		}

		part def Generator {
			port mechanicalIn : ~MechanicalPort;
			port electricOut : ElectricalPort;
			attribute efficiency : Real = 0.98;
		}

		part def PressureSensor {
			port fluidObs : ~FluidPort;
			port readingOut : PressureReadingPort;
		}

		part def FlowMeter {
			port fluidObs : ~FluidPort;
			port readingOut : FlowReadingPort;
		}

		part def Controller {
			port pressureIn : ~PressureReadingPort;
			port flowIn : ~FlowReadingPort;
			port pumpControl : ControlPort;
			port turbineControl : ControlPort;
			port alertOut : AlertPort;
			attribute highPressureLimit : PressureValue;
			attribute overloadPowerLimit : PowerValue;
		}

		action def PumpFluid {
			in fluidIn : Fluid;
			in motorTorque : TorqueValue;
			in motorSpeed : SpeedValue;
			out fluidOut : Fluid;
		}

		action def GeneratePower {
			in fluidIn : Fluid;
			out fluidOut : Fluid;
			out electricalPower : PowerValue;
		}

		action def MonitorPressure {
			in pressure : PressureValue;
			out alert : HighPressureAlert;
		}

		action def MonitorFlow {
			in flowRate : FlowRateValue;
		}

		state def PumpStates {
			in pressureReading : PressureValue;
			in highPressureLimit : PressureValue;
			entry; then idle;
			state idle;
			accept StartSignal then starting;
			state starting;
			accept ReadySignal then running;
			state running {
				do action monitorPressure : MonitorPressure {
					in pressure = pressureReading;
				}
			}
			accept HighPressureAlert then stopping;
			accept StopSignal then stopping;
			state stopping;
			then idle;
		}

		state def TurbineStates {
			in flowReading : FlowRateValue;
			in powerReading : PowerValue;
			in overloadLimit : PowerValue;
			entry; then idle;
			state idle;
			accept StartSignal then starting;
			state starting;
			accept ReadySignal then running;
			state running {
				do action monitorFlow : MonitorFlow {
					in flowRate = flowReading;
				}
			}
			accept OverloadAlert then stopping;
			accept StopSignal then stopping;
			state stopping;
			then idle;
		}

		requirement def EulerTurbomachineryRequirement {
			text = "The pump and turbine performance shall be based on Euler's equations for turbomachinery, relating torque, angular velocity, and fluid momentum change across impeller and runner.";
		}

		requirement def SafetyPressureRequirement {
			text = "The system shall continuously monitor pump discharge pressure and transition to stopping state if high pressure threshold is exceeded.";
		}

		requirement def SafetyOverloadRequirement {
			text = "The system shall monitor generator output power and transition to stopping state if power overload threshold is exceeded.";
		}

		requirement def EnergyStorageRequirement {
			text = "The pumping loop shall convert electrical energy into gravitational potential energy by elevating fluid to the intermediate reservoir.";
		}

		requirement def EnergyRecoveryRequirement {
			text = "The generation loop shall convert gravitational potential energy back into electrical energy via turbine and generator.";
		}
	}

	package Usages {
		private import Definitions::*;

		part system {
			part lowReservoir : Reservoir {
				attribute elevation = 0.0;
			}
			part intermediateReservoir : Reservoir {
				attribute elevation = 150.0;
			}
			part finalReservoir : Reservoir {
				attribute elevation = 0.0;
			}

			part motor : ElectricMotor;
			part pump : CentrifugalPump {
				part impeller {
					attribute bladeCount = 7;
					attribute bladeAngle = 0.5;
					attribute diameter = 0.3;
					attribute inletArea = 0.07;
				}
				part volute {
					attribute inletArea = 0.07;
					attribute outletArea = 0.03;
				}
				perform pumpFluid : PumpFluid {
					in fluidIn = fluidIn.fluid;
					in motorTorque = mechanicalIn.torque;
					in motorSpeed = mechanicalIn.speed;
					out fluidOut = fluidOut.fluid;
				}
			}

			part turbine : HydraulicTurbine {
				part runner {
					attribute bladeCount = 13;
					attribute bladeAngle = 0.4;
					attribute diameter = 0.4;
					attribute inletArea = 0.1;
				}
				part draftTube {
					attribute inletArea = 0.1;
					attribute outletArea = 0.3;
				}
				perform generatePower : GeneratePower {
					in fluidIn = fluidIn.fluid;
					out fluidOut = fluidOut.fluid;
					out electricalPower = mechanicalOut.torque * mechanicalOut.speed;
				}
			}
			part generator : Generator;

			part pumpPressureSensor : PressureSensor;
			part turbineFlowMeter : FlowMeter;

			part controller : Controller {
				attribute highPressureLimit = 5.0e6;
				attribute overloadPowerLimit = 1.0e6;
			}

			flow of fluid : Fluid from lowReservoir.fluidOut.fluid to pump.fluidIn.fluid;
			flow of fluid : Fluid from pump.fluidOut.fluid to intermediateReservoir.fluidIn.fluid;
			flow of fluid : Fluid from intermediateReservoir.fluidOut.fluid to turbine.fluidIn.fluid;
			flow of fluid : Fluid from turbine.fluidOut.fluid to finalReservoir.fluidIn.fluid;

			connect motor.mechanicalOut to pump.mechanicalIn;
			connect turbine.mechanicalOut to generator.mechanicalIn;

			port gridSupply : ElectricalPort;
			connect gridSupply to motor.electricIn;
			connect generator.electricOut to gridSupply;

			connect pump.fluidOut to pumpPressureSensor.fluidObs;
			connect turbine.fluidIn to turbineFlowMeter.fluidObs;
			connect pumpPressureSensor.readingOut to controller.pressureIn;
			connect turbineFlowMeter.readingOut to controller.flowIn;

			connect controller.pumpControl to pump.controlIn;
			connect controller.pumpControl to motor.controlIn;
			connect controller.turbineControl to turbine.controlIn;

			state pumpStates : PumpStates {
				in pressureReading = controller.pressureIn.pressure;
				in highPressureLimit = controller.highPressureLimit;
			}

			state turbineStates : TurbineStates {
				in flowReading = controller.flowIn.flowRate;
				in powerReading = generator.electricOut.power;
				in overloadLimit = controller.overloadPowerLimit;
			}

			satisfy EulerTurbomachineryRequirement by pump.impeller;
			satisfy EulerTurbomachineryRequirement by turbine.runner;
			satisfy SafetyPressureRequirement by pumpPressureSensor;
			satisfy SafetyOverloadRequirement by generator;
			satisfy EnergyStorageRequirement by pump;
			satisfy EnergyRecoveryRequirement by turbine;
		}
	}
}
