package ToFCameraSystem {
	private import ISQ::*;
	private import ScalarValues::Natural;

	item def Scene;
	item def LightPulse;
	item def Reflection;
	item def DepthMap {
		attribute width : Natural = 640;
		attribute height : Natural = 480;
		attribute distances : ISQ::length[*];
	}
	item def CaptureCommand;

	calc def DistanceCalculation {
		in timeOfFlight : ISQ::time;
		return distance : ISQ::length = (timeOfFlight * 299792458 [m/s]) / 2;
	}

	action def EmitPulse {
		out item pulse : LightPulse;
	}
	action def CollectLight {
		in item reflection : Reflection;
		out item focusedLight : Reflection;
	}
	action def DetectLight {
		in item focusedLight : Reflection;
		out item detectedLight : Reflection;
	}
	action def MeasureTimeOfFlight {
		in item pulse : LightPulse;
		in item detectedLight : Reflection;
		out item timeOfFlight : ISQ::time;
	}
	action def CalculateDistance {
		in item timeOfFlight : ISQ::time;
		out item distance : ISQ::length;
	}
	action def AssembleDepthMap {
		in item distances : ISQ::length[*];
		out item depthMap : DepthMap;
	}

	action def CaptureFrame {
		in item scene : Scene;
		out item depthMap : DepthMap;

		action emit : EmitPulse {
			out item pulse;
		}
		flow from emit.pulse to measure.pulse;
		action collect : CollectLight {
			in item reflection;
			out item focusedLight;
		}
		flow from collect.focusedLight to detect.focusedLight;
		action detect : DetectLight {
			in item focusedLight;
			out item detectedLight;
		}
		flow from detect.detectedLight to measure.detectedLight;
		action measure : MeasureTimeOfFlight {
			in item pulse;
			in item detectedLight;
			out item timeOfFlight;
		}
		flow from measure.timeOfFlight to calculate.timeOfFlight;
		action calculate : CalculateDistance {
			in item timeOfFlight;
			out item distance;
		}
		flow from calculate.distance to assemble.distances;
		action assemble : AssembleDepthMap {
			in item distances;
			out item depthMap = CaptureFrame::depthMap;
		}
	}

	port def PowerPort {
		in item power : ISQ::power;
	}
	port def CommandPort {
		in item command : CaptureCommand;
	}
	port def DataPort {
		out item depthMap : DepthMap;
	}

	part def LaserEmitter {
		out item pulse : LightPulse;
	}
	part def OpticalSystem {
		in item reflection : Reflection;
		out item focusedLight : Reflection;
	}
	part def PhotodetectorArray {
		in item focusedLight : Reflection;
		out item detectedLight : Reflection;
		attribute width : Natural = 640;
		attribute height : Natural = 480;
	}
	part def TimingCircuit {
		in item pulse : LightPulse;
		in item detectedLight : Reflection;
		out item timeOfFlight : ISQ::time;
	}
	part def DepthProcessor {
		in item timeOfFlight : ISQ::time;
		out item depthMap : DepthMap;
		attribute speedOfLight : ISQ::speed = 299792458 [m/s];
	}

	part def ToFCamera {
		port powerIn : PowerPort;
		port commandIn : CommandPort;
		port dataOut : DataPort;

		ref item scene : Scene;

		part laserEmitter : LaserEmitter;
		part opticalSystem : OpticalSystem;
		part photodetectorArray : PhotodetectorArray;
		part timingCircuit : TimingCircuit;
		part depthProcessor : DepthProcessor;

		flow laserEmitter.pulse to timingCircuit.pulse;
		flow opticalSystem.focusedLight to photodetectorArray.focusedLight;
		flow photodetectorArray.detectedLight to timingCircuit.detectedLight;
		flow timingCircuit.timeOfFlight to depthProcessor.timeOfFlight;
		flow depthProcessor.depthMap to dataOut.depthMap;

		perform action capture[*] ordered references CaptureFrame;

		state CameraControl {
			state Idle;
			state Capturing;
			transition from Idle to Capturing accept command : CaptureCommand via commandIn;
			transition from Capturing to Idle after 33.33 [ms];
		}
	}

	requirement def ResolutionRequirement {
		attribute width : Natural = 640;
		attribute height : Natural = 480;
	}
	requirement def RangeRequirement {
		attribute minRange : ISQ::length = 0.1 [m];
		attribute maxRange : ISQ::length = 10 [m];
	}
	requirement def AccuracyRequirement {
		attribute maxDepthError : ISQ::length = 0.01 [m];
	}
	requirement def FrameRateRequirement {
		attribute minFrameRate : ISQ::frequency = 30 [Hz];
	}

	part camera : ToFCamera {
		satisfy resolutionRequirement : ResolutionRequirement;
		satisfy rangeRequirement : RangeRequirement;
		satisfy accuracyRequirement : AccuracyRequirement;
		satisfy frameRateRequirement : FrameRateRequirement;
	}
}
