package 'Suction System' {
	private import ISQ::*;
	private import ScalarValues::*;

	package Definitions {
		item def Air;
		item def Debris;
		item def Dust;
		item def CleanAir;
		item def AlertSignal;
		item def BinFullAlert :> AlertSignal;
		item def FilterClogAlert :> AlertSignal;

		attribute def VacuumPressureValue :> PressureValue;
		attribute def AirflowRateValue :> VolumeFlowRateValue;
		attribute def FillLevelValue :> Real;
		attribute def EfficiencyValue :> Real;

		attribute def StartSignal;
		attribute def StopSignal;
		attribute def ResetSignal;
		attribute def LoadEvent;
		attribute def ClogEvent;
		attribute def CleanEvent;

		enum def FilterCondition { clean; partiallyLoaded; clogged; }

		port def AirFlowPort {
			attribute pressure : VacuumPressureValue;
			attribute flowRate : AirflowRateValue;
		}

		port def TorquePort {
			attribute torque : TorqueValue;
		}

		port def PowerPort {
			attribute power : PowerValue;
		}

		port def BinStatusPort {
			attribute fillLevel : FillLevelValue;
		}

		port def FilterStatusPort {
			attribute condition : FilterCondition;
		}

		port def PressureReadingPort {
			attribute pressure : VacuumPressureValue;
		}

		port def AlertPort {
			out item alert : AlertSignal;
		}

		action def GenerateTorque {
			in power : PowerValue;
			out torque : TorqueValue;
		}

		action def GenerateSuction {
			in torque : TorqueValue;
			out airflow : AirflowRateValue;
			out vacuum : VacuumPressureValue;
		}

		action def SeparateDebris {
			in airflow : AirflowRateValue;
			in debris : Debris;
			in dust : Dust;
			out cleanAirflow : AirflowRateValue;
			out separatedDebris : Debris;
		}

		action def FilterAir {
			in dirtyAirflow : AirflowRateValue;
			in dust : Dust;
			out cleanAirflow : AirflowRateValue;
		}

		action def SensePressure {
			out pressure : VacuumPressureValue;
		}

		action def RegulateMotor {
			in pressure : VacuumPressureValue;
			out power : PowerValue;
		}

		action def TriggerBinFullAlert;
		action def TriggerFilterClogAlert;

		state def FilterStates;
		state def ControllerStates;

		part def Motor {
			attribute powerRating : PowerValue;
			port cmdPort : PowerPort;
			port shaftPort : TorquePort;
			perform action generateTorque : GenerateTorque;
		}

		part def Impeller {
			port shaftPort : TorquePort;
			port suctionPort : AirFlowPort;
			perform action generateSuction : GenerateSuction;
		}

		part def CycloneSeparator {
			port intakePort : AirFlowPort;
			port cleanAirPort : AirFlowPort;
			port debrisPort : AirFlowPort;
			perform action separateDebris : SeparateDebris;
		}

		part def DebrisBin {
			attribute capacity : MassValue;
			attribute fillLevel : FillLevelValue;
			port debrisPort : AirFlowPort;
			port statusPort : BinStatusPort;
		}

		part def HepaFilter {
			attribute efficiency : EfficiencyValue;
			attribute condition : FilterCondition;
			port dirtyAirPort : AirFlowPort;
			port cleanAirPort : AirFlowPort;
			port statusPort : FilterStatusPort;
			perform action filterAir : FilterAir;
			exhibit state filterState : FilterStates {
				entry; then clean;
				state clean;
				accept LoadEvent then partiallyLoaded;
				state partiallyLoaded;
				accept ClogEvent then clogged;
				state clogged;
				accept CleanEvent then clean;
			}
		}

		part def PressureSensor {
			attribute measuredPressure : VacuumPressureValue;
			port readingPort : PressureReadingPort;
			perform action sensePressure : SensePressure;
		}

		part def ControlUnit {
			port pressurePort : PressureReadingPort;
			port binStatusPort : BinStatusPort;
			port filterStatusPort : FilterStatusPort;
			port motorCmdPort : PowerPort;
			port alertPort : AlertPort;
			perform action regulateMotor : RegulateMotor;
			perform action triggerBinFullAlert : TriggerBinFullAlert;
			perform action triggerFilterClogAlert : TriggerFilterClogAlert;
			exhibit state controllerState : ControllerStates;
		}

		part def SuctionSystem {
			attribute motorPower : PowerValue;
			attribute binCapacity : MassValue;
			attribute currentVacuum : VacuumPressureValue;
			attribute currentAirflow : AirflowRateValue;

			port intakePort : AirFlowPort;
			port exhaustPort : AirFlowPort;
			port alertPort : AlertPort;

			part motor : Motor;
			part impeller : Impeller;
			part cyclone : CycloneSeparator;
			part bin : DebrisBin;
			part filter : HepaFilter;
			part controller : ControlUnit;
			part pressureSensor : PressureSensor;

			connect motor.shaftPort to impeller.shaftPort;
			connect intakePort to cyclone.intakePort;
			connect cyclone.cleanAirPort to filter.dirtyAirPort;
			connect cyclone.debrisPort to bin.debrisPort;
			connect filter.cleanAirPort to exhaustPort;
			connect pressureSensor.readingPort to controller.pressurePort;
			connect bin.statusPort to controller.binStatusPort;
			connect filter.statusPort to controller.filterStatusPort;
			connect controller.motorCmdPort to motor.cmdPort;
			connect controller.alertPort to alertPort;
		}

		requirement def VacuumStrengthRequirement {
			doc /* The system shall generate a vacuum pressure of at least the specified minimum. */
			subject system : SuctionSystem;
			attribute minVacuum : VacuumPressureValue;
			require system.currentVacuum >= minVacuum;
		}

		requirement def AirflowRateRequirement {
			doc /* The system shall provide an airflow rate of at least the specified minimum. */
			subject system : SuctionSystem;
			attribute minAirflow : AirflowRateValue;
			require system.currentAirflow >= minAirflow;
		}

		requirement def FiltrationEfficiencyRequirement {
			doc /* The HEPA filter shall have a minimum filtration efficiency. */
			subject filter : HepaFilter;
			attribute minEfficiency : EfficiencyValue;
			require filter.efficiency >= minEfficiency;
		}

		requirement def BinFullDetectionRequirement {
			doc /* The system shall detect when the debris bin is full and halt operation. */
			subject controller : ControlUnit;
		}

		requirement def FilterClogDetectionRequirement {
			doc /* The system shall detect when the HEPA filter is clogged and signal an alert. */
			subject controller : ControlUnit;
		}
	}

	package Usages {
		private import Definitions::*;

		part industrialSystem : SuctionSystem {
			attribute motorPower = 3000 [W];
			attribute binCapacity = 50 [kg];
			part motor : Motor {
				attribute powerRating = 3000 [W];
			}
			part bin : DebrisBin {
				attribute capacity = 50 [kg];
			}
		}

		part standardSystem : SuctionSystem {
			attribute motorPower = 1200 [W];
			attribute binCapacity = 20 [kg];
		}

		part controller1 : ControlUnit;

		state controller1States : ControllerStates {
			entry; then idle;
			state idle;
			accept StartSignal then running;
			state running {
				do controller1.regulateMotor;
				accept when controller1.binStatusPort.fillLevel >= 0.9 then binFull;
				accept when controller1.filterStatusPort.condition == FilterCondition::clogged then filterClogged;
				accept StopSignal then idle;
			}
			state binFull {
				do controller1.triggerBinFullAlert;
				accept ResetSignal then idle;
			}
			state filterClogged {
				do controller1.triggerFilterClogAlert;
				accept ResetSignal then idle;
			}
		}

		requirement suctionSystemSpec {
			doc /* Overall suction system performance specification */
			subject system : SuctionSystem;
			require VacuumStrengthRequirement {
				subject = system;
				minVacuum = 20000 [Pa];
			}
			require AirflowRateRequirement {
				subject = system;
				minAirflow = 0.05 [m^3/s];
			}
			require FiltrationEfficiencyRequirement {
				subject = system.filter;
				minEfficiency = 99.97;
			}
			require BinFullDetectionRequirement {
				subject = system.controller;
			}
			require FilterClogDetectionRequirement {
				subject = system.controller;
			}
		}
	}
}
