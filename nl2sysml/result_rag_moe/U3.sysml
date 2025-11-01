// Create a central controller with a temperature sensor that is able to log data.
package TemperatureLoggingSystem {
	public import ISQ::*;
	public import SI::*;
	public import Time::*;
	public import ScalarValues::*;

	package ValueDefinitions {
		attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
		attribute def SamplingPeriod :> Time::DurationValue;
	}

	package ItemDefinitions {
		item def TemperatureReading {
			attribute timestamp : Time::TimeStamp;
			attribute value : ValueDefinitions::TemperatureValue;
			attribute sensorId : String;
		}
		
		item def StartCommand;
		item def StopCommand;
	}

	package PortDefinitions {
		port def TemperatureDataPort {
			out reading : ItemDefinitions::TemperatureReading;
		}
		
		port def ControlPort {
			in command : ItemDefinitions::StartCommand | ItemDefinitions::StopCommand;
		}
	}

	package ActionDefinitions {
		action def MeasureAndSend {
			in sensorId : String;
			out reading : ItemDefinitions::TemperatureReading via dataPort;
			port dataPort : PortDefinitions::TemperatureDataPort;
			
			// Opaque expression to simulate a measurement
			let measuredValue = 22.5[°C];
			
			let readingToSend = new ItemDefinitions::TemperatureReading {
				timestamp = now(),
				value = measuredValue,
				::sensorId = sensorId
			};
			
			reading = readingToSend;
		}

		action def AppendToLog {
			in reading : ItemDefinitions::TemperatureReading;
			inout log : ItemDefinitions::TemperatureReading[0..*];
			
			// Expression to append the new reading to the log sequence
			log = log->append(reading);
		}
	}

	package StateDefinitions {
		state machine def SensorBehavior {
			inout sensor : PartDefinitions::TemperatureSensor;
			
			initial transition to Idle;
			
			state Idle;
			
			state Measuring {
				do ActionDefinitions::MeasureAndSend {
					in sensorId = sensor.id;
					port dataPort = sensor.dataPort;
				}
			}
			
			transition start_measuring 
				from Idle to Measuring
				accept command : ItemDefinitions::StartCommand via sensor.controlPort;
				
			transition stop_measuring
				from Measuring to Idle
				accept command : ItemDefinitions::StopCommand via sensor.controlPort;
		}
		
		state machine def ControllerBehavior {
			inout controller : PartDefinitions::CentralController;
			
			initial transition to Idle;
			
			state Idle;
			
			state Logging {
				entry action {
					// Forward the start command to the sensor
					send new ItemDefinitions::StartCommand() to controller.sensor.controlPort;
				}
				exit action {
					// Forward the stop command to the sensor
					send new ItemDefinitions::StopCommand() to controller.sensor.controlPort;
				}
			}
			
			transition start_logging
				from Idle to Logging
				accept command : ItemDefinitions::StartCommand via controller.controlPort;
			
			transition stop_logging
				from Logging to Idle
				accept command : ItemDefinitions::StopCommand via controller.controlPort;
			
			transition log_received_data on Logging {
				accept reading : ItemDefinitions::TemperatureReading via controller.sensorDataPort;
				effect do ActionDefinitions::AppendToLog {
					in reading = reading;
					inout log = controller.logger.log;
				};
			}
		}
	}

	package PartDefinitions {
		part def TemperatureSensor {
			attribute id : String;
			attribute samplingPeriod : ValueDefinitions::SamplingPeriod;
			
			port dataPort : PortDefinitions::TemperatureDataPort;
			port controlPort : ~PortDefinitions::ControlPort; // Conjugated
			
			exhibit states : StateDefinitions::SensorBehavior {
				inout sensor = this;
			}
		}
		
		part def DataLogger {
			attribute log : ItemDefinitions::TemperatureReading[0..*] ordered;
		}
		
		part def CentralController {
			part sensor : TemperatureSensor {
				attribute :>> id = "TS-001";
				attribute :>> samplingPeriod = 1.0[s];
			}
			
			part logger : DataLogger;
			
			port sensorDataPort : ~PortDefinitions::TemperatureDataPort; // Conjugated
			port controlPort : PortDefinitions::ControlPort;
			
			connect sensor.dataPort to sensorDataPort;
			
			exhibit states : StateDefinitions::ControllerBehavior {
				inout controller = this;
			}
		}
	}
	
	package RequirementDefinitions {
		requirement def LoggingRequirement {
			id = "LOG-01";
			text "The system shall log temperature readings from the sensor when in the Logging state.";
			
			subject controller : PartDefinitions::CentralController;
			
			require dataIntegrity {
				text "Each logged reading must contain a timestamp, a temperature value, and a sensor ID.";
				
				// This can be formally verified by checking the definition of TemperatureReading
				assume forall r in controller.logger.log |
					r.timestamp != null and
					r.value != null and
					r.sensorId != null;
			}
		}
		
		requirement def ControlRequirement {
			id = "CTL-01";
			text "The controller shall be able to start and stop the logging process via external commands.";
			
			subject controller : PartDefinitions::CentralController;
			
			// Verified by the state machine transitions triggered from the controlPort
			satisfy by controller.states.start_logging, controller.states.stop_logging;
		}
	}
	
	package Usages {
		import PartDefinitions::*;
		import RequirementDefinitions::*;
		
		part system : CentralController {
			satisfy loggingReq : LoggingRequirement {
				subject controller = system;
			}
			satisfy controlReq : ControlRequirement {
				subject controller = system;
			}
		}
	}
}
}
