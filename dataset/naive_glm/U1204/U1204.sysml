package AutonomousServiceRobot {
    import ScalarValues::*;
    import ISQ::*;
    
    value def Length :> ISQ::Length;
    value def Mass :> ISQ::Mass;
    value def Speed :> ISQ::Speed;
    value def Voltage :> ISQ::ElectricPotential;
    value def Force :> ISQ::Force;
    value def Percentage :> Real;
    
    item def ElectricalPower;
    item def ControlSignal;
    item def SensorData;
    
    port def PowerOutPort {
        out item power : ElectricalPower;
    }
    port def PowerInPort {
        in item power : ElectricalPower;
    }
    port def CommandOutPort {
        out item command : ControlSignal;
    }
    port def CommandInPort {
        in item command : ControlSignal;
    }
    port def DataOutPort {
        out item data : SensorData;
    }
    port def DataInPort {
        in item data : SensorData;
    }
    
    requirement def RobotSpecs {
        attribute height : Length = 1.2 [m];
        attribute weight : Mass = 85 [kg];
        attribute maxSpeed : Speed = 2.0 [m/s];
        attribute armReach : Length = 0.8 [m];
        attribute armPayload : Mass = 15 [kg];
        attribute lidarRange : Length = 30.0 [m];
        attribute batteryVoltage : Voltage = 48.0 [V];
    }
    
    part def Battery {
        attribute voltage : Voltage = 48.0 [V];
        attribute chargeLevel : Percentage = 100.0;
        port powerOut : PowerOutPort;
    }
    
    part def DriveWheel {
        port powerIn : PowerInPort;
        port commandIn : CommandInPort;
    }
    
    part def SteeringSystem {
        port powerIn : PowerInPort;
        port commandIn : CommandInPort;
    }
    
    part def MobilePlatform {
        attribute maxSpeed : Speed = 2.0 [m/s];
        port powerIn : PowerInPort;
        port commandIn : CommandInPort;
        port dataOut : DataOutPort;
        
        part leftWheel : DriveWheel;
        part rightWheel : DriveWheel;
        part steering : SteeringSystem;
        
        connection powerToLeftWheel connect powerIn to leftWheel.powerIn;
        connection powerToRightWheel connect powerIn to rightWheel.powerIn;
        connection powerToSteering connect powerIn to steering.powerIn;
        connection commandToLeftWheel connect commandIn to leftWheel.commandIn;
        connection commandToRightWheel connect commandIn to rightWheel.commandIn;
        connection commandToSteering connect commandIn to steering.commandIn;
    }
    
    part def Joint {
        port powerIn : PowerInPort;
        port commandIn : CommandInPort;
    }
    
    part def Gripper {
        attribute maxForce : Force = 50.0 [N];
        port powerIn : PowerInPort;
        port commandIn : CommandInPort;
    }
    
    part def ManipulatorArm {
        attribute reach : Length = 0.8 [m];
        attribute payload : Mass = 15.0 [kg];
        port powerIn : PowerInPort;
        port commandIn : CommandInPort;
        
        part joints : Joint[6];
        part gripper : Gripper;
        
        connection powerToJoints connect powerIn to joints.powerIn;
        connection powerToGripper connect powerIn to gripper.powerIn;
        connection commandToJoints connect commandIn to joints.commandIn;
        connection commandToGripper connect commandIn to gripper.commandIn;
    }
    
    part def LidarScanner {
        attribute range : Length = 30.0 [m];
        port powerIn : PowerInPort;
        port dataOut : DataOutPort;
    }
    
    part def Camera {
        port powerIn : PowerInPort;
        port dataOut : DataOutPort;
    }
    
    part def ProximitySensor {
        port powerIn : PowerInPort;
        port dataOut : DataOutPort;
    }
    
    part def SensorSuite {
        port powerIn : PowerInPort;
        port dataOut : DataOutPort;
        
        part lidar : LidarScanner;
        part frontCamera : Camera;
        part gripperCamera : Camera;
        part proximitySensors : ProximitySensor[4];
        
        connection powerToLidar connect powerIn to lidar.powerIn;
        connection powerToFrontCam connect powerIn to frontCamera.powerIn;
        connection powerToGripperCam connect powerIn to gripperCamera.powerIn;
        connection powerToProx connect powerIn to proximitySensors.powerIn;
        
        connection lidarData connect lidar.dataOut to dataOut;
        connection frontCamData connect frontCamera.dataOut to dataOut;
        connection gripperCamData connect gripperCamera.dataOut to dataOut;
        connection proxData connect proximitySensors.dataOut to dataOut;
    }
    
    part def Controller {
        port powerIn : PowerInPort;
        port dataIn : DataInPort;
        port commandIn : CommandInPort;
        port commandOut : CommandOutPort;
        
        attribute destinationReached : Boolean = false;
        attribute taskComplete : Boolean = false;
        attribute errorDetected : Boolean = false;
    }
    
    part def AutonomousServiceRobot {
        satisfy RobotSpecs;
        
        attribute height : Length = 1.2 [m];
        attribute weight : Mass = 85.0 [kg];
        
        attribute commandReceived : Boolean = false;
        
        port commandIn : CommandInPort;
        
        part battery : Battery;
        part controller : Controller;
        part platform : MobilePlatform;
        part arm : ManipulatorArm;
        part sensors : SensorSuite;
        
        connection powerToController connect battery.powerOut to controller.powerIn;
        connection powerToPlatform connect battery.powerOut to platform.powerIn;
        connection powerToArm connect battery.powerOut to arm.powerIn;
        connection powerToSensors connect battery.powerOut to sensors.powerIn;
        
        connection sensorDataToController connect sensors.dataOut to controller.dataIn;
        
        connection commandToPlatform connect controller.commandOut to platform.commandIn;
        connection commandToArm connect controller.commandOut to arm.commandIn;
        connection externalCommandToController connect commandIn to controller.commandIn;
        
        state def RobotStates {
            state idle;
            state navigating;
            state executing;
            state charging;
            state error;
            
            transition initial_to_idle initial to idle;
            transition idle_to_navigating 
                from idle to navigating 
                when commandReceived;
            transition navigating_to_executing 
                from navigating to executing 
                when controller.destinationReached;
            transition executing_to_idle 
                from executing to idle 
                when controller.taskComplete;
            transition active_to_charging 
                from {navigating, executing} to charging 
                when battery.chargeLevel < 20.0;
            transition charging_to_idle 
                from charging to idle 
                when battery.chargeLevel >= 80.0;
            transition active_to_error 
                from {navigating, executing} to error 
                when controller.errorDetected;
            transition error_to_idle 
                from error to idle 
                when !controller.errorDetected;
        }
        
        part behavior : RobotStates;
    }
}
