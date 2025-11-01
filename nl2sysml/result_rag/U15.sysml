// Define an interface between a smartphone and a smart TV for screen mirroring functionality.
package ScreenMirroringSystem {
	private import SI::*;
	private import ISQ::*;

	// --- Value and Enumeration Definitions ---
	attribute def Resolution {
		attribute width : Integer;
		attribute height : Integer;
	}

	attribute def VideoCodec : Enumeration {
		enum H264;
		enum H265;
		enum VP9;
	}

	attribute def AudioCodec : Enumeration {
		enum AAC;
		enum Opus;
		enum PCM;
	}

	attribute def ControlCommand : Enumeration {
		enum Play;
		enum Pause;
		enum Stop;
		enum RotateLandscape;
		enum RotatePortrait;
	}

	attribute def TVStatus : Enumeration {
		enum Ready;
		enum Buffering;
		enum Connected;
		enum Disconnected;
	}

	// --- Item Definitions for Data Flows ---
	item def VideoStream {
		attribute resolution : Resolution;
		attribute frameRate :> ISQ::frequency;
		attribute codec : VideoCodec;
	}

	item def AudioStream {
		attribute sampleRate :> ISQ::frequency;
		attribute channels : Integer;
		attribute codec : AudioCodec;
	}

	// --- Port Definitions for the Interface ---
	port def ScreenMirroringClientPort {
		doc "Port on the source device (e.g., Smartphone).";
		out item video : VideoStream;
		out item audio : AudioStream;
		out item control : ControlCommand;
		in item status : TVStatus;
	}

	port def ScreenMirroringServerPort {
		doc "Port on the display device (e.g., Smart TV).";
		in item video : VideoStream;
		in item audio : AudioStream;
		in item control : ControlCommand;
		out item status : TVStatus;
	}

	// --- Part Definitions ---
	part def Smartphone {
		port mirrorClient : ScreenMirroringClientPort;

		action startMirroring;
		action stopMirroring;
		action pauseStream;
		action resumeStream;

		state machine MirroringLifecycle {
			initial state Disconnected;
			state Connecting;
			state Connected;
			state Mirroring;
			state Paused;

			transition from Disconnected to Connecting on startMirroring;
			transition from Connecting to Connected;
			transition from Connected to Mirroring;
			transition from Mirroring to Paused on pauseStream;
			transition from Paused to Mirroring on resumeStream;
			transition from Mirroring to Connected on stopMirroring;
			transition from Connected to Disconnected on stopMirroring;
		}
	}

	part def SmartTV {
		port mirrorServer : ScreenMirroringServerPort;

		action displayStream(in stream : VideoStream);
		action playAudio(in stream : AudioStream);
		action processCommand(in command : ControlCommand);
	}

	// --- Interface Definition ---
	interface def ScreenMirroringInterface {
		doc "Defines the connection and data flows for screen mirroring.";
		end phoneEnd : ScreenMirroringClientPort;
		end tvEnd : ScreenMirroringServerPort;

		flow phoneEnd.video to tvEnd.video;
		flow phoneEnd.audio to tvEnd.audio;
		flow phoneEnd.control to tvEnd.control;
		flow tvEnd.status to phoneEnd.status;
	}

	// --- Requirements ---
	requirement def VideoQuality {
		text "The system shall stream video at a minimum resolution of 1920x1080 pixels.";
	}

	requirement def FrameRate {
		text "The system shall maintain a video frame rate of at least 30 frames per second.";
	}

	requirement def Latency {
		text "The end-to-end latency from phone screen to TV screen shall be less than 150ms.";
	}

	// --- Top-Level System Assembly ---
	part def HomeEntertainmentSystem {
		part phone : Smartphone;
		part tv : SmartTV;

		interface connection : ScreenMirroringInterface connect
			phoneEnd ::> phone.mirrorClient to
			tvEnd ::> tv.mirrorServer;

		satisfy requirement Latency by connection;
	}

	// --- Verification Cases for Requirements ---
	analysis case VerifyVideoQuality {
		subject phone.mirrorClient.video;
		objective {
			check that "Width is at least 1920" (subject.resolution.width >= 1920);
			check that "Height is at least 1080" (subject.resolution.height >= 1080);
		}
		satisfy requirement VideoQuality by self;
	}

	analysis case VerifyFrameRate {
		subject phone.mirrorClient.video;
		objective {
			check that "Frame rate is at least 30 Hz" (subject.frameRate >= 30[Hz]);
		}
		satisfy requirement FrameRate by self;
	}
}
