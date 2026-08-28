package 'Scroll Compressor Refrigeration System' {
	private import ScalarValues::*;

	attribute def PressureValue :> Real;
	attribute def TemperatureValue :> Real;
	attribute def MassFlowRateValue :> Real;
	attribute def EfficiencyValue :> Real;
	attribute def PowerValue :> Real;
	attribute def TorqueValue :> Real;
	attribute def RotationalSpeedValue :> Real;
	attribute def LengthValue :> Real;

	attribute def StartCommand;
	attribute def StopCommand;
	attribute def RunningSignal;
	attribute def FaultSignal;
	attribute def ResetCommand;

	item def RefrigerantGas {
		attribute pressure : PressureValue;
		attribute temperature : TemperatureValue;
		attribute massFlowRate : MassFlowRateValue;
	}
	item def LubricatingOil {
		attribute massFlowRate : MassFlowRateValue;
	}

	port def SuctionPort {
		ref item refrigerant : RefrigerantGas;
	}
	port def DischargePort {
		ref item refrigerant : RefrigerantGas;
	}
	port def OilReturnPort {
		ref item oil : LubricatingOil;
	}
	port def DriveShaftPort {
		attribute torque : TorqueValue;
		attribute speed : RotationalSpeedValue;
	}

	part def FixedScroll {
		attribute scrollProfile : String;
		attribute scrollHeight : LengthValue;
	}
	part def OrbitingScroll {
		attribute orbitRadius : LengthValue;
		port drive : DriveShaftPort;
	}
	part def ElectricMotor {
		attribute ratedPower : PowerValue;
		attribute efficiency : EfficiencyValue;
		port shaft : DriveShaftPort;
		perform action driveShaft : DriveShaftAction;
	}

	action def DriveShaftAction {
		out torque : TorqueValue;
		out speed : RotationalSpeedValue;
	}
	action def CompressionProcess {
		in suctionGas : RefrigerantGas;
		out dischargeGas : RefrigerantGas;
	}
	action def OilSeparationProcess {
		in mixedGas : RefrigerantGas;
		out cleanGas : RefrigerantGas;
		out separatedOil : LubricatingOil;
	}

	state def CompressorStates {
		entry; then stopped;
		state stopped;
		accept StartCommand then starting;
		state starting;
		accept RunningSignal then running;
		accept FaultSignal then fault;
		state running;
		accept StopCommand then stopped;
		accept FaultSignal then fault;
		state fault;
		accept ResetCommand then stopped;
	}

	part def ScrollCompressor {
		part fixedScroll : FixedScroll;
		part orbitingScroll : OrbitingScroll;
		part motor : ElectricMotor;
		port suction : SuctionPort;
		port discharge : DischargePort;
		connect motor.shaft to orbitingScroll.drive;
		perform action compress : CompressionProcess {
			in suctionGas = suction.refrigerant;
			out dischargeGas = discharge.refrigerant;
		}
		exhibit compressorStates : CompressorStates;
	}

	part def OilSeparator {
		port inlet : DischargePort;
		port gasOutlet : DischargePort;
		port oilReturn : OilReturnPort;
		attribute separationEfficiency : EfficiencyValue;
		perform action separate : OilSeparationProcess {
			in mixedGas = inlet.refrigerant;
			out cleanGas = gasOutlet.refrigerant;
			out separatedOil = oilReturn.oil;
		}
	}

	part def RefrigerationSystem {
		part compressor : ScrollCompressor;
		part oilSeparator : OilSeparator;
		port systemSuction : SuctionPort;
		port systemDischarge : DischargePort;
		port systemOilReturn : OilReturnPort;
		connect systemSuction to compressor.suction;
		connect compressor.discharge to oilSeparator.inlet;
		connect oilSeparator.gasOutlet to systemDischarge;
		connect oilSeparator.oilReturn to systemOilReturn;
		exhibit systemStates : CompressorStates;
	}

	constraint def MaxDischargePressure {
		in p : PressureValue;
		p <= 4000000.0
	}
	constraint def MaxDischargeTemperature {
		in t : TemperatureValue;
		t <= 423.15
	}
	constraint def MinEfficiency {
		in e : EfficiencyValue;
		e >= 0.65
	}
	constraint def MinPressureRatio {
		in p_suction : PressureValue;
		in p_discharge : PressureValue;
		p_discharge / p_suction >= 3.0
	}

	requirement def EfficiencyRequirement {
		doc /* The compressor must operate with minimum efficiency of 65%. */
		subject compressor : ScrollCompressor;
		require constraint efficiencyOk : MinEfficiency;
	}
	requirement def SafetyRequirement {
		doc /* Discharge pressure must not exceed 4 MPa and temperature must not exceed 423 K. */
		subject compressor : ScrollCompressor;
		require constraint pressureOk : MaxDischargePressure;
		require constraint temperatureOk : MaxDischargeTemperature;
	}
	requirement def PerformanceRequirement {
		doc /* The compressor must achieve a minimum pressure ratio of 3.0. */
		subject compressor : ScrollCompressor;
		require constraint pressureRatioOk : MinPressureRatio;
	}
	requirement def SystemRequirements {
		doc /* Overall system requirements for the scroll compressor refrigeration system. */
		subject system : RefrigerationSystem;
		requirement efficiencyReq : EfficiencyRequirement {
			subject = system.compressor;
		}
		requirement safetyReq : SafetyRequirement {
			subject = system.compressor;
		}
		requirement performanceReq : PerformanceRequirement {
			subject = system.compressor;
		}
	}

	part refrigerationSystem : RefrigerationSystem {
		requirement systemSpec : SystemRequirements;
		assert satisfy systemSpec by refrigerationSystem;
	}
}
