package EDS_System {
	public import ScalarValues::*;
	public import ISQ::*;

	attribute def Energy :> ISQ::EnergyValue;
	attribute def Pressure :> ISQ::PressureValue;
	attribute def Length :> ISQ::LengthValue;
	attribute def Count :> ScalarValues::Integer;

	attribute def SetupCommand;
	attribute def StartAcquisition;
	attribute def StopAcquisition;
	attribute def ProcessingComplete;
	attribute def Reset;

	item def ElectronBeam {
		attribute energy : Energy;
	}

	item def XRayPhoton {
		attribute energy : Energy;
	}

	item def EnergySpectrum {
		attribute intensity : Count;
		attribute energy : Energy;
	}

	item def CompositionReport {
		attribute element : ScalarValues::String;
		attribute concentration : ScalarValues::Real;
	}

	port def ElectronOutPort {
		out beam : ElectronBeam;
	}

	port def ElectronInPort {
		in beam : ElectronBeam;
	}

	port def XRayOutPort {
		out photon : XRayPhoton;
	}

	port def XRayInPort {
		in photon : XRayPhoton;
	}

	port def SpectrumOutPort {
		out spectrum : EnergySpectrum;
	}

	port def SpectrumInPort {
		in spectrum : EnergySpectrum;
	}

	port def ReportOutPort {
		out report : CompositionReport;
	}

	part def ElectronGun {
		out port electronOut : ElectronOutPort;
		attribute beamEnergy : Energy;
	}

	part def SampleChamber {
		in port electronIn : ElectronInPort;
		out port xrayOut : XRayOutPort;
		attribute vacuumPressure : Pressure;
	}

	part def SiliconDriftDetector {
		in port xrayIn : XRayInPort;
		out port signalOut : XRayOutPort;
	}

	part def DigitalSignalProcessor {
		in port signalIn : XRayInPort;
		out port spectrumOut : SpectrumOutPort;
	}

	part def AnalysisWorkstation {
		in port spectrumIn : SpectrumInPort;
		out port reportOut : ReportOutPort;
	}

	action def GenerateElectrons {
		out beam : ElectronBeam;
	}

	action def EmitXRays {
		in beam : ElectronBeam;
		out photon : XRayPhoton;
	}

	action def DetectXRays {
		in photon : XRayPhoton;
		out detectedPhoton : XRayPhoton;
	}

	action def ProcessSpectrum {
		in detectedPhoton : XRayPhoton;
		out spectrum : EnergySpectrum;
	}

	action def AnalyzeSpectrum {
		in spectrum : EnergySpectrum;
		out report : CompositionReport;
	}

	state def OperationalState {
		entry; then Standby;
		state Standby;
		state Setup;
		state Acquisition;
		state Processing;
		state Report;
		transition first Standby accept SetupCommand then Setup;
		transition first Setup accept StartAcquisition then Acquisition;
		transition first Acquisition accept StopAcquisition then Processing;
		transition first Processing accept ProcessingComplete then Report;
		transition first Report accept Reset then Standby;
	}

	part def EDS_System {
		part gun : ElectronGun {
			perform action generate : GenerateElectrons {
				out beam = electronOut.beam;
			}
		}
		part chamber : SampleChamber {
			perform action emit : EmitXRays {
				in beam = electronIn.beam;
				out photon = xrayOut.photon;
			}
		}
		part detector : SiliconDriftDetector {
			perform action detect : DetectXRays {
				in photon = xrayIn.photon;
				out detectedPhoton = signalOut.photon;
			}
		}
		part dsp : DigitalSignalProcessor {
			perform action process : ProcessSpectrum {
				in detectedPhoton = signalIn.photon;
				out spectrum = spectrumOut.spectrum;
			}
		}
		part workstation : AnalysisWorkstation {
			perform action analyze : AnalyzeSpectrum {
				in spectrum = spectrumIn.spectrum;
				out report = reportOut.report;
			}
		}

		flow gun.electronOut.beam to chamber.electronIn.beam;
		flow chamber.xrayOut.photon to detector.xrayIn.photon;
		flow detector.signalOut.photon to dsp.signalIn.photon;
		flow dsp.spectrumOut.spectrum to workstation.spectrumIn.spectrum;

		state operationalState : OperationalState;
	}

	requirement def DetermineComposition {
		text "The EDS system shall determine the elemental composition of a material sample.";
	}

	requirement def HighSpatialResolution {
		attribute resolution : Length = 1e-6 [ISQ::m];
		text "The EDS system shall analyze features smaller than 1 micrometer.";
	}

	requirement def ZAFCorrection {
		text "The analysis workstation shall apply ZAF correction methods for quantitative elemental analysis.";
	}

	part edsSystem : EDS_System;

	requirement determineCompositionReq : DetermineComposition {
		subject eds : EDS_System;
	}

	requirement highSpatialResolutionReq : HighSpatialResolution {
		subject eds : EDS_System;
	}

	requirement zafCorrectionReq : ZAFCorrection {
		subject eds : EDS_System;
	}

	satisfy determineCompositionReq by edsSystem;
	satisfy highSpatialResolutionReq by edsSystem;
	satisfy zafCorrectionReq by edsSystem;
}
