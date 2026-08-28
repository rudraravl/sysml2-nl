package 'Hall Effect Sensing Unit' {
	private import ScalarValues::Real;
	private import ISQ::MagneticFluxDensityValue;
	private import ISQ::ElectricPotentialValue;
	private import ISQ::ElectricCurrentValue;
	public import Definitions::*;
	public import Usages::*;

	package Definitions {
		attribute def MagneticField :> MagneticFluxDensityValue;
		attribute def Voltage :> ElectricPotentialValue;
		attribute def Current :> ElectricCurrentValue;

		port def MagneticFieldPort {
			out magneticField : MagneticField;
		}
		port def VoltagePort {
			out voltage : Voltage;
		}
		port def CurrentPort {
			out current : Current;
		}

		part def HallEffectSensor {
			port fieldIn : ~MagneticFieldPort;
			port currentIn : ~CurrentPort;
			port rawVoltageOut : VoltagePort;
		}
		part def SignalConditioner {
			port rawVoltageIn : ~VoltagePort;
			port conditionedVoltageOut : VoltagePort;
		}
		part def HallEffectSensingUnit {
			port fieldIn : ~MagneticFieldPort;
			port currentIn : ~CurrentPort;
			port voltageOut : VoltagePort;
			part sensor : HallEffectSensor;
			part conditioner : SignalConditioner;
		}

		action def SenseMagneticField {
			in field : MagneticField;
			in current : Current;
			out rawVoltage : Voltage;
		}
		action def ConditionSignal {
			in rawVoltage : Voltage;
			out conditionedVoltage : Voltage;
		}

		stateMachine def UnitStateMachine {
			state Off;
			state Idle;
			state Sensing;
			state Conditioning;
			transition from Off to Idle;
			transition from Idle to Sensing;
			transition from Sensing to Conditioning;
			transition from Conditioning to Idle;
		}

		requirement def HighAccuracy {
			attribute accuracyPercent : Real;
			constraint { accuracyPercent <= 2.0 }
		}
		requirement def FastResponseTime {
			attribute responseTime_us : Real;
			constraint { responseTime_us <= 10.0 }
		}
		requirement def WideTemperatureRange {
			attribute minTemp_C : Real;
			attribute maxTemp_C : Real;
			constraint { minTemp_C <= -40.0 and maxTemp_C >= 125.0 }
		}
	}

	package Usages {
		part context {
			part sensingUnit : HallEffectSensingUnit {
				bind fieldIn.magneticField = sensor.fieldIn.magneticField;
				bind currentIn.current = sensor.currentIn.current;
				flow sensor.rawVoltageOut.voltage to conditioner.rawVoltageIn.voltage;
				bind conditioner.conditionedVoltageOut.voltage = voltageOut.voltage;

				part sensor : HallEffectSensor {
					perform action sense : SenseMagneticField {
						in field = fieldIn.magneticField;
						in current = currentIn.current;
						out rawVoltage = rawVoltageOut.voltage;
					}
				}
				part conditioner : SignalConditioner {
					perform action condition : ConditionSignal {
						in rawVoltage = rawVoltageIn.voltage;
						out conditionedVoltage = conditionedVoltageOut.voltage;
					}
				}

				stateMachine unitState : UnitStateMachine;
			}

			requirement highAccuracy : HighAccuracy;
			requirement fastResponseTime : FastResponseTime;
			requirement wideTempRange : WideTemperatureRange;

			satisfy highAccuracy by sensingUnit;
			satisfy fastResponseTime by sensingUnit;
			satisfy wideTempRange by sensingUnit;
		}
	}
}
