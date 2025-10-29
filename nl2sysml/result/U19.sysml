// Define a heating system that adjusts the temperature when there is a trigger.
```sysml
package HeatingSystemPackage {

  // Define types
  type Temperature : ScalarValue { unit Unit.C; }
  type Boolean;

  // Define interfaces for communication between parts
  interface TemperatureReading {
    output currentTemperature : Temperature;
  }

  interface HeaterControl {
    output setHeaterOn : Boolean;
    output targetTemperature : Temperature;
  }

  interface SystemControlInput {
    input triggerAdjustment : Boolean; // Represents the "trigger"
    input desiredRoomTemperature : Temperature;
  }

  // Define the individual parts of the system
  part TemperatureSensor {
    port provides : TemperatureReading;
  }

  part Heater {
    port receives : HeaterControl;
  }

  part Controller {
    port senses : TemperatureReading;
    port commands : HeaterControl;
    port receivesExternal : SystemControlInput;
    // The behavior to "adjusts the temperature when there is a trigger"
    // is implicitly handled by this Controller part based on its inputs and outputs.
  }

  // Define the overall HeatingSystem
  part HeatingSystem {
    // Internal parts of the HeatingSystem
    part sensor : TemperatureSensor;
    part heater : Heater;
    part controller : Controller;

    // External port for the HeatingSystem to receive commands and settings
    port systemInput : SystemControlInput;

    // Connect the internal parts
    connect sensor.provides to controller.senses;
    connect controller.commands to heater.receives;

    // Connect the external system input to the internal controller
    connect systemInput to controller.receivesExternal;
  }
}
```
