// Model a weather station that collects temperature, humidity, and wind speed data and is able to transmit it.
```sysml
// Define the fundamental data items collected by the weather station
item def Temperature;
item def Humidity;
item def WindSpeed;

// Define a composite item to bundle all weather data for transmission
item def WeatherData {
  part temperature : Temperature;
  part humidity : Humidity;
  part windSpeed : WindSpeed;
}

// Define the interface for transmitting weather data
interface def DataTransmissionInterface {
  flow transmittedData : WeatherData;
}

// Define the part responsible for sensing temperature
part def TemperatureSensor {
  output sensedTemperature : Temperature;
}

// Define the part responsible for sensing humidity
part def HumiditySensor {
  output sensedHumidity : Humidity;
}

// Define the part responsible for sensing wind speed
part def WindSpeedSensor {
  output sensedWindSpeed : WindSpeed;
}

// Define the part responsible for transmitting the collected data
part def Transmitter {
  input dataToTransmit : WeatherData;
  exposes transmitPort : DataTransmissionInterface;
}

// Define the Weather Station itself
part def WeatherStation {
  // Internal parts representing the sensors
  part tempSensor : TemperatureSensor;
  part humSensor : HumiditySensor;
  part windSensor : WindSpeedSensor;

  // Internal part representing the data transmitter
  part dataTransmitter : Transmitter;

  // Internal parts to hold the current collected readings
  part currentTemperature : Temperature;
  part currentHumidity : Humidity;
  part currentWindSpeed : WindSpeed;

  // Flow the sensed data from the sensors to the current reading parts
  flow from tempSensor.sensedTemperature to currentTemperature;
  flow from humSensor.sensedHumidity to currentHumidity;
  flow from windSensor.sensedWindSpeed to currentWindSpeed;

  // Internal part to assemble the WeatherData bundle for transmission
  part dataBundle : WeatherData;

  // Flow the individual current readings into the data bundle's corresponding parts
  flow from currentTemperature to dataBundle.temperature;
  flow from currentHumidity to dataBundle.humidity;
  flow from currentWindSpeed to dataBundle.windSpeed;

  // Flow the complete data bundle to the transmitter's input
  flow from dataBundle to dataTransmitter.dataToTransmit;

  // Expose the data transmission capability of the WeatherStation
  exposes transmissionPort : DataTransmissionInterface;

  // Connect the internal transmitter's port to the WeatherStation's exposed transmission port
  connect dataTransmitter.transmitPort to transmissionPort;
}
```
