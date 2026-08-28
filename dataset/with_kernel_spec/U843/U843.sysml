package 'Digital Quartz Thermometer' {
	private import ScalarValues::Real;
	private import ISQ::*;

	public import Definitions::*;

	package Definitions {
		attribute def PowerOnSignal;
		attribute def PowerOffSignal;
		attribute def LowPowerSignal;
		attribute def WakeUpSignal;

		part def BatteryPowerSource {
			port powerOut {
				out supply : PowerValue;
			}
			attribute powerLevel : Real;
		}

		part def QuartzCrystalOscillator {
			port powerIn {
				in supply : PowerValue;
			}
			port freqOut {
				out frequency : FrequencyValue;
			}
			attribute resonantFrequency : FrequencyValue;
		}

		part def FrequencyMeasurementCircuit {
			port powerIn {
				in supply : PowerValue;
			}
			port freqIn {
				in frequency : FrequencyValue;
			}
			port freqOut {
				out measuredFrequency : FrequencyValue;
			}
		}

		part def MicroprocessorUnit {
			port powerIn {
				in supply : PowerValue;
			}
			port freqIn {
				in measuredFrequency : FrequencyValue;
			}
			port tempOut {
				out temperature : TemperatureValue;
			}
			attribute calibrationCoefficients : Real[3];
		}

		part def LCDDisplay {
			port powerIn {
				in supply : PowerValue;
			}
			port tempIn {
				in temperature : TemperatureValue;
			}
		}

		action def GenerateFrequency {
			out frequency : FrequencyValue;
		}

		action def MeasureFrequency {
			in frequency : FrequencyValue;
			out measuredFrequency : FrequencyValue;
		}

		action def ConvertToTemperature {
			in measuredFrequency : FrequencyValue;
			in calibrationCoefficients : Real[3];
			out temperature : TemperatureValue;
		}

		action def DisplayTemperature {
			in temperature : TemperatureValue;
		}

		action def MeasureAndDisplayTemperature {
			action generateFrequency : GenerateFrequency;
			flow generateFrequency.frequency to measureFrequency.frequency;
			action measureFrequency : MeasureFrequency;
			flow measureFrequency.measuredFrequency to convertToTemperature.measuredFrequency;
			action convertToTemperature : ConvertToTemperature;
			flow convertToTemperature.temperature to displayTemperature.temperature;
			action displayTemperature : DisplayTemperature;
		}

		state def ThermometerStates;

		requirement def HighAccuracy {
			doc /* The thermometer shall measure temperature with an accuracy of ±0.1°C. */
			attribute accuracyTolerance : Real = 0.1;
			constraint { accuracyTolerance <= 0.1 }
		}

		requirement def FastResponseTime {
			doc /* The thermometer shall respond to temperature changes within 1 second. */
			attribute maxResponseTime : Real = 1.0;
			constraint { maxResponseTime <= 1.0 }
		}

		requirement def LowPowerConsumption {
			doc /* The thermometer shall consume less than 10 mW in operational mode. */
			attribute maxPowerConsumption : Real = 0.01;
			constraint { maxPowerConsumption <= 0.01 }
		}
	}

	package Usages {
		private import Definitions::*;

		part 'Digital Thermometer' {
			part battery : BatteryPowerSource;
			part oscillator : QuartzCrystalOscillator;
			part measurementCircuit : FrequencyMeasurementCircuit;
			part microprocessor : MicroprocessorUnit;
			part display : LCDDisplay;

			flow powerFlow1 of PowerValue
				from battery.powerOut.supply to oscillator.powerIn.supply;
			flow powerFlow2 of PowerValue
				from battery.powerOut.supply to measurementCircuit.powerIn.supply;
			flow powerFlow3 of PowerValue
				from battery.powerOut.supply to microprocessor.powerIn.supply;
			flow powerFlow4 of PowerValue
				from battery.powerOut.supply to display.powerIn.supply;

			flow frequencyFlow of FrequencyValue
				from oscillator.freqOut.frequency to measurementCircuit.freqIn.frequency;
			flow measuredFrequencyFlow of FrequencyValue
				from measurementCircuit.freqOut.measuredFrequency to microprocessor.freqIn.measuredFrequency;
			flow temperatureFlow of TemperatureValue
				from microprocessor.tempOut.temperature to display.tempIn.temperature;

			action measureAndDisplay : MeasureAndDisplayTemperature;

			state thermometerStates : ThermometerStates {
				entry; then off;
				state off;
				accept PowerOnSignal then operational;
				state operational {
					do measureAndDisplay;
				}
				accept LowPowerSignal then lowPower;
				accept PowerOffSignal then off;
				state lowPower;
				accept WakeUpSignal then operational;
				accept PowerOffSignal then off;
			}

			requirement highAccuracy : HighAccuracy;
			requirement fastResponseTime : FastResponseTime;
			requirement lowPowerConsumption : LowPowerConsumption;

			satisfy highAccuracy by microprocessor;
			satisfy fastResponseTime by measurementCircuit;
			satisfy lowPowerConsumption by battery;
		}
	}
}
