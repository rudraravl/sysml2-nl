package 'Holographic Sensing Unit' {
	import ScalarValues::*;
	
	value def Wavelength :> Real { unit 'nm'; }
	value def Length :> Real { unit 'um'; }
	
	item def LaserBeam;
	item def ObjectBeam :> LaserBeam;
	item def ReferenceBeam :> LaserBeam;
	item def ReflectedObjectBeam :> ObjectBeam;
	item def InterferencePattern;
	item def RawHologram;
	item def ReconstructedWave;
	item def MeasurementData;
	
	enum def Command { init; capture; reset; }
	enum def Status { idle; initializing; capturing; processing; complete; error; }
	
	port def OpticalPort {
		out beam : LaserBeam;
	}
	port def ReflectedOpticalPort {
		out beam : ReflectedObjectBeam;
	}
	port def PatternPort {
		out pattern : InterferencePattern;
	}
	port def HologramPort {
		out rawHologram : RawHologram;
	}
	port def CommandPort {
		in cmd : Command;
	}
	port def StatusPort {
		out status : Status;
	}
	port def DataPort {
		out data : MeasurementData;
	}
	
	action def GenerateBeam { out beam : LaserBeam; }
	action def SplitBeam { in beam : LaserBeam; out objectBeam : ObjectBeam; out referenceBeam : ReferenceBeam; }
	action def IlluminateObject { in beam : ObjectBeam; out reflectedBeam : ReflectedObjectBeam; }
	action def RecombineBeams { in objectBeam : ReflectedObjectBeam; in referenceBeam : ReferenceBeam; out pattern : InterferencePattern; }
	action def CapturePattern { in pattern : InterferencePattern; out rawHologram : RawHologram; }
	action def ReconstructWave { in rawHologram : RawHologram; out wave : ReconstructedWave; out data : MeasurementData; }
	
	action def CaptureHologram {
		in objectBeam : ObjectBeam;
		in referenceBeam : ReferenceBeam;
		out data : MeasurementData;
		
		action illuminate : IlluminateObject {
			in beam = objectBeam;
			out reflectedBeam;
		}
		action recombine : RecombineBeams {
			in objectBeam = illuminate.reflectedBeam;
			in referenceBeam = referenceBeam;
			out pattern;
		}
		succession flow from recombine.pattern to capture.pattern;
		action capture : CapturePattern {
			in pattern;
			out rawHologram;
		}
		succession flow from capture.rawHologram to reconstruct.rawHologram;
		action reconstruct : ReconstructWave {
			in rawHologram;
			out wave;
			out data;
		}
	}
	
	part def HolographicSensingUnit {
		attribute wavelength : Wavelength = 632.8;
		attribute accuracy : Length = 0.1;
		attribute resolution : Length = 1.0;
		
		port cmdPort : CommandPort;
		port statusPort : StatusPort;
		port dataPort : DataPort;
		
		state machine {
			state idle;
			state initializing;
			state capturing;
			state processing;
			transition from idle to initializing when cmdPort.cmd == Command::init;
			transition from initializing to capturing when cmdPort.cmd == Command::capture;
			transition from capturing to processing when true; 
			transition from processing to idle when true; 
		}
		
		part laserSource {
			port outPort : OpticalPort;
			perform GenerateBeam { out beam = outPort.beam; }
		}
		part beamSplitter {
			port inPort : ~OpticalPort;
			port objOutPort : OpticalPort;
			port refOutPort : OpticalPort;
			perform SplitBeam {
				in beam = inPort.beam;
				out objectBeam = objOutPort.beam;
				out referenceBeam = refOutPort.beam;
			}
		}
		part objectIlluminator {
			port inPort : ~OpticalPort;
			port outPort : ReflectedOpticalPort;
			perform IlluminateObject {
				in beam = inPort.beam;
				out reflectedBeam = outPort.beam;
			}
		}
		part detector {
			port objInPort : ~ReflectedOpticalPort;
			port refInPort : ~OpticalPort;
			port patternOutPort : PatternPort;
			perform RecombineBeams {
				in objectBeam = objInPort.beam;
				in referenceBeam = refInPort.beam;
				out pattern = patternOutPort.pattern;
			}
		}
		part holographicRecorder {
			port inPort : ~PatternPort;
			port outPort : HologramPort;
			perform CapturePattern {
				in pattern = inPort.pattern;
				out rawHologram = outPort.rawHologram;
			}
		}
		part signalProcessor {
			port inPort : ~HologramPort;
			port outPort : DataPort;
			perform ReconstructWave {
				in rawHologram = inPort.rawHologram;
				out data = outPort.data;
			}
		}
		
		flow laserSource.outPort.beam to beamSplitter.inPort.beam;
		flow beamSplitter.objOutPort.beam to objectIlluminator.inPort.beam;
		flow objectIlluminator.outPort.beam to detector.objInPort.beam;
		flow beamSplitter.refOutPort.beam to detector.refInPort.beam;
		flow detector.patternOutPort.pattern to holographicRecorder.inPort.pattern;
		flow holographicRecorder.outPort.rawHologram to signalProcessor.inPort.rawHologram;
		flow signalProcessor.outPort.data to dataPort.data;
	}
	
	requirement def MeasurementAccuracyRequirement {
		subject hsu : HolographicSensingUnit;
		constraint { hsu.accuracy <= 0.1 }
	}
	
	requirement def SpatialResolutionRequirement {
		subject hsu : HolographicSensingUnit;
		constraint { hsu.resolution <= 1.0 }
	}
	
	requirement def LaserWavelengthRequirement {
		subject hsu : HolographicSensingUnit;
		constraint { hsu.wavelength == 632.8 }
	}
}
