package 'Surgical Trocar System' {
	private import ScalarValues::*;
	private import ISQ::*;

	item def CO2Gas {
		attribute pressure : PressureValue;
	}
	item def SurgicalInstrument {
		attribute diameter : LengthValue;
	}
	item def AbdominalWall;

	attribute def StartProcedureSignal;
	attribute def SealActivatedSignal;
	attribute def LeakDetectedSignal;
	attribute def SealRepairedSignal;
	attribute def StartInflationSignal;
	attribute def StopInflationSignal;
	attribute def ProcedureCompleteSignal;

	action def PierceTissue {
		in item wall : AbdominalWall;
		out force : ForceValue;
	}
	action def RemoveObturator;
	action def ActivateSeal;
	action def InflateAbdomen {
		in item gas : CO2Gas;
		out pressure : PressureValue;
	}
	action def PassInstrument {
		in item instrument : SurgicalInstrument;
	}
	action def InsertTrocar {
		in item wall : AbdominalWall;
		in item gas : CO2Gas;
		in item instrument : SurgicalInstrument;
		action puncture : PierceTissue { in item wall = wall; }
		then action removeObturator : RemoveObturator;
		then action activateSeal : ActivateSeal;
		then action inflateAbdomen : InflateAbdomen { in item gas = gas; }
		then action passInstrument : PassInstrument { in item instrument = instrument; }
	}

	port def ObturatorShaftPort;
	port def CannulaInternalPort;
	port def CannulaTopPort;
	port def CannulaSidePort;
	port def SealCannulaPort;
	port def SealInstrumentPort;
	port def ValveCannulaPort;
	port def ValveGasPort;
	port def GasSupplyPort;

	part def Tip;
	part def BladedTip :> Tip;
	part def NonBladedTip :> Tip;
	part def OpticalTip :> Tip;

	part def Obturator {
		part tip : Tip;
		attribute insertionForce : ForceValue;
		port shaftPort : ObturatorShaftPort;
		perform action pierceTissue : PierceTissue;
	}
	part def Cannula {
		port topPort : CannulaTopPort;
		port sidePort : CannulaSidePort;
		port internalPort : CannulaInternalPort;
		attribute innerDiameter : LengthValue;
	}
	part def SealAssembly {
		port cannulaPort : SealCannulaPort;
		port instrumentPort : SealInstrumentPort;
		attribute leakRate : VolumeFlowRateValue;
		exhibit state 'seal states' {
			entry; then open;
			state open;
			accept SealActivatedSignal then sealed;
			state sealed;
			accept LeakDetectedSignal then compromised;
			state compromised;
			accept SealRepairedSignal then sealed;
		}
	}
	part def ValveAssembly {
		port cannulaPort : ValveCannulaPort;
		port gasPort : ValveGasPort;
		attribute targetPressure : PressureValue;
		attribute currentPressure : PressureValue;
		exhibit state 'valve states' {
			entry; then closed;
			state closed;
			accept StartInflationSignal then inflating;
			state inflating;
			accept when currentPressure >= targetPressure then regulating;
			state regulating;
			accept StopInflationSignal then closed;
		}
	}
	part def GasSupply {
		port output : GasSupplyPort;
	}

	connection def ObturatorCannulaConnection {
		end [1] port obturatorEnd : ObturatorShaftPort;
		end [1] port cannulaEnd : CannulaInternalPort;
	}
	connection def SealCannulaConnection {
		end [1] port sealEnd : SealCannulaPort;
		end [1] port cannulaEnd : CannulaTopPort;
	}
	connection def ValveCannulaConnection {
		end [1] port valveEnd : ValveCannulaPort;
		end [1] port cannulaEnd : CannulaSidePort;
	}
	connection def GasSupplyConnection {
		end [1] port supplyEnd : GasSupplyPort;
		end [1] port valveEnd : ValveGasPort;
	}

	part def TrocarSystem {
		part obturator : Obturator;
		part cannula : Cannula;
		part sealAssembly : SealAssembly;
		part valveAssembly : ValveAssembly;
		part gasSupply : GasSupply;

		connection obturatorCannula : ObturatorCannulaConnection {
			connect obturator.shaftPort to cannula.internalPort;
		}
		connection sealCannula : SealCannulaConnection {
			connect sealAssembly.cannulaPort to cannula.topPort;
		}
		connection valveCannula : ValveCannulaConnection {
			connect valveAssembly.cannulaPort to cannula.sidePort;
		}
		connection gasSupplyConn : GasSupplyConnection {
			connect gasSupply.output to valveAssembly.gasPort;
		}

		perform action insertTrocar : InsertTrocar;
	}

	requirement def InsertionForceLimit {
		doc /* The insertion force must not exceed 50 N to prevent tissue trauma. */
		attribute maxForce : ForceValue = 50;
		constraint { trocarSystem.obturator.insertionForce <= maxForce }
	}
	requirement def InstrumentCompatibility {
		doc /* The cannula must accommodate instruments with diameters between 5 mm and 12 mm. */
		attribute minDiameter : LengthValue = 5;
		attribute maxDiameter : LengthValue = 12;
		constraint { trocarSystem.cannula.innerDiameter >= maxDiameter }
	}
	requirement def SealIntegrity {
		doc /* The seal assembly must maintain gas seal integrity with a leak rate below 0.1 L/min. */
		attribute maxLeakRate : VolumeFlowRateValue = 0.1;
		constraint { trocarSystem.sealAssembly.leakRate <= maxLeakRate }
	}
	requirement def PneumoperitoneumStability {
		doc /* The valve assembly must maintain a stable insufflation pressure of 15 mmHg. */
		attribute targetPressure : PressureValue = 15;
		constraint { trocarSystem.valveAssembly.currentPressure >= targetPressure }
	}

	requirement TrocarSafetyRequirements {
		require InsertionForceLimit;
		require InstrumentCompatibility;
		require SealIntegrity;
		require PneumoperitoneumStability;
	}

	part trocarSystem : TrocarSystem {
		part obturator : Obturator {
			part tip : BladedTip;
			attribute insertionForce : ForceValue = 30;
		}
		part cannula : Cannula {
			attribute innerDiameter : LengthValue = 12;
		}
		part sealAssembly : SealAssembly {
			attribute leakRate : VolumeFlowRateValue = 0.05;
		}
		part valveAssembly : ValveAssembly {
			attribute targetPressure : PressureValue = 15;
			attribute currentPressure : PressureValue = 0;
		}
		part gasSupply : GasSupply;
	}

	satisfy TrocarSafetyRequirements by trocarSystem;
}
