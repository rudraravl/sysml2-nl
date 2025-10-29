// Model a drone system with GPS navigation, a camera module, and an obstacle avoidance function.
```sysml
package DroneSystem {

  part def Drone {
    // Sub-parts of the Drone system
    part gpsModule: GPSNavigationModule;
    part camera: CameraModule;
    part obstacleSensor: ObstacleAvoidanceSensor;
    part flightController: FlightController;

    // Flows representing data exchange between parts
    flow gpsPositionData from gpsModule to flightController;
    flow cameraStreamData from camera to flightController;
    flow obstacleDetectionData from obstacleSensor to flightController;
    flow controlCommands from flightController to gpsModule, camera, obstacleSensor;
  }

  part def GPSNavigationModule {
    // Provides location and navigation data
    attribute currentLocation: Location;
    attribute targetWaypoint: Location;
  }

  part def CameraModule {
    // Captures images and video
    attribute videoResolution: String;
    attribute recordingStatus: Boolean;
  }

  part def ObstacleAvoidanceSensor {
    // Detects obstacles in the drone's path
    attribute detectedObstacleDistance: Real;
    attribute obstacleDetected: Boolean;
  }

  part def FlightController {
    // Processes data from sensors and controls drone operation
    attribute currentFlightMode: String;
    attribute avoidanceManeuverActive: Boolean;
  }

  // Example type definitions for attributes
  type def Location {
    attribute latitude: Real;
    attribute longitude: Real;
    attribute altitude: Real;
  }

}
```
