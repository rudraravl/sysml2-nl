package HTSCMagnetSystem {
	private import ScalarValues::*;
	private import ISQ::*;

	attribute def VoltageValue :> Real;
	attribute def TemperatureValue :> Real;
	attribute def CurrentValue :> Real;
	attribute def MagneticFluxDensityValue :> Real;
	attribute def PowerValue :> Real;
	attribute def DurationValue :> Real;

	item def LiquidNitrogen;
	item def YBCO;
	item def ElectricalPower {
		attribute current : CurrentValue;
		attribute voltage : VoltageValue;
	}
	item def MagneticFlux {
		attribute strength : MagneticFluxDensityValue;
	}

	attribute def StartCoolDownCommand;
	attribute def ShutdownCommand;
	attribute def QuenchAlert;
	attribute def ReturnToNormalCommand;

	action def CirculateCoolant;
	action def CoolDown { in targetTemp : TemperatureValue; }
	action def EnergizeCoil { in targetCurrent : CurrentValue; }
	action def DeenergizeCoil;
	action def GenerateField;
	action def RegulateCurrent { in target : CurrentValue; }
	action def InitiateQuenchProtection;
	action def PerformEmergencyShutdown;
	action def SenseTemperature { out temp : TemperatureValue; }
	action def SenseCurrent { out current : CurrentValue; }
	action def SenseField { out field : MagneticFluxDensityValue; }
	action def MonitorSystem {
		out temp : TemperatureValue;
		out current : CurrentValue;
		out field : MagneticFluxDensityValue;
	}

	port def CryoPort {
		attribute temperature : TemperatureValue;
		out item ln2Supply : LiquidNitrogen;
		in item ln2Return : LiquidNitrogen;
	}
	port def PowerPort {
		out item powerOut : ElectricalPower;
	}
	port def FieldPort {
		out item field : MagneticFlux;
	}
	port def SensorPort {
		attribute temperature : TemperatureValue;
		attribute current : CurrentValue;
		attribute field : MagneticFluxDensityValue;
	}
	port def ControlPort {
		attribute command : String;
		attribute targetCurrent : CurrentValue;
		attribute targetTemp : TemperatureValue;
	}

	state def MagnetStates;
	state def ControllerStates;

	part def HTSCMagnet {
		attribute operatingTemp : TemperatureValue;
		attribute criticalTemp : TemperatureValue;
		attribute nominalCurrent : CurrentValue;
		attribute nominalField : MagneticFluxDensityValue;
		exhibit state magnetStates : MagnetStates;
	}

	part def SuperconductingCoil {
		ref item material : YBCO;
		attribute criticalTemp : TemperatureValue;
		attribute nominalCurrent : CurrentValue;
		attribute inductance : Real;
		port cryoPort : ~CryoPort;
		port powerPort : ~PowerPort;
		port fieldPort : FieldPort;
		port sensorOut : SensorPort;
	}

	part def NitrogenReservoir {
		attribute capacity : Real;
		ref item ln2 : LiquidNitrogen;
		port outlet : CryoPort;
		port inlet : ~CryoPort;
	}

	part def Cryocooler {
		attribute coolingCapacity : PowerValue;
		port coldHead : CryoPort;
	}

	part def TemperatureSensor {
		attribute reading : TemperatureValue;
		port sensorOut : SensorPort;
	}

	part def FlowController {
		attribute flowRate : Real;
		port controlIn : ControlPort;
	}

	part def CryogenicCoolingSystem {
		attribute targetTemp : TemperatureValue;
		attribute coolingCapacity : PowerValue;
		port supplyPort : CryoPort;
		port controlIn : ControlPort;
		part reservoir : NitrogenReservoir;
		part cryocooler : Cryocooler;
		part tempSensor : TemperatureSensor;
		part flowController : FlowController;
	}

	part def PowerSupply {
		attribute maxCurrent : CurrentValue;
		attribute outputVoltage : VoltageValue;
		port outputPort : PowerPort;
		port controlIn : ControlPort;
	}

	part def MagneticShield {
		attribute shieldingFactor : Real;
		port shieldPort : ~FieldPort;
	}

	part def MagnetControlSystem {
		attribute maxOperatingTemp : TemperatureValue;
		attribute quenchThreshold : TemperatureValue;
		attribute responseTime : DurationValue;
		port sensorIn : ~SensorPort;
		port coolingControl : ~ControlPort;
		port powerControl : ~ControlPort;
		exhibit state controllerStates : ControllerStates;
	}

	action senseTemp : SenseTemperature;
	action senseCurrent : SenseCurrent;
	action senseField : SenseField;

	part htscMagnet1 : HTSCMagnet {
		attribute operatingTemp = 77;
		attribute criticalTemp = 90;
		attribute nominalCurrent = 500;
		attribute nominalField = 10;

		part coil : SuperconductingCoil {
			attribute criticalTemp = 90;
			attribute nominalCurrent = 500;
			attribute inductance = 1.5;
		}

		part coolingSystem : CryogenicCoolingSystem {
			attribute targetTemp = 77;
			attribute coolingCapacity = 500;
			part reservoir : NitrogenReservoir {
				attribute capacity = 100.0;
			}
			part cryocooler : Cryocooler {
				attribute coolingCapacity = 500;
			}
			part tempSensor : TemperatureSensor {
				attribute reading = 77;
			}
			part flowController : FlowController {
				attribute flowRate = 10.0;
			}
		}

		part powerSupply : PowerSupply {
			attribute maxCurrent = 600;
			attribute outputVoltage = 20;
		}

		part magneticShield : MagneticShield {
			attribute shieldingFactor = 0.95;
		}

		part controlSystem : MagnetControlSystem {
			attribute maxOperatingTemp = 77;
			attribute quenchThreshold = 85;
			attribute responseTime = 0.1;
		}

		connect coolingSystem.supplyPort to coil.cryoPort;
		connect powerSupply.outputPort to coil.powerPort;
		connect coil.fieldPort to magneticShield.shieldPort;
		connect coil.sensorOut to controlSystem.sensorIn;
		connect controlSystem.coolingControl to coolingSystem.controlIn;
		connect controlSystem.powerControl to powerSupply.controlIn;
	}

	state magnetStates : MagnetStates {
		entry; then idle;
		do action monitor : MonitorSystem { out temp; out current; out field; }

		state idle;
		accept StartCoolDownCommand
			then coolDown;

		state coolDown {
			entry action cool : CoolDown { in targetTemp = htscMagnet1.operatingTemp; }
			do action circulate : CirculateCoolant;
		}
		accept when monitor.temp <= htscMagnet1.operatingTemp
			then superconducting;

		state superconducting {
			entry action energize : EnergizeCoil { in targetCurrent = htscMagnet1.nominalCurrent; }
			do action generateField : GenerateField;
		}
		accept when monitor.temp > htscMagnet1.controlSystem.quenchThreshold
			do send new QuenchAlert() to htscMagnet1.controlSystem
			then quench;
		accept ShutdownCommand
			then shuttingDown;

		state shuttingDown {
			entry action deenergize : DeenergizeCoil;
			do action circulateOff : CirculateCoolant;
		}
		accept when monitor.current <= 0
			then idle;

		state quench {
			entry action protect : InitiateQuenchProtection;
			do action emergency : PerformEmergencyShutdown;
		}
		accept ReturnToNormalCommand
			then coolDown;
	}

	state controllerStates : ControllerStates {
		entry; then monitoring;

		state monitoring;
		accept QuenchAlert
			then handlingQuench;

		state handlingQuench;
		accept ReturnToNormalCommand
			then monitoring;
	}

	requirement def CryogenicStability {
		subject magnet : HTSCMagnet;
		assert constraint {
			magnet.operatingTemp <= 77
			and magnet.operatingTemp < magnet.criticalTemp
		}
	}

	requirement def PowerOutputSpec {
		subject magnet : HTSCMagnet;
		assert constraint {
			magnet.nominalCurrent >= 500
		}
	}

	requirement def MagneticFieldSpec {
		subject magnet : HTSCMagnet;
		assert constraint {
			magnet.nominalField >= 5
		}
	}

	requirement def CoilMaterialSpec {
		subject coil : SuperconductingCoil;
		assert constraint {
			coil.criticalTemp >= 90
		}
	}

	requirement def QuenchSafetyProtocol {
		subject control : MagnetControlSystem;
		assert constraint {
			control.quenchThreshold <= 85
			and control.responseTime <= 0.1
		}
	}
}
