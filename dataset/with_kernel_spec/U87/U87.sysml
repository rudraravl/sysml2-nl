package 'miraDry Medical System' {
	private import ISQ::TemperatureValue;
	private import ISQ::DurationValue;
	private import SI::K;
	private import SI::s;
	private import ScalarValues::Boolean;
	private import ScalarValues::Real;

	item def MicrowaveEnergy;
	item def Coolant;
	item def Vacuum;

	attribute def OverTempAlert;

	port def EnergyPort {
		out item energy : MicrowaveEnergy;
	}
	port def CoolantPort {
		out item coolant : Coolant;
	}
	port def VacuumPort {
		out item vacuum : Vacuum;
	}
	port def SensorOutPort {
		out item temp : TemperatureValue;
		out item contact : Boolean;
	}
	port def SensorInPort {
		in item temp : TemperatureValue;
		in item contact : Boolean;
	}

	part def ConsoleUnit {
		part powerSupply {
			port energyOut : EnergyPort;
		}
		part coolantSystem {
			port coolantOut : CoolantPort;
			port coolantReturn : ~CoolantPort;
		}
		part vacuumPump {
			port vacuumOut : VacuumPort;
		}
		part controlProcessor {
			port sensorIn : SensorInPort;
			attribute maxSafeTemp : TemperatureValue = 318.15 [K];
		}
		port energyInterface : EnergyPort;
		port coolantInterface : CoolantPort;
		port coolantReturnInterface : ~CoolantPort;
		port vacuumInterface : VacuumPort;
		port sensorInterface : SensorInPort;
	}

	part def HandpieceAssembly {
		part microwaveAntenna {
			port energyIn : ~EnergyPort;
		}
		part coolingPlate {
			port coolantIn : ~CoolantPort;
			port coolantOut : CoolantPort;
		}
		part vacuumChamber {
			port vacuumIn : ~VacuumPort;
		}
		part tempSensor {
			port tempOut : SensorOutPort;
		}
		part contactSensor {
			port contactOut : SensorOutPort;
		}
		port energyInterface : ~EnergyPort;
		port coolantInterface : ~CoolantPort;
		port coolantReturnInterface : CoolantPort;
		port vacuumInterface : ~VacuumPort;
		port sensorInterface : SensorOutPort;
	}

	part def BioTipApplicator {
		part ceramicWindow;
		part sterileInterface;
	}

	connection def ConsoleToHandpieceEnergy {
		end consoleEnergy : EnergyPort;
		end handpieceEnergy : ~EnergyPort;
	}
	connection def CoolantLine {
		end consoleCoolant : CoolantPort;
		end handpieceCoolant : ~CoolantPort;
	}
	connection def CoolantReturnLine {
		end handpieceCoolantReturn : CoolantPort;
		end consoleCoolantReturn : ~CoolantPort;
	}
	connection def VacuumLine {
		end consoleVacuum : VacuumPort;
		end handpieceVacuum : ~VacuumPort;
	}
	connection def SensorLine {
		end handpieceSensor : SensorOutPort;
		end consoleSensor : SensorInPort;
	}

	action def PlaceHandpiece;
	action def ActivateVacuum;
	action def ActivateCooling;
	action def DeliverEnergy;
	action def ReleaseVacuum;
	action def MaintainCooling;
	action def MoveHandpiece;

	part miraDrySystem {
		part console : ConsoleUnit {
			flow of energy : MicrowaveEnergy from powerSupply.energyOut.energy to energyInterface.energy;
			flow of coolant : Coolant from coolantSystem.coolantOut.coolant to coolantInterface.coolant;
			flow of coolant : Coolant from coolantReturnInterface.coolant to coolantSystem.coolantReturn.coolant;
			flow of vacuum : Vacuum from vacuumPump.vacuumOut.vacuum to vacuumInterface.vacuum;
			flow of temp : TemperatureValue from sensorInterface.temp to controlProcessor.sensorIn.temp;
			flow of contact : Boolean from sensorInterface.contact to controlProcessor.sensorIn.contact;
		}
		
		part handpiece : HandpieceAssembly {
			flow of energy : MicrowaveEnergy from energyInterface.energy to microwaveAntenna.energyIn.energy;
			flow of coolant : Coolant from coolantInterface.coolant to coolingPlate.coolantIn.coolant;
			flow of coolant : Coolant from coolingPlate.coolantOut.coolant to coolantReturnInterface.coolant;
			flow of vacuum : Vacuum from vacuumInterface.vacuum to vacuumChamber.vacuumIn.vacuum;
			flow of temp : TemperatureValue from tempSensor.tempOut.temp to sensorInterface.temp;
			flow of contact : Boolean from contactSensor.contactOut.contact to sensorInterface.contact;
		}
		
		part bioTip : BioTipApplicator;
		
		connection : ConsoleToHandpieceEnergy connect console.energyInterface to handpiece.energyInterface;
		connection : CoolantLine connect console.coolantInterface to handpiece.coolantInterface;
		connection : CoolantReturnLine connect handpiece.coolantReturnInterface to console.coolantReturnInterface;
		connection : VacuumLine connect console.vacuumInterface to handpiece.vacuumInterface;
		connection : SensorLine connect handpiece.sensorInterface to console.sensorInterface;
		
		perform action treatmentProcess {
			action placeHandpiece : PlaceHandpiece;
			then action activateVacuum : ActivateVacuum;
			then action activateCooling : ActivateCooling;
			then action deliverEnergy : DeliverEnergy;
			then action releaseVacuum : ReleaseVacuum;
			then action moveHandpiece : MoveHandpiece;
		}
		
		state systemStates {
			in handpiece : HandpieceAssembly;
			in console : ConsoleUnit;
			entry; then initialization;
			
			state initialization;
			accept after 5 [s] then ready;
			
			state ready;
			accept when handpiece.contactSensor.contactOut.contact == true then activeTreatment;
			
			state activeTreatment;
			entry action activateVacuum : ActivateVacuum;
			do action deliverEnergy : DeliverEnergy;
			accept when handpiece.tempSensor.tempOut.temp > console.controlProcessor.maxSafeTemp
				do send new OverTempAlert() to console.controlProcessor
				then cooling;
			accept after 10 [s] then cooling;
			
			state cooling;
			entry action releaseVacuum : ReleaseVacuum;
			do action maintainCooling : MaintainCooling;
			accept after 30 [s] then ready;
		}
	}

	requirement def SafeSkinTemperature {
		attribute maxTemp : TemperatureValue = 318.15 [K];
		doc /* Skin surface temperature must not exceed 45C to prevent burns. */
	}
	requirement def SweatGlandElimination {
		doc /* Microwave energy must be delivered at a frequency and power sufficient to heat and destroy sweat glands at a depth of 2-5 mm. */
	}
	requirement def SingleUseBioTip {
		doc /* The BioTip must be used for a single treatment session and then disposed to ensure sterility. */
	}

	satisfy SafeSkinTemperature by miraDrySystem.handpiece.tempSensor;
	satisfy SweatGlandElimination by miraDrySystem.handpiece.microwaveAntenna;
	satisfy SingleUseBioTip by miraDrySystem.bioTip;
}
