package TMS_System {
	import ScalarValues::*;
	import ISQ::*;

	attribute def Celsius :> Unit;
	attribute def Tesla :> Unit;
	attribute def Ampere :> Unit;
	attribute def Volt :> Unit;
	attribute def Hertz :> Unit;
	attribute def Second :> Unit;
	attribute def Watt :> Unit;
	attribute def LiterPerMinute :> Unit;

	value type Temperature :> Real { unit : Celsius; }
	value type MagneticFluxDensity :> Real { unit : Tesla; }
	value type Current :> Real { unit : Ampere; }
	value type Voltage :> Real { unit : Volt; }
	value type Frequency :> Real { unit : Hertz; }
	value type Duration :> Real { unit : Second; }
	value type Power :> Real { unit : Watt; }
	value type FlowRate :> Real { unit : LiterPerMinute; }

	item def Coolant;

	item def MagneticPulse {
		:>> amplitude : MagneticFluxDensity;
		:>> frequency : Frequency;
		:>> timestamp : Duration;
	}

	item def TreatmentProtocol {
		:>> intensity : MagneticFluxDensity = 1.5;
		:>> pulseFrequency : Frequency = 10;
		:>> duration : Duration = 1800;
		:>> pulseCount : Integer = 18000;
		:>> interPulseInterval : Duration = 0.1;
	}

	enum def SafetyStatus { safe | warning | critical; }

	enum def OperationalMode { standby | calibration | positioning | active | shutdown; }

	port def ElectricalPowerPort {
		out voltage : Voltage;
		out current : Current;
	}

	port def CoolantPort {
		in supply : Coolant;
		out return : Coolant;
		:>> flowRate : FlowRate;
	}

	port def MagneticFieldPort {
		out pulse : MagneticPulse;
	}

	port def ControlCommandPort {
		out command : OperationalMode;
		in feedback : Real;
	}

	port def PositionCommandPort {
		out targetX : Real;
		out targetY : Real;
		out targetZ : Real;
		out orientation : Real;
	}

	port def SafetyStatusPort {
		out status : SafetyStatus;
		out measuredTemperature : Temperature;
		out measuredField : MagneticFluxDensity;
	}

	port def ShutdownPort {
		out shutdown : Boolean;
	}

	part def PowerSupply {
		port dischargePort : ElectricalPowerPort;
		port shutdownIn : ~ShutdownPort;
		attribute maxVoltage : Voltage = 3000;
		attribute maxCurrent : Current = 12000;
		attribute storedEnergy : Real = 2000;
		attribute outputVoltage : Voltage;
		attribute outputCurrent : Current;
		attribute enabled : Boolean = false;

		action def Discharge {
			in voltage : Voltage;
			in current : Current;
			out pulseEnergy : Real;
		}

		private action dischargeAction : Discharge {
			in voltage = outputVoltage;
			in current = outputCurrent;
		}
	}

	part def StimulationCoil {
		port powerIn : ~ElectricalPowerPort;
		port coolantPort : ~CoolantPort;
		port fieldOut : MagneticFieldPort;
		attribute temperature : Temperature = 25;
		attribute fieldStrength : MagneticFluxDensity = 0;
		attribute windingCount : Integer = 15;
		attribute maxTemperature : Temperature = 45;
		attribute active : Boolean = false;

		action def GeneratePulse {
			in energy : Real;
			out pulse : MagneticPulse;
		}

		private action generatePulse : GeneratePulse {
			out pulse = fieldOut.pulse;
		}
	}

	part def CoolingSystem {
		port coilSupply : CoolantPort;
		port commandIn : ~ControlCommandPort;
		attribute coolantFlow : FlowRate = 0;
		attribute maxFlow : FlowRate = 5;
		attribute coolantTemperature : Temperature = 18;
		attribute active : Boolean = false;

		action def Circulate {
			in requiredFlow : FlowRate;
			out actualFlow : FlowRate;
		}

		private action circulateAction : Circulate {
			out actualFlow = coolantFlow;
		}
	}

	part def PositioningArm {
		port commandIn : ~ControlCommandPort;
		port positionOut : PositionCommandPort;
		attribute currentX : Real = 0;
		attribute currentY : Real = 0;
		attribute currentZ : Real = 0;
		attribute currentOrientation : Real = 0;
		attribute positioningAccuracy : Real = 0.5;
		attribute maxReach : Real = 800;
		attribute moving : Boolean = false;

		action def MoveTo {
			in x : Real;
			in y : Real;
			in z : Real;
			in orientation : Real;
		}

		private action moveToTarget : MoveTo {
			in x = positionOut.targetX;
			in y = positionOut.targetY;
			in z = positionOut.targetZ;
			in orientation = positionOut.orientation;
		}
	}

	part def SafetyMonitor {
		port fieldSense : ~MagneticFieldPort;
		port statusOut : SafetyStatusPort;
		port shutdownOut : ShutdownPort;
		attribute temperatureLimit : Temperature = 42;
		attribute fieldLimit : MagneticFluxDensity = 2.5;
		attribute currentStatus : SafetyStatus = safe;
		attribute monitoring : Boolean = true;

		action def EvaluateSafety {
			in temp : Temperature;
			in field : MagneticFluxDensity;
			out status : SafetyStatus;
			out shutdown : Boolean;
		}

		private action evaluate : EvaluateSafety {
			in temp = statusOut.measuredTemperature;
			in field = statusOut.measuredField;
			out status = currentStatus;
			out shutdown = shutdownOut.shutdown;
		}
	}

	part def ControlUnit {
		port coilCommand : ControlCommandPort;
		port coolingCommand : ControlCommandPort;
		port armCommand : ControlCommandPort;
		port armPosition : PositionCommandPort;
		port safetyIn : ~SafetyStatusPort;
		attribute protocol : TreatmentProtocol;
		attribute mode : OperationalMode = standby;
		attribute calibratedIntensity : MagneticFluxDensity = 0;
		attribute sessionElapsed : Duration = 0;
		attribute pulsesDelivered : Integer = 0;

		action def Calibrate {
			out intensity : MagneticFluxDensity;
		}

		action def ExecuteProtocol {
			in intensity : MagneticFluxDensity;
			in frequency : Frequency;
			in duration : Duration;
		}

		state machine def TreatmentSequence {
			state idle {
				entry :> mode = standby;
			}
			state calibrating {
				entry :> mode = calibration;
				do :> perform Calibrate;
			}
			state positioning {
				entry :> mode = positioning;
				do :> command arm to target;
			}
			state stimulating {
				entry :> mode = active;
				parallel coilOperation {
					state generatingPulses {
						do :> generate magnetic pulses at protocol.pulseFrequency;
					}
				}
				parallel coolingOperation {
					state circulatingCoolant {
						do :> maintain coolant flow;
					}
				}
				parallel monitoringOperation {
					state monitoring {
						do :> evaluate safety parameters;
					}
				}
			}
			state completing {
				entry :> mode = standby;
				do :> finalize session;
			}
			state emergencyShutdown {
				entry :> mode = shutdown;
				do :> halt all subsystems;
			}
			transition idle -> calibrating when clinicianStarts;
			transition calibrating -> positioning when calibrationComplete;
			transition positioning -> stimulating when positionConfirmed;
			transition stimulating -> completing when protocolComplete;
			transition stimulating -> emergencyShutdown when safetyCritical;
			transition completing -> idle when sessionFinalized;
			transition emergencyShutdown -> idle when systemReset;
		}

		private state machine treatment : TreatmentSequence;
	}

	part def TMSSystem {
		part powerSupply : PowerSupply;
		part coil : StimulationCoil;
		part coolingSystem : CoolingSystem;
		part positioningArm : PositioningArm;
		part controlUnit : ControlUnit;
		part safetyMonitor : SafetyMonitor;

		connection powerDelivery connect powerSupply.dischargePort to coil.powerIn;
		connection coolantLoop connect coolingSystem.coilSupply to coil.coolantPort;
		connection fieldSensing connect coil.fieldOut to safetyMonitor.fieldSense;
		connection coilControl connect controlUnit.coilCommand to coil.powerIn;
		connection coolingControl connect controlUnit.coolingCommand to coolingSystem.commandIn;
		connection armControl connect controlUnit.armCommand to positioningArm.commandIn;
		connection armPositioning connect controlUnit.armPosition to positioningArm.positionOut;
		connection safetyReporting connect safetyMonitor.statusOut to controlUnit.safetyIn;
		connection safetyShutdown connect safetyMonitor.shutdownOut to powerSupply.shutdownIn;
	}

	requirement def SafetyRequirement {
		subject : TMSSystem;
		requirement {
			doc :> "The system shall automatically shut down when coil temperature exceeds 42 degC.";
			check :> coil.temperature > 42 implies powerSupply.enabled == false;
		}
	}

	requirement def FieldLimitRequirement {
		subject : TMSSystem;
		requirement {
			doc :> "The magnetic field strength shall not exceed 2.5 T during operation.";
			check :> coil.fieldStrength <= 2.5;
		}
	}

	requirement def CoolingRequirement {
		subject : TMSSystem;
		requirement {
			doc :> "The cooling system shall maintain coil temperature below 45 degC during sustained operation.";
			check :> coil.temperature < 45;
		}
	}

	requirement def PositioningRequirement {
		subject : TMSSystem;
		requirement {
			doc :> "The positioning arm shall place the coil within 0.5 mm of the target coordinates.";
			check :> positioningArm.positioningAccuracy <= 0.5;
		}
	}

	requirement def ProtocolExecutionRequirement {
		subject : TMSSystem;
		requirement {
			doc :> "The control unit shall execute the treatment protocol defining intensity, frequency, and duration.";
			check :> controlUnit.protocol.intensity > 0 and controlUnit.protocol.pulseFrequency > 0 and controlUnit.protocol.duration > 0;
		}
	}

	requirement def OperationalSequenceRequirement {
		subject : TMSSystem;
		requirement {
			doc :> "The system shall follow the sequence: idle, calibration, positioning, stimulation, completion, with emergency shutdown overriding any state.";
			check :> controlUnit.treatment.isIn(idle) or controlUnit.treatment.isIn(calibrating) or controlUnit.treatment.isIn(positioning) or controlUnit.treatment.isIn(stimulating) or controlUnit.treatment.isIn(completing) or controlUnit.treatment.isIn(emergencyShutdown);
		}
	}

	requirement def ParallelOperationRequirement {
		subject : TMSSystem;
		requirement {
			doc :> "During stimulation, the coil, cooling system, and safety monitor shall operate concurrently.";
			check :> controlUnit.treatment.isIn(stimulating) implies (coil.active and coolingSystem.active and safetyMonitor.monitoring);
		}
	}
}
