package HighPressurePlungerPumpSubsystem {
	import ScalarValues::*;
	import ISQ::*;

	// ---- Value types with units ----
	value type PressureValue :> Real { unit 'Pa'; }
	value type FlowRateValue :> Real { unit 'm^3/s'; }
	value type TorqueValue :> Real { unit 'N*m'; }
	value type RotationalSpeedValue :> Real { unit 'rad/s'; }
	value type VolumeValue :> Real { unit 'm^3'; }
	value type LengthValue :> Real { unit 'm'; }
	value type PowerValue :> Real { unit 'W'; }
	value type TemperatureValue :> Real { unit 'K'; }
	value type VoltageValue :> Real { unit 'V'; }
	value type AngleValue :> Real { unit 'rad'; }
	value type FrequencyValue :> Real { unit 'Hz'; }

	// ---- Item definitions ----
	item def HydraulicFluid;
	item def LowPressureFluid :> HydraulicFluid;
	item def HighPressureFluid :> HydraulicFluid;

	// ---- Port definitions ----
	port def FluidPort {
		item fluid : HydraulicFluid;
		attribute pressure : PressureValue;
		attribute flowRate : FlowRateValue;
		attribute temperature : TemperatureValue;
	}

	port def MechanicalPort {
		attribute torque : TorqueValue;
		attribute speed : RotationalSpeedValue;
	}

	port def ElectricalPort {
		attribute voltage : VoltageValue;
		attribute current : Real { unit 'A'; }
		attribute power : PowerValue;
	}

	port def SignalPort {
		attribute value : Real;
		attribute quality : Real;
	}

	// ---- Interface definitions ----
	interface def FluidFlow {
		end supplier : FluidPort;
		end consumer : FluidPort;
		flow fluidFlow : HydraulicFluid from supplier to consumer;
	}

	interface def MechanicalDrive {
		end driver : MechanicalPort;
		end driven : MechanicalPort;
	}

	interface def ElectricalSupply {
		end source : ElectricalPort;
		end load : ElectricalPort;
	}

	interface def SignalLink {
		end source : SignalPort;
		end sink : SignalPort;
	}

	// ---- Requirements ----
	requirement def PumpPerformanceRequirement {
		doc "The pump subsystem shall deliver high-pressure fluid at a steady flow rate."
		attribute targetDischargePressure : PressureValue = 30e6;
		attribute targetFlowRate : FlowRateValue = 1.0e-3;
		attribute minSteadyFlowRatio : Real = 0.95;
		subject pumpOutlet : FluidPort;
		require { pumpOutlet.pressure >= targetDischargePressure and
			      pumpOutlet.flowRate >= targetFlowRate; }
	}

	requirement def PulsationDampeningRequirement {
		doc "The discharge pressure vessel shall reduce residual pressure pulsation."
		attribute maxPulsationAmplitude : PressureValue = 500e3;
		subject vesselOutlet : FluidPort;
		require { abs(vesselOutlet.pressure - 30e6) <= maxPulsationAmplitude; }
	}

	requirement def SafetyReliefRequirement {
		doc "The discharge vessel shall relieve pressure before exceeding safe limits."
		attribute maxAllowablePressure : PressureValue = 45e6;
		subject vesselInlet : FluidPort;
		require { vesselInlet.pressure <= maxAllowablePressure; }
	}

	requirement def MonitoringRequirement {
		doc "The system shall monitor inlet pressure, outlet pressure, and discharge flow rate."
		subject inletSensor : SignalPort;
		subject outletSensor : SignalPort;
		subject flowSensor : SignalPort;
		require { inletSensor.quality >= 0.95 and
			      outletSensor.quality >= 0.95 and
			      flowSensor.quality >= 0.95; }
	}

	// ---- Supply reservoir ----
	part def SupplyReservoir {
		port outletPort : FluidPort;
		attribute capacity : VolumeValue = 0.5;
		attribute fluidLevel : VolumeValue = 0.4;
		attribute fluidTemperature : TemperatureValue = 293.15;
		attribute ambientPressure : PressureValue = 101325;
		item storedFluid : LowPressureFluid;
		
		action def SupplyFluid {
			in req : SupplyReservoir;
			out delivered : LowPressureFluid;
		}
		
		satisfy SupplyFluid {
			subject self;
		}
	}

	// ---- Check valve ----
	part def CheckValve {
		port inlet : FluidPort;
		port outlet : FluidPort;
		attribute crackingPressure : PressureValue = 10e3;
		attribute isOpen : Boolean = false;
		attribute leakageRate : FlowRateValue = 1.0e-9;
		
		state def ValveStates {
			entry action { isOpen := false; }
			state Closed {
				entry action { isOpen := false; }
			}
			state Open {
				entry action { isOpen := true; }
			}
			transition Closed -> Open
				when { inlet.pressure - outlet.pressure > crackingPressure; }
				then assign isOpen := true;
			transition Open -> Closed
				when { outlet.pressure >= inlet.pressure; }
				then assign isOpen := false;
		}
		
		exhibit ValveStates;
	}

	// ---- Plunger ----
	part def Plunger {
		port inletPort : FluidPort;
		port dischargePort : FluidPort;
		port crankPort : MechanicalPort;
		
		part inletValve : CheckValve;
		part dischargeValve : CheckValve;
		
		attribute strokeLength : LengthValue = 0.05;
		attribute plungerDiameter : LengthValue = 0.02;
		attribute chamberVolume : VolumeValue = 1.57e-5;
		attribute currentPressure : PressureValue;
		attribute currentFlowRate : FlowRateValue;
		attribute crankAngle : AngleValue;
		attribute phaseOffset : AngleValue;
		
		state def PlungerCycle {
			entry action { crankAngle := 0.0; }
			state IntakeStroke {
				entry action { inletValve.isOpen := true; dischargeValve.isOpen := false; }
				do action { chamberVolume := chamberVolume + (strokeLength / 2.0) * sin(crankAngle); }
			}
			state DischargeStroke {
				entry action { inletValve.isOpen := false; dischargeValve.isOpen := true; }
				do action { currentPressure := currentPressure * 1.05; }
			}
			transition IntakeStroke -> DischargeStroke
				when { crankAngle >= 3.14159; }
				then assign crankAngle := 0.0;
			transition DischargeStroke -> IntakeStroke
				when { crankAngle >= 3.14159; }
				then assign crankAngle := 0.0;
		}
		
		exhibit PlungerCycle;
		
		connect inletPort to inletValve.inlet;
		connect inletValve.outlet to dischargePort;
		connect dischargeValve.inlet to dischargePort;
	}

	// ---- Crank mechanism ----
	part def CrankMechanism {
		port driveInput : MechanicalPort;
		port plungerDrive1 : MechanicalPort;
		port plungerDrive2 : MechanicalPort;
		port plungerDrive3 : MechanicalPort;
		
		attribute crankRadius : LengthValue = 0.025;
		attribute connectingRodLength : LengthValue = 0.10;
		attribute phaseOffset1 : AngleValue = 0.0;
		attribute phaseOffset2 : AngleValue = 2.0944;
		attribute phaseOffset3 : AngleValue = 4.1888;
		attribute angularVelocity : RotationalSpeedValue;
		
		action def ConvertRotationToReciprocation {
			in rotation : MechanicalPort;
			out recip1 : MechanicalPort;
			out recip2 : MechanicalPort;
			out recip3 : MechanicalPort;
		}
		
		satisfy ConvertRotationToReciprocation {
			subject self;
		}
	}

	// ---- Triplex plunger pump ----
	part def TriplexPlungerPump {
		port inletPort : FluidPort;
		port dischargePort : FluidPort;
		port drivePort : MechanicalPort;
		
		part crank : CrankMechanism;
		part plungers[3] : Plunger;
		
		attribute nominalDischargePressure : PressureValue = 30e6;
		attribute nominalFlowRate : FlowRateValue = 1.0e-3;
		attribute efficiency : Real = 0.88;
		
		satisfy PumpPerformanceRequirement {
			subject dischargePort;
		}
		
		connect drivePort to crank.driveInput via MechanicalDrive;
		connect crank.plungerDrive1 to plungers[1].crankPort via MechanicalDrive;
		connect crank.plungerDrive2 to plungers[2].crankPort via MechanicalDrive;
		connect crank.plungerDrive3 to plungers[3].crankPort via MechanicalDrive;
		
		connect inletPort to plungers[1].inletPort via FluidFlow;
		connect inletPort to plungers[2].inletPort via FluidFlow;
		connect inletPort to plungers[3].inletPort via FluidFlow;
		
		connect plungers[1].dischargePort to dischargePort via FluidFlow;
		connect plungers[2].dischargePort to dischargePort via FluidFlow;
		connect plungers[3].dischargePort to dischargePort via FluidFlow;
	}

	// ---- Electric motor ----
	part def ElectricMotor {
		port electricalInput : ElectricalPort;
		port driveOutput : MechanicalPort;
		
		attribute ratedPower : PowerValue = 15000;
		attribute ratedSpeed : RotationalSpeedValue = 157.08;
		attribute ratedVoltage : VoltageValue = 400;
		attribute efficiency : Real = 0.92;
		attribute startingTorque : TorqueValue = 120;
		attribute running : Boolean = false;
		
		state def MotorStates {
			entry action { running := false; }
			state Off {
				entry action { running := false; }
			}
			state Starting {
				entry action { running := false; }
				do action { driveOutput.torque := startingTorque; }
			}
			state Running {
				entry action { running := true; }
				do action { driveOutput.speed := ratedSpeed; }
			}
			state Faulted {
				entry action { running := false; }
			}
			transition Off -> Starting
				when { electricalInput.power > 0 and electricalInput.voltage >= 0.9 * ratedVoltage; }
				then assign running := false;
			transition Starting -> Running
				when { driveOutput.speed >= 0.9 * ratedSpeed; }
				then assign running := true;
			transition Running -> Off
				when { electricalInput.power == 0; }
				then assign running := false;
			transition Running -> Faulted
				when { driveOutput.speed > 1.2 * ratedSpeed; }
				then assign running := false;
			transition Faulted -> Off
				when { electricalInput.power == 0; };
		}
		
		exhibit MotorStates;
	}

	// ---- Discharge pressure vessel ----
	part def DischargePressureVessel {
		port inletPort : FluidPort;
		port outletPort : FluidPort;
		port reliefPort : FluidPort;
		
		attribute volume : VolumeValue = 0.02;
		attribute prechargePressure : PressureValue = 5e6;
		attribute maxWorkingPressure : PressureValue = 40e6;
		attribute safetyReliefPressure : PressureValue = 45e6;
		attribute gasVolume : VolumeValue = 0.015;
		attribute fluidVolume : VolumeValue = 0.005;
		attribute isRelieving : Boolean = false;
		
		state def VesselStates {
			entry action { isRelieving := false; }
			state Normal {
				entry action { isRelieving := false; }
				do action { outletPort.pressure := inletPort.pressure - 100e3; }
			}
			state Relieving {
				entry action { isRelieving := true; }
				do action { reliefPort.flowRate := 0.5e-3; }
			}
			transition Normal -> Relieving
				when { inletPort.pressure > safetyReliefPressure; }
				then assign isRelieving := true;
			transition Relieving -> Normal
				when { inletPort.pressure < 0.95 * safetyReliefPressure; }
				then assign isRelieving := false;
		}
		
		exhibit VesselStates;
		
		satisfy PulsationDampeningRequirement {
			subject outletPort;
		}
		satisfy SafetyReliefRequirement {
			subject inletPort;
		}
	}

	// ---- Pressure sensor ----
	part def PressureSensor {
		port measuredPort : FluidPort;
		port signalOut : SignalPort;
		
		attribute range : PressureValue = 50e6;
		attribute accuracy : Real = 0.01;
		attribute sampleRate : FrequencyValue = 1000;
		
		action def MeasurePressure {
			in measured : FluidPort;
			out signal : SignalPort;
			assign signal.value := measured.pressure;
			assign signal.quality := 1.0 - accuracy;
		}
		
		satisfy MeasurePressure {
			subject self;
		}
	}

	// ---- Flow meter ----
	part def FlowMeter {
		port measuredPort : FluidPort;
		port signalOut : SignalPort;
		
		attribute range : FlowRateValue = 0.01;
		attribute accuracy : Real = 0.02;
		attribute sampleRate : FrequencyValue = 500;
		
		action def MeasureFlow {
			in measured : FluidPort;
			out signal : SignalPort;
			assign signal.value := measured.flowRate;
			assign signal.quality := 1.0 - accuracy;
		}
		
		satisfy MeasureFlow {
			subject self;
		}
	}

	// ---- Top-level subsystem ----
	part def HighPressurePumpSubsystem {
		satisfy PumpPerformanceRequirement;
		satisfy PulsationDampeningRequirement;
		satisfy SafetyReliefRequirement;
		satisfy MonitoringRequirement;
		
		part supplyTank : SupplyReservoir;
		part motor : ElectricMotor;
		part pump : TriplexPlungerPump;
		part dischargeVessel : DischargePressureVessel;
		part inletPressureSensor : PressureSensor;
		part outletPressureSensor : PressureSensor;
		part dischargeFlowMeter : FlowMeter;
		
		port externalElectricalSupply : ElectricalPort;
		port systemDischargePort : FluidPort;
		
		attribute systemStatus : String = "Idle";
		attribute totalOperatingHours : Real = 0.0;
		
		connect externalElectricalSupply to motor.electricalInput via ElectricalSupply;
		connect motor.driveOutput to pump.drivePort via MechanicalDrive;
		connect supplyTank.outletPort to pump.inletPort via FluidFlow;
		connect pump.dischargePort to dischargeVessel.inletPort via FluidFlow;
		connect dischargeVessel.outletPort to systemDischargePort via FluidFlow;
		
		connect inletPressureSensor.measuredPort to pump.inletPort;
		connect outletPressureSensor.measuredPort to pump.dischargePort;
		connect dischargeFlowMeter.measuredPort to dischargeVessel.outletPort;
		
		satisfy MonitoringRequirement {
			subject inletPressureSensor.signalOut;
			subject outletPressureSensor.signalOut;
			subject dischargeFlowMeter.signalOut;
		}
	}
}
