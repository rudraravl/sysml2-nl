package 'Intelligent Home Control System' {
    private import ScalarValues::*;
    
    unit degC;
    unit lux;
    unit percent;
    unit kWh;

    value type TemperatureValue :> Real {
        unit degC;
    }
    value type LightLevelValue :> Real {
        unit lux;
    }
    value type HumidityValue :> Real {
        unit percent;
    }
    value type EnergyValue :> Real {
        unit kWh;
    }

    item def TemperatureData {
        attribute value : TemperatureValue;
    }
    item def LightData {
        attribute value : LightLevelValue;
    }
    item def HumidityData {
        attribute value : HumidityValue;
    }
    item def OccupancyData {
        attribute isOccupied : Boolean;
    }
    item def ClimateCommand {
        attribute setpoint : TemperatureValue;
    }
    item def LightingCommand {
        attribute level : LightLevelValue;
    }
    item def SecurityCommand {
        attribute arm : Boolean;
    }
    item def UserPreferences {
        attribute targetTemp : TemperatureValue;
        attribute targetLight : LightLevelValue;
        attribute awayModeEnabled : Boolean;
    }
    item def SystemStatus {
        attribute currentTemp : TemperatureValue;
        attribute energyUsage : EnergyValue;
        attribute securityArmed : Boolean;
    }

    port def TempDataOut { out data : TemperatureData; }
    port def LightDataOut { out data : LightData; }
    port def HumidityDataOut { out data : HumidityData; }
    port def OccupancyDataOut { out data : OccupancyData; }

    port def TempDataIn { in data : TemperatureData; }
    port def LightDataIn { in data : LightData; }
    port def HumidityDataIn { in data : HumidityData; }
    port def OccupancyDataIn { in data : OccupancyData; }

    port def ClimateCmdOut { out cmd : ClimateCommand; }
    port def LightingCmdOut { out cmd : LightingCommand; }
    port def SecurityCmdOut { out cmd : SecurityCommand; }

    port def ClimateCmdIn { in cmd : ClimateCommand; }
    port def LightingCmdIn { in cmd : LightingCommand; }
    port def SecurityCmdIn { in cmd : SecurityCommand; }

    port def PrefsOut { out prefs : UserPreferences; }
    port def PrefsIn { in prefs : UserPreferences; }
    port def StatusOut { out status : SystemStatus; }
    port def StatusIn { in status : SystemStatus; }

    part def TemperatureSensor {
        port dataOut : TempDataOut;
    }
    part def LightSensor {
        port dataOut : LightDataOut;
    }
    part def HumiditySensor {
        port dataOut : HumidityDataOut;
    }
    part def OccupancySensor {
        port dataOut : OccupancyDataOut;
    }

    part def ClimateActuator {
        port cmdIn : ClimateCmdIn;
    }
    part def LightingActuator {
        port cmdIn : LightingCmdIn;
    }
    part def SecurityActuator {
        port cmdIn : SecurityCmdIn;
    }

    part def UserInterface {
        port prefsOut : PrefsOut;
        port statusIn : StatusIn;
    }

    part def CentralController {
        port tempIn : TempDataIn;
        port lightIn : LightDataIn;
        port humidityIn : HumidityDataIn;
        port occupancyIn : OccupancyDataIn;

        port climateOut : ClimateCmdOut;
        port lightingOut : LightingCmdOut;
        port securityOut : SecurityCmdOut;

        port prefsIn : PrefsIn;
        port statusOut : StatusOut;

        attribute isOccupied : Boolean;
        attribute awayModeEnabled : Boolean;

        state machine {
            state Idle;
            state Monitoring;
            state Away;
            transition from Idle to Monitoring when isOccupied;
            transition from Monitoring to Away when !isOccupied && awayModeEnabled;
            transition from Away to Monitoring when isOccupied;
        }
    }

    part def Home {
        part controller : CentralController;
        part ui : UserInterface;
        part tempSensor : TemperatureSensor;
        part lightSensor : LightSensor;
        part humiditySensor : HumiditySensor;
        part occupancySensor : OccupancySensor;
        part climateActuator : ClimateActuator;
        part lightingActuator : LightingActuator;
        part securityActuator : SecurityActuator;

        connect tempSensor.dataOut to controller.tempIn;
        connect lightSensor.dataOut to controller.lightIn;
        connect humiditySensor.dataOut to controller.humidityIn;
        connect occupancySensor.dataOut to controller.occupancyIn;

        connect controller.climateOut to climateActuator.cmdIn;
        connect controller.lightingOut to lightingActuator.cmdIn;
        connect controller.securityOut to securityActuator.cmdIn;

        connect ui.prefsOut to controller.prefsIn;
        connect controller.statusOut to ui.statusIn;
    }

    part home : Home;

    requirement def ComfortRequirement {
        doc /* The system shall maintain temperature and lighting to user preferences when occupied. */
    }
    requirement def EnergyEfficiencyRequirement {
        doc /* The system shall reduce energy consumption when the home is empty. */
    }
    requirement def SecurityRequirement {
        doc /* The system shall arm the security system when away mode is enabled and the home is empty. */
    }

    requirement comfortReq : ComfortRequirement;
    requirement energyReq : EnergyEfficiencyRequirement;
    requirement securityReq : SecurityRequirement;

    satisfy comfortReq by home;
    satisfy energyReq by home;
    satisfy securityReq by home;
}
