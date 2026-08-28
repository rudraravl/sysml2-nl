package UAVSystem {
    import ScalarValues::*;

    attribute def Distance :> Real {
        attribute unit : String = "m";
    }
    attribute def Speed :> Real {
        attribute unit : String = "m/s";
    }
    attribute def BatteryLevel :> Real {
        attribute unit : String = "%";
    }
    attribute def FlightDuration :> Real {
        attribute unit : String = "min";
    }
    attribute def Angle :> Real {
        attribute unit : String = "deg";
    }

    item def TelemetryData {
        attribute position : String;
        attribute speed : Speed;
        attribute batteryLevel : BatteryLevel;
        attribute systemHealth : String;
    }

    item def MissionPlan {
        attribute waypoints : String;
        attribute homePosition : String;
    }

    item def Command {
        attribute type : String;
    }

    port def TelemetryPort {
        out telemetry : TelemetryData;
    }

    port def CommandPort {
        in command : Command;
        in missionPlan : MissionPlan;
    }

    part def Airframe {
        attribute material : String = "Carbon Fiber";
    }

    part def Propeller {
        attribute diameter : Distance = 0.25;
    }

    part def BrushlessMotor {
        port in speedCommand : Real;
        attribute maxRPM : Real = 10000;
    }

    part def ESC {
        port in throttleCommand : Real;
        port out speedCommand : Real;
    }

    part def Battery {
        attribute type : String = "Lithium-Polymer";
        attribute capacity_mAh : Real = 5000;
        attribute currentLevel : BatteryLevel = 100;
        port out powerSupply : Real;
    }

    part def GPSReceiver {
        port out position : String;
    }

    part def IMU {
        attribute roll : Angle;
        attribute pitch : Angle;
        attribute yaw : Angle;
        port out orientation : String;
    }

    part def ObstacleAvoidanceSensor {
        attribute range : Distance = 15;
        port out obstacleDistance : Distance;
    }

    part def Camera {
        attribute resolution : String = "4K";
        port out videoStream : String;
    }

    part def RadioTransceiver {
        attribute range : Distance = 10000;
        port telemetryOut : TelemetryPort;
        port commandIn : CommandPort;
    }

    part def FlightController {
        port commandIn : CommandPort;
        port telemetryOut : TelemetryPort;
        
        part gps : GPSReceiver;
        part imu : IMU;
        part obstacleSensor : ObstacleAvoidanceSensor;
        part camera : Camera;
        part radio : RadioTransceiver;
        
        port out motorCommands[4] : Real;
        
        attribute batteryLevel : BatteryLevel;
        attribute currentCommand : String;
        
        state def FlightStateMachine {
            entry; then PreFlightCheck;
            
            state PreFlightCheck;
            transition from PreFlightCheck to Armed when currentCommand == "Arm";
            
            state Armed;
            transition from Armed to Takeoff when currentCommand == "Takeoff";
            
            state Takeoff;
            transition from Takeoff to Navigating when currentCommand == "TakeoffComplete";
            
            state Navigating;
            transition from Navigating to Loitering when currentCommand == "Loiter";
            transition from Navigating to ReturnToLaunch when batteryLevel <= 20 or currentCommand == "Return";
            
            state Loitering;
            transition from Loitering to Navigating when currentCommand == "Continue";
            transition from Loitering to ReturnToLaunch when batteryLevel <= 20;
            
            state ReturnToLaunch;
            transition from ReturnToLaunch to Landing when currentCommand == "Land";
            
            state Landing;
            transition from Landing to PreFlightCheck when currentCommand == "Reset";
        }
        
        part stateMachine : FlightStateMachine;
    }

    part def QuadcopterUAV {
        part airframe : Airframe;
        part battery : Battery;
        part flightController : FlightController;
        part motors[4] : BrushlessMotor;
        part propellers[4] : Propeller;
        part escs[4] : ESC;
        
        connection connectESCtoMotor {
            from escs.speedCommand;
            to motors.speedCommand;
        }
        
        connection connectFCtoESC {
            from flightController.motorCommands;
            to escs.throttleCommand;
        }
        
        connection connectBatteryToFC {
            from battery.currentLevel;
            to flightController.batteryLevel;
        }
    }

    part def GroundControlStation {
        port telemetryIn : ~TelemetryPort;
        port commandOut : ~CommandPort;
    }

    part def UAVSystem {
        part uav : QuadcopterUAV;
        part gcs : GroundControlStation;
        
        connection connectRadioToGCS {
            from uav.flightController.radio.telemetryOut;
            to gcs.telemetryIn;
        }
        connection connectGCSToRadio {
            from gcs.commandOut;
            to uav.flightController.radio.commandIn;
        }
    }

    requirement def FlightTimeRequirement {
        attribute requiredDuration : FlightDuration = 30;
        subject uav : QuadcopterUAV;
        doc /* The UAV shall have a flight time of over 30 minutes. */
    }

    requirement def ObstacleAvoidanceRequirement {
        attribute requiredRange : Distance = 15;
        subject uav : QuadcopterUAV;
        doc /* The UAV shall detect and prevent collisions within a 15-meter range. */
    }

    requirement def CommunicationRangeRequirement {
        attribute requiredRange : Distance = 10000;
        subject uav : QuadcopterUAV;
        doc /* The UAV shall communicate with a ground control station up to 10 kilometers away. */
    }

    requirement def AutonomousMissionRequirement {
        subject uav : QuadcopterUAV;
        doc /* The UAV shall execute missions autonomously based on uploaded waypoints. */
    }
}
