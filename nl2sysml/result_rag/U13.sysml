// Model a weather station that collects temperature, humidity, and wind speed data and is able to transmit it.
package 'Weather Station System' {
	private import ScalarValues::*;
	public import ISQ::SI_Units::{Celsius, Percent, MetersPerSecond};
	public import ISQ::Time;

	package DataTypes {
		value def TemperatureValue :> Real {
			unit = Celsius;
		}
		
		value def RelativeHumidityValue :> Real {
			unit = Percent;
		}
		
		value def VelocityValue :> Real {
			unit = MetersPerSecond;
		}
		
		item def WeatherReport {
			attribute temperature : TemperatureValue;
			attribute humidity : RelativeHumidityValue;
			attribute windSpeed : VelocityValue;
		}
		
		item def RFSignal;
	}

	package Components {
		import 'Weather Station System'::DataTypes::*;

		abstract part def Sensor {
			attribute lastMeasurementTime : Time::TimeInstantValue;
		}

		part def TemperatureSensor :> Sensor {
			attribute currentTemp : TemperatureValue;
			out port tempOut : TemperatureValue;
			
			exhibit state Reading {
				do {
					// Continuously output the current temperature
					send self.currentTemp on self.tempOut;
				}
			}
		}

		part def HumiditySensor :> Sensor {
			attribute currentHumidity : RelativeHumidityValue;
			out port humidityOut : RelativeHumidityValue;
			
			exhibit state Reading {
				do {
					send self.currentHumidity on self.humidityOut;
				}
			}
		}

		part def Anemometer :> Sensor {
			attribute currentWindSpeed : VelocityValue;
			out port windSpeedOut : VelocityValue;
			
			exhibit state Reading {
				do {
					send self.currentWindSpeed on self.windSpeedOut;
				}
			}
		}

		part def Transmitter {
			in port dataIn : WeatherReport;
			out port rfOut : RFSignal;
			
			action transmit(in report : WeatherReport) {
				// Abstract representation of generating and sending an RF signal
				send new RFSignal on self.rfOut;
			}
			
			// When a WeatherReport is received on dataIn, call the transmit action
			accept dataIn call transmit;
		}

		part def ControlUnit {
			in port tempIn : TemperatureValue;
			in port humidityIn : RelativeHumidityValue;
			in port windSpeedIn : VelocityValue;
			out port reportOut : WeatherReport;
			
			attribute lastReport : WeatherReport;
			
			state machine ReportingCycle {
				initial state Idle;
				state CollectingAndTransmitting;
				
				transition from Idle to CollectingAndTransmitting 
					on after(5 min);
				
				transition from CollectingAndTransmitting to Idle {
					action {
						// Create a new report from the latest sensor data
						let newReport = new WeatherReport {
							temperature = self.owner.tempIn,
							humidity = self.owner.humidityIn,
							windSpeed = self.owner.windSpeedIn
						};
						
						// Store it locally and send it to the transmitter
						self.owner.lastReport = newReport;
						send newReport on self.owner.reportOut;
					}
				}
			}
		}
	}

	package Requirements {
		import 'Weather Station System'::DataTypes::*;
		import ISQ::Time::DurationValue;

		requirement def TemperatureAccuracy {
			id = "WS-REQ-01";
			text "The temperature sensor shall measure the ambient temperature with an error no greater than the specified maximum.";
			attribute maxError : TemperatureValue = 0.5;
		}

		requirement def ReportingInterval {
			id = "WS-REQ-02";
			text "The weather station shall collect and transmit a new weather report at a regular interval.";
			attribute interval : DurationValue = 300 s;
		}

		requirement def OperationalRange {
			id = "WS-REQ-03";
			text "The weather station assembly must operate correctly within a specified ambient temperature range.";
			attribute minTemp : TemperatureValue = -40.0;
			attribute maxTemp : TemperatureValue = 85.0;
		}
	}

	part def WeatherStation {
		import 'Weather Station System'::Components::*;
		import 'Weather Station System'::DataTypes::RFSignal;
		
		part tempSensor : TemperatureSensor;
		part humiditySensor : HumiditySensor;
		part anemometer : Anemometer;
		part transmitter : Transmitter;
		part controlUnit : ControlUnit;
		
		out port rfSignal : RFSignal redefines transmitter.rfOut;
		
		connect tempSensor.tempOut to controlUnit.tempIn;
		connect humiditySensor.humidityOut to controlUnit.humidityIn;
		connect anemometer.windSpeedOut to controlUnit.windSpeedIn;
		connect controlUnit.reportOut to transmitter.dataIn;
	}

	// Example instance and satisfaction of requirements
	part stationAssembly : WeatherStation;
	
	requirement tempAccuracyReq : Requirements::TemperatureAccuracy;
	requirement reportingReq : Requirements::ReportingInterval {
		:>> interval = 5 min;
	}
	
	satisfy by stationAssembly.tempSensor to tempAccuracyReq;
	satisfy by stationAssembly.controlUnit.ReportingCycle to reportingReq;
}
