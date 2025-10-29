// Model a weather station that collects temperature, humidity, and wind speed data and is able to transmit it.
package 'Weather Station Model' {
	private import ScalarValues::*;

	attribute def TemperatureValue :> Real;
	attribute def HumidityValue :> Real;
	attribute def WindSpeedValue :> Real;

	item def WeatherData {
		attribute temperature: TemperatureValue;
		attribute humidity: HumidityValue;
		attribute windSpeed: WindSpeedValue;
	}

	part def WeatherStation {
		port dataOutput {
			flow transmittedData: WeatherData out;
		}
	}
}
