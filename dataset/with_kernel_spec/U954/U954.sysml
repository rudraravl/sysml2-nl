package SmartHouseSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def TemperatureValue :> ISQ::TemperatureValue;
    attribute def HumidityValue :> ScalarValues::Real;
    attribute def LightLevel :> ISQ::IlluminanceValue;
    attribute def PowerValue :> ISQ::PowerValue;
    
    item def SensorData {
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute light : LightLevel;
        attribute occupancy : Boolean;
        attribute motion : Boolean;
        attribute doorOpen : Boolean;
    }
    item def ClimateCommand {
        attribute targetTemperature : TemperatureValue;
        attribute mode : ClimateMode;
    }
    item def LightCommand {
        attribute isOn : Boolean;
        attribute brightness : Real;
    }
    item def SecurityCommand {
        attribute mode : SecurityMode;
    }
    item def EnergyCommand {
        attribute powerLimit : PowerValue;
    }
    item def IntrusionAlert;
    
    enum def ClimateMode { heating; cooling; off; }
    enum def SecurityMode { disarmed; armed; alarming; }
    enum def HouseMode { home; away; night; }
    
    port def SensorOutPort {
        out sensorData : SensorData;
    }
    port def ControllerInPort {
        in sensorData : SensorData;
        in powerData : PowerValue;
    }
    port def ClimateInPort {
        in command : ClimateCommand;
    }
    port def LightingInPort {
        in command : LightCommand;
    }
    port def SecurityInPort {
        in command : SecurityCommand;
    }
    port def EnergyInPort {
        in command : EnergyCommand;
    }
    port def PowerOutPort {
        out power : PowerValue;
    }
    port def ControllerOutPort {
        out climateCmd : ClimateCommand;
        out lightCmd : LightCommand;
        out securityCmd : SecurityCommand;
        out energyCmd : EnergyCommand;
    }
    
    action def SenseEnvironment { out sensorData : SensorData; }
    action def AnalyzeData { in sensorData : SensorData; in powerData : PowerValue; out mode : HouseMode; }
    action def IssueCommands { in mode : HouseMode; out climateCmd : ClimateCommand; out lightCmd : LightCommand; out securityCmd : SecurityCommand; out energyCmd : EnergyCommand; }
    action def ControlClimate { in command : ClimateCommand; }
    action def ControlLighting { in command : LightCommand; }
    action def TrackPower { in command : EnergyCommand; out power : PowerValue; }
    
    state def HouseModes {
        entry; then home;
        state home;
        accept data : SensorData if data.occupancy == false then away;
        state away;
        accept data : SensorData if data.occupancy == true then home;
    }
    state def SecurityStates {
        entry; then disarmed;
        state disarmed;
        accept cmd : SecurityCommand if cmd.mode == SecurityMode::armed then armed;
        state armed;
        accept data : SensorData if data.motion == true then alarming;
        accept cmd : SecurityCommand if cmd.mode == SecurityMode::disarmed then disarmed;
        state alarming;
        accept cmd : SecurityCommand if cmd.mode == SecurityMode::disarmed then disarmed;
    }
    
    part def SensorNetwork {
        port sensorOut : SensorOutPort;
        perform action senseEnvironment : SenseEnvironment;
    }
    part def AutomationController {
        port controllerIn : ControllerInPort;
        port controllerOut : ControllerOutPort;
        perform action analyzeData : AnalyzeData;
        perform action issueCommands : IssueCommands;
        exhibit state houseModes : HouseModes;
    }
    part def ClimateControlSystem {
        port climateIn : ClimateInPort;
        perform action controlClimate : ControlClimate;
    }
    part def LightingSystem {
        port lightingIn : LightingInPort;
        perform action controlLighting : ControlLighting;
    }
    part def SecuritySystem {
        port securityIn : SecurityInPort;
        exhibit state securityStates : SecurityStates;
    }
    part def EnergyManagementSystem {
        port energyIn : EnergyInPort;
        port powerOut : PowerOutPort;
        perform action trackPower : TrackPower;
    }
    part def SmartHouse {
        part sensorNet : SensorNetwork;
        part controller : AutomationController;
        part climateControl : ClimateControlSystem;
        part lightingControl : LightingSystem;
        part securitySystem : SecuritySystem;
        part energyManagement : EnergyManagementSystem;
        
        flow sensorFlow of SensorData 
            from sensorNet.sensorOut.sensorData to controller.controllerIn.sensorData;
        flow powerFlow of PowerValue 
            from energyManagement.powerOut.power to controller.controllerIn.powerData;
        
        flow climateCmdFlow of ClimateCommand 
            from controller.controllerOut.climateCmd to climateControl.climateIn.command;
        flow lightCmdFlow of LightCommand 
            from controller.controllerOut.lightCmd to lightingControl.lightingIn.command;
        flow securityCmdFlow of SecurityCommand 
            from controller.controllerOut.securityCmd to securitySystem.securityIn.command;
        flow energyCmdFlow of EnergyCommand 
            from controller.controllerOut.energyCmd to energyManagement.energyIn.command;
    }
    
    requirement def ComfortRequirement {
        subject house : SmartHouse;
        doc /* The system shall maintain a comfortable temperature and humidity level. */
    }
    requirement def SecurityRequirement {
        subject house : SmartHouse;
        doc /* The security system shall detect intrusions and trigger an alarm when armed. */
    }
    requirement def EnergyEfficiencyRequirement {
        subject house : SmartHouse;
        doc /* The system shall optimize energy usage, reducing power when unoccupied. */
    }
    
    part smartHouse : SmartHouse;
    
    requirement comfortReq : ComfortRequirement {
        subject = smartHouse;
    }
    requirement securityReq : SecurityRequirement {
        subject = smartHouse;
    }
    requirement energyReq : EnergyEfficiencyRequirement {
        subject = smartHouse;
    }
}
