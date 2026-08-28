package 'Multi-Sensor Flame Detector System' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		attribute def IRIntensity :> Real;
		attribute def AmbientTemperature :> ISQ::TemperatureValue;
		attribute def FlickerRate :> ISQ::FrequencyValue;

		item def Power;
		attribute def ActivationCommand;

		attribute def EngageSignal;
		attribute def PotentialFlame;
		attribute def FlameConfirmed;
		attribute def ResetSignal;

		action def SenseIR { out ir : IRIntensity; }
		action def SenseTemp { out temp : AmbientTemperature; }
		action def SenseFlicker { out flicker : FlickerRate; }
		action def AnalyzeData {
			in ir : IRIntensity;
			in temp : AmbientTemperature;
			in flicker : FlickerRate;
			out confirmed : Boolean;
		}
		action def SoundSiren;
		action def FlashStrobe;
		action def RegulatePower;

		part def IRSensor {
			port powerIn { in power : Power; }
			port irOut { out irData : IRIntensity; }
			perform action senseIR : SenseIR;
		}

		part def TemperatureSensor {
			port powerIn { in power : Power; }
			port tempOut { out tempData : AmbientTemperature; }
			perform action senseTemp : SenseTemp;
		}

		part def FlickerDetector {
			port powerIn { in power : Power; }
			port flickerOut { out flickerData : FlickerRate; }
			perform action senseFlicker : SenseFlicker;
		}

		part def AnalysisModule {
			port powerIn { in power : Power; }
			port irIn { in irData : IRIntensity; }
			port tempIn { in tempData : AmbientTemperature; }
			port flickerIn { in flickerData : FlickerRate; }
			port cmdOut { out activationCmd : ActivationCommand; }

			attribute irThreshold : IRIntensity = 100;
			attribute tempThreshold : AmbientTemperature = 50;
			attribute flickerThreshold : FlickerRate = 10;

			perform action analyzeData : AnalyzeData;
			exhibit state analysisStates : AnalysisStates;
		}

		part def AlarmUnit {
			port powerIn { in power : Power; }
			port cmdIn { in activationCmd : ActivationCommand; }
			perform action soundSiren : SoundSiren;
			perform action flashStrobe : FlashStrobe;
		}

		part def PowerModule {
			port powerOut { out power : Power; }
			perform action regulatePower : RegulatePower;
		}

		part def FlameDetectorSystem {
			part irSensor : IRSensor;
			part tempSensor : TemperatureSensor;
			part flickerDetector : FlickerDetector;
			part analysisModule : AnalysisModule;
			part alarmUnit : AlarmUnit;
			part powerModule : PowerModule;
		}

		state def AnalysisStates;

		requirement def MultiFactorConfirmation {
			doc /*
			 * A flame is only confirmed when the measured IR intensity, temperature,
			 * and flicker rate all exceed their specified limits at the same time.
			 */
			subject ir : IRIntensity;
			subject temp : AmbientTemperature;
			subject flicker : FlickerRate;
		}

		requirement def TriggerAlarm {
			doc /*
			 * Once the analysis module confirms a genuine flame signature,
			 * it immediately sends an activation command to a high-output alarm unit.
			 */
			subject confirmed : Boolean;
			subject cmd : ActivationCommand;
		}
	}

	package Usages {
		private import Definitions::*;

		part system_b : FlameDetectorSystem {
			flow powerToIR of Power from powerModule.powerOut.power to irSensor.powerIn.power;
			flow powerToTemp of Power from powerModule.powerOut.power to tempSensor.powerIn.power;
			flow powerToFlicker of Power from powerModule.powerOut.power to flickerDetector.powerIn.power;
			flow powerToAnalysis of Power from powerModule.powerOut.power to analysisModule.powerIn.power;
			flow powerToAlarm of Power from powerModule.powerOut.power to alarmUnit.powerIn.power;

			flow irFlow of IRIntensity from irSensor.irOut.irData to analysisModule.irIn.irData;
			flow tempFlow of AmbientTemperature from tempSensor.tempOut.tempData to analysisModule.tempIn.tempData;
			flow flickerFlow of FlickerRate from flickerDetector.flickerOut.flickerData to analysisModule.flickerIn.flickerData;
			flow cmdFlow of ActivationCommand from analysisModule.cmdOut.activationCmd to alarmUnit.cmdIn.activationCmd;
		}

		state analysisStates : AnalysisStates {
			entry; then standby;
			state standby;
			accept EngageSignal then activeMonitoring;
			state activeMonitoring;
			accept PotentialFlame then analysis;
			state analysis;
			accept FlameConfirmed
				do send new ActivationCommand() to system_b.alarmUnit
				then alarm;
			state alarm {
				entry action soundSiren { }
				entry action flashStrobe { }
			}
			accept ResetSignal then activeMonitoring;
		}
	}
}
