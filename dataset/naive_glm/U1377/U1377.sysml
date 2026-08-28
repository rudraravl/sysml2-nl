package AutomatedAquariumSystem {

    // ---- Value types with units ----
    value type TemperatureValue > Real { unit 'degC'; }
    value type pHValue > Real { unit 'pH'; }
    value type LengthValue > Real { unit 'm'; }
    value type VolumeValue > Real { unit 'L'; }
    value type FlowRateValue > Real { unit 'L/min'; }
    value type PowerValue > Real { unit 'W'; }
    value type MassValue > Real { unit 'g'; }
    value type DurationValue > Real { unit 'h'; }
    value type IlluminanceValue > Real { unit 'lux'; }
    value type PercentageValue > Real { unit '%'; }
    value type DissolvedOxygenValue > Real { unit 'mg/L'; }
    value type TimeOfDayValue > Real { unit 'h'; }

    // ---- Enumerations ----
    enum SystemMode { normal, maintenance, emergency; }
    enum LightPhase { day, twilight, night; }
    enum FilterType { mechanical, biological; }

    // ---- Item definitions ----
    item def Water;
    item def FilteredWater :> Water;
    item def Food;
    item def Waste;
    item def AmbientAir;
    item def OxygenatedWater :> Water;

    // ---- Port definitions ----
    port def WaterOutPort { out item water : Water; }
    port def WaterInPort { in item water : Water; }
    port def FoodOutPort { out item food : Food; }
    port def FoodInPort { in item food : Food; }
    port def AirInPort { in item air : AmbientAir; }
    port def PowerOutPort { out attribute power : PowerValue; }
    port def PowerInPort { in attribute power : PowerValue; }
    port def DataOutPort { out attribute value : Real; }
    port def DataInPort { in attribute value : Real; }
    port def ModeOutPort { out attribute mode : SystemMode; }
    port def ModeInPort { in attribute mode : SystemMode; }

    // ---- Interfaces ----
    interface def WaterFlowInterface {
        end supplier : WaterOutPort;
        end consumer : WaterInPort;
        flow of Water from supplier to consumer;
    }

    interface def FoodDispenseInterface {
        end supplier : FoodOutPort;
        end consumer : FoodInPort;
        flow of Food from supplier to consumer;
    }

    interface def PowerInterface {
        end supplier : PowerOutPort;
        end consumer : PowerInPort;
        attribute power : PowerValue;
    }

    interface def DataInterface {
        end supplier : DataOutPort;
        end consumer : DataInPort;
        attribute value : Real;
    }

    // ---- Requirements ----
    requirement def MaintainTemperatureRequirement {
        doc "The system shall maintain water temperature within the target range.";
        attribute targetTemp : TemperatureValue = 25;
        attribute tolerance : TemperatureValue = 1;
        attribute maxSafeTemp : TemperatureValue = 30;
        subject tank : Tank;
        constraint { |tank.measuredTemp - targetTemp| <= tolerance }
    }

    requirement def MaintainpHRequirement {
        doc "The system shall maintain pH within the safe range.";
        attribute minpH : pHValue = 6.5;
        attribute maxpH : pHValue = 7.5;
        attribute criticalMinpH : pHValue = 6.0;
        attribute criticalMaxpH : pHValue = 8.0;
        subject tank : Tank;
        constraint { tank.measuredpH >= minpH and tank.measuredpH <= maxpH }
    }

    requirement def MaintainWaterLevelRequirement {
        doc "The system shall maintain water level above the minimum threshold.";
        attribute minLevel : LengthValue = 0.4;
        attribute criticalLevel : LengthValue = 0.3;
        subject tank : Tank;
        constraint { tank.measuredLevel >= minLevel }
    }

    requirement def ContinuousFiltrationRequirement {
        doc "The system shall continuously circulate and filter water.";
        attribute minFlow : FlowRateValue = 50;
        subject pump : Pump;
        constraint { pump.flowRate >= minFlow }
    }

    requirement def DayNightCycleRequirement {
        doc "The system shall simulate a natural day-and-night light cycle.";
        attribute dayDuration : DurationValue = 12;
        attribute nightDuration : DurationValue = 10;
        attribute twilightDuration : DurationValue = 2;
        subject lighting : LightingSystem;
    }

    requirement def ScheduledFeedingRequirement {
        doc "The system shall dispense a set amount of food at scheduled times.";
        attribute feedAmount : MassValue = 5;
        attribute feedTimes : TimeOfDayValue[4] = [8, 12, 16, 20];
        subject feeder : AutomaticFeeder;
    }

    requirement def EmergencyResponseRequirement {
        doc "The system shall enter emergency mode when critical parameters exceed safe limits.";
        subject controller : CentralController;
        constraint { controller.currentMode == SystemMode::emergency when
            (controller.tempInput.value > 30 or controller.pHInput.value < 6.0 or controller.pHInput.value > 8.0 or controller.levelInput.value < 0.3) }
    }

    requirement def ModeSupportRequirement {
        doc "The system shall support normal, maintenance, and emergency operating modes.";
        subject system : AquariumSystem;
    }

    // ---- Part definitions ----

    part def Tank {
        attribute capacity : VolumeValue = 200;
        attribute measuredTemp : TemperatureValue;
        attribute measuredpH : pHValue;
        attribute measuredLevel : LengthValue;
        attribute measuredDO : DissolvedOxygenValue;
        attribute targetTemp : TemperatureValue = 25;

        port waterOut : WaterOutPort;
        port waterIn : WaterInPort;
        port foodIn : FoodInPort;
        port airIn : AirInPort;

        state tankState {
            entry; then Stable;
            state Stable {
                entry { /* tank conditions nominal */ }
            }
            state Disturbed {
                entry { /* conditions outside nominal */ }
            }
            transition stable_to_disturbed first Stable
                if measuredTemp > 30 or measuredpH < 6.0 or measuredpH > 8.0 or measuredLevel < 0.3
                then Disturbed;
            transition disturbed_to_stable first Disturbed
                if measuredTemp <= 30 and measuredpH >= 6.0 and measuredpH <= 8.0 and measuredLevel >= 0.3
                then Stable;
        }
    }

    part def Pump {
        attribute flowRate : FlowRateValue = 75;
        attribute power : PowerValue = 25;
        attribute isRunning : Boolean = true;

        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
        port powerIn : PowerInPort;
        port controlIn : DataInPort;

        action circulate {
            in item water : Water;
            out item pressurizedWater : Water;
        }

        state pumpState {
            entry; then Running;
            state Running;
            state Stopped;
            transition running_to_stopped first Running if controlIn.value == 0 then Stopped;
            transition stopped_to_running first Stopped if controlIn.value > 0 then Running;
        }
    }

    part def Filter {
        attribute filterType : FilterType;
        attribute efficiency : PercentageValue = 95;
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;

        action filterWater {
            in item water : Water;
            out item cleanWater : FilteredWater;
            out item waste : Waste;
        }
    }

    part def MechanicalFilter :> Filter {
        attribute filterType : FilterType = FilterType::mechanical;
        attribute meshSize : LengthValue = 0.0001;
    }

    part def BiologicalFilter :> Filter {
        attribute filterType : FilterType = FilterType::biological;
        attribute bacteriaColonyDensity : PercentageValue = 80;
    }

    part def Heater {
        attribute power : PowerValue = 100;
        attribute isOn : Boolean = false;
        attribute targetTemp : TemperatureValue = 25;
        port powerIn : PowerInPort;
        port controlIn : DataInPort;

        state heaterState {
            entry; then Off;
            state Off;
            state On;
            transition off_to_on first Off if controlIn.value > 0 then On;
            transition on_to_off first On if controlIn.value == 0 then Off;
        }
    }

    part def Aerator {
        attribute power : PowerValue = 5;
        attribute isOn : Boolean = false;
        attribute oxygenOutput : DissolvedOxygenValue = 8;
        port powerIn : PowerInPort;
        port controlIn : DataInPort;
        port airIn : AirInPort;

        action aerate {
            in item air : AmbientAir;
            out item oxygenatedWater : OxygenatedWater;
        }
    }

    part def Sensor {
        attribute reading : Real;
        port signalOut : DataOutPort;
        port powerIn : PowerInPort;
    }

    part def TemperatureSensor :> Sensor {
        attribute reading : TemperatureValue;
        attribute minRange : TemperatureValue = 0;
        attribute maxRange : TemperatureValue = 50;
    }

    part def pHSensor :> Sensor {
        attribute reading : pHValue;
        attribute minRange : pHValue = 0;
        attribute maxRange : pHValue = 14;
    }

    part def WaterLevelSensor :> Sensor {
        attribute reading : LengthValue;
        attribute minRange : LengthValue = 0;
        attribute maxRange : LengthValue = 1;
    }

    part def LightingSystem {
        attribute dayIntensity : IlluminanceValue = 5000;
        attribute twilightIntensity : IlluminanceValue = 1000;
        attribute nightIntensity : IlluminanceValue = 50;
        attribute currentPhase : LightPhase = LightPhase::day;
        port powerIn : PowerInPort;
        port controlIn : DataInPort;

        state lightCycle {
            entry; then Day;
            state Day {
                entry { currentPhase = LightPhase::day; }
            }
            state Twilight {
                entry { currentPhase = LightPhase::twilight; }
            }
            state Night {
                entry { currentPhase = LightPhase::night; }
            }
            transition day_to_twilight first Day if controlIn.value == 1 then Twilight;
            transition twilight_to_night first Twilight if controlIn.value == 2 then Night;
            transition night_to_twilight first Night if controlIn.value == 1 then Twilight;
            transition twilight_to_day first Twilight if controlIn.value == 0 then Day;
        }
    }

    part def AutomaticFeeder {
        attribute foodCapacity : MassValue = 200;
        attribute remainingFood : MassValue = 200;
        attribute feedAmount : MassValue = 5;
        port foodOut : FoodOutPort;
        port powerIn : PowerInPort;
        port controlIn : DataInPort;

        action dispenseFood {
            out item food : Food;
        }

        state feederState {
            entry; then Idle;
            state Idle;
            state Dispensing;
            transition idle_to_dispensing first Idle if controlIn.value > 0 then Dispensing;
            transition dispensing_to_idle first Dispensing if remainingFood <= foodCapacity - feedAmount then Idle;
        }
    }

    part def CentralController {
        attribute currentMode : SystemMode = SystemMode::normal;
        attribute targetTemp : TemperatureValue = 25;
        attribute targetpH : pHValue = 7.0;
        attribute minWaterLevel : LengthValue = 0.4;
        attribute criticalMaxTemp : TemperatureValue = 30;
        attribute criticalMinpH : pHValue = 6.0;
        attribute criticalMaxpH : pHValue = 8.0;
        attribute criticalLevel : LengthValue = 0.3;
        attribute feedSchedule : TimeOfDayValue[4] = [8, 12, 16, 20];

        port tempInput : DataInPort;
        port pHInput : DataInPort;
        port levelInput : DataInPort;
        port heaterControl : DataOutPort;
        port aeratorControl : DataOutPort;
        port pumpControl : DataOutPort;
        port lightControl : DataOutPort;
        port feederControl : DataOutPort;
        port modeOut : ModeOutPort;

        action evaluateConditions {
            in temp : TemperatureValue;
            in pH : pHValue;
            in level : LengthValue;
            out heaterCommand : Real;
            out aeratorCommand : Real;
            out pumpCommand : Real;
            perform {
                if temp < targetTemp then heaterCommand = 1; else heaterCommand = 0;
                if pH < 6.5 or pH > 7.5 then aeratorCommand = 1; else aeratorCommand = 0;
                pumpCommand = 1;
            }
        }

        action checkEmergency {
            in temp : TemperatureValue;
            in pH : pHValue;
            in level : LengthValue;
            out isEmergency : Boolean;
            perform {
                if temp > criticalMaxTemp or pH < criticalMinpH or pH > criticalMaxpH or level < criticalLevel
                then isEmergency = true; else isEmergency = false;
            }
        }

        state controllerState {
            entry; then NormalMode;

            state NormalMode {
                entry { currentMode = SystemMode::normal; modeOut.mode = SystemMode::normal; }
                do evaluateConditions;
            }

            state MaintenanceMode {
                entry { currentMode = SystemMode::maintenance; modeOut.mode = SystemMode::maintenance; }
            }

            state EmergencyMode {
                entry { currentMode = SystemMode::emergency; modeOut.mode = SystemMode::emergency; }
                do checkEmergency;
            }

            transition normal_to_maintenance first NormalMode if modeOut.mode == SystemMode::maintenance then MaintenanceMode;
            transition maintenance_to_normal first MaintenanceMode if modeOut.mode == SystemMode::normal then NormalMode;
            transition normal_to_emergency first NormalMode
                if tempInput.value > criticalMaxTemp or pHInput.value < criticalMinpH or pHInput.value > criticalMaxpH or levelInput.value < criticalLevel
                then EmergencyMode;
            transition maintenance_to_emergency first MaintenanceMode
                if tempInput.value > criticalMaxTemp or pHInput.value < criticalMinpH or pHInput.value > criticalMaxpH or levelInput.value < criticalLevel
                then EmergencyMode;
            transition emergency_to_normal first EmergencyMode
                if tempInput.value <= criticalMaxTemp and pHInput.value >= criticalMinpH and pHInput.value <= criticalMaxpH and levelInput.value >= criticalLevel
                then NormalMode;
        }
    }

    part def PowerSupply {
        attribute outputPower : PowerValue = 500;
        port powerOut : PowerOutPort;
    }

    // ---- Top-level system ----
    part def AquariumSystem {
        attribute systemName : String = "AutomatedAquarium";
        attribute currentMode : SystemMode = SystemMode::normal;

        part tank : Tank;
        part pump : Pump;
        part mechanicalFilter : MechanicalFilter;
        part biologicalFilter : BiologicalFilter;
        part heater : Heater;
        part aerator : Aerator;
        part tempSensor : TemperatureSensor;
        part pHSensor : pHSensor;
        part levelSensor : WaterLevelSensor;
        part lighting : LightingSystem;
        part feeder : AutomaticFeeder;
        part controller : CentralController;
        part powerSupply : PowerSupply;

        // Water circulation path: tank -> pump -> mechanical -> biological -> tank
        connection waterFlow1 : WaterFlowInterface connect tank.waterOut to pump.waterIn;
        connection waterFlow2 : WaterFlowInterface connect pump.waterOut to mechanicalFilter.waterIn;
        connection waterFlow3 : WaterFlowInterface connect mechanicalFilter.waterOut to biologicalFilter.waterIn;
        connection waterFlow4 : WaterFlowInterface connect biologicalFilter.waterOut to tank.waterIn;

        // Food dispensing
        connection foodDispense : FoodDispenseInterface connect feeder.foodOut to tank.foodIn;

        // Air supply to aerator
        connection airToAerator connect tank.airIn to aerator.airIn;

        // Sensor data to controller
        connection tempData : DataInterface connect tempSensor.signalOut to controller.tempInput;
        connection pHData : DataInterface connect pHSensor.signalOut to controller.pHInput;
        connection levelData : DataInterface connect levelSensor.signalOut to controller.levelInput;

        // Control commands from controller to actuators
        connection heaterCmd : DataInterface connect controller.heaterControl to heater.controlIn;
        connection aeratorCmd : DataInterface connect controller.aeratorControl to aerator.controlIn;
        connection pumpCmd : DataInterface connect controller.pumpControl to pump.controlIn;
        connection lightCmd : DataInterface connect controller.lightControl to lighting.controlIn;
        connection feederCmd : DataInterface connect controller.feederControl to feeder.controlIn;

        // Power distribution
        connection powerPump : PowerInterface connect powerSupply.powerOut to pump.powerIn;
        connection powerHeater : PowerInterface connect powerSupply.powerOut to heater.powerIn;
        connection powerAerator : PowerInterface connect powerSupply.powerOut to aerator.powerIn;
        connection powerLight : PowerInterface connect powerSupply.powerOut to lighting.powerIn;
        connection powerFeeder : PowerInterface connect powerSupply.powerOut to feeder.powerIn;
        connection powerTempSensor : PowerInterface connect powerSupply.powerOut to tempSensor.powerIn;
        connection powerpHSensor : PowerInterface connect powerSupply.powerOut to pHSensor.powerIn;
        connection powerLevelSensor : PowerInterface connect powerSupply.powerOut to levelSensor.powerIn;

        // Requirement satisfactions
        requirement tempReq : MaintainTemperatureRequirement { subject tank; }
        requirement pHReq : MaintainpHRequirement { subject tank; }
        requirement levelReq : MaintainWaterLevelRequirement { subject tank; }
        requirement filtrationReq : ContinuousFiltrationRequirement { subject pump; }
        requirement lightReq : DayNightCycleRequirement { subject lighting; }
        requirement feedReq : ScheduledFeedingRequirement { subject feeder; }
        requirement emergencyReq : EmergencyResponseRequirement { subject controller; }
        requirement modeReq : ModeSupportRequirement { subject system; }

        satisfy tempReq by tank;
        satisfy pHReq by tank;
        satisfy levelReq by tank;
        satisfy filtrationReq by pump;
        satisfy lightReq by lighting;
        satisfy feedReq by feeder;
        satisfy emergencyReq by controller;
        satisfy modeReq by AquariumSystem;
    }

}
