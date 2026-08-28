package PropertySecuritySystem {
    private import ScalarValues::*;
    
    item def AccessCode;
    item def AlertMessage;
    item def ArmCommand;
    item def DisarmCommand;
    item def ResetCommand;
    item def IntrusionDetected {
        attribute severity : IncidentSeverity;
    }
    
    enum def IncidentSeverity {
        minor;
        critical;
    }
    
    attribute def Voltage :> ScalarValues::Real;
    attribute def Power :> ScalarValues::Real;
    
    port def SensorEventPort {
        out attribute intrusion : IntrusionDetected;
    }
    
    port def CommandPort {
        in attribute cmd : ScalarValues::String;
    }
    
    port def NetworkPort {
        out attribute msg : AlertMessage;
    }
    
    port def ExternalNetworkPort {
        in attribute msg : AlertMessage;
    }
    
    port def PowerPort {
        out attribute voltage : Voltage;
    }
    
    part def Sensor {
        port eventPort : SensorEventPort;
        port powerIn : ~PowerPort;
    }
    
    part def DoorSensor :> Sensor;
    part def WindowSensor :> Sensor;
    part def MotionSensor :> Sensor;
    
    part def Camera {
        port cmdPort : ~CommandPort;
        port powerIn : ~PowerPort;
        attribute hasNightVision : ScalarValues::Boolean = true;
        attribute isRecording : ScalarValues::Boolean = false;
    }
    
    part def ControlPanel {
        port ctrlPort : CommandPort;
        port powerIn : ~PowerPort;
        attribute enteredCode : AccessCode;
    }
    
    part def Siren {
        port cmdPort : ~CommandPort;
        port powerIn : ~PowerPort;
        attribute active : ScalarValues::Boolean = false;
    }
    
    part def CommunicationModule {
        port netPort : ~NetworkPort;
        port extPort : ExternalNetworkPort;
        port powerIn : ~PowerPort;
    }
    
    part def MonitoringStation {
        port rcvPort : ~ExternalNetworkPort;
    }
    
    part def BackupPowerSupply {
        port powerOut : PowerPort;
        attribute voltage : Voltage = 12;
        attribute capacity : Power = 100;
    }
    
    part def SecurityController {
        port sensorPort : ~SensorEventPort;
        port panelPort : CommandPort;
        port cameraPort : ~CommandPort;
        port sirenPort : ~CommandPort;
        port commPort : NetworkPort;
        port powerIn : ~PowerPort;
        
        attribute armed : ScalarValues::Boolean = false;
    }
    
    state def SecuritySystemStates;
    state securitySystemStates : SecuritySystemStates {
        entry; then disarmed;
        
        state disarmed;
        
        transition t1
            first disarmed
            accept ArmCommand
            then armed;
        
        state armed {
            entry; then monitoring;
            state monitoring;
            
            transition t2
                first monitoring
                accept IntrusionDetected
                then responding;
            
            state responding {
                do action handleIncident {
                    in severity : IncidentSeverity;
                }
            }
            
            transition t3
                first responding
                accept ResetCommand
                then monitoring;
        }
        
        transition t4
            first armed
            accept DisarmCommand
            then disarmed;
    }
    
    requirement def BackupPowerRequirement {
        doc /* The system shall include a backup power supply to ensure operation during power outages. */
        subject supply : BackupPowerSupply;
    }
    
    requirement def RedundantSirenRequirement {
        doc /* The system shall include at least two sirens for redundancy. */
        subject siren1 : Siren;
        subject siren2 : Siren;
    }
    
    part securitySystem {
        part controller : SecurityController {
            perform securitySystemStates;
        }
        
        part backupPower : BackupPowerSupply;
        part controlPanel : ControlPanel;
        part frontDoorSensor : DoorSensor;
        part backWindowSensor : WindowSensor;
        part livingRoomMotionSensor : MotionSensor;
        part hallwayMotionSensor : MotionSensor;
        
        part frontCamera : Camera;
        part backyardCamera : Camera;
        
        part siren1 : Siren;
        part siren2 : Siren;
        
        part commModule : CommunicationModule;
        part monitoringStation : MonitoringStation;
        
        connect controlPanel.ctrlPort to controller.panelPort;
        
        connect frontDoorSensor.eventPort to controller.sensorPort;
        connect backWindowSensor.eventPort to controller.sensorPort;
        connect livingRoomMotionSensor.eventPort to controller.sensorPort;
        connect hallwayMotionSensor.eventPort to controller.sensorPort;
        
        connect controller.cameraPort to frontCamera.cmdPort;
        connect controller.cameraPort to backyardCamera.cmdPort;
        
        connect controller.sirenPort to siren1.cmdPort;
        connect controller.sirenPort to siren2.cmdPort;
        
        connect controller.commPort to commModule.netPort;
        connect commModule.extPort to monitoringStation.rcvPort;
        
        connect backupPower.powerOut to controller.powerIn;
        connect backupPower.powerOut to controlPanel.powerIn;
        connect backupPower.powerOut to commModule.powerIn;
        connect backupPower.powerOut to frontCamera.powerIn;
        connect backupPower.powerOut to backyardCamera.powerIn;
        connect backupPower.powerOut to siren1.powerIn;
        connect backupPower.powerOut to siren2.powerIn;
        connect backupPower.powerOut to frontDoorSensor.powerIn;
        connect backupPower.powerOut to backWindowSensor.powerIn;
        connect backupPower.powerOut to livingRoomMotionSensor.powerIn;
        connect backupPower.powerOut to hallwayMotionSensor.powerIn;
    }
    
    satisfy BackupPowerRequirement by securitySystem::backupPower;
    satisfy RedundantSirenRequirement by securitySystem::siren1;
    satisfy RedundantSirenRequirement by securitySystem::siren2;
}
