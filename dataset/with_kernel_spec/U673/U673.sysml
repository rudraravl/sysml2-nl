package FBGSensingSystem {
	private import ScalarValues::Real;
	private import ISQ::length;
	private import ISQ::Temperature;
	private import SI::*;

	attribute def WavelengthValue :> length;
	attribute def TemperatureValue :> Temperature;

	item def LightSpectrum;
	item def ReflectedLight :> LightSpectrum;

	item def WavelengthData {
		attribute value : WavelengthValue;
	}

	item def MeasurementData {
		attribute strain : Real;
		attribute temperature : TemperatureValue;
	}

	port def OpticalPort {
		out item light : LightSpectrum;
	}

	port def BidirectionalOpticalPort {
		out item forwardLight : LightSpectrum;
		in item reflectedLight : ReflectedLight;
	}

	port def DataOutPort {
		out item wavelength : WavelengthData;
	}

	port def DataInPort {
		in item wavelength : WavelengthData;
	}

	port def MeasurementOutPort {
		out item measurement : MeasurementData;
	}

	part def BroadbandLightSource {
		port lightOutPort : OpticalPort;
		attribute outputPower : Real;
	}

	part def OpticalCirculator {
		port sourcePort : ~OpticalPort;
		port sensorPort : BidirectionalOpticalPort;
		port analyzerPort : OpticalPort;
	}

	part def FBG {
		port lightPort : ~BidirectionalOpticalPort;
		attribute braggWavelength : WavelengthValue;
		attribute appliedStrain : Real;
		attribute appliedTemperature : TemperatureValue;
		attribute reflectedWavelength : WavelengthValue;
	}

	part def OpticalSpectrumAnalyzer {
		port lightInPort : ~OpticalPort;
		port dataOutPort : DataOutPort;
		attribute measuredWavelength : WavelengthValue;
	}

	part def SignalProcessingUnit {
		port dataInPort : DataInPort;
		port measurementOutPort : MeasurementOutPort;
		attribute calculatedStrain : Real;
		attribute calculatedTemperature : TemperatureValue;
	}

	action def EmitLight {
		out light : LightSpectrum;
	}

	action def RouteLightToSensor {
		in light : LightSpectrum;
		out routedLight : LightSpectrum;
	}

	action def ReflectLight {
		in light : LightSpectrum;
		out reflectedLight : ReflectedLight;
	}

	action def RouteLightToAnalyzer {
		in light : ReflectedLight;
		out routedLight : ReflectedLight;
	}

	action def MeasureWavelength {
		in light : ReflectedLight;
		out wavelength : WavelengthData;
	}

	action def ProcessSignal {
		in wavelength : WavelengthData;
		out measurement : MeasurementData;
	}

	state def FBGOperationState {
		entry; then Standby;
		state Standby;
		state SensingCycle {
			state Emitting;
			state Reflecting;
			state Analyzing;
			state Processing;
			transition t2 first Emitting then Reflecting;
			transition t3 first Reflecting then Analyzing;
			transition t4 first Analyzing then Processing;
		}
		transition t1 first Standby then SensingCycle;
		transition t5 first SensingCycle.Processing then Standby;
	}

	requirement def MeasurementAccuracy {
		subject sensingUnit : SignalProcessingUnit;
		attribute maxStrainError : Real;
		attribute maxTempError : TemperatureValue;
		attribute actualStrainError : Real;
		attribute actualTempError : TemperatureValue;
		doc /* The system shall measure strain and temperature within specified error limits. */
		require constraint { actualStrainError <= maxStrainError and actualTempError <= maxTempError }
	}

	part sensingSystem {
		part lightSource : BroadbandLightSource {
			perform action emitLight : EmitLight {
				out light = lightOutPort.light;
			}
		}

		part circulator : OpticalCirculator {
			perform action routeLightToSensor : RouteLightToSensor {
				in light = sourcePort.light;
				out routedLight = sensorPort.forwardLight;
			}
			perform action routeLightToAnalyzer : RouteLightToAnalyzer {
				in light = sensorPort.reflectedLight;
				out routedLight = analyzerPort.light;
			}
		}

		part fbgSensor : FBG {
			perform action reflectLight : ReflectLight {
				in light = lightPort.forwardLight;
				out reflectedLight = lightPort.reflectedLight;
			}
		}

		part analyzer : OpticalSpectrumAnalyzer {
			perform action measureWavelength : MeasureWavelength {
				in light = lightInPort.light;
				out wavelength = dataOutPort.wavelength;
			}
		}

		part processor : SignalProcessingUnit {
			perform action processSignal : ProcessSignal {
				in wavelength = dataInPort.wavelength;
				out measurement = measurementOutPort.measurement;
			}
		}

		flow of light : LightSpectrum
			from lightSource.lightOutPort.light to circulator.sourcePort.light;

		flow of light : LightSpectrum
			from circulator.sensorPort.forwardLight to fbgSensor.lightPort.forwardLight;

		flow of reflectedLight : ReflectedLight
			from fbgSensor.lightPort.reflectedLight to circulator.sensorPort.reflectedLight;

		flow of reflectedLight : ReflectedLight
			from circulator.analyzerPort.light to analyzer.lightInPort.light;

		flow of wavelength : WavelengthData
			from analyzer.dataOutPort.wavelength to processor.dataInPort.wavelength;

		exhibit FBGOperationState;

		requirement systemAccuracy : MeasurementAccuracy {
			subject :>> sensingUnit = processor;
			:>> maxStrainError = 1.0;
			:>> maxTempError = 0.1 [kelvin];
			:>> actualStrainError = 0.5;
			:>> actualTempError = 0.05 [kelvin];
		}
	}
}
