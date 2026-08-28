package Control4HomeAutomation {
    private import ScalarValues::*;
    private import ISQ::*;
    
    item def Command;
    item def Status;
    item def Alert;
    attribute def SceneComplete;
    attribute def TempUpdate;
    attribute def TargetReached;
    attribute def ArmHome;
    attribute def ArmAway;
    attribute def Disarm;
    attribute def PerimeterBreach;
    attribute def AnyBreach;
    
    attribute def Brightness :> Real;
    attribute def Volume :> Real;
    
    enum def HvacMode {
        enum heating;
        enum cooling;
        enum automatic;
        enum off;
    }
    enum def SecurityMode {
        enum disarmed;
        enum armedHome;
        enum armedAway;
    }
    enum def SceneName {
        enum None;
        enum GoodMorning;
        enum MovieTime;
        enum Away;
    }
    
    port def NetworkPort {
        in cmd : Command;
        out stat : Status;
    }
    port def AlertPort {
        out alert : Alert;
    }
    
    part def MainController {
        port netPort : NetworkPort;
        attribute activeScene : SceneName = SceneName::None;
        
        exhibit state controllerStates {
            state idle;
            state executingScene;
            transition idle_to_executing
                first idle
                accept cmd : Command
                then executingScene;
            transition executing_to_idle
                first executingScene
                accept SceneComplete
                then idle;
        }
        
        action executeGoodMorning;
        action executeMovieTime;
        action executeAway;
    }
    
    part def LightingController {
        attribute zoneId : Integer;
        attribute brightness : Brightness = 0;
        port netPort : NetworkPort;
        
        action turnOn;
        action turnOff;
        action dim {
            in level : Brightness;
        }
    }
    
    part def Thermostat {
        attribute zoneId : Integer;
        attribute currentTemp : ISQ::Temperature;
        attribute setTemp : ISQ::Temperature = 22 [K];
        attribute mode : HvacMode = HvacMode::automatic;
        port netPort : NetworkPort;
        
        exhibit state hvacStates {
            state idle;
            state regulating;
            transition idle_to_regulating
                first idle
                accept TempUpdate
                then regulating;
            transition regulating_to_idle
                first regulating
                accept TargetReached
                then idle;
        }
    }
    
    part def SecurityPanel {
        attribute mode : SecurityMode = SecurityMode::disarmed;
        port netPort : NetworkPort;
        port alertPort : AlertPort;
        
        exhibit state securityStates {
            state disarmed;
            state armedHome;
            state armedAway;
            state alarmTriggered;
            
            transition disarmed_to_armedHome
                first disarmed
                accept ArmHome
                then armedHome;
            transition disarmed_to_armedAway
                first disarmed
                accept ArmAway
                then armedAway;
            transition armedHome_to_alarm
                first armedHome
                accept PerimeterBreach
                then alarmTriggered;
            transition armedAway_to_alarm
                first armedAway
                accept AnyBreach
                then alarmTriggered;
            transition alarm_to_disarmed
                first alarmTriggered
                accept Disarm
                then disarmed;
        }
    }
    
    part def AudioZone {
        attribute zoneId : Integer;
        attribute volume : Volume = 0;
        port netPort : NetworkPort;
        
        action play;
        action pause;
        action stop;
        action setVolume {
            in vol : Volume;
        }
    }
    
    part def AudioController {
        part zones : AudioZone[6];
        port netPort : NetworkPort;
    }
    
    part def Touchscreen {
        attribute location : String;
        port netPort : NetworkPort;
    }
    
    part def HomeAutomationSystem {
        part mainController : MainController;
        part lightingControllers : LightingController[8];
        part thermostats : Thermostat[3];
        part securityPanel : SecurityPanel;
        part audioController : AudioController;
        part touchscreens : Touchscreen[3];
        
        connect mainController.netPort to lightingControllers.netPort;
        connect mainController.netPort to thermostats.netPort;
        connect mainController.netPort to securityPanel.netPort;
        connect mainController.netPort to audioController.netPort;
        connect touchscreens.netPort to mainController.netPort;
    }
    
    requirement def ContinuousOperationReq {
        doc /* The system shall be continuously operational, monitoring device health and regulating climate. */
        attribute operational : Boolean;
        require constraint { operational == true }
    }
    requirement def CoordinatedScenesReq {
        doc /* The system shall execute coordinated scenes across multiple subsystems via a single command. */
        attribute sceneExecuted : Boolean;
        require constraint { sceneExecuted == true }
    }
    requirement def SubsystemControlReq {
        doc /* The system shall allow independent control of lighting, climate, security, and audio. */
        attribute lightingControlled : Boolean;
        attribute climateControlled : Boolean;
        attribute securityControlled : Boolean;
        attribute audioControlled : Boolean;
        require constraint { 
            lightingControlled and climateControlled and securityControlled and audioControlled 
        }
    }
    
    part automationSystem : HomeAutomationSystem {
        satisfy continuousOp : ContinuousOperationReq;
        satisfy coordinatedScenes : CoordinatedScenesReq;
        satisfy subsystemCtrl : SubsystemControlReq;
    }
}
