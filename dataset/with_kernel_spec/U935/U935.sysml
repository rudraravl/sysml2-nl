package 'Total Energy Variometer' {
	private import ScalarValues::*;

	value def PressureValue :> Real;
	value def AltitudeValue :> Real;
	value def VerticalSpeedValue :> Real;
	value def AirspeedValue :> Real;
	value def FrequencyValue :> Real;

	item def PressureData {
		attribute staticPressure : PressureValue;
		attribute dynamicPressure : PressureValue;
	}

	item def AltitudeData {
		attribute altitude : AltitudeValue;
	}

	item def AirspeedData {
		attribute airspeed : AirspeedValue;
	}

	item def DisplayCommand {
		attribute rateOfClimb : VerticalSpeedValue;
		attribute displayMode : DisplayMode;
	}

	item def AudioCommand {
		attribute toneFrequency : FrequencyValue;
		attribute tonePattern : TonePattern;
	}

	enum def DisplayMode {
		needle;
		graphicalBar;
	}

	enum def TonePattern {
		intermittent;
		steady;
		silent;
	}

	attribute def PowerOnSignal;
	attribute def PowerOffSignal;
	attribute def SelfTestComplete;

	port def PressurePort {
		out pressureData : PressureData;
	}

	port def DisplayPort {
		out displayCommand : DisplayCommand;
	}

	port def AudioPort {
		out audioCommand : AudioCommand;
	}

	action def 'Perform Self Test';
	action def 'Calibrate Sensors';

	action def 'Measure Pressure' {
		out pressureData : PressureData;
	}

	action def 'Compute Altitude' {
		in pressureData : PressureData;
		out altitudeData : AltitudeData;
	}

	action def 'Compute Airspeed' {
		in pressureData : PressureData;
		out airspeedData : AirspeedData;
	}

	action def 'Compute Vertical Speed' {
		in altitudeData : AltitudeData;
		out verticalSpeed : VerticalSpeedValue;
	}

	action def 'Compute Total Energy Compensation' {
		in verticalSpeed : VerticalSpeedValue;
		in airspeed : AirspeedValue;
		out compensatedVerticalSpeed : VerticalSpeedValue;
	}

	action def 'Generate Display Command' {
		in compensatedVerticalSpeed : VerticalSpeedValue;
		out displayCommand : DisplayCommand;
	}

	action def 'Generate Audio Command' {
		in compensatedVerticalSpeed : VerticalSpeedValue;
		out audioCommand : AudioCommand;
	}

	action def 'Render Display' {
		in displayCommand : DisplayCommand;
	}

	action def 'Play Audio' {
		in audioCommand : AudioCommand;
	}

	state def 'Variometer States';
	state def 'Computation States';

	part def PressureSensor {
		port pressureOut : PressurePort;
		perform action 'measure pressure' : 'Measure Pressure';
	}

	part def ComputationUnit {
		port pressureIn : ~PressurePort;
		port displayOut : DisplayPort;
		port audioOut : AudioPort;
		perform action 'compute altitude' : 'Compute Altitude';
		perform action 'compute airspeed' : 'Compute Airspeed';
		perform action 'compute vertical speed' : 'Compute Vertical Speed';
		perform action 'compute total energy compensation' : 'Compute Total Energy Compensation';
		perform action 'generate display command' : 'Generate Display Command';
		perform action 'generate audio command' : 'Generate Audio Command';
		exhibit state 'computation states' : 'Computation States';
	}

	part def VisualDisplay {
		port displayIn : ~DisplayPort;
		perform action 'render display' : 'Render Display';
	}

	part def AudioIndicator {
		port audioIn : ~AudioPort;
		perform action 'play audio' : 'Play Audio';
	}

	part def TotalEnergyVariometer {
		attribute minClimbRate : VerticalSpeedValue = 0.1;
		attribute minDescentRate : VerticalSpeedValue = -0.1;

		port powerOnPort {
			in powerOn : PowerOnSignal;
		}
		port powerOffPort {
			in powerOff : PowerOffSignal;
		}

		part pressureSensor : PressureSensor;
		part computationUnit : ComputationUnit;
		part visualDisplay : VisualDisplay;
		part audioIndicator : AudioIndicator;

		connect pressureSensor.pressureOut to computationUnit.pressureIn;
		connect computationUnit.displayOut to visualDisplay.displayIn;
		connect computationUnit.audioOut to audioIndicator.audioIn;

		exhibit state 'variometer states' : 'Variometer States';
	}

	requirement def 'Variometer Performance Requirement' {
		subject variometer : TotalEnergyVariometer;
		requirement verticalSpeedAccuracy {
			doc /* The variometer shall measure vertical speed with an accuracy of +/- 0.1 m/s. */
		}
		requirement totalEnergyCompensation {
			doc /* The variometer shall compensate vertical speed for changes in airspeed to provide total energy compensated readings. */
		}
		requirement audioFeedback {
			doc /* The variometer shall provide audio feedback with rising intermittent beeps for climb and steady low-pitched drone for descent. */
		}
	}

	action 'perform self test' : 'Perform Self Test';
	action 'calibrate sensors' : 'Calibrate Sensors';
	action 'measure pressure' : 'Measure Pressure';
	action 'compute altitude' : 'Compute Altitude';
	action 'compute airspeed' : 'Compute Airspeed';
	action 'compute vertical speed' : 'Compute Vertical Speed';
	action 'compute total energy compensation' : 'Compute Total Energy Compensation';
	action 'generate display command' : 'Generate Display Command';
	action 'generate audio command' : 'Generate Audio Command';
	action 'render display' : 'Render Display';
	action 'play audio' : 'Play Audio';

	part variometerSystem : TotalEnergyVariometer {
		flow pressureFlow of PressureData
			from pressureSensor.pressureOut.pressureData to computationUnit.pressureIn.pressureData;
		flow displayFlow of DisplayCommand
			from computationUnit.displayOut.displayCommand to visualDisplay.displayIn.displayCommand;
		flow audioFlow of AudioCommand
			from computationUnit.audioOut.audioCommand to audioIndicator.audioIn.audioCommand;
	}

	state 'variometer states' : 'Variometer States' {
		entry; then poweredDown;

		state poweredDown;
		accept PowerOnSignal
			then initializing;

		state initializing {
			entry 'perform self test';
			do 'calibrate sensors';
		}
		accept SelfTestComplete
			then operational;

		state operational {
			entry; then level;

			do 'measure pressure';
			do 'compute altitude';
			do 'compute airspeed';
			do 'compute vertical speed';
			do 'compute total energy compensation';
			do 'generate display command';
			do 'generate audio command';
			do 'render display';
			do 'play audio';

			state level;
			accept when 'compute total energy compensation'.compensatedVerticalSpeed > variometerSystem.minClimbRate
				then climbing;
			accept when 'compute total energy compensation'.compensatedVerticalSpeed < variometerSystem.minDescentRate
				then descending;

			state climbing;
			accept when 'compute total energy compensation'.compensatedVerticalSpeed <= variometerSystem.minClimbRate
				then level;

			state descending;
			accept when 'compute total energy compensation'.compensatedVerticalSpeed >= variometerSystem.minDescentRate
				then level;
		}
		accept PowerOffSignal
			then poweredDown;
	}

	state 'computation states' : 'Computation States' {
		entry; then processing;

		state processing {
			do 'compute altitude';
			do 'compute airspeed';
			do 'compute vertical speed';
			do 'compute total energy compensation';
			do 'generate display command';
			do 'generate audio command';
		}
	}

	requirement 'System Performance' : 'Variometer Performance Requirement' {
		subject variometer :>> variometerSystem;
	}
}
