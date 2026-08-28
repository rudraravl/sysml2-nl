package 'Hall Probe Magnetometer' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;
	public import Definitions::*;
	public import Usages::*;

	package Definitions {
		private import ISQ::*;
		private import SI::*;
		private import ScalarValues::*;

		alias MagneticFluxDensity for ISQ::MagneticFluxDensityValue;
		alias ElectricCurrent for ISQ::ElectricCurrentValue;
		alias Voltage for ISQ::ElectricPotentialValue;
		alias Temperature for ISQ::ThermodynamicTemperatureValue;

		item def BiasCurrent;
		item def HallVoltage;
		item def AmplifiedVoltage;
		item def FilteredVoltage;
		item def DigitalValue;
		item def TemperatureReading;
		item def CorrectedMagneticField;

		attribute def CalibrationData {
			attribute gain : Real;
			attribute offset : Real;
		}

		action def 'Generate Hall Voltage' {
			in magneticField : MagneticFluxDensity;
			in biasCurrent : BiasCurrent;
			out hallVoltage : HallVoltage;
		}

		action def 'Amplify Signal' {
			in hallVoltage : HallVoltage;
			out amplifiedVoltage : AmplifiedVoltage;
		}

		action def 'Filter Noise' {
			in amplifiedVoltage : AmplifiedVoltage;
			out filteredVoltage : FilteredVoltage;
		}

		action def 'Convert Analog to Digital' {
			in filteredVoltage : FilteredVoltage;
			out digitalValue : DigitalValue;
		}

		action def 'Process and Compensate' {
			in digitalValue : DigitalValue;
			in temperatureReading : TemperatureReading;
			in calibration : CalibrationData;
			out correctedMagneticField : CorrectedMagneticField;
		}

		action def 'Display Reading' {
			in correctedMagneticField : CorrectedMagneticField;
		}

		action def 'Measure Magnetic Field' {
			in magneticField : MagneticFluxDensity;
			in biasCurrent : BiasCurrent;
			in temperatureReading : TemperatureReading;
			in calibration : CalibrationData;
			out correctedMagneticField : CorrectedMagneticField;
		}

		part def HallElement;
		part def BiasCurrentSource;
		part def SignalAmplifier;
		part def NoiseFilter;
		part def ADC;
		part def MPU;
		part def TemperatureSensor;
		part def DisplayInterface;
		part def Magnetometer;

		requirement def MeasurementRangeRequirement {
			doc /* The magnetometer shall measure magnetic flux density in the range of -2.0 T to +2.0 T. */
			attribute minRange : MagneticFluxDensity = -2.0 [T];
			attribute maxRange : MagneticFluxDensity = 2.0 [T];
		}

		requirement def HighAccuracyRequirement {
			doc /* The magnetometer shall provide high accuracy and resolution across the operating range. */
			attribute accuracy : Real = 0.001;
		}

		requirement def TemperatureCompensationRequirement {
			doc /* The magnetometer shall compensate for measurement drift due to temperature changes using an integrated temperature sensor. */
		}

		requirement def NoiseFilteringRequirement {
			doc /* The magnetometer shall filter electrical noise from the amplified Hall voltage before digitization. */
		}

		requirement def ContinuousOperationRequirement {
			doc /* The magnetometer shall operate continuously to provide real-time magnetic field measurements. */
		}
	}

	package Usages {
		private import Definitions::*;

		requirement measurementRange : MeasurementRangeRequirement;
		requirement highAccuracy : HighAccuracyRequirement;
		requirement temperatureCompensation : TemperatureCompensationRequirement;
		requirement noiseFiltering : NoiseFilteringRequirement;
		requirement continuousOperation : ContinuousOperationRequirement;

		part magnetometer : Magnetometer {
			port magneticFieldInputPort { in magneticField : MagneticFluxDensity; }

			attribute calibration : CalibrationData;

			part hallElement : HallElement {
				port magneticFieldPort { in magneticField : MagneticFluxDensity; }
				port biasCurrentPort { in biasCurrent : BiasCurrent; }
				port hallVoltagePort { out hallVoltage : HallVoltage; }
			}

			part biasCurrentSource : BiasCurrentSource {
				port biasCurrentOutPort { out biasCurrent : BiasCurrent; }
			}

			part signalAmplifier : SignalAmplifier {
				port hallVoltageInPort { in hallVoltage : HallVoltage; }
				port amplifiedVoltageOutPort { out amplifiedVoltage : AmplifiedVoltage; }
			}

			part noiseFilter : NoiseFilter {
				port amplifiedVoltageInPort { in amplifiedVoltage : AmplifiedVoltage; }
				port filteredVoltageOutPort { out filteredVoltage : FilteredVoltage; }
			}

			part adc : ADC {
				port filteredVoltageInPort { in filteredVoltage : FilteredVoltage; }
				port digitalValueOutPort { out digitalValue : DigitalValue; }
			}

			part temperatureSensor : TemperatureSensor {
				port temperatureOutPort { out temperatureReading : TemperatureReading; }
			}

			part mpu : MPU {
				port digitalValueInPort { in digitalValue : DigitalValue; }
				port temperatureInPort { in temperatureReading : TemperatureReading; }
				port correctedFieldOutPort { out correctedMagneticField : CorrectedMagneticField; }
			}

			part displayInterface : DisplayInterface {
				port correctedFieldInPort { in correctedMagneticField : CorrectedMagneticField; }
			}

			flow magneticFieldFlow of MagneticFluxDensity
				from magneticFieldInputPort.magneticField
				to hallElement.magneticFieldPort.magneticField;

			flow biasCurrentFlow of BiasCurrent
				from biasCurrentSource.biasCurrentOutPort.biasCurrent
				to hallElement.biasCurrentPort.biasCurrent;

			flow hallVoltageFlow of HallVoltage
				from hallElement.hallVoltagePort.hallVoltage
				to signalAmplifier.hallVoltageInPort.hallVoltage;

			flow amplifiedVoltageFlow of AmplifiedVoltage
				from signalAmplifier.amplifiedVoltageOutPort.amplifiedVoltage
				to noiseFilter.amplifiedVoltageInPort.amplifiedVoltage;

			flow filteredVoltageFlow of FilteredVoltage
				from noiseFilter.filteredVoltageOutPort.filteredVoltage
				to adc.filteredVoltageInPort.filteredVoltage;

			flow digitalValueFlow of DigitalValue
				from adc.digitalValueOutPort.digitalValue
				to mpu.digitalValueInPort.digitalValue;

			flow temperatureFlow of TemperatureReading
				from temperatureSensor.temperatureOutPort.temperatureReading
				to mpu.temperatureInPort.temperatureReading;

			flow correctedFieldFlow of CorrectedMagneticField
				from mpu.correctedFieldOutPort.correctedMagneticField
				to displayInterface.correctedFieldInPort.correctedMagneticField;

			action 'measure magnetic field' : 'Measure Magnetic Field' {
				in magneticField : MagneticFluxDensity;
				in biasCurrent : BiasCurrent;
				in temperatureReading : TemperatureReading;
				in calibration : CalibrationData;
				out correctedMagneticField : CorrectedMagneticField;

				loop {
					action 'generate hall voltage' : 'Generate Hall Voltage' {
						in magneticField = 'measure magnetic field'::magneticField;
						in biasCurrent = 'measure magnetic field'::biasCurrent;
						out hallVoltage : HallVoltage;
					}
					flow 'generate hall voltage'.hallVoltage to 'amplify signal'.hallVoltage;

					action 'amplify signal' : 'Amplify Signal' {
						in hallVoltage : HallVoltage;
						out amplifiedVoltage : AmplifiedVoltage;
					}
					flow 'amplify signal'.amplifiedVoltage to 'filter noise'.amplifiedVoltage;

					action 'filter noise' : 'Filter Noise' {
						in amplifiedVoltage : AmplifiedVoltage;
						out filteredVoltage : FilteredVoltage;
					}
					flow 'filter noise'.filteredVoltage to 'convert analog to digital'.filteredVoltage;

					action 'convert analog to digital' : 'Convert Analog to Digital' {
						in filteredVoltage : FilteredVoltage;
						out digitalValue : DigitalValue;
					}
					flow 'convert analog to digital'.digitalValue to 'process and compensate'.digitalValue;

					action 'process and compensate' : 'Process and Compensate' {
						in digitalValue : DigitalValue;
						in temperatureReading = 'measure magnetic field'::temperatureReading;
						in calibration = 'measure magnetic field'::calibration;
						out correctedMagneticField : CorrectedMagneticField;
					}
					flow 'process and compensate'.correctedMagneticField to 'display reading'.correctedMagneticField;

					action 'display reading' : 'Display Reading' {
						in correctedMagneticField : CorrectedMagneticField;
					}
				}
			}
		}

		satisfy measurementRange by magnetometer;
		satisfy highAccuracy by magnetometer;
		satisfy temperatureCompensation by magnetometer;
		satisfy noiseFiltering by magnetometer;
		satisfy continuousOperation by magnetometer;
	}
}
