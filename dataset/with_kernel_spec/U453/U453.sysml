package OphthalmicExaminationSystem {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	attribute def TableHeightValue :> LengthValue {
		attribute height : TableHeightValue :>> self {
			doc
			/*
			 * Welner table height shall be limited to the range between 0.60 m and 1.20 m inclusive.
			 */
		}
		assert constraint { height >= 0.60 [m] and height <= 1.20 [m] }
	}

	attribute def ArmTiltAngleValue :> PlaneAngleValue {
		attribute angle : ArmTiltAngleValue :>> self {
			doc
			/*
			 * Instrument arm tilt shall be limited to the range between -15 degrees and +45 degrees inclusive.
			 */
		}
		assert constraint { angle >= -15 ['°'] and angle <= 45 ['°'] }
	}

	attribute def ChairHeightValue :> LengthValue {
		attribute height : ChairHeightValue :>> self {
			doc
			/*
			 * Patient chair working height range.
			 */
		}
		assert constraint { height >= 0.40 [m] and height <= 0.80 [m] }
	}

	attribute def LensPowerValue :> Real;

	item def PowerSignal {
		attribute voltage : ElectricPotentialValue;
		attribute maxCurrent : ElectricCurrentValue;
	}

	item def CommandSignal {
		attribute commandType : String;
		attribute targetValue : Real;
	}

	item def StatusSignal {
		attribute mode : String;
		attribute currentValue : Real;
	}

	item def EmergencyStopSignal {
		attribute active : Boolean = true;
	}

	port def PowerPort {
		in item power : PowerSignal;
	}

	port def CommandPort {
		in item command : CommandSignal;
	}

	port def StatusPort {
		out item status : StatusSignal;
	}

	port def EmergencyStopPort {
		in item stop : EmergencyStopSignal;
	}

	port def MechanicalMountPort;

	part def LinearActuator {
		port powerIn : PowerPort;
		port commandIn : CommandPort;
		port statusOut : StatusPort;
		attribute position : TableHeightValue = 0.90 [m];
	}

	part def TiltActuator {
		port powerIn : PowerPort;
		port commandIn : CommandPort;
		port statusOut : StatusPort;
		attribute angle : ArmTiltAngleValue = 0 ['°'];
	}

	part def ChairLiftActuator {
		port powerIn : PowerPort;
		port commandIn : CommandPort;
		port statusOut : StatusPort;
		attribute height : ChairHeightValue = 0.45 [m];
	}

	part def Phoropter {
		port powerIn : PowerPort;
		port commandIn : CommandPort;
		port statusOut : StatusPort;
		port mount : MechanicalMountPort;
		attribute sphericalPower : LensPowerValue = 0.0;
		attribute cylindricalPower : LensPowerValue = 0.0;
	}

	part def InstrumentArm {
		attribute tiltAngle : ArmTiltAngleValue = 0 ['°'];
		port mount : MechanicalMountPort;
		part tiltActuator : TiltActuator[1];
		part mountedPhoropter : Phoropter[1];

		bind tiltActuator.angle = tiltAngle;
		connect mount to mountedPhoropter.mount;
		connect tiltActuator.powerIn to mountedPhoropter.powerIn;
		connect tiltActuator.commandIn to mountedPhoropter.commandIn;
	}

	part def WelnerTable {
		attribute height : TableHeightValue = 0.90 [m];
		port powerIn : PowerPort;
		port commandIn : CommandPort;
		port statusOut : StatusPort;
		part heightActuator : LinearActuator[1];
		part instrumentArm : InstrumentArm[1];

		bind heightActuator.position = height;
		connect powerIn to heightActuator.powerIn;
		connect powerIn to instrumentArm.tiltActuator.powerIn;
		connect commandIn to heightActuator.commandIn;
		connect commandIn to instrumentArm.tiltActuator.commandIn;
	}

	part def PatientChair {
		attribute height : ChairHeightValue = 0.45 [m];
		attribute maxPatientMass : MassValue = 180 [kg];
		port powerIn : PowerPort;
		port commandIn : CommandPort;
		port statusOut : StatusPort;
		part liftActuator : ChairLiftActuator[1];

		bind liftActuator.height = height;
		connect powerIn to liftActuator.powerIn;
		connect commandIn to liftActuator.commandIn;
	}

	part def TouchscreenControlPanel {
		port powerIn : PowerPort;
		port tableCommandOut : ~CommandPort;
		port chairCommandOut : ~CommandPort;
		port phoropterCommandOut : ~CommandPort;
		port emergencyStopOut : ~EmergencyStopPort;
		port tableStatusIn : ~StatusPort;
		port chairStatusIn : ~StatusPort;
		port phoropterStatusIn : ~StatusPort;
		attribute currentMode : String;
	}

	part def PowerSupplyUnit {
		port acInput : PowerPort;
		port dcOutput : ~PowerPort;
		attribute outputVoltage : ElectricPotentialValue = 24 [V];
		attribute outputCurrent : ElectricCurrentValue = 10 [A];
	}

	action def PositionTable {
		in targetHeight : TableHeightValue;
		in targetTilt : ArmTiltAngleValue;
		out actualHeight : TableHeightValue;
		out actualTilt : ArmTiltAngleValue;
	}

	action def PositionChair {
		in targetHeight : ChairHeightValue;
		out actualHeight : ChairHeightValue;
	}

	action def AdjustPhoropter {
		in targetSphere : LensPowerValue;
		in targetCylinder : LensPowerValue;
		out sphereSetting : LensPowerValue;
		out cylinderSetting : LensPowerValue;
	}

	action def EmergencyStopAction {
		out motionDisabled : Boolean;
	}

	state machine def OperationalMode {
		state idle;
		state positioning;
		state examining;
		state emergencyStopped;

		transition t1 {
			source idle;
			target positioning;
		}
		transition t2 {
			source positioning;
			target examining;
		}
		transition t3 {
			source examining;
			target positioning;
		}
		transition t4 {
			source positioning;
			target idle;
		}
		transition t5 {
			source idle;
			target emergencyStopped;
		}
		transition t6 {
			source positioning;
			target emergencyStopped;
		}
		transition t7 {
			source examining;
			target emergencyStopped;
		}
		transition t8 {
			source emergencyStopped;
			target idle;
		}
	}

	requirement def HeightAdjustmentRequirement {
		doc
		/*
		 * The Welner table height shall be adjustable between 0.60 m and 1.20 m.
		 */
		subject table : WelnerTable;
		require { table.height >= 0.60 [m] and table.height <= 1.20 [m] }
	}

	requirement def TiltAdjustmentRequirement {
		doc
		/*
		 * The instrument arm tilt shall be adjustable between -15 and +45 degrees.
		 */
		subject arm : InstrumentArm;
		require { arm.tiltAngle >= -15 ['°'] and arm.tiltAngle <= 45 ['°'] }
	}

	requirement def PatientWeightRequirement {
		doc
		/*
		 * The patient chair shall support patients weighing up to 180 kg.
		 */
		subject chair : PatientChair;
		require { chair.maxPatientMass >= 180 [kg] }
	}

	requirement def EmergencyStopRequirement {
		doc
		/*
		 * The system shall halt all motorized motion instantly when emergency stop is activated.
		 */
	}

	requirement def CentralControlRequirement {
		doc
		/*
		 * All components shall be managed from a central touchscreen control panel.
		 */
	}

	requirement def PowerSupplyRequirement {
		doc
		/*
		 * A single power supply unit shall convert wall power to low-voltage DC for all motors and electronics.
		 */
	}

	part examinationSystem {
		satisfy HeightAdjustmentRequirement;
		satisfy TiltAdjustmentRequirement;
		satisfy PatientWeightRequirement;
		satisfy EmergencyStopRequirement;
		satisfy CentralControlRequirement;
		satisfy PowerSupplyRequirement;

		part table : WelnerTable[1];
		part chair : PatientChair[1];
		part controlPanel : TouchscreenControlPanel[1];
		part powerSupply : PowerSupplyUnit[1];

		connect powerSupply.dcOutput to table.powerIn;
		connect powerSupply.dcOutput to chair.powerIn;
		connect powerSupply.dcOutput to controlPanel.powerIn;

		connect controlPanel.tableCommandOut to table.commandIn;
		connect controlPanel.chairCommandOut to chair.commandIn;
		connect controlPanel.phoropterCommandOut to table.instrumentArm.mountedPhoropter.commandIn;

		connect table.statusOut to controlPanel.tableStatusIn;
		connect chair.statusOut to controlPanel.chairStatusIn;
		connect table.instrumentArm.mountedPhoropter.statusOut to controlPanel.phoropterStatusIn;

		state machine operationalState : OperationalMode;
	}
}
