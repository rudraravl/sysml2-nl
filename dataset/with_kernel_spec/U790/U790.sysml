package 'Digital Odometer System' {
	private import ISQ::*;
	private import ScalarValues::*;

	attribute def Pulse;
	attribute def ResetCommand;
	attribute def PowerOn;
	attribute def PowerOff;

	part def Driver {
		port resetPort {
			out reset : ResetCommand;
		}
		port powerPort {
			out powerOn : PowerOn;
			out powerOff : PowerOff;
		}
	}

	part def WheelRotationSensor {
		attribute pulsesPerRevolution : Integer = 6;
		port pulsePort {
			out pulse : Pulse;
		}
	}

	part def NonVolatileStorage {
		attribute storedDistance : LengthValue := 0 [m];
		port loadPort {
			out loadValue : LengthValue;
		}
		port savePort {
			in storeValue : LengthValue;
		}
		state StorageState {
			state active {
				entry {
					assign loadPort.loadValue := storedDistance;
				}
				do {
					loop {
						accept val : LengthValue;
						then assign storedDistance := val;
						then assign loadPort.loadValue := storedDistance;
					}
				}
			}
		}
	}

	part def DistanceCalculationUnit {
		attribute wheelDiameter : LengthValue := 0.65 [m];
		attribute wheelCircumference : LengthValue := 3.14159 * wheelDiameter;
		attribute pulsesPerRev : Integer = 6;
		attribute totalDistance : LengthValue := 0 [m];
		attribute currentSpeed : SpeedValue := 0 [m/s];
		attribute currentTripIncrement : LengthValue;

		port pulsePort {
			in pulse : Pulse;
		}
		port displayPort {
			out speed : SpeedValue;
			out totalDistanceOut : LengthValue;
		}
		port tripIncrementPort {
			out tripIncrement : LengthValue;
		}
		port nvmPort {
			in loadValue : LengthValue;
			out storeValue : LengthValue;
		}
		port controlPort {
			in powerOn : PowerOn;
			in powerOff : PowerOff;
		}

		state OdometerState {
			state off;
			state initializing {
				entry {
					assign totalDistance := nvmPort.loadValue;
					then assign currentSpeed := 0 [m/s];
				}
			}
			state measuring {
				do {
					loop {
						accept p : Pulse;
						then assign currentTripIncrement := wheelCircumference / pulsesPerRev;
						then assign totalDistance := totalDistance + currentTripIncrement;
						then assign currentSpeed := currentTripIncrement / 1 [s];
						then assign displayPort.totalDistanceOut := totalDistance;
						then assign displayPort.speed := currentSpeed;
						then assign tripIncrementPort.tripIncrement := currentTripIncrement;
						then assign nvmPort.storeValue := totalDistance;
					}
				}
			}
			transition off to initializing accept PowerOn;
			transition initializing to measuring;
			transition measuring to off accept PowerOff;
		}
	}

	part def TripMeter {
		attribute tripDistance : LengthValue := 0 [m];
		port incrementPort {
			in increment : LengthValue;
		}
		port displayPort {
			out tripDistanceOut : LengthValue;
		}
		port resetPort {
			in reset : ResetCommand;
		}

		state TripMeterState {
			state tracking {
				do {
					loop {
						accept inc : LengthValue;
						then assign tripDistance := tripDistance + inc;
						then assign displayPort.tripDistanceOut := tripDistance;
					}
				}
			}
			state resetting {
				entry {
					assign tripDistance := 0 [m];
					then assign displayPort.tripDistanceOut := tripDistance;
				}
			}
			transition tracking to resetting accept ResetCommand;
			transition resetting to tracking;
		}
	}

	part def DisplayUnit {
		port speedPort {
			in speed : SpeedValue;
		}
		port totalDistPort {
			in totalDistance : LengthValue;
		}
		port tripDistPort {
			in tripDistance : LengthValue;
		}
	}

	requirement def OdometerFunction {
		subject system : DigitalOdometerSystem;
		doc 'The system shall measure, store, and display the total cumulative distance, trip distance, and current speed.';
	}

	requirement def DataRetention {
		subject storage : NonVolatileStorage;
		doc 'The system shall retain total distance data when power is off.';
	}

	requirement def TripResetRequirement {
		subject tripMeter : TripMeter;
		doc 'The trip distance shall be resettable by the driver without affecting the total odometer distance.';
	}

	part def DigitalOdometerSystem {
		requirement odometerFunctionReq : OdometerFunction;
		requirement dataRetentionReq : DataRetention;
		requirement tripResetReq : TripResetRequirement;

		part driver : Driver;
		part wheelSensor : WheelRotationSensor;
		part calculationUnit : DistanceCalculationUnit;
		part tripMeter : TripMeter;
		part display : DisplayUnit;
		part storage : NonVolatileStorage;

		flow pulseFlow of Pulse
			from wheelSensor.pulsePort.pulse to calculationUnit.pulsePort.pulse;
		flow speedFlow of SpeedValue
			from calculationUnit.displayPort.speed to display.speedPort.speed;
		flow totalDistFlow of LengthValue
			from calculationUnit.displayPort.totalDistanceOut to display.totalDistPort.totalDistance;
		flow tripIncFlow of LengthValue
			from calculationUnit.tripIncrementPort.tripIncrement to tripMeter.incrementPort.increment;
		flow tripDistFlow of LengthValue
			from tripMeter.displayPort.tripDistanceOut to display.tripDistPort.tripDistance;
		flow resetFlow of ResetCommand
			from driver.resetPort.reset to tripMeter.resetPort.reset;
		flow powerOnFlow of PowerOn
			from driver.powerPort.powerOn to calculationUnit.controlPort.powerOn;
		flow powerOffFlow of PowerOff
			from driver.powerPort.powerOff to calculationUnit.controlPort.powerOff;
		flow loadFlow of LengthValue
			from storage.loadPort.loadValue to calculationUnit.nvmPort.loadValue;
		flow saveFlow of LengthValue
			from calculationUnit.nvmPort.storeValue to storage.savePort.storeValue;
	}
}
