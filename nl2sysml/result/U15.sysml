// Define an interface between a smartphone and a smart TV for screen mirroring functionality.
package 'ScreenMirroring' {
	item def VideoStream;
	item def AudioStream;
	item def ControlCommand;

	port def SmartphoneMirroringPort {
		out item video : VideoStream;
		out item audio : AudioStream;
		in item command : ControlCommand;
	}

	port def SmartTVMirroringPort {
		in item video : VideoStream;
		in item audio : AudioStream;
		out item command : ControlCommand;
	}

	part def Smartphone {
		port mirroringPort : SmartphoneMirroringPort;
	}

	part def SmartTV {
		port mirroringPort : SmartTVMirroringPort;
	}

	interface def ScreenMirroringInterface {
		end smartphoneEnd : SmartphoneMirroringPort;
		end tvEnd : SmartTVMirroringPort;
		flow smartphoneEnd.video to tvEnd.video;
		flow smartphoneEnd.audio to tvEnd.audio;
		flow tvEnd.command to smartphoneEnd.command;
	}
}
