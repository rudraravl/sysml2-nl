// Create a central controller with a temperature sensor that is able to log data.
package 'Controller System' {
	part def CentralController {
		part tempSensor : TemperatureSensor;
		part dataLogger : Logger;
	}
	part def TemperatureSensor {
		perform action senseTemperature;
	}
	part def Logger {
		perform action logData;
	}
}
