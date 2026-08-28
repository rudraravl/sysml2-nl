package StarshipDeliveryRobot {
    private import ISQ::*;
    private import ScalarValues::*;
    
    attribute def DeliveryOrder {
        pickupLocation : LengthValue;
        deliveryLocation : LengthValue;
        cargoType : String;
    }
    
    attribute def OrderReceived;
    attribute def ArrivedAtPickup;
    attribute def CargoSecured;
    attribute def ArrivedAtDelivery;
    attribute def CargoReleased;
    attribute def ObstacleDetected;
    attribute def ObstacleAvoided;
    attribute def BatteryLow;
    attribute def ChargingComplete;
    
    item def SensorData;
    item def RouteData;
    
    attribute def MotorCommand {
        speed : SpeedValue;
        steeringAngle : Real;
    }
    
    part def CargoCompartment {
        attribute isLocked : Boolean = true;
        attribute isTemperatureControlled : Boolean = true;
        attribute temperature : TemperatureValue;
        port cargoCtrlPort {
            in attribute code : String;
            out attribute releaseSignal : CargoReleased;
        }
        perform action unlockCargo {
            in attribute code : String;
        }
        perform action lockCargo { }
    }
    
    part def LidarSensor {
        port dataOut { out data : SensorData; }
    }
    
    part def CameraArray {
        port dataOut { out data : SensorData; }
    }
    
    part def UltrasonicSensor {
        port dataOut { out data : SensorData; }
    }
    
    part def GPSReceiver {
        port dataOut { out data : SensorData; }
    }
    
    part def IMU {
        port dataOut { out data : SensorData; }
    }
    
    part def WirelessCommunicationModule {
        port orderIn { in attribute order : DeliveryOrder; }
        port orderOut { out attribute order : DeliveryOrder; }
        perform action receiveOrder {
            out attribute order : DeliveryOrder;
        }
    }
    
    part def PathPlanningSystem {
        port sensorDataIn { in data : SensorData; }
        port routeOut { out route : RouteData; }
        port obstacleOut { out obstacle : ObstacleDetected; }
        port powerIn { in attribute power : PowerValue; }
        perform action calculateRoute {
            in sensorData : SensorData;
            out route : RouteData;
        }
    }
    
    part def MotionController {
        port routeIn { in route : RouteData; }
        port commandOut { out command : MotorCommand; }
        port powerIn { in attribute power : PowerValue; }
        perform action translateRouteToCommands {
            in route : RouteData;
            out command : MotorCommand;
        }
        perform action emergencyStop { }
    }
    
    part def ElectricMotor {
        port commandIn { in command : MotorCommand; }
    }
    
    part def Wheel;
    
    part def Battery {
        attribute capacity : EnergyValue;
        attribute stateOfCharge : Real;
        port powerOut { out attribute power : PowerValue; }
        port statusOut { out attribute isLow : Boolean; }
    }
    
    part def DeliveryRobot {
        part cargoCompartment : CargoCompartment;
        part lidar : LidarSensor;
        part cameras : CameraArray;
        part ultrasonicSensors : UltrasonicSensor;
        part gps : GPSReceiver;
        part imu : IMU;
        part commModule : WirelessCommunicationModule;
        part pathPlanner : PathPlanningSystem;
        part motionController : MotionController;
        part motors[6] : ElectricMotor;
        part wheels[6] : Wheel;
        part battery : Battery;
        
        connect lidar.dataOut to pathPlanner.sensorDataIn;
        connect cameras.dataOut to pathPlanner.sensorDataIn;
        connect ultrasonicSensors.dataOut to pathPlanner.sensorDataIn;
        connect gps.dataOut to pathPlanner.sensorDataIn;
        connect imu.dataOut to pathPlanner.sensorDataIn;
        
        connect pathPlanner.routeOut to motionController.routeIn;
        connect motionController.commandOut to motors.commandIn;
        
        connect battery.powerOut to motionController.powerIn;
        connect battery.powerOut to pathPlanner.powerIn;
        
        exhibit state robotStates {
            entry; then idle;
            
            state idle;
            accept OrderReceived then navigatingToPickup;
            
            state navigatingToPickup;
            accept ArrivedAtPickup then securingCargo;
            accept ObstacleDetected then obstacleAvoidance;
            accept BatteryLow then returningToBase;
            
            state securingCargo;
            accept CargoSecured then navigatingToDelivery;
            
            state navigatingToDelivery;
            accept ArrivedAtDelivery then awaitingRelease;
            accept ObstacleDetected then obstacleAvoidance;
            accept BatteryLow then returningToBase;
            
            state awaitingRelease;
            accept CargoReleased then idle;
            
            state obstacleAvoidance;
            accept ObstacleAvoided then navigatingToDelivery;
            
            state returningToBase;
            accept ChargingComplete then idle;
        }
    }
    
    requirement def AutonomousDeliveryRequirement {
        subject robot : DeliveryRobot;
        doc /* The robot shall autonomously execute a delivery mission from order receipt to final cargo release without human intervention. */
    }
    
    requirement def ObstacleAvoidanceRequirement {
        subject robot : DeliveryRobot;
        doc /* The robot shall detect unexpected obstacles and execute an evasive maneuver or come to a complete stop to prevent collision. */
    }
    
    requirement def CargoSecurityRequirement {
        subject compartment : CargoCompartment;
        doc /* The cargo compartment shall remain locked until the recipient provides the correct security code. */
    }
}
