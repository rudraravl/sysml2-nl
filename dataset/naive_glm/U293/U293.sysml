package MediastinoscopeSystem {
	import ScalarValues::*;
	import SI::*;

	// ---------- Value Types ----------
	value def IlluminanceValue :> Real { unit "lx"; }
	value def PowerValue :> Real { unit "W"; }
	value def VoltageValue :> Real { unit "V"; }
	value def LengthValue :> Real { unit "mm"; }
	value def DiameterValue :> Real { unit "mm"; }
	value def TemperatureValue :> Real { unit "K"; }
	value def FrequencyValue :> Real { unit "Hz"; }
	value def ResolutionValue :> Real { unit "px"; }
	value def MassValue :> Real { unit "g"; }
	value def DurationValue :> Real { unit "s"; }

	// ---------- Items ----------
	item def VideoFrame {
		attribute width : ResolutionValue;
		attribute height : ResolutionValue;
		attribute frameRate : FrequencyValue;
	}
	item def LightBeam {
		attribute illuminance : IlluminanceValue;
		attribute colorTemp : TemperatureValue;
	}
	item def TissueSample {
		attribute mass : MassValue;
		attribute source : String;
	}
	item def ControlCommand {
		attribute commandType : String;
		attribute timestamp : DurationValue;
	}
	item def PowerSignal {
		attribute voltage : VoltageValue;
		attribute active : Boolean;
	}

	// ---------- Port Definitions ----------
	port def VideoOutPort { out videoFrame : VideoFrame; }
	port def VideoInPort { in videoFrame : VideoFrame; }
	port def LightOutPort { out light : LightBeam; }
	port def LightInPort { in light : LightBeam; }
	port def PowerOutPort { out power : PowerSignal; }
	port def PowerInPort { in power : PowerSignal; }
	port def ControlOutPort { out command : ControlCommand; }
	port def ControlInPort { in command : ControlCommand; }
	port def BiopsySamplePort { out sample : TissueSample; }
	port def BiopsyChannelPort { in sample : TissueSample; }

	// ---------- Requirements ----------
	requirement def RigidMediastinoscopeRequirement {
		doc "A medical device for minimally invasive diagnostic procedures inside the chest cavity.";
		subject scope : Mediastinoscope;
		objective {
			doc "Allow a surgeon to visually examine the mediastinum and take tissue samples for analysis.";
		}
	}

	requirement def IlluminationRequirement {
		doc "The light source shall provide high-intensity, daylight-colored illumination of the surgical area.";
		attribute minIlluminance : IlluminanceValue = 50000;
		attribute targetColorTemp : TemperatureValue = 5600;
		satisfy by lightSource : LightSource;
	}

	requirement def VideoQualityRequirement {
		doc "The video processor shall enhance raw video to high-definition quality in real time.";
		attribute minResolution : ResolutionValue = 1080;
		attribute minFrameRate : FrequencyValue = 30;
		satisfy by videoProcessor : VideoProcessor;
	}

	requirement def BiopsyRequirement {
		doc "The biopsy instrument shall precisely collect tissue samples through a channel in the insertion tube.";
		attribute channelDiameter : DiameterValue = 5.0;
		attribute maxSampleMass : MassValue = 0.5;
		satisfy by biopsyInstrument : BiopsyInstrument;
	}

	requirement def InsertionTubeRequirement {
		doc "The insertion tube shall be rigid and sized for mediastinal access.";
		attribute outerDiameter : DiameterValue = 12.0;
		attribute length : LengthValue = 200.0;
		satisfy by insertionTube : InsertionTube;
	}

	requirement def WorkflowRequirement {
		doc "The system shall support the full examination workflow.";
		satisfy by scope : Mediastinoscope;
	}

	// ---------- Part Definitions ----------
	part def LightSource {
		attribute ratedPower : PowerValue = 50.0;
		attribute colorTemp : TemperatureValue = 5600.0;
		attribute illuminance : IlluminanceValue = 60000.0;
		port powerIn : PowerInPort;
		port lightOut : LightOutPort;
		port controlIn : ControlInPort;

		state def LightSourceStates {
			initial off;
			state warmingUp;
			state on;
			state fault;
			transition off to warmingUp when powerIn.power.active;
			transition warmingUp to on when warmupComplete;
			transition on to off when powerOff;
			transition on to fault when overtemp;
			transition fault to off when reset;
		}

		action def GenerateLight {
			in power : PowerSignal;
			out light : LightBeam;
		}
	}

	part def OpticalSystem {
		attribute focalLength : LengthValue = 30.0;
		attribute fieldOfView : Real = 90.0;
		port lightIn : LightInPort;
		port videoOut : VideoOutPort;

		action def CaptureVideo {
			in light : LightBeam;
			out frame : VideoFrame;
		}
	}

	part def InsertionTube {
		attribute outerDiameter : DiameterValue = 12.0;
		attribute length : LengthValue = 200.0;
		attribute material : String = "Surgical stainless steel";
		port distalLight : LightOutPort;
		port distalVideoIn : VideoInPort;
		port biopsyChannel : BiopsyChannelPort;

		action def InsertScope {
			in target : String;
			out position : LengthValue;
		}
	}

	part def VideoProcessor {
		attribute outputResolution : ResolutionValue = 1080;
		attribute outputFrameRate : FrequencyValue = 60.0;
		attribute latency : DurationValue = 0.03;
		port videoIn : VideoInPort;
		port videoOut : VideoOutPort;
		port powerIn : PowerInPort;

		action def EnhanceVideo {
			in rawFrame : VideoFrame;
			out hdFrame : VideoFrame;
		}
	}

	part def ControlConsole {
		attribute displaySize : Real = 24.0;
		port displayIn : VideoInPort;
		port controlOut : ControlOutPort;
		port powerOut : PowerOutPort;

		state def ConsoleStates {
			initial standby;
			state active;
			state shutdown;
			transition standby to active when powerOn;
			transition active to standby when powerOff;
			transition active to shutdown when shutdownRequested;
			transition shutdown to standby when reset;
		}

		action def DisplayVideo {
			in frame : VideoFrame;
		}
		action def IssueCommand {
			out command : ControlCommand;
		}
	}

	part def BiopsyInstrument {
		attribute channelDiameter : DiameterValue = 5.0;
		attribute maxSampleMass : MassValue = 0.5;
		port sampleOut : BiopsySamplePort;
		port controlIn : ControlInPort;

		state def BiopsyStates {
			initial idle;
			state armed;
			state extending;
			state collecting;
			state retracting;
			transition idle to armed when arm;
			transition armed to extending when extend;
			transition extending to collecting when atTarget;
			transition collecting to retracting when sampleAcquired;
			transition retracting to idle when home;
		}

		action def CollectSample {
			in command : ControlCommand;
			out sample : TissueSample;
		}
	}

	// ---------- Top-level System ----------
	part def Mediastinoscope {
		part insertionTube : InsertionTube;
		part opticalSystem : OpticalSystem;
		part lightSource : LightSource;
		part videoProcessor : VideoProcessor;
		part controlConsole : ControlConsole;
		part biopsyInstrument : BiopsyInstrument;

		satisfy RigidMediastinoscopeRequirement;
		satisfy WorkflowRequirement;

		// Internal connections
		connection powerToLight from controlConsole.powerOut to lightSource.powerIn;
		connection powerToProcessor from controlConsole.powerOut to videoProcessor.powerIn;
		connection lightToOptical from lightSource.lightOut to opticalSystem.lightIn;
		connection opticalToTube from opticalSystem.videoOut to insertionTube.distalVideoIn;
		connection tubeToProcessor from insertionTube.distalVideoIn to videoProcessor.videoIn;
		connection processorToConsole from videoProcessor.videoOut to controlConsole.displayIn;
		connection controlToLight from controlConsole.controlOut to lightSource.controlIn;
		connection controlToBiopsy from controlConsole.controlOut to biopsyInstrument.controlIn;
		connection biopsyToTube from biopsyInstrument.sampleOut to insertionTube.biopsyChannel;

		// System-level state machine
		state def SystemStates {
			initial poweredOff;
			state poweringOn;
			state standby;
			state inserting;
			state examining;
			state performingBiopsy;
			state withdrawing;
			state poweringOff;

			transition poweredOff to poweringOn when powerButtonPressed;
			transition poweringOn to standby when systemReady;
			transition standby to inserting when startProcedure;
			transition inserting to examining when scopeInPosition;
			transition examining to performingBiopsy when biopsyRequested;
			transition performingBiopsy to examining when biopsyComplete;
			transition examining to withdrawing when procedureComplete;
			transition withdrawing to standby when scopeWithdrawn;
			transition standby to poweringOff when shutdownRequested;
			transition poweringOff to poweredOff when powerRemoved;
		}

		// System-level workflow action
		action def ExaminationWorkflow {
			in patient : String;
			out samples : TissueSample[*];

			action powerOn;
			action insertScope {
				out position : LengthValue;
			}
			action examine {
				in position : LengthValue;
				out frames : VideoFrame[*];
			}
			action performBiopsy {
				out sample : TissueSample;
			}
			action withdrawScope;
			action powerOff;

			sequence {
				powerOn then insertScope;
				insertScope then examine;
				examine then performBiopsy;
				performBiopsy then withdrawScope;
				withdrawScope then powerOff;
			}
		}
	}
}
