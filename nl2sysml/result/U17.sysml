// Define the basic structure of a security system with a door sensor and an alarm.
package SecuritySystemModel {

  // Define item types for communication
  item def DoorState {
    attribute isOpen : Boolean;
  }

  item def AlarmCommand {
    attribute activate : Boolean;
  }

  // Define the basic components
  part def DoorSensor {
    // A DoorSensor detects the state of the door and outputs it.
    flow output doorState : DoorState;
  }

  part def Alarm {
    // An Alarm receives a command to activate.
    flow input alarmCommand : AlarmCommand;
  }

  // Define a controller part to manage the logic between the sensor and the alarm.
  part def SecurityController {
    // Receives the door state from the sensor.
    flow input doorStateIn : DoorState;
    // Outputs the alarm command to the alarm.
    flow output alarmCommandOut : AlarmCommand;
  }

  // Define the overall Security System
  part def SecuritySystem {
    // Internal parts of the SecuritySystem
    part doorSensor : DoorSensor;
    part alarm : Alarm;
    part controller : SecurityController;

    // Define the flows (connections) between the internal parts.

    // Connect the DoorSensor's output to the SecurityController's input.
    flow connectSensorToController {
      from doorSensor.doorState;
      to controller.doorStateIn;
    }

    // Connect the SecurityController's output to the Alarm's input.
    flow connectControllerToAlarm {
      from controller.alarmCommandOut;
      to alarm.alarmCommand;
    }
  }
}
