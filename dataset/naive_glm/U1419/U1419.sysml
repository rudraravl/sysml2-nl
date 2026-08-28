package TwoStageGasCompressorSystem {

	import ScalarValues::*;
	import ISQ::*;

	// ---------- Value Types ----------
	value def PressureUnit => Real { unit 'Pa'; }
	value def PressureBar => Real { unit 'bar'; }
	value def TemperatureK => Real { unit 'K'; }
	value def MassFlowRate => Real { unit 'kg/s'; }
	value def RotationalSpeed => Real { unit 'rpm'; }
	value def Power => Real { unit 'kW'; }
	value def ValvePosition => Real { unit '%'; min 0; max 100; }
	value def Voltage => Real { unit 'V'; }
	value def Current => Real { unit 'A'; }
	value def TemperatureC => Real { unit 'degC'; }

	item def Gas {
		attribute molarMass : MassValue;
		attribute specificHeatRatio : Real;
	}

	item def GasFlow {
		end gas : Gas;
		attribute pressure : PressureUnit;
		attribute temperature : TemperatureK;
		attribute massFlowRate : MassFlowRate;
	}

	port def GasPort {
		in item flowIn : GasFlow;
		out item flowOut : GasFlow;
	}

	port def ElectricalPort {
		attribute voltage : Voltage;
		attribute current : Current;
	}

	port def MechanicalPort {
		attribute speed : RotationalSpeed;
		attribute torque : Real;
	}

	port def ControlSignalPort {
		out attribute command : Real;
		in attribute feedback : Real;
	}

	port def PressureFeedbackPort {
		out attribute measuredPressure : PressureUnit;
	}

	// ---------- Requirements ----------
	requirement def CompressorSystemRequirements {
		subject : compressorSystem :> TwoStageGasCompressorSystem;

		requirement def IncreasePressure {
			doc /* The system shall increase gas pressure from low inlet pressure to high discharge pressure. */
			subject : compressorSystem;
			requirement constraint { compressorSystem.dischargePressure >= 150e5 [Pa] }
		}

		requirement def Intercooling {
			doc /* The intercooler shall cool gas to a target temperature before the second stage. */
			subject : intercooler :> Intercooler;
			requirement constraint { intercooler.outletTemperature <= 313.15 [K] }
		}

		requirement def PressureRegulation {
			doc /* The controller shall maintain discharge pressure within tolerance of setpoint. */
			subject : controller :> SystemController;
			requirement constraint { abs(controller.actualPressure - controller.setpoint) <= 0.5e5 [Pa] }
		}

		requirement def SafetyShutdown {
			doc /* The system shall trigger emergency shutdown on overpressure or motor overload. */
			subject : compressorSystem;
			requirement constraint { compressorSystem.overpressureThreshold == 170e5 [Pa] }
		}

		requirement increasePressure : IncreasePressure;
		requirement intercooling : Intercooling;
		requirement pressureRegulation : PressureRegulation;
		requirement safetyShutdown : SafetyShutdown;
	}

	// ---------- Parts ----------
	part def ElectricMotor {
		port electricalIn : ElectricalPort;
		port mechanicalOut : MechanicalPort;
		port controlIn : ControlSignalPort;

		attribute ratedPower : Power = 500 [kW];
		attribute currentSpeed : RotationalSpeed;
		attribute overloadCurrent : Current = 1200 [A];

		attribute powerOn : Boolean = false;

		action def Operate {
			in electricalEnergy : ElectricalPort;
			out mechanicalWork : MechanicalPort;
		}

		state MotorBehavior {
			entry; then Off;
			state Off;
			state Running;
			state Overloaded;

			transition off_to_running
				first Off
				then Running
				if controlIn.command > 0;

			transition running_to_off
				first Running
				then Off
				if controlIn.command == 0;

			transition running_to_overloaded
				first Running
				then Overloaded
				if electricalIn.current > overloadCurrent;

			transition overloaded_to_off
				first Overloaded
				then Off
				if controlIn.command == 0;
		}
	}

	part def CompressionStage {
		port gasIn : GasPort;
		port gasOut : GasPort;
		port mechIn : MechanicalPort;

		attribute pressureRatio : Real;
		attribute inletPressure : PressureUnit;
		attribute outletPressure : PressureUnit;
		attribute inletTemperature : TemperatureK;
		attribute outletTemperature : TemperatureK;

		action def Compress {
			in inputGas : GasFlow;
			out outputGas : GasFlow;
		}

		state CompressionOperation {
			entry; then Idle;
			state Idle;
			state Active;
			transition idle_to_active
				first Idle
				then Active
				if mechIn.speed > 0;
			transition active_to_idle
				first Active
				then Idle
				if mechIn.speed == 0;
		}
	}

	part def Intercooler {
		port gasIn : GasPort;
		port gasOut : GasPort;
		port coolantControl : ControlSignalPort;

		attribute inletTemperature : TemperatureK;
		attribute outletTemperature : TemperatureK;
		attribute targetOutletTemperature : TemperatureK = 313.15 [K];
		attribute coolingCapacity : Power = 150 [kW];

		action def CoolGas {
			in hotGas : GasFlow;
			out cooledGas : GasFlow;
		}

		state CoolingOperation {
			entry; then Standby;
			state Standby;
			state Cooling;
			transition standby_to_cooling
				first Standby
				then Cooling
				if gasIn.flowIn.temperature > targetOutletTemperature;
			transition cooling_to_standby
				first Cooling
				then Standby
				if gasIn.flowIn.temperature <= targetOutletTemperature;
		}
	}

	part def DischargeControlValve {
		port gasIn : GasPort;
		port gasOut : GasPort;
		port controlIn : ControlSignalPort;

		attribute position : ValvePosition = 0 [%];
		attribute maxFlowRate : MassFlowRate = 10 [kg/s];

		action def RegulateFlow {
			in inputGas : GasFlow;
			out outputGas : GasFlow;
		}

		state ValveOperation {
			entry; then Closed;
			state Closed;
			state PartiallyOpen;
			state FullyOpen;
			transition closed_to_partial
				first Closed
				then PartiallyOpen
				if controlIn.command > 0;
			transition partial_to_full
				first PartiallyOpen
				then FullyOpen
				if controlIn.command >= 90;
			transition full_to_partial
				first FullyOpen
				then PartiallyOpen
				if controlIn.command < 90;
			transition partial_to_closed
				first PartiallyOpen
				then Closed
				if controlIn.command == 0;
		}
	}

	part def PressureSensor {
		port gasMeasurement : GasPort;
		port feedbackOut : PressureFeedbackPort;

		attribute measuredPressure : PressureUnit;
		attribute samplingRate : Real = 100 [Hz];

		action def MeasurePressure {
			in gas : GasFlow;
			out pressureReading : PressureUnit;
		}

		state SensorOperation {
			entry; then Inactive;
			state Inactive;
			state Measuring;
			transition inactive_to_measuring
				first Inactive
				then Measuring
				if gasMeasurement.flowIn.massFlowRate > 0;
			transition measuring_to_inactive
				first Measuring
				then Inactive
				if gasMeasurement.flowIn.massFlowRate == 0;
		}
	}

	part def SystemController {
		port pressureFeedback : PressureFeedbackPort;
		port motorControl : ControlSignalPort;
		port valveControl : ControlSignalPort;
		port intercoolerControl : ControlSignalPort;

		attribute setpoint : PressureUnit = 150e5 [Pa];
		attribute actualPressure : PressureUnit;
		attribute overpressureThreshold : PressureUnit = 170e5 [Pa];
		attribute motorOverloadSignal : Boolean = false;

		action def ControlLoop {
			in pressureReading : PressureUnit;
			out motorCommand : Real;
			out valveCommand : Real;
		}

		state def ControllerState;

		state ControllerBehavior {
			entry; then Idle;
			state Idle;
			state Startup;
			state NormalRunning;
			state Shutdown;
			state EmergencyShutdown;

			transition idle_to_startup
				first Idle
				then Startup
				if pressureFeedback.measuredPressure < setpoint;

			transition startup_to_running
				first Startup
				then NormalRunning
				if pressureFeedback.measuredPressure >= 0.9 * setpoint;

			transition running_to_shutdown
				first NormalRunning
				then Shutdown
				if motorOverloadSignal == false and pressureFeedback.measuredPressure >= setpoint and pressureFeedback.measuredPressure < overpressureThreshold and commandShutdown == true;

			transition shutdown_to_idle
				first Shutdown
				then Idle
				if motorControl.command == 0 and valveControl.command == 0;

			transition any_to_emergency
				first NormalRunning
				then EmergencyShutdown
				if pressureFeedback.measuredPressure >= overpressureThreshold or motorOverloadSignal == true;

			transition emergency_to_idle
				first EmergencyShutdown
				then Idle
				if motorControl.command == 0 and valveControl.command == 0 and resetCommand == true;

			attribute commandShutdown : Boolean = false;
			attribute resetCommand : Boolean = false;
		}
	}

	// ---------- Top-level System ----------
	part def TwoStageGasCompressorSystem {
		port gasInlet : GasPort;
		port gasOutlet : GasPort;
		port electricalInput : ElectricalPort;

		attribute inletPressure : PressureUnit = 1e5 [Pa];
		attribute dischargePressure : PressureUnit;
		attribute overpressureThreshold : PressureUnit = 170e5 [Pa];

		part motor : ElectricMotor {
			redefines electricalIn = electricalInput;
		}

		part stage1 : CompressionStage {
			attribute redefines pressureRatio = 5.0;
		}

		part intercooler : Intercooler;

		part stage2 : CompressionStage {
			attribute redefines pressureRatio = 6.0;
		}

		part dischargeValve : DischargeControlValve;

		part pressureSensor : PressureSensor;

		part controller : SystemController;

		// Connections
		connection gasInlet to stage1.gasIn;
		connection stage1.gasOut to intercooler.gasIn;
		connection intercooler.gasOut to stage2.gasIn;
		connection stage2.gasOut to dischargeValve.gasIn;
		connection dischargeValve.gasOut to gasOutlet;

		// Mechanical drive connections
		connection motor.mechanicalOut to stage1.mechIn;
		connection motor.mechanicalOut to stage2.mechIn;

		// Measurement connection
		connection stage2.gasOut to pressureSensor.gasMeasurement;

		// Control connections
		connection pressureSensor.feedbackOut to controller.pressureFeedback;
		connection controller.motorControl to motor.controlIn;
		connection controller.valveControl to dischargeValve.controlIn;
		connection controller.intercoolerControl to intercooler.coolantControl;

		requirement systemRequirements : CompressorSystemRequirements {
			subject redefines compressorSystem = TwoStageGasCompressorSystem::this;
		}
	}

}
