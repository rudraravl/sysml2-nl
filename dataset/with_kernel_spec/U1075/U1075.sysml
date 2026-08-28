package SmartHomeSystem {
    private import ISQ::*;
    private import ScalarValues::*;
    
    package Definitions {
        enum OccupancyState { occupied; vacant; sleeping; }
        enum SecurityMode { disarmed; armedHome; armedAway; }
        enum ClimateMode { idle; heating; cooling; }
        enum LightingMode { off; dimmed; on; }
        
        attribute def TemperatureValue :> Real;
        attribute def PowerValue :> Real;
        attribute def HumidityValue :> Real;
        attribute def LightLevel :> Real;
        attribute def AirQualityIndex :> Integer;
        
        item def EnvironmentalData {
            attribute temperature : TemperatureValue;
            attribute humidity : HumidityValue;
            attribute airQuality : AirQualityIndex;
            attribute lightLevel : LightLevel;
        }
        item def OccupancyData {
            attribute occupancyState : OccupancyState;
        }
        item def ClimateCommand {
            attribute mode : ClimateMode;
            attribute targetTemp : TemperatureValue;
        }
        item def LightingCommand {
            attribute mode : LightingMode;
            attribute intensity : Real;
        }
        item def SecurityCommand {
            attribute mode : SecurityMode;
        }
        item def EnergyData {
            attribute consumption : PowerValue;
            attribute maxLoad : PowerValue;
        }
        item def LoadShedCommand {
            attribute shedAmount : PowerValue;
        }
        item def SecurityAlert {
            attribute alertType : String;
        }
        
        port def EnvDataOutPort { out data : EnvironmentalData; }
        port def EnvDataInPort { in data : EnvironmentalData; }
        port def OccupancyOutPort { out data : OccupancyData; }
        port def OccupancyInPort { in data : OccupancyData; }
        port def ClimateCmdOutPort { out cmd : ClimateCommand; }
        port def ClimateCmdInPort { in cmd : ClimateCommand; }
        port def LightingCmdOutPort { out cmd : LightingCommand; }
        port def LightingCmdInPort { in cmd : LightingCommand; }
        port def SecurityCmdOutPort { out cmd : SecurityCommand; }
        port def SecurityCmdInPort { in cmd : SecurityCommand; }
        port def EnergyDataOutPort { out data : EnergyData; }
        port def EnergyDataInPort { in data : EnergyData; }
        port def LoadShedCmdOutPort { out cmd : LoadShedCommand; }
        port def LoadShedCmdInPort { in cmd : LoadShedCommand; }
        port def SecurityAlertOutPort { out alert : SecurityAlert; }
        port def SecurityAlertInPort { in alert : SecurityAlert; }
        
        part def EnvironmentalSensor {
            port dataOut : EnvDataOutPort;
            exhibit state sensorStates {
                entry; then active;
                state active;
            }
        }
        
        part def OccupancySensor {
            port dataOut : OccupancyOutPort;
            exhibit state sensorStates {
                entry; then active;
                state active;
            }
        }
        
        part def SmartMeter {
            port dataOut : EnergyDataOutPort;
            exhibit state meterStates {
                entry; then active;
                state active;
            }
        }
        
        part def ClimateControlSystem {
            port cmdIn : ClimateCmdInPort;
            port shedCmdIn : LoadShedCmdInPort;
            exhibit state climateStates {
                entry; then idle;
                state idle;
                transition idle_to_heating
                    first idle
                    accept cmd : ClimateCommand via cmdIn
                    if cmd.mode == ClimateMode::heating
                    then heating;
                state heating;
                transition heating_to_cooling
                    first heating
                    accept cmd : ClimateCommand via cmdIn
                    if cmd.mode == ClimateMode::cooling
                    then cooling;
                state cooling;
                transition cooling_to_idle
                    first cooling
                    accept cmd : ClimateCommand via cmdIn
                    if cmd.mode == ClimateMode::idle
                    then idle;
            }
        }
        
        part def LightingSystem {
            port cmdIn : LightingCmdInPort;
            exhibit state lightingStates {
                entry; then off;
                state off;
                transition off_to_dimmed
                    first off
                    accept cmd : LightingCommand via cmdIn
                    if cmd.mode == LightingMode::dimmed
                    then dimmed;
                state dimmed;
                transition dimmed_to_on
                    first dimmed
                    accept cmd : LightingCommand via cmdIn
                    if cmd.mode == LightingMode::on
                    then on;
                state on;
                transition on_to_off
                    first on
                    accept cmd : LightingCommand via cmdIn
                    if cmd.mode == LightingMode::off
                    then off;
            }
        }
        
        part def SecuritySystem {
            port cmdIn : SecurityCmdInPort;
            port alertOut : SecurityAlertOutPort;
            exhibit state securityStates {
                entry; then disarmed;
                state disarmed;
                transition disarmed_to_armedHome
                    first disarmed
                    accept cmd : SecurityCommand via cmdIn
                    if cmd.mode == SecurityMode::armedHome
                    then armedHome;
                transition disarmed_to_armedAway
                    first disarmed
                    accept cmd : SecurityCommand via cmdIn
                    if cmd.mode == SecurityMode::armedAway
                    then armedAway;
                state armedHome;
                transition armedHome_to_disarmed
                    first armedHome
                    accept cmd : SecurityCommand via cmdIn
                    if cmd.mode == SecurityMode::disarmed
                    then disarmed;
                state armedAway;
                transition armedAway_to_disarmed
                    first armedAway
                    accept cmd : SecurityCommand via cmdIn
                    if cmd.mode == SecurityMode::disarmed
                    then disarmed;
            }
        }
        
        part def EnergyManagementSystem {
            port meterDataIn : EnergyDataInPort;
            port reportOut : EnergyDataOutPort;
            exhibit state energyStates {
                entry; then monitoring;
                state monitoring;
                transition monitoring_to_alerting
                    first monitoring
                    accept data : EnergyData via meterDataIn
                    if data.consumption > data.maxLoad
                    do send new EnergyData() to reportOut
                    then alerting;
                state alerting;
                transition alerting_to_monitoring
                    first alerting
                    accept data : EnergyData via meterDataIn
                    if data.consumption <= data.maxLoad
                    then monitoring;
            }
        }
        
        part def HomeAutomationController {
            port envDataIn : EnvDataInPort;
            port occDataIn : OccupancyInPort;
            port climateCmdOut : ClimateCmdOutPort;
            port lightingCmdOut : LightingCmdOutPort;
            port securityCmdOut : SecurityCmdOutPort;
            port energyReportIn : EnergyDataInPort;
            port loadShedCmdOut : LoadShedCmdOutPort;
            port alertIn : SecurityAlertInPort;
            
            exhibit state controllerStates {
                entry; then monitoring;
                state monitoring;
                transition monitoring_to_monitoring_occ
                    first monitoring
                    accept occ : OccupancyData via occDataIn
                    if occ.occupancyState == OccupancyState::vacant
                    do send new SecurityCommand() to securityCmdOut
                    then monitoring;
                transition monitoring_to_monitoring_env
                    first monitoring
                    accept env : EnvironmentalData via envDataIn
                    if env.temperature < 18.0
                    do send new ClimateCommand() to climateCmdOut
                    then monitoring;
                transition monitoring_to_monitoring_energy
                    first monitoring
                    accept energy : EnergyData via energyReportIn
                    if energy.consumption > energy.maxLoad
                    do send new LoadShedCommand() to loadShedCmdOut
                    then monitoring;
            }
        }
        
        part def SmartHome {
            part controller : HomeAutomationController;
            part envSensor : EnvironmentalSensor;
            part occSensor : OccupancySensor;
            part climate : ClimateControlSystem;
            part lighting : LightingSystem;
            part security : SecuritySystem;
            part energy : EnergyManagementSystem;
            part meter : SmartMeter;
            
            interface envDataInterface connect envSensor.dataOut to controller.envDataIn;
            interface occDataInterface connect occSensor.dataOut to controller.occDataIn;
            interface climateCmdInterface connect controller.climateCmdOut to climate.cmdIn;
            interface lightingCmdInterface connect controller.lightingCmdOut to lighting.cmdIn;
            interface securityCmdInterface connect controller.securityCmdOut to security.cmdIn;
            interface alertInterface connect security.alertOut to controller.alertIn;
            interface meterDataInterface connect meter.dataOut to energy.meterDataIn;
            interface energyReportInterface connect energy.reportOut to controller.energyReportIn;
            interface loadShedInterface connect controller.loadShedCmdOut to climate.shedCmdIn;
        }
        
        requirement def ComfortReq {
            doc /* The system shall maintain comfortable temperature and humidity. */
            attribute actualTemp : TemperatureValue;
            attribute targetTemp : TemperatureValue;
            attribute actualHumidity : HumidityValue;
            attribute minHumidity : HumidityValue;
            attribute maxHumidity : HumidityValue;
            require constraint { abs(actualTemp - targetTemp) <= 1.0 && actualHumidity >= minHumidity && actualHumidity <= maxHumidity }
        }
        requirement def EnergyEfficiencyReq {
            doc /* The system shall minimize energy waste. */
            attribute totalConsumption : PowerValue;
            attribute maxConsumption : PowerValue;
            require constraint { totalConsumption <= maxConsumption }
        }
        requirement def SecurityReq {
            doc /* The system shall detect breaches and trigger alarms. */
            attribute breachDetected : Boolean;
            attribute alarmTriggered : Boolean;
            require constraint { breachDetected implies alarmTriggered }
        }
        requirement def LoadManagementReq {
            doc /* The system shall prevent circuit overloading. */
            attribute currentLoad : PowerValue;
            attribute maxLoad : PowerValue;
            require constraint { currentLoad <= maxLoad }
        }
    }
}
