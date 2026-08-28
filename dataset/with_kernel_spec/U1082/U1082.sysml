package HomeOfTheFuture {
    private import ScalarValues::*;
    
    datatype TemperatureValue :> Real;
    datatype HumidityValue :> Real;
    datatype IlluminanceValue :> Real;
    datatype PowerValue :> Real;
    datatype EnergyValue :> Real;
    datatype AirQualityValue :> Integer;
    datatype TimeValue :> Real;
    
    enum def ClimateMode { off; heating; cooling; ventilation; economy; preheat; }
    enum def LightingScene { off; morning; day; evening; night; away; }
    enum def SecurityMode { disarmed; armedAway; armedStay; alarmTriggered; }
    enum def EnergyMode { idle; solarPriority; batteryDischarge; gridImport; offPeak; }
    
    item def EnvironmentalReading {
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute airQuality : AirQualityValue;
        attribute ambientLight : IlluminanceValue;
        attribute timestamp : TimeValue;
    }
    item def OccupancyReading {
        attribute isOccupied : Boolean;
        attribute roomId : String;
        attribute timestamp : TimeValue;
    }
    item def ClimateCommand {
        attribute mode : ClimateMode;
        attribute targetTemperature : TemperatureValue;
        attribute targetHumidity : HumidityValue;
    }
    item def LightingCommand {
        attribute scene : LightingScene;
        attribute brightness : IlluminanceValue;
    }
    item def SecurityCommand {
        attribute mode : SecurityMode;
        attribute code : String;
    }
    item def EnergyCommand {
        attribute mode : EnergyMode;
        attribute batteryReserve : Real;
        attribute applianceSchedule : String;
    }
    item def AlarmAlert {
        attribute alertText : String;
        attribute severity : Integer;
    }
    item def PowerFlow {
        attribute powerLevel : PowerValue;
        attribute direction : String;
    }
    
    port def EnvironmentalDataOutPort {
        out item reading : EnvironmentalReading;
    }
    port def EnvironmentalDataInPort {
        in item reading : EnvironmentalReading;
    }
    port def OccupancyDataOutPort {
        out item reading : OccupancyReading;
    }
    port def OccupancyDataInPort {
        in item reading : OccupancyReading;
    }
    port def ClimateCmdOutPort {
        out item command : ClimateCommand;
    }
    port def ClimateCmdInPort {
        in item command : ClimateCommand;
    }
    port def LightingCmdOutPort {
        out item command : LightingCommand;
    }
    port def LightingCmdInPort {
        in item command : LightingCommand;
    }
    port def SecurityCmdOutPort {
        out item command : SecurityCommand;
    }
    port def SecurityCmdInPort {
        in item command : SecurityCommand;
    }
    port def AlarmOutPort {
        out item alert : AlarmAlert;
    }
    port def AlarmInPort {
        in item alert : AlarmAlert;
    }
    port def EnergyCmdOutPort {
        out item command : EnergyCommand;
    }
    port def EnergyCmdInPort {
        in item command : EnergyCommand;
    }
    port def PowerFlowOutPort {
        out item powerFlow : PowerFlow;
    }
    port def PowerFlowInPort {
        in item powerFlow : PowerFlow;
    }
    port def PowerFlowInOutPort {
        inout item powerFlow : PowerFlow;
    }
    port def ApplianceCmdOutPort {
        out item command : String;
    }
    port def ApplianceCmdInPort {
        in item command : String;
    }
    
    action def SenseEnvironment {
        out reading : EnvironmentalReading;
    }
    action def DetectOccupancy {
        out reading : OccupancyReading;
    }
    action def AdjustClimate;
    action def AdjustLighting;
    action def MonitorSecurity;
    action def OptimizeEnergy;
    action def GeneratePower;
    action def ChargeDischarge;
    action def GridInteraction;
    action def RunAppliances;
    action def GatherSensorData;
    action def AnalyzeAndOrchestrate;
    action def LearnRoutines;
    
    part def EnvironmentalSensor {
        port dataOut : EnvironmentalDataOutPort;
        attribute latestReading : EnvironmentalReading;
        perform action senseEnvironment : SenseEnvironment;
        exhibit state sensorStates {
            entry; then sensing;
            state sensing {
                do senseEnvironment;
            }
        }
    }
    
    part def OccupancySensor {
        port dataOut : OccupancyDataOutPort;
        attribute latestReading : OccupancyReading;
        perform action detectOccupancy : DetectOccupancy;
        exhibit state sensorStates {
            entry; then sensing;
            state sensing {
                do detectOccupancy;
            }
        }
    }
    
    part def CentralIntelligenceHub {
        port envDataIn : EnvironmentalDataInPort;
        port occDataIn : OccupancyDataInPort;
        port climateCmdOut : ClimateCmdOutPort;
        port lightingCmdOut : LightingCmdOutPort;
        port securityCmdOut : SecurityCmdOutPort;
        port energyCmdOut : EnergyCmdOutPort;
        port alarmIn : AlarmInPort;
        
        attribute userPreferences : String;
        attribute learnedPatterns : String;
        
        perform action gatherSensorData : GatherSensorData;
        perform action analyzeAndOrchestrate : AnalyzeAndOrchestrate;
        perform action learnRoutines : LearnRoutines;
        
        exhibit state hubStates {
            entry; then active;
            state active {
                do gatherSensorData;
                do analyzeAndOrchestrate;
                do learnRoutines;
            }
        }
    }
    
    part def ClimateControlSystem {
        port controlIn : ClimateCmdInPort;
        attribute currentMode : ClimateMode;
        attribute actualTemperature : TemperatureValue;
        attribute targetTemperature : TemperatureValue;
        perform action adjustClimate : AdjustClimate;
        exhibit state climateStates {
            entry; then idle;
            state idle;
            transition t_idle_to_heating
                first idle
                accept cmd : ClimateCommand via controlIn
                if cmd.mode == ClimateMode::heating
                then heating;
            transition t_idle_to_cooling
                first idle
                accept cmd : ClimateCommand via controlIn
                if cmd.mode == ClimateMode::cooling
                then cooling;
            transition t_idle_to_ventilation
                first idle
                accept cmd : ClimateCommand via controlIn
                if cmd.mode == ClimateMode::ventilation
                then ventilation;
            transition t_idle_to_economy
                first idle
                accept cmd : ClimateCommand via controlIn
                if cmd.mode == ClimateMode::economy
                then economy;
            transition t_idle_to_preheat
                first idle
                accept cmd : ClimateCommand via controlIn
                if cmd.mode == ClimateMode::preheat
                then preheat;
            state heating {
                do adjustClimate;
                transition t_heating_to_idle
                    first heating
                    accept cmd : ClimateCommand via controlIn
                    if cmd.mode == ClimateMode::off
                    then idle;
            }
            state cooling {
                do adjustClimate;
                transition t_cooling_to_idle
                    first cooling
                    accept cmd : ClimateCommand via controlIn
                    if cmd.mode == ClimateMode::off
                    then idle;
            }
            state ventilation {
                do adjustClimate;
                transition t_ventilation_to_idle
                    first ventilation
                    accept cmd : ClimateCommand via controlIn
                    if cmd.mode == ClimateMode::off
                    then idle;
            }
            state economy {
                do adjustClimate;
                transition t_economy_to_idle
                    first economy
                    accept cmd : ClimateCommand via controlIn
                    if cmd.mode == ClimateMode::off
                    then idle;
            }
            state preheat {
                do adjustClimate;
                transition t_preheat_to_idle
                    first preheat
                    accept cmd : ClimateCommand via controlIn
                    if cmd.mode == ClimateMode::off
                    then idle;
            }
        }
    }
    
    part def IntelligentLightingSystem {
        port controlIn : LightingCmdInPort;
        attribute currentScene : LightingScene;
        attribute brightness : IlluminanceValue;
        perform action adjustLighting : AdjustLighting;
        exhibit state lightingStates {
            entry; then off;
            state off;
            transition t_off_to_morning
                first off
                accept cmd : LightingCommand via controlIn
                if cmd.scene == LightingScene::morning
                then morning;
            transition t_off_to_day
                first off
                accept cmd : LightingCommand via controlIn
                if cmd.scene == LightingScene::day
                then day;
            transition t_off_to_evening
                first off
                accept cmd : LightingCommand via controlIn
                if cmd.scene == LightingScene::evening
                then evening;
            transition t_off_to_night
                first off
                accept cmd : LightingCommand via controlIn
                if cmd.scene == LightingScene::night
                then night;
            transition t_off_to_away
                first off
                accept cmd : LightingCommand via controlIn
                if cmd.scene == LightingScene::away
                then away;
            state morning {
                do adjustLighting;
                transition t_morning_to_off
                    first morning
                    accept cmd : LightingCommand via controlIn
                    if cmd.scene == LightingScene::off
                    then off;
            }
            state day {
                do adjustLighting;
                transition t_day_to_off
                    first day
                    accept cmd : LightingCommand via controlIn
                    if cmd.scene == LightingScene::off
                    then off;
            }
            state evening {
                do adjustLighting;
                transition t_evening_to_off
                    first evening
                    accept cmd : LightingCommand via controlIn
                    if cmd.scene == LightingScene::off
                    then off;
            }
            state night {
                do adjustLighting;
                transition t_night_to_off
                    first night
                    accept cmd : LightingCommand via controlIn
                    if cmd.scene == LightingScene::off
                    then off;
            }
            state away {
                do adjustLighting;
                transition t_away_to_off
                    first away
                    accept cmd : LightingCommand via controlIn
                    if cmd.scene == LightingScene::off
                    then off;
            }
        }
    }
    
    part def SecuritySystem {
        port controlIn : SecurityCmdInPort;
        port occupancyIn : OccupancyDataInPort;
        port alarmOut : AlarmOutPort;
        attribute currentMode : SecurityMode;
        perform action monitorSecurity : MonitorSecurity;
        exhibit state securityStates {
            entry; then disarmed;
            state disarmed;
            transition t_disarmed_to_armedAway
                first disarmed
                accept cmd : SecurityCommand via controlIn
                if cmd.mode == SecurityMode::armedAway
                then armedAway;
            transition t_disarmed_to_armedStay
                first disarmed
                accept cmd : SecurityCommand via controlIn
                if cmd.mode == SecurityMode::armedStay
                then armedStay;
            state armedAway {
                do monitorSecurity;
                transition t_armedAway_to_alarm
                    first armedAway
                    accept reading : OccupancyReading via occupancyIn
                    if reading.isOccupied == true
                    do send new AlarmAlert() to alarmOut
                    then alarmTriggered;
                transition t_armedAway_to_disarmed
                    first armedAway
                    accept cmd : SecurityCommand via controlIn
                    if cmd.mode == SecurityMode::disarmed
                    then disarmed;
            }
            state armedStay {
                do monitorSecurity;
                transition t_armedStay_to_alarm
                    first armedStay
                    accept reading : OccupancyReading via occupancyIn
                    if reading.isOccupied == true
                    do send new AlarmAlert() to alarmOut
                    then alarmTriggered;
                transition t_armedStay_to_disarmed
                    first armedStay
                    accept cmd : SecurityCommand via controlIn
                    if cmd.mode == SecurityMode::disarmed
                    then disarmed;
            }
            state alarmTriggered {
                do monitorSecurity;
                transition t_alarm_to_disarmed
                    first alarmTriggered
                    accept cmd : SecurityCommand via controlIn
                    if cmd.mode == SecurityMode::disarmed
                    then disarmed;
            }
        }
    }
    
    part def EnergyManagementSystem {
        port controlIn : EnergyCmdInPort;
        port solarIn : PowerFlowInPort;
        port batteryPort : PowerFlowInOutPort;
        port gridPort : PowerFlowInOutPort;
        port appliancePowerOut : PowerFlowOutPort;
        port applianceCmdOut : ApplianceCmdOutPort;
        attribute currentMode : EnergyMode;
        attribute batteryStateOfCharge : Real;
        perform action optimizeEnergy : OptimizeEnergy;
        exhibit state energyStates {
            entry; then idle;
            state idle;
            transition t_idle_to_solarPriority
                first idle
                accept cmd : EnergyCommand via controlIn
                if cmd.mode == EnergyMode::solarPriority
                then solarPriority;
            transition t_idle_to_batteryDischarge
                first idle
                accept cmd : EnergyCommand via controlIn
                if cmd.mode == EnergyMode::batteryDischarge
                then batteryDischarge;
            transition t_idle_to_gridImport
                first idle
                accept cmd : EnergyCommand via controlIn
                if cmd.mode == EnergyMode::gridImport
                then gridImport;
            transition t_idle_to_offPeak
                first idle
                accept cmd : EnergyCommand via controlIn
                if cmd.mode == EnergyMode::offPeak
                then offPeak;
            state solarPriority {
                do optimizeEnergy;
                transition t_solarPriority_to_idle
                    first solarPriority
                    accept cmd : EnergyCommand via controlIn
                    if cmd.mode == EnergyMode::idle
                    then idle;
            }
            state batteryDischarge {
                do optimizeEnergy;
                transition t_batteryDischarge_to_idle
                    first batteryDischarge
                    accept cmd : EnergyCommand via controlIn
                    if cmd.mode == EnergyMode::idle
                    then idle;
            }
            state gridImport {
                do optimizeEnergy;
                transition t_gridImport_to_idle
                    first gridImport
                    accept cmd : EnergyCommand via controlIn
                    if cmd.mode == EnergyMode::idle
                    then idle;
            }
            state offPeak {
                do optimizeEnergy;
                transition t_offPeak_to_idle
                    first offPeak
                    accept cmd : EnergyCommand via controlIn
                    if cmd.mode == EnergyMode::idle
                    then idle;
            }
        }
    }
    
    part def SolarPanelArray {
        port powerOut : PowerFlowOutPort;
        attribute ratedPower : PowerValue;
        perform action generatePower : GeneratePower;
    }
    
    part def HomeBattery {
        port powerPort : PowerFlowInOutPort;
        attribute stateOfCharge : Real;
        attribute capacity : EnergyValue;
        perform action chargeDischarge : ChargeDischarge;
    }
    
    part def MainGridConnection {
        port powerPort : PowerFlowInOutPort;
        perform action gridInteraction : GridInteraction;
    }
    
    part def SmartAppliances {
        port powerIn : PowerFlowInPort;
        port cmdIn : ApplianceCmdInPort;
        perform action runAppliances : RunAppliances;
    }
    
    requirement def ComfortMaintenanceReq {
        doc /* The system shall maintain ideal temperature and humidity in occupied rooms within user preferences. */
        attribute setTemp : TemperatureValue;
        attribute actualTemp : TemperatureValue;
        attribute setHumidity : HumidityValue;
        attribute actualHumidity : HumidityValue;
        require constraint { abs(actualTemp - setTemp) <= 1.0 and abs(actualHumidity - setHumidity) <= 5.0 }
    }
    requirement def EnergyEfficiencyReq {
        doc /* The system shall minimize energy waste by conditioning only occupied rooms and prioritizing renewable energy. */
        attribute renewableUsage : Real;
        attribute gridImport : PowerValue;
        attribute maxGridImport : PowerValue;
        require constraint { renewableUsage >= 60.0 and gridImport <= maxGridImport }
    }
    requirement def SecurityResponseReq {
        doc /* The system shall trigger an alarm within 2 seconds of breach detection. */
        attribute breachDetectionTime : TimeValue;
        attribute alarmTriggerTime : TimeValue;
        require constraint { alarmTriggerTime - breachDetectionTime <= 2.0 }
    }
    requirement def AdaptiveLearningReq {
        doc /* The system shall learn from daily routines and refine operations over time. */
        attribute learningEnabled : Boolean;
        attribute adaptationPeriod : TimeValue;
        require constraint { learningEnabled == true and adaptationPeriod <= 30.0 }
    }
    
    part def Home {
        part hub : CentralIntelligenceHub;
        part envSensors : EnvironmentalSensor;
        part occSensors : OccupancySensor;
        part climate : ClimateControlSystem;
        part lighting : IntelligentLightingSystem;
        part security : SecuritySystem;
        part energy : EnergyManagementSystem;
        part solar : SolarPanelArray;
        part battery : HomeBattery;
        part grid : MainGridConnection;
        part appliances : SmartAppliances;
        
        connect envSensors.dataOut to hub.envDataIn;
        connect occSensors.dataOut to hub.occDataIn;
        connect hub.climateCmdOut to climate.controlIn;
        connect hub.lightingCmdOut to lighting.controlIn;
        connect hub.securityCmdOut to security.controlIn;
        connect hub.energyCmdOut to energy.controlIn;
        connect occSensors.dataOut to security.occupancyIn;
        connect security.alarmOut to hub.alarmIn;
        connect solar.powerOut to energy.solarIn;
        connect battery.powerPort to energy.batteryPort;
        connect grid.powerPort to energy.gridPort;
        connect energy.appliancePowerOut to appliances.powerIn;
        connect energy.applianceCmdOut to appliances.cmdIn;
        
        requirement comfort : ComfortMaintenanceReq;
        requirement efficiency : EnergyEfficiencyReq;
        requirement security : SecurityResponseReq;
        requirement learning : AdaptiveLearningReq;
    }
    
    part homeOfTheFuture : Home;
}
