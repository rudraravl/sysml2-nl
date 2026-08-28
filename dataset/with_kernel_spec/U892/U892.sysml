package 'Vehicle Speedometer System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import ISQSpaceTime::*;
	private import SI::*;

	item def RotationSignal {
		attribute frequency : FrequencyValue;
		attribute timestamp : TimeValue;
	}

	item def SpeedCommand {
		attribute speed : SpeedValue;
		attribute timestamp : TimeValue;
	}

	occurrence def PowerOn;
	occurrence def PowerOff;
	occurrence def SpeedRefresh;

	action def SenseRotation {
		out rotation : RotationSignal;
	}

	action def CalculateSpeed {
		in rotation : RotationSignal;
		in radius : LengthValue;
		out speed : SpeedCommand;
	}

	action def RenderSpeed {
		in speed : SpeedCommand;
	}

	part def WheelSpeedSensor {
		attribute wheelCircumference : LengthValue;
		port rotationOut {
			out rotation : RotationSignal;
		}
		perform action senseRotation : SenseRotation {
			out rotation = rotationOut.rotation;
		}
		exhibit state sensorStates {
			entry; then active;
			state active {
				do senseRotation;
			}
		}
	}

	part def SpeedProcessor {
		attribute wheelRadius : LengthValue;
		port rotationIn {
			in rotation : RotationSignal;
		}
		port speedOut {
			out speed : SpeedCommand;
		}
		perform action calculateSpeed : CalculateSpeed {
			in rotation = rotationIn.rotation;
			in radius = wheelRadius;
			out speed = speedOut.speed;
		}
		exhibit state processorStates {
			entry; then ready;
			state ready {
				do calculateSpeed;
			}
		}
	}

	part def DigitalDisplay {
		attribute unit : String;
		port speedIn {
			in speed : SpeedCommand;
		}
		perform action renderSpeed : RenderSpeed {
			in speed = speedIn.speed;
		}
		exhibit state displayStates {
			entry; then off;
			state off;
			accept PowerOn then on;
			state on {
				entry; then idle;
				state idle;
				accept SpeedRefresh then updating;
				state updating {
					do renderSpeed;
				}
				accept SpeedRefresh then updating;
			}
			accept PowerOff then off;
		}
	}

	part def VehicleSpeedometerSystem {
		part sensor : WheelSpeedSensor {
			attribute wheelCircumference = 2.0 [m];
		}
		part processor : SpeedProcessor {
			attribute wheelRadius = 0.3 [m];
		}
		part display : DigitalDisplay {
			attribute unit = "km/h";
		}

		flow rotationFlow of RotationSignal
			from sensor.rotationOut.rotation to processor.rotationIn.rotation;
		flow speedFlow of SpeedCommand
			from processor.speedOut.speed to display.speedIn.speed;
	}

	requirement displayUpdateRate {
		doc /* The display must update at least 5 times per second for a smooth, continuous reading. */
		attribute minUpdateRate : FrequencyValue = 5.0 [Hz];
		constraint { minUpdateRate >= 5.0 [Hz] }
	}

	requirement responsiveness {
		doc /* The system must reflect changes in speed within 150 milliseconds. */
		attribute maxResponseTime : TimeValue = 0.150 [s];
		constraint { maxResponseTime <= 0.150 [s] }
	}

	requirement accuracy {
		doc /* The speed measurement must maintain an accuracy of at least +/- 2%. */
		attribute maxError : Real = 0.02;
		constraint { maxError <= 0.02 }
	}

	part speedometerSystem : VehicleSpeedometerSystem;

	satisfy displayUpdateRate by speedometerSystem.display;
	satisfy responsiveness by speedometerSystem;
	satisfy accuracy by speedometerSystem.processor;
}
