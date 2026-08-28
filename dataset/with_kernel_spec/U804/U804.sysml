package IndustrialGasSafetySystem {
	private import ISQ::*;
	private import ScalarValues::*;

	package Definitions {
		attribute def VoltageValue :> Real;
		attribute def ResistanceValue :> Real;
		attribute def ConcentrationValue :> Real;
		attribute def TemperatureValue :> Real;
		attribute def CurrentValue :> Real;

		item def CombustibleGas;

		port def PowerPort {
			supplyCurrent : CurrentValue;
		}
		port def GasPort {
			gas : CombustibleGas;
		}
		port def RawSignalPort {
			rawVoltage : VoltageValue;
		}
		port def ConditionedSignalPort {
			conditionedVoltage : VoltageValue;
		}
		port def ConcentrationPort {
			concentration : ConcentrationValue;
		}
		port def AlarmSignalPort {
			alarmTriggered : Boolean;
		}
		port def ResistancePort {
			resistance : ResistanceValue;
		}

		action def 'Heat Bead' {
			in supplyCurrent : CurrentValue;
			out temperature : TemperatureValue;
		}
		action def 'Oxidize Gas' {
			in gas : CombustibleGas;
			in beadTemperature : TemperatureValue;
			out heatIncrease : TemperatureValue;
		}
		action def 'Measure Resistance' {
			in temperature : TemperatureValue;
			in baseResistance : ResistanceValue;
			out resistance : ResistanceValue;
		}
		action def 'Balance Bridge' {
			in catalyticResistance : ResistanceValue;
			in compensationResistance : ResistanceValue;
			out rawVoltage : VoltageValue;
		}
		action def 'Sense Gas' {
			in gas : CombustibleGas;
			in ambientTemp : TemperatureValue;
			in ambientHumidity : Real;
			in supplyCurrent : CurrentValue;
			out rawVoltage : VoltageValue;
		}
		action def 'Condition Signal' {
			in rawVoltage : VoltageValue;
			out conditionedVoltage : VoltageValue;
		}
		action def 'Calculate Concentration' {
			in conditionedVoltage : VoltageValue;
			in calibrationFactor : Real;
			out concentration : ConcentrationValue;
		}
		action def 'Provide Power' {
			out supplyCurrent : CurrentValue;
		}
		action def 'Activate Alarm' {
			in trigger : Boolean;
		}

		part def CeramicBead {
			attribute baseResistance : ResistanceValue;
			attribute operatingTemperature : TemperatureValue;
			attribute currentResistance : ResistanceValue;
			port resistanceOut : ResistancePort;
			perform action 'heat bead' : 'Heat Bead';
			perform action 'measure resistance' : 'Measure Resistance';
			connect currentResistance to resistanceOut.resistance;
		}

		part def PellistorSensor {
			port gasIn : GasPort;
			port powerIn : PowerPort;
			port rawSignalOut : RawSignalPort;
			attribute ambientTemperature : TemperatureValue;
			attribute ambientHumidity : Real;

			part catalyticBead : CeramicBead {
				attribute isCatalytic : Boolean = true;
				event occurrence gasOxidation;
				perform action 'oxidize gas' : 'Oxidize Gas';
			}
			part compensationBead : CeramicBead {
				attribute isCatalytic : Boolean = false;
			}
			part wheatstoneBridge {
				attribute referenceResistance : ResistanceValue;
				attribute isBalanced : Boolean;
				perform action 'balance bridge' : 'Balance Bridge';
			}
			perform action 'sense gas' : 'Sense Gas';

			connect powerIn.supplyCurrent to catalyticBead.'heat bead'.supplyCurrent;
			connect powerIn.supplyCurrent to compensationBead.'heat bead'.supplyCurrent;
			connect catalyticBead.resistanceOut.resistance to wheatstoneBridge.'balance bridge'.catalyticResistance;
			connect compensationBead.resistanceOut.resistance to wheatstoneBridge.'balance bridge'.compensationResistance;
			connect wheatstoneBridge.'balance bridge'.rawVoltage to rawSignalOut.rawVoltage;
		}

		part def SignalConditioner {
			port rawSignalIn : RawSignalPort;
			port conditionedSignalOut : ConditionedSignalPort;
			port powerIn : PowerPort;
			perform action 'condition signal' : 'Condition Signal';
			connect rawSignalIn.rawVoltage to 'condition signal'.rawVoltage;
			connect 'condition signal'.conditionedVoltage to conditionedSignalOut.conditionedVoltage;
		}

		part def ConcentrationCalculator {
			port conditionedSignalIn : ConditionedSignalPort;
			port concentrationOut : ConcentrationPort;
			port powerIn : PowerPort;
			attribute calibrationFactor : Real = 1.0;
			perform action 'calculate concentration' : 'Calculate Concentration';
			connect conditionedSignalIn.conditionedVoltage to 'calculate concentration'.conditionedVoltage;
			connect calibrationFactor to 'calculate concentration'.calibrationFactor;
			connect 'calculate concentration'.concentration to concentrationOut.concentration;
		}

		state def 'Alarm Controller States' {
			in currentConcentration : ConcentrationValue;
			in warningThreshold : ConcentrationValue;
			in alarmThreshold : ConcentrationValue;
			out alarmTriggered : Boolean;
			entry; then Normal;
			state Normal;
			transition 'normal-to-warning'
				first Normal
				if currentConcentration > warningThreshold
				then Warning;
			state Warning;
			transition 'warning-to-alarm'
				first Warning
				if currentConcentration > alarmThreshold
				then CriticalAlarm;
			transition 'warning-to-normal'
				first Warning
				if currentConcentration <= warningThreshold
				then Normal;
			state CriticalAlarm;
			transition 'alarm-to-warning'
				first CriticalAlarm
				if currentConcentration <= alarmThreshold
				then Warning;
		}

		part def AlarmController {
			port concentrationIn : ConcentrationPort;
			port alarmOut : AlarmSignalPort;
			port powerIn : PowerPort;
			attribute warningThreshold : ConcentrationValue = 10.0;
			attribute alarmThreshold : ConcentrationValue = 25.0;
			exhibit state alarmStates : 'Alarm Controller States' {
				in currentConcentration = concentrationIn.concentration;
				in warningThreshold = warningThreshold;
				in alarmThreshold = alarmThreshold;
				out alarmTriggered = alarmOut.alarmTriggered;
			}
		}

		part def PowerModule {
			port powerOut : PowerPort;
			perform action 'provide power' : 'Provide Power';
			connect 'provide power'.supplyCurrent to powerOut.supplyCurrent;
		}

		part def ExternalAlarm {
			port alarmIn : AlarmSignalPort;
			perform action 'activate alarm' : 'Activate Alarm';
			connect alarmIn.alarmTriggered to 'activate alarm'.trigger;
		}

		part def IndustrialGasDetector {
			part powerModule : PowerModule;
			part sensor : PellistorSensor;
			part conditioner : SignalConditioner;
			part calculator : ConcentrationCalculator;
			part controller : AlarmController;
			part alarm : ExternalAlarm;

			flow powerModule.powerOut.supplyCurrent to sensor.powerIn.supplyCurrent;
			flow powerModule.powerOut.supplyCurrent to conditioner.powerIn.supplyCurrent;
			flow powerModule.powerOut.supplyCurrent to calculator.powerIn.supplyCurrent;
			flow powerModule.powerOut.supplyCurrent to controller.powerIn.supplyCurrent;
			flow sensor.rawSignalOut.rawVoltage to conditioner.rawSignalIn.rawVoltage;
			flow conditioner.conditionedSignalOut.conditionedVoltage to calculator.conditionedSignalIn.conditionedVoltage;
			flow calculator.concentrationOut.concentration to controller.concentrationIn.concentration;
			flow controller.alarmOut.alarmTriggered to alarm.alarmIn.alarmTriggered;
		}
	}

	public import Definitions::*;

	package Requirements {
		private import Definitions::*;

		requirement def 'Detect Combustible Gas' {
			doc /* The system shall detect combustible gases using pellistor sensor technology. */
			subject detector : IndustrialGasDetector;
			require constraint {
				detector.sensor.catalyticBead.operatingTemperature > 300.0
			}
		}

		requirement def 'Environmental Compensation' {
			doc /* The sensor shall compensate for ambient temperature and humidity changes using a compensation bead. */
			subject detector : IndustrialGasDetector;
			require constraint {
				detector.sensor.compensationBead.baseResistance == detector.sensor.catalyticBead.baseResistance
			}
		}

		requirement def 'Concentration Calculation' {
			doc /* The system shall calculate gas concentration as %LEL from conditioned voltage. */
			subject detector : IndustrialGasDetector;
			require constraint {
				detector.calculator.calibrationFactor > 0.0
			}
		}

		requirement def 'Alarm Thresholds' {
			doc /* The alarm controller shall activate warning at 10% LEL and alarm at 25% LEL. */
			subject detector : IndustrialGasDetector;
			require constraint {
				detector.controller.warningThreshold == 10.0 and detector.controller.alarmThreshold == 25.0
			}
		}

		requirement def 'Power Supply' {
			doc /* The power module shall provide stable current to all system components. */
			subject detector : IndustrialGasDetector;
			require constraint {
				detector.powerModule.powerOut.supplyCurrent > 0.0
			}
		}
	}
}
