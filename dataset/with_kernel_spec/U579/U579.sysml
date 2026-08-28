package 'Automated Water Pumping System' {
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;
	private import ISQ::VolumeValue;
	private import ISQ::LengthValue;
	private import SI::m;
	private import SI::L;
	private import SI::s;

	item def Water;

	item def LevelReading {
		attribute level : LengthValue;
		attribute timestamp : Real;
	}

	item def PumpStartCommand;
	item def PumpStopCommand;

	port def WaterOutPort {
		out item water : Water;
	}

	port def WaterInPort {
		in item water : Water;
	}

	port def LevelOutPort {
		out item reading : LevelReading;
	}

	port def LevelInPort {
		in item reading : LevelReading;
	}

	port def CommandOutPort {
		out item startCmd : PumpStartCommand;
		out item stopCmd : PumpStopCommand;
	}

	port def CommandInPort {
		in item startCmd : PumpStartCommand;
		in item stopCmd : PumpStopCommand;
	}

	part def SourceReservoir {
		attribute capacity : VolumeValue;
		port waterOutPort : WaterOutPort;
	}

	part def DestinationTank {
		attribute maxVolume : VolumeValue;
		attribute currentLevel : LengthValue;
		port waterInPort : WaterInPort;
	}

	action def SenseLevel {
		out reading : LevelReading;
	}

	state def SensorStates;

	state def PumpOperatingStates;

	state def ControllerStates;

	part def LevelSensor {
		attribute accuracy : LengthValue;
		port levelOutPort : LevelOutPort;

		state sensorStates : SensorStates {
			entry; then sensing;
			state sensing {
				do action senseLevel : SenseLevel {
					out reading = levelOutPort.reading;
				}
			}
		}
	}

	part def WaterPump {
		port waterInPort : WaterInPort;
		port waterOutPort : WaterOutPort;
		port commandInPort : CommandInPort;
		attribute flowRate : VolumeValue;

		state pumpStates : PumpOperatingStates {
			entry; then idle;
			state idle;
			accept startCmd : PumpStartCommand via commandInPort
				then starting;
			state starting {
				entry action startMotor { /* ramp up motor */ }
				do action rampUp { /* gradually increase flow */ }
			}
			accept after 5 [s]
				then running;
			state running {
				do action pumpWater {
					in water : Water = waterInPort.water;
					out waterOut : Water = waterOutPort.water;
				}
			}
			accept stopCmd : PumpStopCommand via commandInPort
				then stopping;
			state stopping {
				entry action beginShutdown { /* begin motor shutdown */ }
				do action rampDown { /* gradually decrease flow */ }
			}
			accept after 3 [s]
				then idle;
		}
	}

	part def PumpController {
		attribute lowSetpoint : LengthValue;
		attribute highSetpoint : LengthValue;
		port levelInPort : LevelInPort;
		port commandOutPort : CommandOutPort;

		state controllerStates : ControllerStates {
			entry; then monitoring;
			state monitoring;
			accept reading : LevelReading via levelInPort
				if reading.level < lowSetpoint
				do send new PumpStartCommand() via commandOutPort
				then monitoring;
			accept reading : LevelReading via levelInPort
				if reading.level >= highSetpoint
				do send new PumpStopCommand() via commandOutPort
				then monitoring;
		}
	}

	part systemContext {
		part sourceReservoir : SourceReservoir {
			attribute capacity = 10000 [L];
		}

		flow of water : Water
			from sourceReservoir.waterOutPort.water to waterPump.waterInPort.water;

		part waterPump : WaterPump {
			attribute flowRate = 50 [L];
		}

		flow of water : Water
			from waterPump.waterOutPort.water to destinationTank.waterInPort.water;

		part destinationTank : DestinationTank {
			attribute maxVolume = 2000 [L];
			attribute currentLevel : LengthValue;

			part levelSensor : LevelSensor {
				attribute accuracy = 0.01 [m];
			}
		}

		part pumpController : PumpController {
			attribute lowSetpoint = 0.5 [m];
			attribute highSetpoint = 1.8 [m];
		}

		flow of reading : LevelReading
			from destinationTank.levelSensor.levelOutPort.reading to pumpController.levelInPort.reading;

		flow of startCmd : PumpStartCommand
			from pumpController.commandOutPort.startCmd to waterPump.commandInPort.startCmd;

		flow of stopCmd : PumpStopCommand
			from pumpController.commandOutPort.stopCmd to waterPump.commandInPort.stopCmd;
	}

	requirement def AutomatedPumpingRequirement {
		doc /* The system shall automatically maintain the water level in the destination tank between low and high setpoints. */
	}

	requirement def OverflowPreventionRequirement {
		doc /* The system shall prevent the destination tank from overflowing by stopping the pump when the high setpoint is reached. */
	}

	requirement def SupplyReliabilityRequirement {
		doc /* The system shall ensure a reliable water supply by activating the pump when the water level drops below the low setpoint. */
	}

	requirement def SensorAccuracyRequirement {
		doc /* The level sensor shall measure the water level with an accuracy of at least 0.01 m. */
	}

	requirement def PumpStateTransitionRequirement {
		doc /* The water pump shall transition through starting, running, and stopping states to manage water flow. */
	}

	requirement automatedPumping : AutomatedPumpingRequirement;
	requirement overflowPrevention : OverflowPreventionRequirement;
	requirement supplyReliability : SupplyReliabilityRequirement;

	requirement sensorAccuracy : SensorAccuracyRequirement {
		subject levelSensor : LevelSensor = systemContext.destinationTank.levelSensor;
		constraint { levelSensor.accuracy <= 0.01 [m] }
	}

	requirement pumpStateTransition : PumpStateTransitionRequirement {
		subject waterPump : WaterPump = systemContext.waterPump;
	}
}
