package DodrillGMRHeartLungMachine {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		item def Blood {
			attribute oxygenSaturation : Real;
			attribute temperature : TemperatureValue;
			attribute pressure : PressureValue;
		}
		item def DeoxygenatedBlood :> Blood;
		item def OxygenatedBlood :> Blood;
		item def Oxygen;
		item def CarbonDioxide;

		attribute def StartCommand;
		attribute def StopCommand;
		attribute def PrimingComplete;
		attribute def BypassComplete;
		attribute def AlarmSignal;
		attribute def ClearAlarmSignal;

		part def VenousCannula {
			port in venousBloodIn : DeoxygenatedBlood;
			port out venousBloodOut : DeoxygenatedBlood;
		}
		part def VenousReservoir {
			port in bloodIn : DeoxygenatedBlood;
			port out bloodOut : DeoxygenatedBlood;
			port out pressureOut : PressureValue;
			attribute capacity : VolumeValue = 2.0;
			perform action drainBlood : DrainBlood;
		}
		part def RollerPump {
			port in bloodIn : DeoxygenatedBlood;
			port out bloodOut : DeoxygenatedBlood;
			port out flowRateOut : VolumeFlowRateValue;
			attribute pumpSpeed : Real;
			perform action pumpBlood : PumpBlood;
			exhibit state pumpStates : PumpStates;
		}
		part def BubbleOxygenator {
			port in bloodIn : DeoxygenatedBlood;
			port out bloodOut : OxygenatedBlood;
			port in oxygenIn : Oxygen;
			port out co2Out : CarbonDioxide;
			port out o2SatOut : Real;
			perform action oxygenateBlood : OxygenateBlood;
			exhibit state oxygenatorStates : OxygenatorStates;
		}
		part def HeatExchangerUnit {
			port in bloodIn : OxygenatedBlood;
			port out bloodOut : OxygenatedBlood;
			port out tempOut : TemperatureValue;
			perform action regulateTemperature : RegulateTemperature;
			exhibit state heatExchangerStates : HeatExchangerStates;
		}
		part def BloodFilter {
			port in bloodIn : OxygenatedBlood;
			port out bloodOut : OxygenatedBlood;
			perform action filterBlood : FilterBlood;
		}
		part def ArterialCannula {
			port in arterialBloodIn : OxygenatedBlood;
			port out arterialBloodOut : OxygenatedBlood;
		}
		part def MonitoringConsole {
			port in flowRateIn : VolumeFlowRateValue;
			port in pressureIn : PressureValue;
			port in tempIn : TemperatureValue;
			port in o2SatIn : Real;
			perform action monitorParameters : MonitorParameters;
			exhibit state monitorStates : MonitorStates;
		}
		part def Patient {
			port out venousBloodOut : DeoxygenatedBlood;
			port in arterialBloodIn : OxygenatedBlood;
		}

		part def DodrillGMRMachine {
			part patient : Patient;
			part venousCannula : VenousCannula;
			part venousReservoir : VenousReservoir;
			part rollerPump : RollerPump;
			part bubbleOxygenator : BubbleOxygenator;
			part heatExchanger : HeatExchangerUnit;
			part bloodFilter : BloodFilter;
			part arterialCannula : ArterialCannula;
			part monitoringConsole : MonitoringConsole;

			connect patient.venousBloodOut to venousCannula.venousBloodIn;
			connect venousCannula.venousBloodOut to venousReservoir.bloodIn;
			connect venousReservoir.bloodOut to rollerPump.bloodIn;
			connect rollerPump.bloodOut to bubbleOxygenator.bloodIn;
			connect bubbleOxygenator.bloodOut to heatExchanger.bloodIn;
			connect heatExchanger.bloodOut to bloodFilter.bloodIn;
			connect bloodFilter.bloodOut to arterialCannula.arterialBloodIn;
			connect arterialCannula.arterialBloodOut to patient.arterialBloodIn;

			connect rollerPump.flowRateOut to monitoringConsole.flowRateIn;
			connect venousReservoir.pressureOut to monitoringConsole.pressureIn;
			connect heatExchanger.tempOut to monitoringConsole.tempIn;
			connect bubbleOxygenator.o2SatOut to monitoringConsole.o2SatIn;

			exhibit state systemStates : SystemStates;
		}

		action def DrainBlood {
			in blood : DeoxygenatedBlood;
			out drainedBlood : DeoxygenatedBlood;
		}
		action def PumpBlood {
			in blood : DeoxygenatedBlood;
			out pumpedBlood : DeoxygenatedBlood;
		}
		action def OxygenateBlood {
			in blood : DeoxygenatedBlood;
			in oxygen : Oxygen;
			out oxygenatedBlood : OxygenatedBlood;
			out co2 : CarbonDioxide;
		}
		action def RegulateTemperature {
			in blood : OxygenatedBlood;
			out tempControlledBlood : OxygenatedBlood;
		}
		action def FilterBlood {
			in blood : OxygenatedBlood;
			out filteredBlood : OxygenatedBlood;
		}
		action def MonitorParameters {
			in flowRate : VolumeFlowRateValue;
			in pressure : PressureValue;
			in temperature : TemperatureValue;
			in o2Sat : Real;
		}
		action def PrimeSystem;
		action def StartBypass;
		action def StopBypass;
		action def ProvideLifeSupport;

		state def SystemStates;
		state def PumpStates;
		state def OxygenatorStates;
		state def HeatExchangerStates;
		state def MonitorStates;

		requirement def CardiopulmonaryBypassRequirement {
			doc /* The system shall temporarily replace the patient's heart and lung function during open-heart surgery by providing extracorporeal circulation and oxygenation. */
		}
		requirement def OxygenationRequirement {
			doc /* The bubble oxygenator shall oxygenate deoxygenated blood and remove carbon dioxide. */
		}
		requirement def TemperatureControlRequirement {
			doc /* The heat exchanger shall precisely control the temperature of the blood. */
		}
		requirement def FiltrationRequirement {
			doc /* The blood filter shall remove small particles, debris, and air bubbles. */
		}
		requirement def MonitoringRequirement {
			doc /* The monitoring console shall continuously display blood flow rate, pressure, temperature, and oxygen saturation. */
		}
	}

	package Usages {
		private import Definitions::*;

		action 'prime system' : PrimeSystem;
		action 'start bypass' : StartBypass;
		action 'stop bypass' : StopBypass;
		action 'provide life support' : ProvideLifeSupport;
		action 'pump blood' : PumpBlood;
		action 'oxygenate blood' : OxygenateBlood;
		action 'regulate temperature' : RegulateTemperature;
		action 'filter blood' : FilterBlood;
		action 'monitor parameters' : MonitorParameters;

		part dodrillGMR : DodrillGMRMachine;

		state 'system states' : SystemStates parallel {
			ref machine : DodrillGMRMachine = dodrillGMR;

			state 'operational states' {
				entry; then standby;
				state standby;
				accept StartCommand
					do 'prime system'
					then priming;
				state priming;
				accept PrimingComplete
					do 'start bypass'
					then operating;
				state operating {
					entry 'start bypass';
					do 'provide life support';
					exit 'stop bypass';
				}
				accept StopCommand
					then weaning;
				state weaning;
				accept BypassComplete
					do 'stop bypass'
					then standby;
			}

			state 'safety states' {
				entry; then normal;
				state normal;
				accept AlarmSignal
					then alarm;
				state alarm;
				accept ClearAlarmSignal
					then normal;
			}
		}

		state 'pump states' : PumpStates {
			ref pump : RollerPump = dodrillGMR.rollerPump;
			entry; then stopped;
			state stopped;
			accept StartCommand
				do 'pump blood'
				then running;
			state running {
				do 'pump blood';
			}
			accept StopCommand
				then stopped;
		}

		state 'oxygenator states' : OxygenatorStates {
			ref oxygenator : BubbleOxygenator = dodrillGMR.bubbleOxygenator;
			entry; then idle;
			state idle;
			accept StartCommand
				do 'oxygenate blood'
				then active;
			state active {
				do 'oxygenate blood';
			}
			accept StopCommand
				then idle;
		}

		state 'heat exchanger states' : HeatExchangerStates {
			ref heatExchanger : HeatExchangerUnit = dodrillGMR.heatExchanger;
			entry; then standby;
			state standby;
			accept StartCommand
				do 'regulate temperature'
				then regulating;
			state regulating {
				do 'regulate temperature';
			}
			accept StopCommand
				then standby;
		}

		state 'monitor states' : MonitorStates {
			ref monitor : MonitoringConsole = dodrillGMR.monitoringConsole;
			entry; then monitoring;
			state monitoring {
				do 'monitor parameters';
			}
		}

		requirement cardiopulmonaryBypassReq : CardiopulmonaryBypassRequirement;
		requirement oxygenationReq : OxygenationRequirement;
		requirement temperatureControlReq : TemperatureControlRequirement;
		requirement filtrationReq : FiltrationRequirement;
		requirement monitoringReq : MonitoringRequirement;

		satisfy cardiopulmonaryBypassReq by dodrillGMR;
		satisfy oxygenationReq by dodrillGMR.bubbleOxygenator.oxygenateBlood;
		satisfy temperatureControlReq by dodrillGMR.heatExchanger.regulateTemperature;
		satisfy filtrationReq by dodrillGMR.bloodFilter.filterBlood;
		satisfy monitoringReq by dodrillGMR.monitoringConsole.monitorParameters;
	}
}
