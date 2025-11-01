// Create a central controller with a temperature sensor that is able to log data.
package TemperatureLoggingSystem {
	public import ISQ::*;
	public import SI::*;
	public import Time::*;

	package Libraries {
		package ValueTypes {
			attribute def Temperature redefines ISQ::ThermodynamicTemperature;
		}

		package ItemDefinitions {
			import ScalarValues::*;
			import ValueTypes::Temperature;
			import Time::DateTime;

			item def TemperatureReading {
				attribute value: Temperature;
				attribute timestamp: DateTime;
			}

			item def Power {
				attribute voltage: ISQ::ElectricPotential;
				attribute current: ISQ::ElectricCurrent;
			}
		}

		package InterfaceDefinitions {
			import ItemDefinitions::*;

			interface def TemperatureDataFlow {
				inout reading: TemperatureReading;
			}

			interface def PowerFlow {
				inout power: Power;
			}
		}
	}

	package ComponentDefinitions {
		import Libraries::ItemDefinitions::*;
		import Libraries::ValueTypes::*;
		import Libraries::InterfaceDefinitions::*;
		import ScalarValues::*;

		part def TemperatureSensor {
			attribute accuracy: Real;
			port powerIn: PowerFlow;
			port dataOut: ~TemperatureDataFlow;

			action measureTemperature {
				out reading: TemperatureReading;
				language "SysML";
				body {
					let now: DateTime = Time::now();
					let tempValue: Temperature = 25.0[°C];
					reading = new TemperatureReading(value = tempValue, timestamp = now);
				}
			}
		}

		part def DataLogger {
			attribute log: TemperatureReading[0..*] ordered;
			port dataIn: TemperatureDataFlow;

			action storeReading {
				in reading: TemperatureReading;
				language "SysML";
				body {
					log->add(reading);
				}
			}
		}

		part def PowerSource {
			attribute capacity: ISQ::Energy;
			port powerOut: ~PowerFlow;
		}

		part def CentralController {
			port powerIn: PowerFlow;
			port sensorIn: TemperatureDataFlow;
			port loggerOut: ~TemperatureDataFlow;

			exhibit state machine ControllerStates {
				state Initializing;
				state Idle;
				state Active;
				state Fault;

				transition from Initializing to Idle;

				transition startLogging from Idle to Active;

				transition stopLogging from Active to Idle;

				transition measureAndLog
					first Active
					when 1[s]
					do {
						if sensorIn.reading != null {
						   send sensorIn.reading to loggerOut;
						}
					}
					then Active;

				transition handleError from Active to Fault;
			}
		}
	}

	package SystemAssembly {
		import ComponentDefinitions::*;
		import Libraries::ItemDefinitions::*;

		part system {
			part controller: CentralController;
			part sensor: TemperatureSensor {
				attribute accuracy = 0.5;
			}
			part logger: DataLogger;
			part power: PowerSource {
				attribute capacity = 10000[J];
			}

			connect sensor.dataOut to controller.sensorIn;
			connect controller.loggerOut to logger.dataIn {
				item flow reading: TemperatureReading from controller.loggerOut to logger.dataIn;
			}
			connect power.powerOut to controller.powerIn;
			connect power.powerOut to sensor.powerIn;

			action sensorBehavior {
				inout s = sensor;
				loop {
					perform s.measureTemperature {
						out reading;
					}
					send reading to s.dataOut;
					wait 1[s];
				}
			}

			action loggerBehavior {
				inout l = logger;
				loop {
					accept reading: TemperatureReading from l.dataIn;
					perform l.storeReading(reading);
				}
			}
		}
	}

	package Requirements {
		import SystemAssembly::system;

		requirement def DataLoggingCapability {
			subject system;
			doc "The system shall be capable of logging temperature data from its
			     integrated sensor into a data log.";
		}

		requirement def LoggingFrequency {
			subject system.controller;
			doc "The system shall log temperature data at a rate of 1 Hz.";
		}

		requirement def TemperatureAccuracy {
			subject system.sensor;
			doc "The temperature sensor shall have an accuracy of +/- 0.5 degrees Celsius.";
		}

		requirement model {
			requirement loggingReq: DataLoggingCapability;
			requirement freqReq: LoggingFrequency {
				refines loggingReq;
			}
			requirement accReq: TemperatureAccuracy {
				refines loggingReq;
			}

			satisfy system.logger by loggingReq;
			satisfy system.controller.ControllerStates.measureAndLog by freqReq;
			satisfy system.sensor by accReq;
		}
	}
}
