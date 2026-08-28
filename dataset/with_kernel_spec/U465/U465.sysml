package AldgatePumpingSubsystem {
	private import ScalarValues::*;
	private import ISQ::VolumeValue;
	private import ISQ::PressureValue;
	private import ISQ::VolumeFlowRateValue;
	private import SI::L;
	private import SI::s;
	private import SI::Pa;

	item def Fluid;

	port def FluidOutPort {
		out item fluid : Fluid;
		attribute pressure : PressureValue;
	}
	port def FluidInPort {
		in item fluid : Fluid;
		attribute pressure : PressureValue;
	}
	port def FlowSignalPort {
		out attribute flowRate : VolumeFlowRateValue;
	}
	port def PressureSignalPort {
		out attribute pressure : PressureValue;
	}

	part def SourceTank {
		attribute capacity : VolumeValue = 10000 [L];
		attribute currentLevel : VolumeValue;
		attribute minOperatingLevel : VolumeValue;
		port fluidOut : FluidOutPort;
	}

	part def DestinationTank {
		attribute capacity : VolumeValue = 15000 [L];
		attribute currentLevel : VolumeValue;
		attribute maxOperatingLevel : VolumeValue;
		port fluidIn : FluidInPort;
	}

	part def Motor {
		attribute isRunning : Boolean = false;
	}

	part def Impeller {
		attribute rpm : Real;
	}

	part def AldgatePump {
		port inlet : FluidInPort;
		port outlet : FluidOutPort;
		part motor : Motor;
		part impeller : Impeller;
		attribute flowRate : VolumeFlowRateValue;
	}

	part def FlowMeter {
		port flowOut : FlowSignalPort;
	}

	part def PressureSensor {
		port pressureOut : PressureSignalPort;
	}

	action def StartPump { in motor : Motor; }
	action def StopPump { in motor : Motor; }

	state def PumpControl {
		in source : SourceTank;
		in dest : DestinationTank;
		in pumpMotor : Motor;
		entry; then idle;
		state idle;
		accept when source.currentLevel > source.minOperatingLevel
			and dest.currentLevel < dest.maxOperatingLevel
			then pumping;
		state pumping {
			entry action startPump : StartPump { in motor = pumpMotor; }
			exit action stopPump : StopPump { in motor = pumpMotor; }
		}
		accept when source.currentLevel <= source.minOperatingLevel
			or dest.currentLevel >= dest.maxOperatingLevel
			then idle;
	}

	requirement def MinFlowRateRequirement {
		doc { "The system shall maintain a minimum flow rate of 10 L/s during pump operation." }
		attribute minFlowRate : VolumeFlowRateValue = 10 [L/s];
	}

	requirement def MaxPressureRequirement {
		doc { "The system shall operate below a maximum discharge pressure of 500 kPa." }
		attribute maxPressure : PressureValue = 500000 [Pa];
	}

	part context {
		part sourceTank : SourceTank {
			attribute minOperatingLevel : VolumeValue = 1000 [L];
		}
		part destTank : DestinationTank {
			attribute maxOperatingLevel : VolumeValue = 14000 [L];
		}
		part pump : AldgatePump;
		part flowMeter : FlowMeter;
		part suctionSensor : PressureSensor;
		part dischargeSensor : PressureSensor;

		flow of fluid : Fluid
			from sourceTank.fluidOut.fluid to pump.inlet.fluid;
		flow of fluid : Fluid
			from pump.outlet.fluid to destTank.fluidIn.fluid;

		bind flowMeter.flowOut.flowRate = pump.flowRate;
		bind suctionSensor.pressureOut.pressure = pump.inlet.pressure;
		bind dischargeSensor.pressureOut.pressure = pump.outlet.pressure;

		state control : PumpControl {
			in source = sourceTank;
			in dest = destTank;
			in pumpMotor = pump.motor;
		}

		requirement minFlowRateReq : MinFlowRateRequirement;
		requirement maxPressureReq : MaxPressureRequirement;
		satisfy minFlowRateReq by flowMeter;
		satisfy maxPressureReq by dischargeSensor;
	}
}
