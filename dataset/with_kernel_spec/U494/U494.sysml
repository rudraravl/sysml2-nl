package MechanicalSealSystem {
	private import ScalarValues::*;
	private import ISQ::*;

	item def ProcessFluid;
	item def BarrierFluid;

	attribute def PressureValue :> Real;
	attribute def TemperatureValue :> Real;
	attribute def LeakageRateValue :> Real;
	attribute def ForceValue :> Real;
	attribute def LengthValue :> Real;
	attribute def RotationalSpeedValue :> Real;

	attribute def StartSignal;
	attribute def OnSignal;
	attribute def OffSignal;
	attribute def CompleteSignal;
	attribute def MaintenanceComplete;

	part def StationaryRing {
		attribute material : String = "Silicon Carbide";
	}
	part def RotatingRing {
		attribute material : String = "Carbon Graphite";
	}
	part def SpringMechanism {
		attribute springForce : ForceValue = 50.0;
	}
	part def Housing {
		attribute material : String = "Stainless Steel";
	}
	part def SecondarySeal {
		attribute sealType : String = "O-ring";
	}
	part def BarrierFluidChamber {
		attribute volume : Real = 0.001;
	}
	part def Shaft;

	port def ProcessFluidPort {
		attribute pressure : PressureValue;
	}
	port def BarrierFluidPort {
		attribute pressure : PressureValue;
	}
	port def ShaftPort {
		attribute speed : RotationalSpeedValue;
	}

	action def GenerateFluidFilm {
		in closingForce : ForceValue;
		in openingForce : PressureValue;
		in shaftSpeed : RotationalSpeedValue;
		out filmThickness : LengthValue;
	}
	action def MonitorHealth {
		out temp : TemperatureValue;
		out leak : LeakageRateValue;
	}

	state def SealStates;

	part def MechanicalSeal {
		part stationaryRing : StationaryRing;
		part rotatingRing : RotatingRing;
		part spring : SpringMechanism;
		part gland : Housing;
		part oRings : SecondarySeal;
		part barrierChamber : BarrierFluidChamber;

		port processFluidPort : ProcessFluidPort;
		port barrierFluidPort : BarrierFluidPort;
		port shaftPort : ShaftPort;

		attribute maxLeakage : LeakageRateValue = 0.1;
		attribute criticalLeakage : LeakageRateValue = 1.0;
		attribute maxTemp : TemperatureValue = 400.0;
		attribute processPressure : PressureValue = 100000.0;
		attribute barrierPressure : PressureValue = 150000.0;

		perform action 'generate fluid film' : GenerateFluidFilm;
		perform action 'monitor health' : MonitorHealth;

		exhibit state 'seal states' : SealStates;
	}

	requirement def SealPerformanceRequirement {
		doc /* The seal shall limit leakage to a near-zero controlled rate. */
		subject seal : MechanicalSeal;
		constraint { seal.barrierPressure > seal.processPressure; }
	}
	requirement def BarrierFluidPressureRequirement {
		doc /* The barrier fluid pressure shall exceed process fluid pressure to prevent hazardous leakage. */
		subject seal : MechanicalSeal;
		constraint { seal.barrierPressure > seal.processPressure; }
	}
	requirement def FaceLubricationRequirement {
		doc /* The seal faces shall be lubricated by a fluid film to prevent wear. */
		subject seal : MechanicalSeal;
		constraint { seal.spring.springForce > 0.0; }
	}

	action 'generate fluid film' : GenerateFluidFilm;
	action 'monitor health' : MonitorHealth;

	part sealAssembly : MechanicalSeal {
		part shaft : Shaft;

		connect shaft to shaftPort;
		connect barrierChamber to gland;
		connect spring to stationaryRing;
		connect stationaryRing to rotatingRing;
		connect rotatingRing to shaft;

		satisfy SealPerformanceRequirement;
		satisfy BarrierFluidPressureRequirement;
		satisfy FaceLubricationRequirement;
	}

	state 'seal states' : SealStates parallel {
		state 'operational states' {
			entry; then idle;
			state idle;
			accept StartSignal then startup;
			state startup {
				do 'generate fluid film' {
					in closingForce = sealAssembly.spring.springForce;
					in openingForce = sealAssembly.barrierPressure;
					in shaftSpeed = sealAssembly.shaftPort.speed;
					out filmThickness;
				}
			}
			accept OnSignal then normalOperation;
			state normalOperation {
				do 'generate fluid film';
			}
			accept OffSignal then shutdown;
			state shutdown;
			accept CompleteSignal then idle;
		}
		state 'health states' {
			entry; then normal;
			do 'monitor health';
			state normal;
			accept when 'monitor health'.leak > sealAssembly.maxLeakage or 'monitor health'.temp > sealAssembly.maxTemp then degraded;
			state degraded;
			accept when 'monitor health'.leak > sealAssembly.criticalLeakage then failed;
			state failed;
			accept MaintenanceComplete then normal;
		}
	}
}
