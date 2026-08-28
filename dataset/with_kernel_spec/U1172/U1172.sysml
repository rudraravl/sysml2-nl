package QuantumDotPhotonEmissionSystem {
	private import ISQ::*;
	private import ScalarValues::*;

	attribute def Wavelength :> ISQ::LengthValue;
	attribute def Intensity :> Real;
	attribute def SpectralPurity :> Real;

	item def Photon {
		attribute wavelength : Wavelength;
	}
	item def UVPhoton :> Photon {
		attribute redefines wavelength = 405e-9 [m];
	}
	item def GreenPhoton :> Photon {
		attribute redefines wavelength = 530e-9 [m];
	}
	item def MeasurementData {
		attribute wavelength : Wavelength;
		attribute intensity : Intensity;
		attribute spectralPurity : SpectralPurity;
	}
	item def ThermalSignal {
		attribute temperature : ISQ::TemperatureValue;
	}

	port def OpticalOut {
		out item photon : Photon;
	}
	port def OpticalIn {
		in item photon : Photon;
	}
	port def ThermalOut {
		out item signal : ThermalSignal;
	}
	port def ThermalIn {
		in item signal : ThermalSignal;
	}

	part def ExcitationSource {
		port uvOutput : OpticalOut;
		action def EmitUV {
			out photon : UVPhoton;
		}
		action emit : EmitUV {
			out photon = uvOutput.photon;
		}
	}

	part def QuantumDot {
		attribute material : String = "Cadmium Selenide";
		attribute size : ISQ::LengthValue = 5e-9 [m];
		port uvInput : OpticalIn;
		port greenOutput : OpticalOut;
		port thermalInput : ThermalIn;
		attribute operatingTemp : ISQ::TemperatureValue = 298.15 [K];

		action def AbsorbAndEmit {
			in uvPhoton : UVPhoton;
			out greenPhoton : GreenPhoton;
		}
		action absorbAndEmit : AbsorbAndEmit {
			in uvPhoton = uvInput.photon;
			out greenPhoton = greenOutput.photon;
		}
	}

	part def OpticalFilter {
		port mixedInput : OpticalIn;
		port greenOutput : OpticalOut;
		attribute cutoffWavelength : Wavelength = 500e-9 [m];

		action def FilterLight {
			in mixedPhoton : Photon;
			out greenPhoton : GreenPhoton;
		}
		action filterLight : FilterLight {
			in mixedPhoton = mixedInput.photon;
			out greenPhoton = greenOutput.photon;
		}
	}

	part def PhotoDetector {
		port greenInput : OpticalIn;
		attribute measuredWavelength : Wavelength;
		attribute measuredIntensity : Intensity;
		attribute measuredPurity : SpectralPurity;

		action def Measure {
			in greenPhoton : GreenPhoton;
			out wavelength : Wavelength;
			out intensity : Intensity;
			out purity : SpectralPurity;
		}
		action measure : Measure {
			in greenPhoton = greenInput.photon;
			out wavelength = measuredWavelength;
			out intensity = measuredIntensity;
			out purity = measuredPurity;
		}
	}

	part def TemperatureController {
		attribute targetTemp : ISQ::TemperatureValue = 298.15 [K];
		port tempOutput : ThermalOut;
	}

	part def System {
		part excitationSource : ExcitationSource;
		part quantumDot : QuantumDot;
		part opticalFilter : OpticalFilter;
		part photoDetector : PhotoDetector;
		part tempController : TemperatureController;

		connect excitationSource.uvOutput to quantumDot.uvInput;
		connect quantumDot.greenOutput to opticalFilter.mixedInput;
		connect opticalFilter.greenOutput to photoDetector.greenInput;
		connect tempController.tempOutput to quantumDot.thermalInput;

		flow excitationSource.uvOutput.photon to quantumDot.uvInput.photon;
		flow quantumDot.greenOutput.photon to opticalFilter.mixedInput.photon;
		flow opticalFilter.greenOutput.photon to photoDetector.greenInput.photon;
		flow tempController.tempOutput.signal to quantumDot.thermalInput.signal;

		action generateGreenLight {
			action emit : ExcitationSource::EmitUV {
				out photon = excitationSource.uvOutput.photon;
			}
			action absorbAndEmit : QuantumDot::AbsorbAndEmit {
				in uvPhoton = quantumDot.uvInput.photon;
				out greenPhoton = quantumDot.greenOutput.photon;
			}
			action filterLight : OpticalFilter::FilterLight {
				in mixedPhoton = opticalFilter.mixedInput.photon;
				out greenPhoton = opticalFilter.greenOutput.photon;
			}
			action measure : PhotoDetector::Measure {
				in greenPhoton = photoDetector.greenInput.photon;
				out wavelength = photoDetector.measuredWavelength;
				out intensity = photoDetector.measuredIntensity;
				out purity = photoDetector.measuredPurity;
			}
			first emit;
			then absorbAndEmit;
			then filterLight;
			then measure;
		}
	}

	requirement def GreenEmissionRequirement {
		doc /* The quantum dot shall emit green light with peak wavelength 530 nm. */
		attribute peakWavelength : Wavelength = 530e-9 [m];
	}
	requirement def TemperatureStabilityRequirement {
		doc /* The quantum dot temperature shall be maintained at 25 degrees Celsius. */
		attribute setPoint : ISQ::TemperatureValue = 298.15 [K];
	}
	requirement def FilteringRequirement {
		doc /* The optical filter shall block UV light and transmit green light. */
		attribute cutoffWavelength : Wavelength = 500e-9 [m];
	}
	requirement def MeasurementRequirement {
		doc /* The photodetector shall measure wavelength, intensity, and spectral purity. */
	}

	requirement greenEmissionReq : GreenEmissionRequirement;
	requirement tempStabilityReq : TemperatureStabilityRequirement;
	requirement filteringReq : FilteringRequirement;
	requirement measurementReq : MeasurementRequirement;

	part systemUsage : System {
		satisfy greenEmissionReq by quantumDot;
		satisfy tempStabilityReq by tempController;
		satisfy filteringReq by opticalFilter;
		satisfy measurementReq by photoDetector;
	}
}
