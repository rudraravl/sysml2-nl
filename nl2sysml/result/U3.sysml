// Create a central controller with a temperature sensor that is able to log data.
item def TemperatureData {
    attribute value : Scalar; // e.g., degrees Celsius
}

item def LogEntry {
    attribute timestamp : Time;
    attribute data : TemperatureData;
}

item def TemperatureSensor {
    output sensedTemperature : TemperatureData;
}

item def DataLogger {
    input logInput : LogEntry;
}

item def CentralController {
    input temperatureInput : TemperatureData;
    output logOutput : LogEntry;
}

part def MonitoringSystem {
    part controller : CentralController;
    part sensor : TemperatureSensor;
    part logger : DataLogger;

    flow temperatureDataFlow from sensor.sensedTemperature to controller.temperatureInput;
    flow logDataFlow from controller.logOutput to logger.logInput;
}
