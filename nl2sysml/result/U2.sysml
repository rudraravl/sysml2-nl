// Create a model for a drone with a battery, a motor, and an altitude sensor.
```sysml
package DroneModel {

  part def Drone {
    part battery: Battery;
    part motor: Motor;
    part altitudeSensor: AltitudeSensor;
  }

  part def Battery {
    // Attributes or further parts can be added here
  }

  part def Motor {
    // Attributes or further parts can be added here
  }

  part def AltitudeSensor {
    // Attributes or further parts can be added here
  }

}
```
