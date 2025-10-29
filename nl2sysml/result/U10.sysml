// Model a smart home system that is able to turn on the lights.
```sysml
package SmartHome {

  // Define the type of item that flows as a command
  item def TurnOnCommand;

  // Define the Smart Home Controller part
  part def SmartHomeController {
    // Output port to send commands to lights
    port controlOut: out TurnOnCommand;

    // Action for the controller to send a "turn on" command
    action sendTurnOnCommand {
      // Create and send a new TurnOnCommand item out of the controlOut port
      self.controlOut.send(new TurnOnCommand());
    }
  }

  // Define the Light part
  part def Light {
    // Input port to receive commands from the controller
    port controlIn: in TurnOnCommand;

    // Attribute to represent the current state of the light (on or off)
    attribute isOn: Boolean = false; // Initially, the light is off

    // Action for the light to turn itself on
    action turnOn {
      // When this action is performed, the light's state changes to on
      self.isOn = true;
    }
  }

  // Define the top-level Smart Home System
  part def SmartHomeSystem {
    // Declare instances of the controller and light within the system
    part controller: SmartHomeController;
    part light: Light;

    // Connect the controller's output port to the light's input port
    // This enables the flow of TurnOnCommand items from the controller to the light
    connect controller.controlOut to light.controlIn;

    // Define the overall system action to turn on the lights
    action turnOnLights {
      // Step 1: The controller performs its action to send a "turn on" command
      controller.sendTurnOnCommand();

      // Step 2: The light, having received the command (implicitly via the connection),
      // performs its action to turn itself on.
      // This sequence models the causal relationship within the system.
      light.turnOn();
    }
  }
}
```
