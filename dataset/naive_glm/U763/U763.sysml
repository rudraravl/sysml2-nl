package MagneticLevelGaugeSystem {
	import ISQ::*;
	import ScalarValues::*;

	// ---- Value Types with Units ----
	value type Length :> Real { unit 'm'; }
	value type Height :> Length;
	value type Pressure :> Real { unit 'Pa'; }
	value type Temperature :> Real {> 'K'; }
	value type ElectricCurrent :> Real { unit 'A'; }
	value type CurrentLoopSignal :> ElectricCurrent { min 0.004; max 0.020; }
	value type Voltage :> Real { unit 'V'; }
	value type LevelPercent :> Real { unit '%'; min 0; max 100; }
	value type MagneticFluxDensity :> Real { unit 'T'; }
	value type TimeDuration :> Real { unit 's'; }
	value type Mass :> Real { unit 'kg'; }
	value type Density :> Real { unit 'kg/m^3'; }

	// ---- Item Definitions ----
	item def ProcessFluid {
		attribute pressure : Pressure;
		attribute temperature : Temperature;
		attribute density : Density;
	}
	item def MagneticField {
		attribute fluxDensity : MagneticFluxDensity;
		attribute sourceHeight : Height;
	}
	item def DiscreteAlarmSignal {
		attribute active : Boolean;
		attribute setpoint : Height;
	}
	item def VisualIndication {
		attribute indicatedLevel : LevelPercent;
		attribute color : String;
	}

	// ---- Enumerations ----
	enum SwitchState { open; closed; }
	enum IndicatorColor { red; silver; }
	enum OperationalStatus { normal; highAlarm; lowAlarm; fault; }
	enum TransmitterMode { measuring; calibrating; faulted; }

	// ---- Port Definitions ----
	port def FluidConnectionPort {
		in item fluid : ProcessFluid;
	}
	port def MagneticCouplingPort {
		out item field : MagneticField;
	}
	port def MagneticReceiverPort {
		in item field : MagneticField;
	}
	port def AnalogOutputPort {
		out current : CurrentLoopSignal;
	}
	port def DiscreteOutputPort {
		out signal : DiscreteAlarmSignal;
		out state : SwitchState;
	}
	port def VisualDisplayPort {
		out indication : VisualIndication;
	}
	port def ControlSystemPort {
		in current : CurrentLoopSignal;
		in highSignal : DiscreteAlarmSignal;
		in lowSignal : DiscreteAlarmSignal;
	}

	// ---- Requirements ----
	requirement def ContinuousMeasurementRequirement {
		doc "The magnetic level gauge shall continuously measure the fluid level within the process vessel without measurement or indication components coming into direct contact with the process fluid."
		subject gauge : MagneticLevelGauge;
		objective {
			measure gauge.measurementAccuracy : Length <= 0.005 [m];
		}
	}

	requirement def BypassChamberLevelEqualityRequirement {
		doc "The fluid level inside the bypass chamber shall equal the fluid level inside the process vessel at all times."
		subject chamber : BypassChamber;
		objective {
			measure chamber.levelDifference : Length <= 0.002 [m];
		}
	}

	requirement def FloatTrackingRequirement {
		doc "The magnetic float shall rest on the liquid surface and track vertical level changes of the fluid."
		subject float : MagneticFloat;
		objective {
			measure float.trackingError : Length <= 0.003 [m];
		}
	}

	requirement def IndicatorVisualReadoutRequirement {
		doc "The indicator assembly shall provide a local visual reading of fluid level magnetically coupled to the float."
		subject indicator : IndicatorAssembly;
		objective {
			measure indicator.responseTime : TimeDuration <= 0.5 [s];
		}
	}

	requirement def TransmitterAnalogOutputRequirement {
		doc "The level transmitter shall convert float position into a 4-20 mA analog signal proportional to fluid level."
		subject transmitter : LevelTransmitter;
		objective {
			measure transmitter.outputCurrent : CurrentLoopSignal >= 0.004 [A];
			measure transmitter.outputCurrent : CurrentLoopSignal <= 0.020 [A];
		}
	}

	requirement def AlarmSwitchRequirement {
		doc "High and low alarm switches shall activate discrete outputs when the float reaches configured setpoints."
		subject alarmSwitch : AlarmSwitch;
		objective {
			measure alarmSwitch.actuationDelay : TimeDuration <= 0.1 [s];
		}
	}

	requirement def EnvironmentalRobustnessRequirement {
		doc "The gauge shall be constructed from robust materials such as stainless steel to ensure safety and longevity in high-pressure, high-temperature, or corrosive environments."
		subject gauge : MagneticLevelGauge;
		assume {
			gauge.material = "stainlessSteel";
		}
		objective {
			measure gauge.maxOperatingPressure : Pressure >= 10000000 [Pa];
			measure gauge.maxOperatingTemperature : Temperature >= 523.15 [K];
		}
	}

	// ---- Part Definitions ----

	part def BypassChamber {
		attribute material : String = "stainlessSteel";
		attribute chamberHeight : Height = 3.0 [m];
		attribute innerDiameter : Length = 0.05 [m];
		attribute wallThickness : Length = 0.005 [m];
		attribute maxPressure : Pressure = 15000000 [Pa];
		attribute maxTemperature : Temperature = 573.15 [K];
		attribute currentFluidLevel : Height;
		attribute levelDifference : Height;

		port upperVesselConnection : FluidConnectionPort;
		port lowerVesselConnection : FluidConnectionPort;
		port floatInterface : MagneticCouplingPort;

		action def EqualizeLevel {
			in vesselLevel : Height;
			out chamberLevel : Height;
			perform {
				chamberLevel := vesselLevel;
			}
		}

		state def ChamberOperation {
			entry { currentFluidLevel = 0.0 [m]; }
			state Equalizing {
				entry { perform EqualizeLevel; }
			}
			state Steady {
				do { currentFluidLevel = currentFluidLevel; }
			}
			transition equalizing_to_steady
				first Equalizing
				then Steady
				when levelDifference <= 0.002 [m];
			transition steady_to_equalizing
				first Steady
				then Equalizing
				when levelDifference > 0.002 [m];
		}

		satisfy BypassChamberLevelEqualityRequirement by chamberOperation;
	}

	part def MagneticFloat {
		attribute material : String = "stainlessSteel";
		attribute floatMass : Mass = 0.8 [kg];
		attribute floatDiameter : Length = 0.045 [m];
		attribute floatHeight : Length = 0.15 [m];
		attribute magnetFluxDensity : MagneticFluxDensity = 0.4 [T];
		attribute currentPosition : Height;
		attribute trackingError : Length;
		attribute buoyancyForce : Real;

		port magneticEmission : MagneticCouplingPort;

		action def TrackLiquidSurface {
			in liquidLevel : Height;
			out floatPosition : Height;
			perform {
				floatPosition := liquidLevel;
				currentPosition := floatPosition;
			}
		}

		state def FloatMotion {
			entry { currentPosition = 0.0 [m]; }
			state Resting {
				do { perform TrackLiquidSurface; }
			}
			state Rising {
				do { currentPosition := currentPosition + 0.001 [m]; }
			}
			state Falling {
				do { currentPosition := currentPosition - 0.001 [m]; }
			}
			transition resting_to_rising
				first Resting
				then Rising
				when currentPosition < currentFluidLevel;
			transition rising_to_resting
				first Rising
				then Resting
				when currentPosition >= currentFluidLevel;
			transition resting_to_falling
				first Resting
				then Falling
				when currentPosition > currentFluidLevel;
			transition falling_to_resting
				first Falling
				then Resting
				when currentPosition <= currentFluidLevel;
		}

		satisfy FloatTrackingRequirement by floatMotion;
	}

	part def IndicatorAssembly {
		attribute scaleLength : Height = 3.0 [m];
		attribute resolution : Length = 0.01 [m];
		attribute responseTime : TimeDuration;
		attribute indicatedLevel : LevelPercent;
		attribute flipperColor : IndicatorColor;

		port magneticInput : MagneticReceiverPort;
		port visualOutput : VisualDisplayPort;

		action def UpdateIndication {
			in floatHeight : Height;
			out indication : VisualIndication;
			perform {
				indicatedLevel := (floatHeight / scaleLength) * 100.0;
				flipperColor := (floatHeight > scaleLength / 2.0) ? IndicatorColor::red : IndicatorColor::silver;
				indication := VisualIndication { indicatedLevel = indicatedLevel; color = (flipperColor == IndicatorColor::red) ? "red" : "silver"; };
			}
		}

		state def IndicatorOperation {
			entry { indicatedLevel = 0.0; flipperColor = IndicatorColor::silver; }
			state Idle;
			state Updating {
				do { perform UpdateIndication; }
			}
			transition idle_to_updating
				first Idle
				then Updating
				when magneticInput.field.sourceHeight != indicatedLevel;
			transition updating_to_idle
				first Updating
				then Idle
				when responseTime <= 0.5 [s];
		}

		satisfy IndicatorVisualReadoutRequirement by indicatorOperation;
	}

	part def LevelTransmitter {
		attribute supplyVoltage : Voltage = 24.0 [V];
		attribute measurementRangeMin : Height = 0.0 [m];
		attribute measurementRangeMax : Height = 3.0 [m];
		attribute outputCurrent : CurrentLoopSignal;
		attribute mode : TransmitterMode;
		attribute measuredHeight : Height;

		port magneticInput : MagneticReceiverPort;
		port analogOutput : AnalogOutputPort;

		action def ConvertHeightToCurrent {
			in floatHeight : Height;
			out current : CurrentLoopSignal;
			perform {
				measuredHeight := floatHeight;
				outputCurrent := 0.004 [A] + ((floatHeight - measurementRangeMin) / (measurementRangeMax - measurementRangeMin)) * 0.016 [A];
				current := outputCurrent;
			}
		}

		state def TransmitterOperation {
			entry { outputCurrent = 0.004 [A]; mode = TransmitterMode::measuring; }
			state Measuring {
				do { perform ConvertHeightToCurrent; }
			}
			state Calibrating {
				do { outputCurrent = 0.012 [A]; }
			}
			state Faulted {
				do { outputCurrent = 0.0035 [A]; }
				entry { mode = TransmitterMode::faulted; }
			}
			transition measuring_to_calibrating
				first Measuring
				then Calibrating
				when mode == TransmitterMode::calibrating;
			transition calibrating_to_measuring
				first Calibrating
				then Measuring
				when mode == TransmitterMode::measuring;
			transition measuring_to_faulted
				first Measuring
				then Faulted
				when supplyVoltage < 10.0 [V];
		}

		satisfy TransmitterAnalogOutputRequirement by transmitterOperation;
	}

	part def AlarmSwitch {
		attribute setpoint : Height;
		attribute isHighSwitch : Boolean;
		attribute switchState : SwitchState;
		attribute actuationDelay : TimeDuration;
		attribute hysteresis : Length = 0.01 [m];

		port magneticInput : MagneticReceiverPort;
		port discreteOutput : DiscreteOutputPort;

		action def EvaluateSwitch {
			in floatHeight : Height;
			out signal : DiscreteAlarmSignal;
			out state : SwitchState;
			perform {
				if isHighSwitch {
					if floatHeight >= setpoint {
						switchState := SwitchState::closed;
					} else if floatHeight <= (setpoint - hysteresis) {
						switchState := SwitchState::open;
					}
				} else {
					if floatHeight <= setpoint {
						switchState := SwitchState::closed;
					} else if floatHeight >= (setpoint + hysteresis) {
						switchState := SwitchState::open;
					}
				}
				signal := DiscreteAlarmSignal { active = (switchState == SwitchState::closed); setpoint = setpoint; };
				state := switchState;
			}
		}

		state def SwitchOperation {
			entry { switchState = SwitchState::open; }
			state Monitoring {
				do { perform EvaluateSwitch; }
			}
			state Alarmed {
				do { perform EvaluateSwitch; }
			}
			transition monitoring_to_alarmed
				first Monitoring
				then Alarmed
				when switchState == SwitchState::closed;
			transition alarmed_to_monitoring
				first Alarmed
				then Monitoring
				when switchState == SwitchState::open;
		}

		satisfy AlarmSwitchRequirement by switchOperation;
	}

	part def ProcessVessel {
		attribute vesselHeight : Height = 4.0 [m];
		attribute vesselPressure : Pressure = 8000000 [Pa];
		attribute vesselTemperature : Temperature = 450.0 [K];
		attribute fluidLevel : Height;

		port upperChamberConnection : FluidConnectionPort;
		port lowerChamberConnection : FluidConnectionPort;

		state def VesselOperation {
			entry { fluidLevel = 1.0 [m]; }
			state Operating {
				do { fluidLevel := fluidLevel; }
			}
		}
	}

	part def ControlSystem {
		attribute receivedCurrent : CurrentLoopSignal;
		attribute highAlarmActive : Boolean;
		attribute lowAlarmActive : Boolean;
		attribute status : OperationalStatus;

		port controlInterface : ControlSystemPort;

		action def ProcessSignals {
			in current : CurrentLoopSignal;
			in highSignal : DiscreteAlarmSignal;
			in lowSignal : DiscreteAlarmSignal;
			perform {
				receivedCurrent := current;
				highAlarmActive := highSignal.active;
				lowAlarmActive := lowSignal.active;
				if highAlarmActive { status := OperationalStatus::highAlarm; }
				else if lowAlarmActive { status := OperationalStatus::lowAlarm; }
				else { status := OperationalStatus::normal; }
			}
		}

		state def ControlOperation {
			entry { status = OperationalStatus::normal; }
			state Normal {
				do { perform ProcessSignals; }
			}
			state HighAlarm {
				do { perform ProcessSignals; }
			}
			state LowAlarm {
				do { perform ProcessSignals; }
			}
			transition normal_to_high
				first Normal
				then HighAlarm
				when highAlarmActive == true;
			transition normal_to_low
				first Normal
				then LowAlarm
				when lowAlarmActive == true;
			transition high_to_normal
				first HighAlarm
				then Normal
				when highAlarmActive == false;
			transition low_to_normal
				first LowAlarm
				then Normal
				when lowAlarmActive == false;
		}
	}

	// ---- System-Level Part ----
	part def MagneticLevelGauge {
		attribute material : String = "stainlessSteel";
		attribute maxOperatingPressure : Pressure = 15000000 [Pa];
		attribute maxOperatingTemperature : Temperature = 573.15 [K];
		attribute measurementAccuracy : Length;
		attribute systemStatus : OperationalStatus;

		part processVessel : ProcessVessel {
			perform VesselOperation;
		}
		part bypassChamber : BypassChamber {
			perform ChamberOperation;
		}
		part magneticFloat : MagneticFloat {
			perform FloatMotion;
		}
		part indicatorAssembly : IndicatorAssembly {
			perform IndicatorOperation;
		}
		part levelTransmitter : LevelTransmitter {
			perform TransmitterOperation;
		}
		part highAlarmSwitch : AlarmSwitch {
			attribute setpoint = 2.7 [m];
			attribute isHighSwitch = true;
			perform SwitchOperation;
		}
		part lowAlarmSwitch : AlarmSwitch {
			attribute setpoint = 0.3 [m];
			attribute isHighSwitch = false;
			perform SwitchOperation;
		}
		part controlSystem : ControlSystem {
			perform ControlOperation;
		}

		connection vesselUpperToChamberUpper connect processVessel.upperChamberConnection to bypassChamber.upperVesselConnection;
		connection vesselLowerToChamberLower connect processVessel.lowerChamberConnection to bypassChamber.lowerVesselConnection;
		connection floatMagneticToIndicator connect magneticFloat.magneticEmission to indicatorAssembly.magneticInput;
		connection floatMagneticToTransmitter connect magneticFloat.magneticEmission to levelTransmitter.magneticInput;
		connection floatMagneticToHighSwitch connect magneticFloat.magneticEmission to highAlarmSwitch.magneticInput;
		connection floatMagneticToLowSwitch connect magneticFloat.magneticEmission to lowAlarmSwitch.magneticInput;
		connection transmitterToControl connect levelTransmitter.analogOutput to controlSystem.controlInterface;
		connection highSwitchToControl connect highAlarmSwitch.discreteOutput to controlSystem.controlInterface;
		connection lowSwitchToControl connect lowAlarmSwitch.discreteOutput to controlSystem.controlInterface;

		satisfy ContinuousMeasurementRequirement;
		satisfy EnvironmentalRobustnessRequirement;
	}
}
