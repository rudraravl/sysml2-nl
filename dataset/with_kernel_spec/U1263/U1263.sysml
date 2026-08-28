package IndustrialRobotSafetySystem {
    private import ScalarValues::*;
    
    item def SensorData {
        attribute distance : Real;
        attribute confidence : Real;
    }
    
    item def RobotCommand {
        attribute targetSpeed : Real;
        attribute safeguardedStop : Boolean;
        attribute emergencyStop : Boolean;
    }
    
    item def ManualResetSignal;
    
    part def LaserScanner {
        attribute maxRange : Real = 5.0;
        port sensorOut {
            out sensorData : SensorData;
        }
    }
    
    part def VisionCamera {
        attribute maxRange : Real = 10.0;
        port sensorOut {
            out sensorData : SensorData;
        }
    }
    
    part def ProximitySensor {
        attribute maxRange : Real = 1.0;
        port sensorOut {
            out sensorData : SensorData;
        }
    }
    
    part def ForceTorqueSensor {
        port forceOut {
            out forceData : Real;
        }
    }
    
    part def CollaborativeRobot {
        port cmdIn {
            in robotCommand : RobotCommand;
        }
        action executeTask;
        action reduceSpeed;
        action safeguardedStopAction;
        action emergencyStopAction;
        
        exhibit state robotStates {
            entry; then normalOperation;
            state normalOperation {
                do executeTask;
            }
            accept RobotCommand via cmdIn
                then normalOperation;
        }
    }
    
    part def SafetyController {
        port laserIn {
            in sensorData : SensorData;
        }
        port cameraIn {
            in sensorData : SensorData;
        }
        port proximityIn {
            in sensorData : SensorData;
        }
        port forceIn {
            in forceData : Real;
        }
        port cmdOut {
            out robotCommand : RobotCommand;
        }
        port resetIn {
            in resetSignal : ManualResetSignal;
        }
        ref part robot : CollaborativeRobot;
        
        attribute warningZoneMax : Real = 3.5;
        attribute restrictedZoneMax : Real = 2.0;
        attribute prohibitedZoneMax : Real = 0.5;
        
        attribute currentDistance : Real;
        attribute currentForce : Real;
        
        exhibit state safetyStates {
            entry; then collaborative;
            state collaborative;
            accept when currentDistance <= warningZoneMax and currentDistance > restrictedZoneMax
                do send new RobotCommand() to robot
                then warning;
            state warning;
            accept when currentDistance <= restrictedZoneMax and currentDistance > prohibitedZoneMax
                do send new RobotCommand() to robot
                then restricted;
            state restricted;
            accept when currentDistance <= prohibitedZoneMax
                do send new RobotCommand() to robot
                then prohibited;
            state prohibited;
            accept ManualResetSignal via resetIn
                then collaborative;
        }
    }
    
    part safetySystem {
        part laserScanners[4] : LaserScanner;
        part visionCameras[2] : VisionCamera;
        part proximitySensors[8] : ProximitySensor;
        part forceTorqueSensor : ForceTorqueSensor;
        part safetyController : SafetyController;
        part robot : CollaborativeRobot;
        part resetButton {
            port resetOut {
                out resetSignal : ManualResetSignal;
            }
        }
        
        bind safetyController.robot = robot;
        
        flow laserFlow of SensorData from laserScanners.sensorOut.sensorData to safetyController.laserIn.sensorData;
        flow cameraFlow of SensorData from visionCameras.sensorOut.sensorData to safetyController.cameraIn.sensorData;
        flow proximityFlow of SensorData from proximitySensors.sensorOut.sensorData to safetyController.proximityIn.sensorData;
        flow forceFlow of Real from forceTorqueSensor.forceOut.forceData to safetyController.forceIn.forceData;
        flow commandFlow of RobotCommand from safetyController.cmdOut.robotCommand to robot.cmdIn.robotCommand;
        flow resetFlow of ManualResetSignal from resetButton.resetOut.resetSignal to safetyController.resetIn.resetSignal;
    }
    
    req def SafetyRequirement {
        doc "The system must prevent collisions between the robot and human workers.";
    }
    
    req def EmergencyStopRequirement :> SafetyRequirement {
        doc "If a worker enters the prohibited zone (<0.5m), an emergency stop must be triggered immediately.";
    }
    
    req def SafeguardedStopRequirement :> SafetyRequirement {
        doc "If a worker enters the restricted zone (1-2m), a safeguarded stop must be initiated.";
    }
    
    req def SpeedReductionRequirement :> SafetyRequirement {
        doc "If a worker enters the warning zone (2-3.5m), the robot must reduce speed.";
    }
    
    req def ForceLimitationRequirement :> SafetyRequirement {
        doc "The force-torque sensor shall ensure that any incidental contact force remains below 150 N to prevent injury.";
    }
}
