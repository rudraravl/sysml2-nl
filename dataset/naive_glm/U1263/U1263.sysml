package RobotSafetySystem {
    import ScalarValues::*;
    import ISQ::*;

    // Value Types
    value def Distance :> Real { unit 'm'; }
    value def Speed :> Real { unit 'm/s'; }
    value def Force :> Real { unit 'N'; }
    value def Torque :> Real { unit 'Nm'; }

    // Items
    item def SensorData;
    item def LaserScanData :> SensorData;
    item def VisionData :> SensorData;
    item def ProximityData :> SensorData;
    item def ForceTorqueData :> SensorData;
    item def WorkerPosition {
        attr distance : Distance;
    }
    item def RobotCommand {
        attr targetSpeed : Speed;
        attr emergencyStop : Boolean;
        attr safeguardedStop : Boolean;
    }

    // Requirements
    requirement def SafetySystemRequirements {
        subject system : RobotSafetySystem;
        
        requirement def SensorRedundancyReq {
            subject network : SensorNetwork;
            doc /* The system must use multiple sensor types for redundancy. */
            require network.laserScanners.size == 4 and network.visionCameras.size == 2 and network.proximitySensors.size == 8;
        }
        
        requirement def ZoneControlReq {
            subject controller : SafetyController;
            doc /* The controller must enforce nested safety zones. */
            require controller.zoneStateMachine.Warning.isActive when controller.minWorkerDistance >= 2.0 and controller.minWorkerDistance <= 3.5;
            require controller.zoneStateMachine.Restricted.isActive when controller.minWorkerDistance >= 1.0 and controller.minWorkerDistance < 2.0;
            require controller.zoneStateMachine.Prohibited.isActive when controller.minWorkerDistance < 0.5;
        }
        
        requirement def ForceThresholdReq {
            subject sensor : ForceTorqueSensor;
            doc /* Force must remain below safe injury thresholds. */
            require sensor.measuredForce <= 150.0;
        }
    }

    // Parts
    part def LaserScanner {
        port out dataOut : LaserScanData;
        attr scanRange : Distance = 5.0;
    }
    
    part def VisionCamera {
        port out dataOut : VisionData;
        attr fieldOfView : Real = 60.0;
    }
    
    part def ProximitySensor {
        port out dataOut : ProximityData;
        attr detectionRange : Distance = 1.0;
    }
    
    part def ForceTorqueSensor {
        port out dataOut : ForceTorqueData;
        attr measuredForce : Force;
        attr measuredTorque : Torque;
    }
    
    part def SensorNetwork {
        part laserScanners : LaserScanner[4];
        part visionCameras : VisionCamera[2];
        part proximitySensors : ProximitySensor[8];
        
        port out aggregatedData : SensorData;
        
        action def AggregateData {
            in data : SensorData[*];
            out aggregated : SensorData;
        }
    }
    
    part def SafetyController {
        port in sensorDataIn : SensorData;
        port in forceTorqueDataIn : ForceTorqueData;
        port out commandOut : RobotCommand;
        
        attr minWorkerDistance : Distance;
        
        state machine ZoneStateMachine {
            entry then Collaborative;
            state Collaborative {
                entry { commandOut.targetSpeed = 1.0; commandOut.emergencyStop = false; commandOut.safeguardedStop = false; }
                transition to Warning when minWorkerDistance <= 3.5 and minWorkerDistance > 2.0;
            }
            state Warning {
                entry { commandOut.targetSpeed = 0.5; commandOut.emergencyStop = false; commandOut.safeguardedStop = false; }
                transition to Collaborative when minWorkerDistance > 3.5;
                transition to Restricted when minWorkerDistance <= 2.0 and minWorkerDistance > 1.0;
            }
            state Restricted {
                entry { commandOut.safeguardedStop = true; commandOut.emergencyStop = false; }
                transition to Warning when minWorkerDistance > 2.0;
                transition to Prohibited when minWorkerDistance <= 0.5;
            }
            state Prohibited {
                entry { commandOut.emergencyStop = true; }
                transition to Restricted when manualReset == true;
            }
        }
        
        attribute manualReset : Boolean = false;
        
        action def ProcessSensorData {
            in data : SensorData;
            in ftData : ForceTorqueData;
            out command : RobotCommand;
        }
    }
    
    part def CollaborativeRobot {
        part forceTorqueSensor : ForceTorqueSensor;
        port in commandIn : RobotCommand;
        port out forceTorqueOut : ForceTorqueData;
        
        attr currentSpeed : Speed;
        attr axes : Integer = 6;
        
        connection ftToPort connect forceTorqueSensor.dataOut to forceTorqueOut;
        
        state machine RobotOperation {
            entry then NormalOperation;
            state NormalOperation {
                transition to SafeguardedStop when commandIn.safeguardedStop == true;
                transition to EmergencyStop when commandIn.emergencyStop == true;
            }
            state SafeguardedStop {
                transition to NormalOperation when commandIn.safeguardedStop == false;
                transition to EmergencyStop when commandIn.emergencyStop == true;
            }
            state EmergencyStop {
                transition to NormalOperation when manualReset == true;
            }
        }
        
        attribute manualReset : Boolean = false;
    }
    
    part def RobotSafetySystem {
        part sensorNetwork : SensorNetwork;
        part safetyController : SafetyController;
        part robot : CollaborativeRobot;
        
        satisfy SafetySystemRequirements::SensorRedundancyReq by sensorNetwork;
        satisfy SafetySystemRequirements::ZoneControlReq by safetyController;
        satisfy SafetySystemRequirements::ForceThresholdReq by robot.forceTorqueSensor;
        
        connection sensorToController connect sensorNetwork.aggregatedData to safetyController.sensorDataIn;
        connection controllerToRobot connect safetyController.commandOut to robot.commandIn;
        connection robotToController connect robot.forceTorqueOut to safetyController.forceTorqueDataIn;
    }
}
