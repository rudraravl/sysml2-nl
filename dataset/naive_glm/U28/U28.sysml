package Vaimos {
    import ScalarValues::*;
    import ISQ::*;
    
    // Value Types
    item def Distance :> Real { unit "m"; }
    item def Velocity :> Real { unit "m/s"; }
    item def Angle :> Real { unit "deg"; }
    item def Power :> Real { unit "W"; }
    item def Energy :> Real { unit "kWh"; }
    item def Duration :> Real { unit "h"; }

    // Items
    item def NavigationData {
        attribute position : Distance;
        attribute velocity : Velocity;
        attribute orientation : Angle;
    }
    
    item def EnvironmentalData {
        attribute temperature : Real;
        attribute salinity : Real;
        attribute depth : Distance;
    }
    
    item def ThrustCommand {
        attribute thrustForce : Real;
    }
    
    item def StabilizationCommand {
        attribute pitch : Angle;
        attribute roll : Angle;
        attribute yaw : Angle;
    }
    
    item def TelemetryData {
        attribute healthStatus : String;
        attribute envData : EnvironmentalData;
    }
    
    item def Waypoint {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute depth : Distance;
    }
    
    item def PowerSupply {
        attribute voltage : Real;
        attribute current : Real;
    }

    // Ports
    port def NavDataPort { item navData : NavigationData; }
    port def SensorDataPort { item envData : EnvironmentalData; }
    port def ThrustCmdPort { item thrustCmd : ThrustCommand; }
    port def StabCmdPort { item stabCmd : StabilizationCommand; }
    port def PowerPort { item power : PowerSupply; }
    port def CommPort { item telemetry : TelemetryData; }
    
    // Interfaces
    interface def NavInterface {
        end source : NavDataPort;
        end target : NavDataPort;
    }
    interface def SensorInterface {
        end source : SensorDataPort;
        end target : SensorDataPort;
    }
    interface def ThrustInterface {
        end source : ThrustCmdPort;
        end target : ThrustCmdPort;
    }
    interface def StabInterface {
        end source : StabCmdPort;
        end target : StabCmdPort;
    }
    interface def PowerInterface {
        end source : PowerPort;
        end target : PowerPort;
    }
    interface def CommInterface {
        end source : CommPort;
        end target : CommPort;
    }

    // Parts
    part def GuidanceComputer {
        port in navInput : NavDataPort;
        port in sensorInput : SensorDataPort;
        port out thrustOutput : ThrustCmdPort;
        port out stabOutput : StabCmdPort;
        port in powerInput : PowerPort;
        port out commOutput : CommPort;
        
        attribute currentWaypoint : Waypoint;
        attribute missionComplete : Boolean = false;
        
        action def computeTrajectory {
            in nav : NavigationData;
            in sensor : EnvironmentalData;
            in waypoint : Waypoint;
            out thrust : ThrustCommand;
            out stab : StabilizationCommand;
        }
    }
    
    part def NavigationSystem {
        port out navOutput : NavDataPort;
        port in powerInput : PowerPort;
    }
    
    part def SensorArray {
        port out sensorOutput : SensorDataPort;
        port in powerInput : PowerPort;
    }
    
    part def PropulsionSystem {
        port in thrustInput : ThrustCmdPort;
        port in powerInput : PowerPort;
    }
    
    part def StabilizationSystem {
        port in stabInput : StabCmdPort;
        port in powerInput : PowerPort;
    }
    
    part def PowerManagement {
        port out powerOutput : PowerPort;
        port in batteryInput : PowerPort;
    }
    
    part def Battery {
        port out powerOutput : PowerPort;
        attribute capacity : Energy;
    }
    
    part def CommunicationModule {
        port in commInput : CommPort;
        port out commOutput : CommPort;
        port in powerInput : PowerPort;
    }
    
    part def GroundStation {
        port in commInput : CommPort;
    }
    
    part def VaimosVehicle {
        part guidanceComputer : GuidanceComputer;
        part navigationSystem : NavigationSystem;
        part sensorArray : SensorArray;
        part propulsionSystem : PropulsionSystem;
        part stabilizationSystem : StabilizationSystem;
        part powerManagement : PowerManagement;
        part battery : Battery;
        part communicationModule : CommunicationModule;
        
        interface navConn : NavInterface connect navigationSystem.navOutput to guidanceComputer.navInput;
        interface sensorConn : SensorInterface connect sensorArray.sensorOutput to guidanceComputer.sensorInput;
        interface thrustConn : ThrustInterface connect guidanceComputer.thrustOutput to propulsionSystem.thrustInput;
        interface stabConn : StabInterface connect guidanceComputer.stabOutput to stabilizationSystem.stabInput;
        interface commConn : CommInterface connect guidanceComputer.commOutput to communicationModule.commInput;
        
        interface batteryConn : PowerInterface connect battery.powerOutput to powerManagement.batteryInput;
        interface powerNavConn : PowerInterface connect powerManagement.powerOutput to navigationSystem.powerInput;
        interface powerSensorConn : PowerInterface connect powerManagement.powerOutput to sensorArray.powerInput;
        interface powerPropConn : PowerInterface connect powerManagement.powerOutput to propulsionSystem.powerInput;
        interface powerStabConn : PowerInterface connect powerManagement.powerOutput to stabilizationSystem.powerInput;
        interface powerGuidConn : PowerInterface connect powerManagement.powerOutput to guidanceComputer.powerInput;
        interface powerCommConn : PowerInterface connect powerManagement.powerOutput to communicationModule.powerInput;
        
        attribute missionDuration : Duration;
        attribute waypoints : Waypoint[0..*];
        
        state def MissionExecution {
            entry; then Idle;
            
            state Idle;
            transition from Idle to Active when start;
            
            state Active {
                entry; then Sensing;
                state Sensing;
                transition from Sensing to Computing when navInput.navData is received;
                state Computing;
                transition from Computing to Adjusting when thrustOutput.thrustCmd is sent;
                state Adjusting;
                transition from Adjusting to Sensing when sensorInput.envData is received;
            }
            
            transition from Active to Transmitting when guidanceComputer.missionComplete == true;
            
            state Transmitting;
            transition from Transmitting to Complete when communicationModule.commOutput.telemetry is sent;
            
            state Complete;
            transition from Complete to done when powerOff;
        }
    }
    
    // Requirements
    requirement def LongRangeOperation {
        attribute maxRange : Distance = 50000 [m];
        doc /* The system must be able to transmit data to a ground station up to 50 kilometers away. */
    }
    
    requirement def LongDurationOperation {
        attribute maxDuration : Duration = 24 [h];
        doc /* The system must be capable of running continuously for up to 24 hours on a single charge. */
    }
    
    requirement def AutonomousNavigation {
        doc /* The system must autonomously follow a series of pre-defined waypoints. */
    }
    
    requirement def EnvironmentalMonitoring {
        doc /* The system must gather and transmit environmental readings. */
    }
    
    requirement def VaimosRequirements {
        requirement longRange : LongRangeOperation;
        requirement longDuration : LongDurationOperation;
        requirement autonomousNav : AutonomousNavigation;
        requirement envMonitor : EnvironmentalMonitoring;
    }
    
    part def VaimosSystem {
        part vehicle : VaimosVehicle {
            satisfy VaimosRequirements;
        }
        part groundStation : GroundStation;
        
        interface groundConn : CommInterface connect vehicle.communicationModule.commOutput to groundStation.commInput;
    }
}
