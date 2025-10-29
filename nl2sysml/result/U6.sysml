// Specify a water pump system that activates below 30% and deactivates at 90% tank level.
```sysml
package WaterPumpSystem {

  // Define a unit for percentage
  unit percent;

  // Define a value type for tank level, using the 'percent' unit
  value def TankLevel {
    quantity level: Real units percent;
  }

  // Define the Pump item
  item Pump {
    attribute isOn: Boolean; // Indicates if the pump is active
  }

  // Define the Level Sensor item
  item LevelSensor {
    output currentLevel: TankLevel; // Outputs the current tank level
  }

  // Define the Controller item, which contains the control logic
  item Controller {
    input levelInput: TankLevel; // Receives tank level from the sensor
    output pumpOutput: Boolean;  // Controls the pump's on/off state

    // Behavior for the controller, modeled as a State Machine
    behavior controlLogic: StateMachine {
      // Initial state: Pump is off
      state PumpOff {
        entry { pumpOutput = false; } // Ensure pump is off when entering this state
        transition to PumpOn {
          // Activate pump if level drops below 30%
          trigger when levelInput.level < 30.0 percent;
        }
      }

      // State: Pump is on
      state PumpOn {
        entry { pumpOutput = true; } // Ensure pump is on when entering this state
        transition to PumpOff {
          // Deactivate pump if level rises above 90%
          trigger when levelInput.level > 90.0 percent;
        }
      }
    }
  }

  // Define the top-level Water Pump System
  part WaterPumpSystem {
    part pump: Pump;
    part sensor: LevelSensor;
    part controller: Controller;

    // Connect the sensor output to the controller input
    connect sensor.currentLevel to controller.levelInput;

    // Connect the controller output to the pump's control input
    connect controller.pumpOutput to pump.isOn;
  }
}
```
