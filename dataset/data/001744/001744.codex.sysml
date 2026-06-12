package AquariumSystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Temperature_C :> Real {
        unit = "degC";
    }

    attribute def Volume_L :> Real {
        unit = "L";
    }

    attribute def FlowRate_L_per_min :> Real {
        unit = "L/min";
    }

    attribute def Power_W :> Real {
        unit = "W";
    }

    attribute def Concentration_mg_per_L :> Real {
        unit = "mg/L";
    }

    attribute def Illuminance_lx :> Real {
        unit = "lx";
    }

    attribute def Time_h :> Real {
        unit = "h";
    }

    item def Water {
        attribute temperature : Temperature_C;
        attribute volume : Volume_L;
        attribute dissolvedOxygen : Concentration_mg_per_L;
        attribute ammonia : Concentration_mg_per_L;
        attribute nitrate : Concentration_mg_per_L;
        attribute pH : Real;
    }

    item def ElectricalPower {
        attribute voltage : Real;
        attribute current : Real;
        attribute power : Power_W;
    }

    item def FishFood {
        attribute portionMass_g : Real;
        attribute feedingInterval_h : Time_h;
    }

    item def Waste {
        attribute ammoniaContribution : Concentration_mg_per_L;
    }

    item def Light {
        attribute intensity : Illuminance_lx;
        attribute photoperiod : Time_h;
    }

    port def WaterPort {
        inout item water : Water;
    }

    port def PowerPort {
        in item power : ElectricalPower;
    }

    port def FoodPort {
        in item food : FishFood;
    }

    port def WastePort {
        out item waste : Waste;
    }

    port def LightPort {
        out item light : Light;
    }

    part def Aquarium {
        attribute designVolume : Volume_L = 120.0;
        attribute targetTemperature : Temperature_C = 25.0;
        attribute minimumDissolvedOxygen : Concentration_mg_per_L = 6.0;
        attribute maximumAmmonia : Concentration_mg_per_L = 0.25;
        attribute targetPH : Real = 7.2;

        port powerIn : PowerPort;
        port foodIn : FoodPort;

        part tank : GlassTank {
            attribute capacity : Volume_L = designVolume;
        }

        part waterBody : AquaticWater {
            attribute temperature : Temperature_C = 25.0;
            attribute volume : Volume_L = 110.0;
            attribute dissolvedOxygen : Concentration_mg_per_L = 7.5;
            attribute ammonia : Concentration_mg_per_L = 0.05;
            attribute nitrate : Concentration_mg_per_L = 20.0;
            attribute pH : Real = 7.2;
        }

        part filter : BioMechanicalFilter {
            attribute flowRate : FlowRate_L_per_min = 8.0;
            attribute powerDraw : Power_W = 12.0;
        }

        part heater : ThermostaticHeater {
            attribute heatingPower : Power_W = 100.0;
            attribute setPoint : Temperature_C = targetTemperature;
        }

        part lightUnit : AquariumLight {
            attribute outputIntensity : Illuminance_lx = 3500.0;
            attribute dailyPhotoperiod : Time_h = 8.0;
        }

        part aerator : AirPump {
            attribute airFlowRate : FlowRate_L_per_min = 2.5;
            attribute powerDraw : Power_W = 4.0;
        }

        part feeder : AutomaticFeeder {
            attribute portionMass_g : Real = 1.5;
            attribute feedingInterval : Time_h = 12.0;
        }

        part controller : AquariumController {
            attribute sampleInterval : Time_h = 0.02;
        }

        part temperatureSensor : TemperatureSensor;
        part chemistrySensor : WaterChemistrySensor;
        part fishCommunity : FishCommunity {
            attribute populationCount : Integer = 12;
            attribute preferredTemperatureMin : Temperature_C = 24.0;
            attribute preferredTemperatureMax : Temperature_C = 26.0;
        }

        connect powerIn to heater.powerIn;
        connect powerIn to filter.powerIn;
        connect powerIn to lightUnit.powerIn;
        connect powerIn to aerator.powerIn;
        connect powerIn to feeder.powerIn;
        connect powerIn to controller.powerIn;

        connect tank.waterPort to waterBody.waterPort;
        connect waterBody.waterPort to filter.inlet;
        connect filter.outlet to waterBody.waterPort;
        connect waterBody.waterPort to heater.waterPort;
        connect waterBody.waterPort to aerator.waterPort;
        connect waterBody.waterPort to temperatureSensor.waterPort;
        connect waterBody.waterPort to chemistrySensor.waterPort;
        connect feeder.foodOut to fishCommunity.foodIn;
        connect fishCommunity.wasteOut to waterBody.wasteIn;
        connect lightUnit.lightOut to tank.lightIn;

        connect temperatureSensor.temperatureOut to controller.temperatureIn;
        connect chemistrySensor.chemistryOut to controller.chemistryIn;
        connect controller.heaterCommandOut to heater.commandIn;
        connect controller.filterCommandOut to filter.commandIn;
        connect controller.aeratorCommandOut to aerator.commandIn;
        connect controller.lightCommandOut to lightUnit.commandIn;
        connect controller.feederCommandOut to feeder.commandIn;

        perform action maintainAquaticHabitat : MaintainAquaticHabitat;
        exhibit state operatingState : AquariumOperatingStates;
    }

    part def GlassTank {
        attribute capacity : Volume_L;
        port waterPort : WaterPort;
        port lightIn : LightPort;
    }

    part def AquaticWater {
        attribute temperature : Temperature_C;
        attribute volume : Volume_L;
        attribute dissolvedOxygen : Concentration_mg_per_L;
        attribute ammonia : Concentration_mg_per_L;
        attribute nitrate : Concentration_mg_per_L;
        attribute pH : Real;

        port waterPort : WaterPort;
        port wasteIn : WastePort;
    }

    part def BioMechanicalFilter {
        attribute flowRate : FlowRate_L_per_min;
        attribute powerDraw : Power_W;

        port powerIn : PowerPort;
        port inlet : WaterPort;
        port outlet : WaterPort;
        port commandIn : ControlPort;

        perform action removeParticulatesAndAmmonia : FilterWater;
    }

    part def ThermostaticHeater {
        attribute heatingPower : Power_W;
        attribute setPoint : Temperature_C;

        port powerIn : PowerPort;
        port waterPort : WaterPort;
        port commandIn : ControlPort;

        perform action regulateTemperature : HeatWater;
    }

    part def AquariumLight {
        attribute outputIntensity : Illuminance_lx;
        attribute dailyPhotoperiod : Time_h;

        port powerIn : PowerPort;
        port commandIn : ControlPort;
        port lightOut : LightPort;

        perform action provideDayNightCycle : IlluminateTank;
    }

    part def AirPump {
        attribute airFlowRate : FlowRate_L_per_min;
        attribute powerDraw : Power_W;

        port powerIn : PowerPort;
        port waterPort : WaterPort;
        port commandIn : ControlPort;

        perform action oxygenateWater : AddDissolvedOxygen;
    }

    part def AutomaticFeeder {
        attribute portionMass_g : Real;
        attribute feedingInterval : Time_h;

        port powerIn : PowerPort;
        port commandIn : ControlPort;
        port foodOut : FoodPort;

        perform action dispenseFood : FeedFish;
    }

    part def FishCommunity {
        attribute populationCount : Integer;
        attribute preferredTemperatureMin : Temperature_C;
        attribute preferredTemperatureMax : Temperature_C;

        port foodIn : FoodPort;
        port wasteOut : WastePort;

        perform action consumeFoodAndProduceWaste : FishMetabolism;
    }

    part def TemperatureSensor {
        port waterPort : WaterPort;
        port temperatureOut : MeasurementPort;
    }

    part def WaterChemistrySensor {
        port waterPort : WaterPort;
        port chemistryOut : MeasurementPort;
    }

    port def ControlPort {
        in item command : ControlCommand;
    }

    port def MeasurementPort {
        out item measurement : SensorMeasurement;
    }

    item def ControlCommand {
        attribute enabled : Boolean;
        attribute dutyCycle : Real;
    }

    item def SensorMeasurement {
        attribute measuredTemperature : Temperature_C;
        attribute measuredDissolvedOxygen : Concentration_mg_per_L;
        attribute measuredAmmonia : Concentration_mg_per_L;
        attribute measuredPH : Real;
    }

    part def AquariumController {
        attribute sampleInterval : Time_h;

        port powerIn : PowerPort;
        port temperatureIn : MeasurementPort;
        port chemistryIn : MeasurementPort;
        port heaterCommandOut : ControlPort;
        port filterCommandOut : ControlPort;
        port aeratorCommandOut : ControlPort;
        port lightCommandOut : ControlPort;
        port feederCommandOut : ControlPort;

        perform action monitorAndControl : MonitorAquarium;
        exhibit state controlState : ControllerStates;
    }

    action def MaintainAquaticHabitat {
        inout item water : Water;
        in item power : ElectricalPower;
        in item food : FishFood;

        first start;
        then monitorWater;
        then regulateTemperature;
        then circulateAndFilter;
        then oxygenate;
        then illuminate;
        then feed;
        then assessHabitat;
        then done;

        action monitorWater : MonitorAquarium;
        action regulateTemperature : HeatWater;
        action circulateAndFilter : FilterWater;
        action oxygenate : AddDissolvedOxygen;
        action illuminate : IlluminateTank;
        action feed : FeedFish;
        action assessHabitat {
            out attribute habitatStable : Boolean;
        }
    }

    action def MonitorAquarium {
        in item temperatureMeasurement : SensorMeasurement;
        in item chemistryMeasurement : SensorMeasurement;
        out item heaterCommand : ControlCommand;
        out item filterCommand : ControlCommand;
        out item aeratorCommand : ControlCommand;
        out item lightCommand : ControlCommand;
        out item feederCommand : ControlCommand;
    }

    action def HeatWater {
        inout item water : Water;
        in item command : ControlCommand;
        out attribute deliveredHeat : Power_W;
    }

    action def FilterWater {
        inout item water : Water;
        in item command : ControlCommand;
        out attribute removedAmmonia : Concentration_mg_per_L;
        out attribute removedParticulateFraction : Real;
    }

    action def AddDissolvedOxygen {
        inout item water : Water;
        in item command : ControlCommand;
        out attribute oxygenIncrease : Concentration_mg_per_L;
    }

    action def IlluminateTank {
        in item command : ControlCommand;
        out item light : Light;
    }

    action def FeedFish {
        in item command : ControlCommand;
        out item food : FishFood;
    }

    action def FishMetabolism {
        in item food : FishFood;
        out item waste : Waste;
    }

    state def AquariumOperatingStates {
        entry; then Initializing;

        state Initializing;
        state StableHabitat;
        state Heating;
        state Filtering;
        state Oxygenating;
        state Feeding;
        state Alarm;

        transition Initializing_to_StableHabitat
            first Initializing
            accept when waterReady
            then StableHabitat;

        transition StableHabitat_to_Heating
            first StableHabitat
            accept when waterTemperatureBelowSetPoint
            then Heating;

        transition Heating_to_StableHabitat
            first Heating
            accept when waterTemperatureAtSetPoint
            then StableHabitat;

        transition StableHabitat_to_Filtering
            first StableHabitat
            accept when ammoniaAboveNominal
            then Filtering;

        transition Filtering_to_StableHabitat
            first Filtering
            accept when ammoniaWithinNominal
            then StableHabitat;

        transition StableHabitat_to_Oxygenating
            first StableHabitat
            accept when dissolvedOxygenLow
            then Oxygenating;

        transition Oxygenating_to_StableHabitat
            first Oxygenating
            accept when dissolvedOxygenRecovered
            then StableHabitat;

        transition StableHabitat_to_Feeding
            first StableHabitat
            accept when scheduledFeedingTime
            then Feeding;

        transition Feeding_to_StableHabitat
            first Feeding
            accept after 0.05 [h]
            then StableHabitat;

        transition Any_to_Alarm
            first StableHabitat
            accept when criticalWaterCondition
            then Alarm;
    }

    state def ControllerStates {
        entry; then Sampling;

        state Sampling;
        state Evaluating;
        state CommandingActuators;
        state FaultDetected;

        transition Sampling_to_Evaluating
            first Sampling
            accept after 0.02 [h]
            then Evaluating;

        transition Evaluating_to_CommandingActuators
            first Evaluating
            accept when controlDecisionAvailable
            then CommandingActuators;

        transition CommandingActuators_to_Sampling
            first CommandingActuators
            accept when commandsIssued
            then Sampling;

        transition Evaluating_to_FaultDetected
            first Evaluating
            accept when sensorInvalid
            then FaultDetected;
    }

    requirement def PrimaryAquariumFunction {
        doc /* The aquarium shall provide a controlled aquatic habitat that contains water and aquatic life while maintaining water temperature, oxygenation, cleanliness, illumination, and feeding support within ranges suitable for healthy fish. */

        subject aquarium : Aquarium;

        require constraint {
            aquarium.waterBody.volume >= 100.0 and
            aquarium.waterBody.temperature >= 24.0 and
            aquarium.waterBody.temperature <= 26.0 and
            aquarium.waterBody.dissolvedOxygen >= 6.0 and
            aquarium.waterBody.ammonia <= 0.25 and
            aquarium.waterBody.pH >= 6.8 and
            aquarium.waterBody.pH <= 7.6
        }
    }

    requirement def FiltrationRequirement {
        doc /* The aquarium filtration subsystem shall circulate and treat the water volume sufficiently to reduce particulate waste and keep ammonia below the safe operating threshold. */

        subject aquarium : Aquarium;

        require constraint {
            aquarium.filter.flowRate >= 6.0 and
            aquarium.waterBody.ammonia <= aquarium.maximumAmmonia
        }
    }

    requirement def ThermalRequirement {
        doc /* The aquarium shall regulate water temperature within the preferred range of the fish community during normal operation. */

        subject aquarium : Aquarium;

        require constraint {
            aquarium.waterBody.temperature >= aquarium.fishCommunity.preferredTemperatureMin and
            aquarium.waterBody.temperature <= aquarium.fishCommunity.preferredTemperatureMax
        }
    }

    requirement def OxygenationRequirement {
        doc /* The aquarium shall maintain dissolved oxygen at or above the minimum concentration required for healthy aquatic life. */

        subject aquarium : Aquarium;

        require constraint {
            aquarium.waterBody.dissolvedOxygen >= aquarium.minimumDissolvedOxygen
        }
    }

    requirement def LightingRequirement {
        doc /* The aquarium shall provide a repeatable day-night light cycle for visibility and biological rhythm support. */

        subject aquarium : Aquarium;

        require constraint {
            aquarium.lightUnit.dailyPhotoperiod >= 6.0 and
            aquarium.lightUnit.dailyPhotoperiod <= 10.0 and
            aquarium.lightUnit.outputIntensity >= 2000.0
        }
    }

    requirement def FeedingRequirement {
        doc /* The aquarium shall provide scheduled feeding in controlled portions to support fish health while limiting excess nutrient loading. */

        subject aquarium : Aquarium;

        require constraint {
            aquarium.feeder.portionMass_g >= 0.5 and
            aquarium.feeder.portionMass_g <= 3.0 and
            aquarium.feeder.feedingInterval >= 8.0 and
            aquarium.feeder.feedingInterval <= 24.0
        }
    }

    satisfy PrimaryAquariumFunction by Aquarium::maintainAquaticHabitat;
    satisfy FiltrationRequirement by BioMechanicalFilter::removeParticulatesAndAmmonia;
    satisfy ThermalRequirement by ThermostaticHeater::regulateTemperature;
    satisfy OxygenationRequirement by AirPump::oxygenateWater;
    satisfy LightingRequirement by AquariumLight::provideDayNightCycle;
    satisfy FeedingRequirement by AutomaticFeeder::dispenseFood;
}