package 'Digital Holography System' {
	private import ScalarValues::*;
	
	item def CoherentBeam;
	item def ObjectBeam;
	item def ReferenceBeam;
	item def ObjectWavefront;
	item def ReferenceWavefront;
	item def InterferencePattern;
	item def HologramData;
	item def Reconstructed3DImage;
	
	attribute def DepthResolution :> Real;
	
	port def BeamPort {
		out beam : CoherentBeam;
	}
	port def ObjectBeamPort {
		out objectBeam : ObjectBeam;
	}
	port def ReferenceBeamPort {
		out referenceBeam : ReferenceBeam;
	}
	port def ObjectWavefrontPort {
		out objectWavefront : ObjectWavefront;
	}
	port def ReferenceWavefrontPort {
		out referenceWavefront : ReferenceWavefront;
	}
	port def DataPort {
		out hologramData : HologramData;
	}
	port def ImagePort {
		out image : Reconstructed3DImage;
	}
	
	action def GenerateBeam {
		out beam : CoherentBeam;
	}
	action def SplitBeam {
		in beam : CoherentBeam;
		out objectBeam : ObjectBeam;
		out referenceBeam : ReferenceBeam;
	}
	action def IlluminateObject {
		in objectBeam : ObjectBeam;
		out objectWavefront : ObjectWavefront;
	}
	action def ReflectReference {
		in referenceBeam : ReferenceBeam;
		out referenceWavefront : ReferenceWavefront;
	}
	action def RecordInterference {
		in objectWavefront : ObjectWavefront;
		in referenceWavefront : ReferenceWavefront;
		out interferencePattern : InterferencePattern;
		out hologramData : HologramData;
	}
	action def ReconstructImage {
		in hologramData : HologramData;
		out image : Reconstructed3DImage;
	}
	action def CaptureHologram {
		out image : Reconstructed3DImage;
	}
	
	requirement def HighDepthResolution {
		/* The system shall achieve depth resolution capable of distinguishing features smaller than a micrometer. */
		subject depthResolution : DepthResolution;
		constraint { depthResolution <= 1e-6 }
	}
	
	part def LaserSource {
		port beamPort : BeamPort;
	}
	part def BeamSplitter {
		port beamPort : ~BeamPort;
		port objectBeamPort : ObjectBeamPort;
		port referenceBeamPort : ReferenceBeamPort;
	}
	part def TargetObject {
		port objectBeamPort : ~ObjectBeamPort;
		port objectWavefrontPort : ObjectWavefrontPort;
	}
	part def Mirror {
		port referenceBeamPort : ~ReferenceBeamPort;
		port referenceWavefrontPort : ReferenceWavefrontPort;
	}
	part def InterferenceRecorder {
		port objectWavefrontPort : ~ObjectWavefrontPort;
		port referenceWavefrontPort : ~ReferenceWavefrontPort;
		port dataPort : DataPort;
	}
	part def NumericalReconstructor {
		port dataPort : ~DataPort;
		port imagePort : ImagePort;
	}
	
	part context {
		part laserSource : LaserSource;
		part beamSplitter : BeamSplitter;
		part targetObject : TargetObject;
		part mirror : Mirror;
		part interferenceRecorder : InterferenceRecorder;
		part numericalReconstructor : NumericalReconstructor;
		
		interface laserToSplitter connect laserSource.beamPort to beamSplitter.beamPort;
		interface splitterToObject connect beamSplitter.objectBeamPort to targetObject.objectBeamPort;
		interface splitterToMirror connect beamSplitter.referenceBeamPort to mirror.referenceBeamPort;
		interface objectToRecorder connect targetObject.objectWavefrontPort to interferenceRecorder.objectWavefrontPort;
		interface mirrorToRecorder connect mirror.referenceWavefrontPort to interferenceRecorder.referenceWavefrontPort;
		interface recorderToReconstructor connect interferenceRecorder.dataPort to numericalReconstructor.dataPort;
		
		requirement highDepthResolution : HighDepthResolution {
			depthResolution = 0.5e-6;
		}
		satisfy highDepthResolution by numericalReconstructor;
	}
	
	action captureHologram : CaptureHologram {
		out image : Reconstructed3DImage;
		
		action generateBeam : GenerateBeam {
			out beam;
		}
		flow beamFlow from generateBeam.beam to splitBeam.beam;
		
		action splitBeam : SplitBeam {
			in beam;
			out objectBeam;
			out referenceBeam;
		}
		flow objectBeamFlow from splitBeam.objectBeam to illuminateObject.objectBeam;
		flow referenceBeamFlow from splitBeam.referenceBeam to reflectReference.referenceBeam;
		
		action illuminateObject : IlluminateObject {
			in objectBeam;
			out objectWavefront;
		}
		flow objectWavefrontFlow from illuminateObject.objectWavefront to recordInterference.objectWavefront;
		
		action reflectReference : ReflectReference {
			in referenceBeam;
			out referenceWavefront;
		}
		flow referenceWavefrontFlow from reflectReference.referenceWavefront to recordInterference.referenceWavefront;
		
		action recordInterference : RecordInterference {
			in objectWavefront;
			in referenceWavefront;
			out hologramData;
		}
		flow dataFlow from recordInterference.hologramData to reconstructImage.hologramData;
		
		action reconstructImage : ReconstructImage {
			in hologramData;
			out image;
		}
		
		first start;
		then generateBeam;
		then splitBeam;
		then fork parallelPaths;
		then illuminateObject;
		then reflectReference;
		first illuminateObject then recordReady;
		first reflectReference then recordReady;
		join recordReady;
		then recordInterference;
		then reconstructImage;
		then done;
	}
}
