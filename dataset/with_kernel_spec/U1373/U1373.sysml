package ResidentialAirConditioningSystem {
    private import ScalarValues::*;
    
    attribute def Temperature :> Real;
    attribute def Pressure :> Real;
    attribute def Power :> Real;
    attribute def Humidity :> Real;
    attribute def Ratio :> Real;
    attribute def Speed :> Real;
    
    enum def RefrigerantPhase { liquid; gas; twoPhase; }
    enum def Mode { off; cooling; heating; fanOnly; auto; }
    
    item def Refrigerant {
        attribute temperature : Temperature;
        attribute pressure : Pressure;
        attribute phase : RefrigerantPhase;
    }
    item def Air {
        attribute temperature : Temperature;
        attribute humidity : Humidity;
    }
    item def ThermostatSetting {
        attribute desiredTemperature : Temperature;
        attribute mode : Mode;
    }
    
    part def Compressor {
        port refrigerantIn { in refrigerant : Refrigerant; }
        port refrigerantOut { out refrigerant : Refrigerant; }
        port powerIn { in power : Power; }
        port controlIn { in compressorSpeed : Speed; }
    }
    part def Condenser {
        port refrigerantIn { in refrigerant : Refrigerant; }
        port refrigerantOut { out refrigerant : Refrigerant; }
        port airIn { in air : Air; }
        port airOut { out air : Air; }
    }
    part def OutdoorFan {
        port airOut { out air : Air; }
        port powerIn { in power : Power; }
        port controlIn { in fanSpeed : Speed; }
    }
    part def ExpansionValve {
        port refrigerantIn { in refrigerant : Refrigerant; }
        port refrigerantOut { out refrigerant : Refrigerant; }
    }
    part def Evaporator {
        port refrigerantIn { in refrigerant : Refrigerant; }
        port refrigerantOut { out refrigerant : Refrigerant; }
        port airIn { in air : Air; }
        port airOut { out air : Air; }
    }
    part def IndoorFan {
        port airIn { in air : Air; }
        port airOut { out air : Air; }
        port powerIn { in power : Power; }
        port controlIn { in fanSpeed : Speed; }
    }
    part def TemperatureSensor {
        port tempOut { out temperature : Temperature; }
    }
    part def HumiditySensor {
        port humOut { out humidity : Humidity; }
    }
    part def Thermostat {
        port settingOut { out setting : ThermostatSetting; }
    }
    part def Room {
        port airReturn { in returnAir : Air; }
        port airSupply { out supplyAir : Air; }
        attribute temperature : Temperature;
        attribute humidity : Humidity;
    }
    part def PowerSource {
        port powerOut { out power : Power; }
    }
    
    part def ElectronicController {
        port tempSensorIn { in temperature : Temperature; }
        port humSensorIn { in humidity : Humidity; }
        port thermostatIn { in setting : ThermostatSetting; }
        port powerIn { in power : Power; }
        port compressorControlOut { out compressorSpeed : Speed; }
        port outdoorFanControlOut { out outdoorFanSpeed : Speed; }
        port indoorFanControlOut { out indoorFanSpeed : Speed; }
        
        attribute currentCompressorSpeed : Speed;
        attribute currentOutdoorFanSpeed : Speed;
        attribute currentIndoorFanSpeed : Speed;
        
        state machine controllerBehavior {
            state Off;
            state Cooling;
            state Heating;
            state FanOnly;
            state Auto;
            
            transition initial to Off;
            transition Off to Cooling when thermostatIn.setting.mode == Mode::cooling;
            transition Off to Heating when thermostatIn.setting.mode == Mode::heating;
            transition Off to FanOnly when thermostatIn.setting.mode == Mode::fanOnly;
            transition Off to Auto when thermostatIn.setting.mode == Mode::auto;
            transition Auto to Cooling when tempSensorIn.temperature > thermostatIn.setting.desiredTemperature + 0.5;
            transition Auto to Heating when tempSensorIn.temperature < thermostatIn.setting.desiredTemperature - 0.5;
            transition Auto to FanOnly when tempSensorIn.temperature <= thermostatIn.setting.desiredTemperature + 0.5 and tempSensorIn.temperature >= thermostatIn.setting.desiredTemperature - 0.5;
            transition Cooling to Off when thermostatIn.setting.mode == Mode::off;
            transition Heating to Off when thermostatIn.setting.mode == Mode::off;
            transition FanOnly to Off when thermostatIn.setting.mode == Mode::off;
            transition Auto to Off when thermostatIn.setting.mode == Mode::off;
        }
    }
    
    part def AirConditioner {
        part compressor : Compressor;
        part condenser : Condenser;
        part outdoorFan : OutdoorFan;
        part expansionValve : ExpansionValve;
        part evaporator : Evaporator;
        part indoorFan : IndoorFan;
        part temperatureSensor : TemperatureSensor;
        part humiditySensor : HumiditySensor;
        part thermostat : Thermostat;
        part controller : ElectronicController;
        part room : Room;
        part powerSource : PowerSource;
        
        connect compressor.refrigerantOut to condenser.refrigerantIn;
        connect condenser.refrigerantOut to expansionValve.refrigerantIn;
        connect expansionValve.refrigerantOut to evaporator.refrigerantIn;
        connect evaporator.refrigerantOut to compressor.refrigerantIn;
        
        connect outdoorFan.airOut to condenser.airIn;
        connect room.airReturn to indoorFan.airIn;
        connect indoorFan.airOut to evaporator.airIn;
        connect evaporator.airOut to room.airSupply;
        
        connect temperatureSensor.tempOut to controller.tempSensorIn;
        connect humiditySensor.humOut to controller.humSensorIn;
        connect thermostat.settingOut to controller.thermostatIn;
        
        connect controller.compressorControlOut to compressor.controlIn;
        connect controller.outdoorFanControlOut to outdoorFan.controlIn;
        connect controller.indoorFanControlOut to indoorFan.controlIn;
        
        connect powerSource.powerOut to compressor.powerIn;
        connect powerSource.powerOut to outdoorFan.powerIn;
        connect powerSource.powerOut to indoorFan.powerIn;
        connect powerSource.powerOut to controller.powerIn;
    }
    
    requirement def CoolingCapacityReqDef {
        doc /* The air conditioning system shall provide a minimum cooling capacity. */
        attribute coolingCapacity : Power;
        attribute minCoolingCapacity : Power;
        require constraint { coolingCapacity >= minCoolingCapacity }
    }
    requirement def EnergyEfficiencyReqDef {
        doc /* The system shall achieve a minimum coefficient of performance (COP). */
        attribute cop : Ratio;
        attribute minCop : Ratio;
        require constraint { cop >= minCop }
    }
    requirement def TotalPowerConsumptionReqDef {
        doc /* The total electrical power consumption shall not exceed the maximum limit. */
        attribute totalPower : Power;
        attribute maxTotalPower : Power;
        require constraint { totalPower <= maxTotalPower }
    }
    requirement def TemperatureRegulationReqDef {
        doc /* The system shall maintain the room temperature within 1.0 K of the setpoint. */
        attribute setTemperature : Temperature;
        attribute actualTemperature : Temperature;
        require constraint { (actualTemperature - setTemperature) <= 1.0 and (setTemperature - actualTemperature) <= 1.0 }
    }
    requirement def HumidityControlReqDef {
        doc /* The system shall maintain relative humidity within the specified range. */
        attribute humidity : Humidity;
        attribute minHumidity : Humidity;
        attribute maxHumidity : Humidity;
        require constraint { humidity >= minHumidity and humidity <= maxHumidity }
    }
    
    requirement coolingCapacityReq : CoolingCapacityReqDef {
        attribute redef minCoolingCapacity = 5000;
        attribute redef coolingCapacity = 5200;
    }
    requirement energyEfficiencyReq : EnergyEfficiencyReqDef {
        attribute redef minCop = 3.5;
        attribute redef cop = 3.8;
    }
    requirement totalPowerReq : TotalPowerConsumptionReqDef {
        attribute redef maxTotalPower = 2000;
        attribute redef totalPower = 1800;
    }
    requirement temperatureRegulationReq : TemperatureRegulationReqDef {
        attribute redef setTemperature = 295.0;
        attribute redef actualTemperature = 295.0;
    }
    requirement humidityControlReq : HumidityControlReqDef {
        attribute redef minHumidity = 0.4;
        attribute redef maxHumidity = 0.6;
        attribute redef humidity = 0.5;
    }
    
    part ac : AirConditioner {
        satisfy coolingCapacityReq;
        satisfy energyEfficiencyReq;
        satisfy totalPowerReq;
        satisfy temperatureRegulationReq;
        satisfy humidityControlReq;
    }
}
