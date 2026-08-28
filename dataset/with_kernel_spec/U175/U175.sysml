package BronchitisKettleModel {
    private import ISQ::*;
    private import SI::*;
    private import ScalarFunctions::*;

    attribute def Temperature :> ISQ::Temperature;
    attribute def Volume :> ISQ::Volume;
    attribute def Duration :> ISQ::Time;
    attribute def Pressure :> ISQ::Pressure;
    attribute def Power :> ISQ::Power;
    attribute def Voltage :> ISQ::ElectricPotential;

    item def Water {
        attribute temperature : Temperature;
        attribute volume : Volume;
    }
    item def MedicinalAdditive {
        attribute concentration : Real;
    }
    item def TherapeuticVapor {
        attribute temperature : Temperature;
        attribute medicationConcentration : Real;
    }
    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute power : Power;
    }
    item def Heat {
        attribute power : Power;
    }
    item def HeaterCommand {
        attribute requestedPower : Power;
    }
    item def TreatmentSettings {
        attribute targetTemperature : Temperature;
        attribute treatmentDuration : Duration;
    }
    item def TemperatureReading {
        attribute value : Temperature;
    }
    item def WaterLevelReading {
        attribute value : Volume;
    }
    item def PressureReading {
        attribute value : Pressure;
    }
    item def StatusReport {
        attribute code : String;
        attribute msg : String;
    }

    item def StartSignal;
    item def ResetSignal;

    port def WaterInPort { in item water : Water; }
    port def WaterOutPort { out item water : Water; }
    port def AdditiveInPort { in item additive : MedicinalAdditive; }
    port def VaporInPort { in item vapor : TherapeuticVapor; }
    port def VaporOutPort { out item vapor : TherapeuticVapor; }
    port def HeatInPort { in item heat : Heat; }
    port def HeatOutPort { out item heat : Heat; }
    port def PowerInPort { in item pwr : ElectricalPower; }
    port def HeaterControlInPort { in item command : HeaterCommand; }
    port def HeaterControlOutPort { out item command : HeaterCommand; }
    port def SettingsInPort { in item settings : TreatmentSettings; }
    port def SettingsOutPort { out item settings : TreatmentSettings; }
    port def CommandInPort {
        in item startCmd : StartSignal;
        in item resetCmd : ResetSignal;
    }
    port def CommandOutPort {
        out item startCmd : StartSignal;
        out item resetCmd : ResetSignal;
    }
    port def StatusInPort { in item status : StatusReport; }
    port def StatusOutPort { out item status : StatusReport; }
    port def TempSensorOutPort { out item reading : TemperatureReading; }
    port def TempSensorInPort { in item reading : TemperatureReading; }
    port def LevelSensorOutPort { out item reading : WaterLevelReading; }
    port def LevelSensorInPort { in item reading : WaterLevelReading; }
    port def PressureOutPort { out item reading : PressureReading; }
    port def PressureInPort { in item reading : PressureReading; }

    requirement def TherapeuticTemperatureReq {
        doc /* The kettle shall heat medicated water to a therapeutic temperature around 95C (368K). */
        attribute actualTemp : Temperature;
        attribute targetTemp : Temperature = 368 [K];
        require constraint { abs(actualTemp - targetTemp) <= 2 [K] }
    }
    requirement def TreatmentDurationReq {
        doc /* The kettle shall support a treatment session of about 20 minutes. */
        attribute actualDuration : Duration;
        attribute targetDuration : Duration = 20 [min];
        require constraint { abs(actualDuration - targetDuration) <= 1 [min] }
    }
    requirement def OverheatProtectionReq {
        doc /* The controller shall shut down the heater before boiling chamber temperature exceeds 100C. */
        attribute currentTemp : Temperature;
        attribute maxTemp : Temperature = 373 [K];
        require constraint { currentTemp <= maxTemp }
    }
    requirement def LowWaterProtectionReq {
        doc /* The controller shall shut down the heater when water level is too low. */
        attribute waterLevel : Volume;
        attribute minWaterLevel : Volume = 0.05 [L];
        require constraint { waterLevel >= minWaterLevel }
    }
    requirement def PressureReliefReq {
        doc /* The safety valve shall release excess pressure above 150 kPa. */
        attribute chamberPressure : Pressure;
        attribute reliefPressure : Pressure = 150 [kPa];
        require constraint { chamberPressure <= reliefPressure }
    }
    requirement def PowerSupplyReq {
        doc /* The kettle shall operate on a standard 230V electrical supply. */
        attribute supplyVoltage : Voltage;
        attribute nominalVoltage : Voltage = 230 [V];
        require constraint { supplyVoltage == nominalVoltage }
    }
    requirement def ReservoirCapacityReq {
        doc /* The water reservoir shall hold up to 2.0 liters. */
        attribute capacity : Volume;
        require constraint { capacity <= 2.0 [L] }
    }
    requirement def VaporOutputReq {
        doc /* The nozzle shall deliver a consistent flow of therapeutic vapor. */
        attribute vaporFlowRate : Real;
        attribute minFlowRate : Real = 0.5;
        require constraint { vaporFlowRate >= minFlowRate }
    }

    part def WaterReservoir {
        attribute capacity : Volume = 2.0 [L];
        attribute currentLevel : Volume;
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
        perform action storeWater;
    }

    part def BoilingChamber {
        attribute maxVolume : Volume = 0.5 [L];
        attribute currentTemp : Temperature;
        attribute waterLevel : Volume;
        attribute pressure : Pressure;
        port waterIn : WaterInPort;
        port additiveIn : AdditiveInPort;
        port heatIn : HeatInPort;
        port vaporOut : VaporOutPort;
        port pressureRelief : PressureOutPort;
        perform action vaporizeWater;
    }

    part def HeatingElement {
        attribute maxPower : Power = 1500 [W];
        port powerIn : PowerInPort;
        port controlIn : HeaterControlInPort;
        port heatOut : HeatOutPort;
        perform action generateHeat;
    }

    part def TemperatureSensor {
        attribute accuracy : Temperature = 0.5 [K];
        port readingOut : TempSensorOutPort;
        perform action senseTemperature;
    }

    part def WaterLevelSensor {
        attribute minLevel : Volume = 0.05 [L];
        port levelOut : LevelSensorOutPort;
        perform action senseWaterLevel;
    }

    part def VaporizationNozzle {
        port vaporIn : VaporInPort;
        port vaporOut : VaporOutPort;
        perform action directVapor;
    }

    part def SafetyValve {
        attribute activationPressure : Pressure = 150 [kPa];
        port pressureIn : PressureInPort;
        port reliefOut : VaporOutPort;
        perform action releasePressure;
    }

    part def ControlInterface {
        attribute targetTemperature : Temperature = 368 [K];
        attribute treatmentDuration : Duration = 20 [min];
        port settingsOut : SettingsOutPort;
        port commandOut : CommandOutPort;
        port statusIn : StatusInPort;
        perform action receiveUserInput;
    }

    part def ControllerUnit {
        attribute targetTemp : Temperature = 368 [K];
        attribute maxTemp : Temperature = 373 [K];
        attribute minWaterLevel : Volume = 0.05 [L];
        attribute treatmentDuration : Duration = 20 [min];
        attribute currentTemp : Temperature;
        attribute waterLevel : Volume;
        attribute elapsedTime : Duration;
        port powerIn : PowerInPort;
        port settingsIn : SettingsInPort;
        port cmdIn : CommandInPort;
        port heaterControl : HeaterControlOutPort;
        port tempSensorIn : TempSensorInPort;
        port waterLevelIn : LevelSensorInPort;
        port statusOut : StatusOutPort;

        perform action startHeating;
        perform action stopHeating;
        perform action regulateTemperature;
        perform action startVaporizing;
        perform action resetController;

        exhibit state controllerStates {
            entry action initial;
            state idle {
                entry resetController;
            }
            state heating {
                entry startHeating;
                do regulateTemperature;
                exit stopHeating;
            }
            state vaporizing {
                entry startVaporizing;
                do regulateTemperature;
                exit stopHeating;
            }
            state fault {
                entry stopHeating;
            }
            transition initial then idle;
            transition idle_to_heating
                first idle
                accept startCmd : StartSignal via cmdIn
                then heating;
            transition heating_to_vaporizing
                first heating
                if currentTemp >= targetTemp
                then vaporizing;
            transition heating_to_fault
                first heating
                if currentTemp > maxTemp or waterLevel < minWaterLevel
                then fault;
            transition vaporizing_to_fault
                first vaporizing
                if currentTemp > maxTemp or waterLevel < minWaterLevel
                then fault;
            transition vaporizing_to_idle
                first vaporizing
                if elapsedTime >= treatmentDuration
                then idle;
            transition fault_to_idle
                first fault
                accept resetCmd : ResetSignal via cmdIn
                then idle;
        }
    }

    part def BronchitisKettle {
        attribute supplyVoltage : Voltage = 230 [V];
        port powerInput : PowerInPort;
        port waterFill : WaterInPort;
        port additiveInput : AdditiveInPort;
        port vaporOutput : VaporOutPort;

        part reservoir : WaterReservoir;
        part boiler : BoilingChamber;
        part heater : HeatingElement;
        part tempSensor : TemperatureSensor;
        part waterSensor : WaterLevelSensor;
        part controller : ControllerUnit;
        part nozzle : VaporizationNozzle;
        part safetyValve : SafetyValve;
        part userInterface : ControlInterface;

        connect waterFill to reservoir.waterIn;
        connect reservoir.waterOut to boiler.waterIn;
        connect additiveInput to boiler.additiveIn;
        connect heater.heatOut to boiler.heatIn;
        connect boiler.vaporOut to nozzle.vaporIn;
        connect nozzle.vaporOut to vaporOutput;
        connect tempSensor.readingOut to controller.tempSensorIn;
        connect waterSensor.levelOut to controller.waterLevelIn;
        connect controller.heaterControl to heater.controlIn;
        connect userInterface.settingsOut to controller.settingsIn;
        connect userInterface.commandOut to controller.cmdIn;
        connect controller.statusOut to userInterface.statusIn;
        connect powerInput to heater.powerIn;
        connect powerInput to controller.powerIn;
        connect boiler.pressureRelief to safetyValve.pressureIn;

        requirement therapeuticTemperatureReq : TherapeuticTemperatureReq;
        requirement treatmentDurationReq : TreatmentDurationReq;
        requirement overheatProtectionReq : OverheatProtectionReq;
        requirement lowWaterProtectionReq : LowWaterProtectionReq;
        requirement pressureReliefReq : PressureReliefReq;
        requirement powerSupplyReq : PowerSupplyReq;
        requirement reservoirCapacityReq : ReservoirCapacityReq;
        requirement vaporOutputReq : VaporOutputReq;
    }

    part bronchitisKettle : BronchitisKettle;
}
