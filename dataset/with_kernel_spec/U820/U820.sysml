package PiezoelectricAccelerometerSystem {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		item def MechanicalAcceleration :> ISQ::acceleration;
		item def ElectricCharge :> ISQ::electricCharge;
		item def AnalogVoltage :> ISQ::electricPotential;
		item def TemperatureValue :> ISQ::temperature;
		item def AccelerationMeasurement :> ISQ::acceleration;

		item def DigitalSample {
			attribute value : Integer;
		}

		attribute def PowerOnSignal;
		attribute def PowerOffSignal;
		attribute def CalibrateCommand;
		attribute def CalibrationComplete;
		attribute def InitializationComplete;
		attribute def VibrationEvent;
		attribute def VibrationStopped;
		attribute def ThresholdExceeded;
		attribute def NormalResumed;

		part def MountingBase {
			attribute material : String = "Titanium";
			port mechanicalInput { in acc : MechanicalAcceleration; }
			port mechanicalOutput { out acc : MechanicalAcceleration; }
		}

		part def PiezoelectricCrystal {
			attribute sensitivity : Real;
			port mechanicalInput { in acc : MechanicalAcceleration; }
			port chargeOutput { out charge : ElectricCharge; }
			perform action generateCharge : GenerateCharge;
		}

		part def ChargeAmplifier {
			attribute gain : Real;
			port chargeInput { in charge : ElectricCharge; }
			port voltageOutput { out voltage : AnalogVoltage; }
			perform action amplifyCharge : AmplifyCharge;
		}

		part def SignalFilter {
			attribute cutoffFrequency : Real;
			port voltageInput { in voltage : AnalogVoltage; }
			port voltageOutput { out voltage : AnalogVoltage; }
			perform action filterSignal : FilterSignal;
		}

		part def ADC {
			attribute sampleRate : Real;
			port voltageInput { in voltage : AnalogVoltage; }
			port digitalOutput { out sample : DigitalSample; }
			perform action convertToDigital : ConvertToDigital;
		}

		part def SignalProcessor {
			attribute calibrationFactor : Real;
			attribute offsetCorrection : Real;
			attribute tempCompensation : Real;
			port digitalInput { in sample : DigitalSample; }
			port temperatureInput { in temp : TemperatureValue; }
			port measurementOutput { out measurement : AccelerationMeasurement; }
			perform action processSignal : ProcessSignal;
		}

		part def TemperatureSensor {
			port temperatureOutput { out temp : TemperatureValue; }
			perform action senseTemperature : SenseTemperature;
		}

		part def Accelerometer {
			attribute maxThreshold : MechanicalAcceleration;
			port mechanicalInput { in acc : MechanicalAcceleration; }
			port measurementOutput { out measurement : AccelerationMeasurement; }
			port controlPort {
				in powerOn : PowerOnSignal;
				in powerOff : PowerOffSignal;
				in calibrate : CalibrateCommand;
				out alert : ThresholdExceeded;
			}

			part mountingBase : MountingBase;
			part crystal : PiezoelectricCrystal;
			part chargeAmp : ChargeAmplifier;
			part signalFilter : SignalFilter;
			part adc : ADC;
			part processor : SignalProcessor;
			part tempSensor : TemperatureSensor;

			connect mountingBase.mechanicalOutput to crystal.mechanicalInput;
			connect crystal.chargeOutput to chargeAmp.chargeInput;
			connect chargeAmp.voltageOutput to signalFilter.voltageInput;
			connect signalFilter.voltageOutput to adc.voltageInput;
			connect adc.digitalOutput to processor.digitalInput;
			connect tempSensor.temperatureOutput to processor.temperatureInput;
			connect mechanicalInput to mountingBase.mechanicalInput;
			connect processor.measurementOutput to measurementOutput;

			exhibit state accelerometerStates : AccelerometerStates;
		}

		action def GenerateCharge {
			in acc : MechanicalAcceleration;
			in sensitivity : Real;
			out charge : ElectricCharge;
		}

		action def AmplifyCharge {
			in charge : ElectricCharge;
			in gain : Real;
			out voltage : AnalogVoltage;
		}

		action def FilterSignal {
			in voltageIn : AnalogVoltage;
			in cutoffFrequency : Real;
			out voltageOut : AnalogVoltage;
		}

		action def ConvertToDigital {
			in voltage : AnalogVoltage;
			in sampleRate : Real;
			out sample : DigitalSample;
		}

		action def ProcessSignal {
			in sample : DigitalSample;
			in temp : TemperatureValue;
			in calibrationFactor : Real;
			in offsetCorrection : Real;
			in tempCompensation : Real;
			out measurement : AccelerationMeasurement;
		}

		action def SenseTemperature {
			out temp : TemperatureValue;
		}

		action def InitializeSystem;
		action def PerformCalibration;
		action def MeasureAcceleration;

		state def AccelerometerStates {
			action initializeSystem : InitializeSystem;
			action performCalibration : PerformCalibration;
			action measureAcceleration : MeasureAcceleration;

			entry; then powerOff;
			state powerOff;
			transition powerOff_to_init
				first powerOff
				accept PowerOnSignal
				then initialization;
			state initialization {
				do initializeSystem;
			}
			transition init_to_idle
				first initialization
				accept InitializationComplete
				then idle;
			state idle;
			transition idle_to_calib
				first idle
				accept CalibrateCommand
				then calibration;
			transition idle_to_measuring
				first idle
				accept VibrationEvent
				then measuring;
			state calibration {
				do performCalibration;
			}
			transition calib_to_idle
				first calibration
				accept CalibrationComplete
				then idle;
			state measuring {
				do measureAcceleration;
			}
			transition measuring_to_alert
				first measuring
				accept ThresholdExceeded
				then alert;
			transition measuring_to_idle
				first measuring
				accept VibrationStopped
				then idle;
			state alert;
			transition alert_to_measuring
				first alert
				accept NormalResumed
				then measuring;
			transition idle_to_powerOff
				first idle
				accept PowerOffSignal
				then powerOff;
		}

		requirement def MeasurementAccuracyRequirement {
			doc /* The system shall measure acceleration with an accuracy of ±1% of full scale. */
			subject accelerometer : Accelerometer;
			require { accelerometer.maxThreshold > 0 }
		}

		requirement def FrequencyResponseRequirement {
			doc /* The system shall have a frequency response from 1 Hz to 10 kHz. */
			subject accelerometer : Accelerometer;
		}

		requirement def TemperatureCompensationRequirement {
			doc /* The system shall compensate for temperature variations from -40 degC to 85 degC. */
			subject accelerometer : Accelerometer;
		}
	}

	package Usages {
		private import Definitions::*;

		part accelerometerSystem : Accelerometer {
			attribute redefines maxThreshold = 50;
			part mountingBase {
				attribute redefines material = "Titanium";
			}
			part crystal {
				attribute redefines sensitivity = 1.02e-12;
			}
			part chargeAmp {
				attribute redefines gain = 1.0e12;
			}
			part signalFilter {
				attribute redefines cutoffFrequency = 10000;
			}
			part adc {
				attribute redefines sampleRate = 50000;
			}
			part processor {
				attribute redefines calibrationFactor = 1.0;
				attribute redefines offsetCorrection = 0.0;
				attribute redefines tempCompensation = 0.0;
			}
			exhibit state accelerometerStates : AccelerometerStates;
		}

		requirement accReq : MeasurementAccuracyRequirement {
			subject redefines accelerometer = accelerometerSystem;
		}

		requirement freqReq : FrequencyResponseRequirement {
			subject redefines accelerometer = accelerometerSystem;
		}

		requirement tempReq : TemperatureCompensationRequirement {
			subject redefines accelerometer = accelerometerSystem;
		}

		satisfy accReq by accelerometerSystem;
		satisfy freqReq by accelerometerSystem;
		satisfy tempReq by accelerometerSystem;
	}
}
