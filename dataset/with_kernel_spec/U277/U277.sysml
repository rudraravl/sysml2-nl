package 'Medical Video Laryngoscopy System' {
	private import SI::*;
	private import ScalarValues::*;

	doc /* Medical video laryngoscopy system for airway visualization and tracheal intubation. */

	item def Airway;
	item def VocalCords;
	item def Epiglottis;
	item def Larynx;
	item def AnatomicalView;
	item def IlluminatedScene;
	item def VideoFrame;
	item def VideoSignal;
	item def PowerSignal;
	item def LightEmission;

	port def PowerOutPort {
		out item power : PowerSignal;
	}
	port def PowerInPort {
		in item power : PowerSignal;
	}
	port def VideoOutPort {
		out item video : VideoSignal;
	}
	port def VideoInPort {
		in item video : VideoSignal;
	}

	part def BatteryPack {
		attribute capacity : Real = 2.0 [SI::h];
		attribute chargeLevel : Real;
		out item powerOutput : PowerSignal;
	}

	part def PowerRegulator {
		in item rawPower : PowerSignal;
		out item regulatedPower : PowerSignal;
		attribute outputVoltage : Real = 5.0 [SI::V];
	}

	part def HandleUnit {
		attribute minContinuousOperatingTime : Real = 2.0 [SI::h];
		part battery : BatteryPack;
		part regulator : PowerRegulator;
		port powerOutput : PowerOutPort;
		port videoOutput : VideoOutPort;
		flow battery.powerOutput to regulator.rawPower;
		flow regulator.regulatedPower to powerOutput.power;
	}

	part def LightingModule {
		in item powerIn : PowerSignal;
		out item illumination : LightEmission;
		attribute intensity : Real = 500.0 [SI::cd];
		attribute colorTemp : Real = 5500.0 [SI::K];
		attribute maxSurfaceTemp : Real = 318.15 [SI::K];
	}

	part def LensAssembly {
		in item scene : IlluminatedScene;
		out item opticalImage : AnatomicalView;
		attribute focalLength : Real = 5.0 [SI::mm];
		attribute viewingAngle : Real = 90.0;
	}

	part def ImageProcessor {
		in item opticalImage : AnatomicalView;
		out item videoFrame : VideoFrame;
		attribute resolutionWidth : Integer = 1920;
		attribute resolutionHeight : Integer = 1080;
	}

	part def OpticalChannel {
		in item powerIn : PowerSignal;
		in item scene : IlluminatedScene;
		out item videoOut : VideoSignal;
		part lens : LensAssembly;
		part processor : ImageProcessor;
		flow scene to lens.scene;
		flow lens.opticalImage to processor.opticalImage;
	}

	part def BladeAssembly {
		attribute bladeLength : Real = 150.0 [SI::mm];
		attribute curvature : Real;
		attribute maxTissueForce : Real = 30.0 [SI::N];
		in item powerIn : PowerSignal;
		out item videoOut : VideoSignal;
		part lighting : LightingModule;
		part camera : OpticalChannel;
		flow powerIn to lighting.powerIn;
		flow powerIn to camera.powerIn;
		flow camera.videoOut to videoOut;
	}

	part def HandheldLaryngoscope {
		part handle : HandleUnit;
		part blade : BladeAssembly;
		flow handle.powerOutput.power to blade.powerIn;
		flow blade.videoOut to handle.videoOutput.video;
	}

	part def VideoDisplay {
		port videoInput : VideoInPort;
		attribute screenSize : Real = 200.0 [SI::mm];
	}

	part def Patient {
		item airway : Airway;
		item vocalCords : VocalCords;
		item epiglottis : Epiglottis;
		item larynx : Larynx;
	}

	part def VideoLaryngoscopySystem {
		part laryngoscope : HandheldLaryngoscope;
		part display : VideoDisplay;
		ref part patient : Patient;
		flow laryngoscope.handle.videoOutput.video to display.videoInput.video;
	}

	action def CheckBattery {
		in attribute chargeLevel : Real;
		out attribute sufficient : Boolean;
	}

	action def InsertBlade {
		in ref item targetAirway : Airway;
		out item airwayView : Airway;
	}

	action def IlluminateAirway {
		in item airway : Airway;
		out item illuminatedScene : IlluminatedScene;
	}

	action def CaptureVideo {
		in item scene : IlluminatedScene;
		out item video : VideoSignal;
	}

	action def DisplayVideo {
		in item video : VideoSignal;
	}

	action def AssessAnatomy {
		in item video : VideoSignal;
	}

	action def DocumentFindings;

	action def WithdrawBlade;

	action def LaryngoscopyProcedure {
		first start;
		then action checkBattery : CheckBattery {
			out attribute sufficient;
		}
		then action insertBlade : InsertBlade {
			out item airwayView;
		}
		then action illuminate : IlluminateAirway {
			in item airway = insertBlade.airwayView;
			out item illuminatedScene;
		}
		then action capture : CaptureVideo {
			in item scene = illuminate.illuminatedScene;
			out item video;
		}
		flow from capture.video to display.video;
		then action display : DisplayVideo {
			in item video;
		}
		then action assess : AssessAnatomy {
			in item video = capture.video;
		}
		then action document : DocumentFindings;
		then action withdraw : WithdrawBlade;
	}

	state def SystemOperation {
		initial state preparation;
		state insertion;
		state visualization;
		state documentation;
		state withdrawal;
		final state complete;
		transition from preparation to insertion;
		transition from insertion to visualization;
		transition from visualization to documentation;
		transition from documentation to withdrawal;
		transition from withdrawal to complete;
	}

	requirement def BatteryLifeRequirement {
		subject battery : BatteryPack;
		doc /* The battery shall provide at least 2 hours of continuous operation. */
	}

	requirement def ForceLimitRequirement {
		subject blade : BladeAssembly;
		doc /* Force applied to patient tissue shall not exceed 30 N. */
	}

	requirement def ThermalSafetyRequirement {
		subject lighting : LightingModule;
		doc /* Light source surface temperature shall not exceed 45 degrees Celsius. */
	}

	requirement def SterilizationRequirement {
		subject blade : BladeAssembly;
		doc /* All patient-contact components shall be sterilizable between uses. */
	}

	requirement def ResolutionRequirement {
		subject processor : ImageProcessor;
		doc /* Video shall be captured at 1920x1080 resolution. */
	}

	requirement def ViewingAngleRequirement {
		subject lens : LensAssembly;
		doc /* Camera shall provide a wide viewing angle for airway visualization. */
	}

	part videoLaryngoscopySystem : VideoLaryngoscopySystem {
		perform procedure : LaryngoscopyProcedure;
		perform operation : SystemOperation;
	}
}
