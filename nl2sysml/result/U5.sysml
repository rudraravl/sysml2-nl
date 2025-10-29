// Model a drone system with GPS navigation, a camera module, and an obstacle avoidance function.
package DroneSystem {
    part def Drone {
        part gpsModule;
        part cameraModule;
        part obstacleAvoidanceSensor;
        part flightControlUnit;
        part body;
        part engines[4];
    }
}
