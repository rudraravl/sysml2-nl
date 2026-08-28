package 'LVDT Position Measurement System' {
	public import Definitions::*;

	package Definitions {
		public import ScalarValues::*;

		attribute def Volt;
		attribute def Hertz;
		attribute def Millimeter;

		alias Voltage for ScalarValues::Real;
		alias Displacement for ScalarValues::Real;
		alias Frequency for ScalarValues::Real;

		attribute def SystemStart;
		attribute def SystemStop;

		item def ExcitationSignal {
			attribute amplitude : Voltage;
			attribute frequency : Frequency;
		}

		item def SecondaryVoltage {
			attribute amplitude : Voltage;
			attribute phase : ScalarValues::Real;
		}

		item def ConditionedVoltage {
			attribute value : Voltage;
		}

		item def PositionReading {
			attribute displacement : Displacement;
		}

		part def PowerSupply {
			out port dcOutput : Voltage;
			attribute outputVoltage : Voltage := 24 [Volt];
		}

		part def ExcitationSource {
			in port dcInput : Voltage;
			out port acOutput : ExcitationSignal;
			attribute excitationFrequency : Frequency := 5000 [Hertz];
			attribute excitationAmplitude : Voltage := 3 [Volt];
		}

		part def Coil {
			attribute inductance : ScalarValues::Real := 5.0;
			attribute turns : ScalarValues::Integer := 500;
		}

		part def FerriteCore {
			attribute position : Displacement := 0 [Millimeter];
			attribute maxDisplacement : Displacement := 25 [Millimeter];
			attribute resolution : Displacement := 0.01 [Millimeter];
		}

		part def LVDTAssembly {
			in port excitationInput : ExcitationSignal;
			in port displacementInput : Displacement;
			out port secondaryOutput1 : SecondaryVoltage;
			out port secondaryOutput2 : SecondaryVoltage;
			part primaryCoil : Coil;
			part secondaryCoil1 : Coil;
			part secondaryCoil2 : Coil;
			part ferriteCore : FerriteCore;
		}

		part def SignalConditioner {
			in port secondaryInput1 : SecondaryVoltage;
			in port secondaryInput2 : SecondaryVoltage;
			out port conditionedOutput : ConditionedVoltage;
			attribute gain : ScalarValues::Real := 10.0;
			attribute filterCutoff : Frequency := 100 [Hertz];
		}

		part def DisplayUnit {
			in port conditionedInput : ConditionedVoltage;
			out port positionOutput : PositionReading;
			attribute calibrationFactor : ScalarValues::Real := 2.5;
			attribute displayResolution : Displacement := 0.01 [Millimeter];
		}

		action def 'Generate Excitation' {
			in dcVoltage : Voltage;
			out excitation : ExcitationSignal;
		}

		action def 'Induce Secondary Voltages' {
			in excitation : ExcitationSignal;
			in coreDisplacement : Displacement;
			out secondaryVoltage1 : SecondaryVoltage;
			out secondaryVoltage2 : SecondaryVoltage;
		}

		action def 'Calculate Differential' {
			in voltage1 : SecondaryVoltage;
			in voltage2 : SecondaryVoltage;
			out differential : SecondaryVoltage;
		}

		action def 'Demodulate' {
			in acVoltage : SecondaryVoltage;
			out dcVoltage : Voltage;
		}

		action def 'Filter Signal' {
			in rawDC : Voltage;
			out filteredDC : Voltage;
		}

		action def 'Amplify Signal' {
			in filteredDC : Voltage;
			out amplifiedDC : Voltage;
		}

		action def 'Convert to Position' {
			in dcVoltage : Voltage;
			out positionReading : PositionReading;
		}

		action def 'Measure Position' {
			in objectDisplacement : Displacement;
			out positionReading : PositionReading;
		}

		requirement def 'Measurement Range Requirement' {
			doc /* The system shall measure linear displacement over a range of ±25 mm. */
			attribute minRange : Displacement = -25 [Millimeter];
			attribute maxRange : Displacement = 25 [Millimeter];
		}

		requirement def 'Measurement Resolution Requirement' {
			doc /* The system shall resolve position changes of at least 0.01 mm. */
			attribute minResolution : Displacement = 0.01 [Millimeter];
		}

		state def 'System Operation' {
			state idle;
			accept SystemStart
				then measuring;
			accept SystemStop
				then shutdown;
			state measuring;
			then idle;
			state shutdown;
		}
	}

	package Usages {
		part 'LVDT Position System' {
			in port systemDisplacementInput : Displacement;
			out port systemPositionOutput : PositionReading;

			part powerSupply : PowerSupply;
			part excitationSource : ExcitationSource;
			part lvdtAssembly : LVDTAssembly;
			part signalConditioner : SignalConditioner;
			part displayUnit : DisplayUnit;

			connect powerSupply.dcOutput to excitationSource.dcInput;
			connect excitationSource.acOutput to lvdtAssembly.excitationInput;
			connect systemDisplacementInput to lvdtAssembly.displacementInput;
			connect lvdtAssembly.secondaryOutput1 to signalConditioner.secondaryInput1;
			connect lvdtAssembly.secondaryOutput2 to signalConditioner.secondaryInput2;
			connect signalConditioner.conditionedOutput to displayUnit.conditionedInput;
			connect displayUnit.positionOutput to systemPositionOutput;

			satisfy 'Measurement Range Requirement' by lvdtAssembly.ferriteCore;
			satisfy 'Measurement Resolution Requirement' by lvdtAssembly.ferriteCore;

			state 'system operation' : 'System Operation';

			action 'measure position' : 'Measure Position' {
				in objectDisplacement : Displacement;
				out positionReading : PositionReading;

				bind objectDisplacement = systemDisplacementInput;

				action 'generate excitation' : 'Generate Excitation' {
					in dcVoltage : Voltage;
					out excitation : ExcitationSignal;
				}
				flow 'generate excitation'.excitation
					to 'induce voltages'.excitation;

				action 'induce voltages' : 'Induce Secondary Voltages' {
					in excitation : ExcitationSignal;
					in coreDisplacement : Displacement;
					out secondaryVoltage1 : SecondaryVoltage;
					out secondaryVoltage2 : SecondaryVoltage;
				}
				flow 'induce voltages'.secondaryVoltage1
					to 'calculate differential'.voltage1;
				flow 'induce voltages'.secondaryVoltage2
					to 'calculate differential'.voltage2;

				action 'calculate differential' : 'Calculate Differential' {
					in voltage1 : SecondaryVoltage;
					in voltage2 : SecondaryVoltage;
					out differential : SecondaryVoltage;
				}
				flow 'calculate differential'.differential
					to 'demodulate'.acVoltage;

				action 'demodulate' : 'Demodulate' {
					in acVoltage : SecondaryVoltage;
					out dcVoltage : Voltage;
				}
				flow 'demodulate'.dcVoltage
					to 'filter'.rawDC;

				action 'filter' : 'Filter Signal' {
					in rawDC : Voltage;
					out filteredDC : Voltage;
				}
				flow 'filter'.filteredDC
					to 'amplify'.filteredDC;

				action 'amplify' : 'Amplify Signal' {
					in filteredDC : Voltage;
					out amplifiedDC : Voltage;
				}
				flow 'amplify'.amplifiedDC
					to 'convert to position'.dcVoltage;

				action 'convert to position' : 'Convert to Position' {
					in dcVoltage : Voltage;
					out positionReading : PositionReading;
				}

				bind positionReading = 'convert to position'.positionReading;

				first start;
				then merge continue;
				then action systemStarted accept systemStart : SystemStart;
				then action systemStopped accept systemStop : SystemStop;
				then continue;

				first systemStarted then 'generate excitation';
				first systemStarted then 'induce voltages';
				first systemStarted then 'calculate differential';
				first systemStarted then 'demodulate';
				first systemStarted then 'filter';
				first systemStarted then 'amplify';
				first systemStarted then 'convert to position';

				first 'generate excitation' then systemStopped;
				first 'induce voltages' then systemStopped;
				first 'calculate differential' then systemStopped;
				first 'demodulate' then systemStopped;
				first 'filter' then systemStopped;
				first 'amplify' then systemStopped;
				first 'convert to position' then systemStopped;
			}

			bind systemPositionOutput = 'measure position'.positionReading;
		}
	}
}
