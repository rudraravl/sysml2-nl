package SmartLaundrySystem {
    import SI::*;
    import ISQ::*;

    // ===== Value Types =====
    value type MassValue = Real { unit "kg"; }
    value type VolumeValue = Real { unit "L"; }
    value type TempValue = Real { unit "degC"; }
    value type DurationValue = Real { unit "s"; }
    value type RotationalSpeedValue = Real { unit "rpm"; }
    value type PowerValue = Real { unit "W"; }
    value type CurrentValue = Real { unit "A"; }
    value type VoltageValue = Real { unit "V"; }
    value type MoisturePercent = Real { min 0; max 100; }
    value type VolumeFlowRateValue = Real { unit "L/min"; }
    value type AirFlowRateValue = Real { unit "m^3/min"; }
    value type TorqueValue = Real { unit "N*m"; }

    // ===== Items =====
    item def Water;
    item def Detergent;
    item def Wastewater;
    item def ElectricalPower;
    item def HotAir;
    item def HumidAir;
    item def DirtyClothes;
    item def WetClothes;
    item def DryClothes;

    // ===== Enumerations =====
    enum def WashCycleType { normal; delicate; heavyDuty; }
    enum def DryHeatLevel { low; medium; high; }

    // ===== Port Definitions =====
    port def WaterSupplyPort {
        in item water : Water;
        attribute maxFlowRate : VolumeFlowRateValue = 6.0;
    }
    port def DetergentSupplyPort {
        in item detergent : Detergent;
    }
    port def WastewaterPort {
        out item wastewater : Wastewater;
        attribute maxFlowRate : VolumeFlowRateValue = 8.0;
    }
    port def ElectricalPort {
        in item power : ElectricalPower;
        attribute voltage : VoltageValue = 230;
        attribute maxCurrent : CurrentValue = 16;
    }
    port def ControlPort {
        inout attribute command : String;
        inout attribute status : String;
    }
    port def DrivePort {
        inout attribute speed : RotationalSpeedValue;
        inout attribute torque : TorqueValue;
    }
    port def ThermalPort {
        inout attribute setTemp : TempValue;
        inout attribute measuredTemp : TempValue;
        inout attribute heatPower : PowerValue;
    }
    port def MoistureSensingPort {
        inout attribute measuredMoisture : MoisturePercent;
        inout attribute targetMoisture : MoisturePercent;
    }
    port def AirFlowPort {
        in item hotAir : HotAir;
        attribute flowRate : AirFlowRateValue;
        attribute temp : TempValue;
    }
    port def ExhaustPort {
        out item humidAir : HumidAir;
    }
    port def DirtyClothesPort {
        in item dirtyClothes : DirtyClothes;
    }
    port def WetClothesInPort {
        in item wetClothes : WetClothes;
    }
    port def WetClothesOutPort {
        out item wetClothes : WetClothes;
    }
    port def DryClothesPort {
        out item dryClothes : DryClothes;
    }

    // ===== Sub-component Part Definitions =====

    part def WasherDrum {
        attribute capacity : MassValue = 8.0;
        attribute currentLoadMass : MassValue;
        attribute currentSpeed : RotationalSpeedValue;
        item load : DirtyClothes[0..*];
        port waterIn : WaterSupplyPort;
        port detergentIn : DetergentSupplyPort;
        port driveIn : DrivePort;
        port thermalIn : ThermalPort;
        port wastewaterOut : WastewaterPort;
        port clothesIn : DirtyClothesPort;
        port wetClothesOut : WetClothesOutPort;
    }

    part def WasherMotor {
        attribute maxPower : PowerValue = 500.0;
        attribute currentPower : PowerValue;
        attribute currentSpeed : RotationalSpeedValue;
        port electricalIn : ElectricalPort;
        port driveOut : DrivePort;
    }

    part def WaterHeater {
        attribute maxPower : PowerValue = 2000.0;
        attribute currentPower : PowerValue;
        attribute setTemp : TempValue;
        port electricalIn : ElectricalPort;
        port thermalOut : ThermalPort;
        port thermalIn : ThermalPort;
    }

    part def DetergentDispenser {
        attribute capacity : VolumeValue = 0.5;
        attribute currentAmount : VolumeValue;
        port detergentIn : DetergentSupplyPort;
        port detergentOut : DetergentSupplyPort;
    }

    part def DrainPump {
        attribute maxFlowRate : VolumeFlowRateValue = 8.0;
        attribute currentFlowRate : VolumeFlowRateValue;
        port drainIn : WastewaterPort;
        port drainOut : WastewaterPort;
        port electricalIn : ElectricalPort;
    }

    part def TemperatureSensor {
        attribute measuredTemp : TempValue;
        port thermalOut : ThermalPort;
    }

    part def MoistureSensor {
        attribute measuredMoisture : MoisturePercent;
        attribute targetMoisture : MoisturePercent = 5.0;
        port moistureOut : MoistureSensingPort;
    }

    part def DryerDrum {
        attribute capacity : MassValue = 8.0;
        attribute currentLoadMass : MassValue;
        attribute currentSpeed : RotationalSpeedValue;
        item load : WetClothes[0..*];
        port clothesIn : WetClothesInPort;
        port driveIn : DrivePort;
        port thermalIn : ThermalPort;
        port airIn : AirFlowPort;
        port moistureIn : MoistureSensingPort;
        port exhaustOut : ExhaustPort;
        port clothesOut : DryClothesPort;
    }

    part def DryerMotor {
        attribute maxPower : PowerValue = 750.0;
        attribute currentPower : PowerValue;
        attribute currentSpeed : RotationalSpeedValue;
        port electricalIn : ElectricalPort;
        port driveOut : DrivePort;
    }

    part def HeatingElement {
        attribute maxPower : PowerValue = 2500.0;
        attribute currentPower : PowerValue;
        attribute heatLevel : DryHeatLevel;
        attribute setTemp : TempValue;
        port electricalIn : ElectricalPort;
        port thermalOut : ThermalPort;
        port thermalIn : ThermalPort;
    }

    part def BlowerFan {
        attribute maxAirFlow : AirFlowRateValue = 5.0;
        attribute currentAirFlow : AirFlowRateValue;
        port electricalIn : ElectricalPort;
        port airOut : AirFlowPort;
    }

    // ===== Action Definitions =====

    action def WashCycleAction {
        in cycleType : WashCycleType;
        attribute agitationSpeed : RotationalSpeedValue;
        attribute cycleDuration : DurationValue;
        attribute waterTemp : TempValue;

        action FillDrum;
        action AddDetergent;
        action Wash;
        action Rinse;
        action Spin;
        action Drain;

        succession FillDrum then AddDetergent;
        succession AddDetergent then Wash;
        succession Wash then Rinse;
        succession Rinse then Spin;
        succession Spin then Drain;
    }

    action def DryCycleAction {
        in heatLevel : DryHeatLevel;
        attribute drumSpeed : RotationalSpeedValue;
        attribute targetMoisture : MoisturePercent;

        action HeatUp;
        action Tumble;
        action MonitorMoisture;
        action Cooldown;
        action EndCycle;

        succession HeatUp then Tumble;
        succession Tumble then MonitorMoisture;
        succession MonitorMoisture then Cooldown;
        succession Cooldown then EndCycle;
    }

    // ===== Washing Machine =====

    part def WashingMachine {
        attribute selectedCycle : WashCycleType = WashCycleType::normal;
        attribute setWaterTemp : TempValue = 40.0;
        attribute setAgitation : RotationalSpeedValue = 50;
        attribute setCycleDuration : DurationValue = 1800;
        attribute currentStatus : String = "standby";
        attribute cycleComplete : Boolean = false;

        port electrical : ElectricalPort;
        port waterSupply : WaterSupplyPort;
        port detergentSupply : DetergentSupplyPort;
        port wastewater : WastewaterPort;
        port clothesInput : DirtyClothesPort;
        port wetClothesOutput : WetClothesOutPort;
        port control : ControlPort;

        part drum : WasherDrum;
        part motor : WasherMotor;
        part heater : WaterHeater;
        part dispenser : DetergentDispenser;
        part pump : DrainPump;
        part tempSensor : TemperatureSensor;

        connection waterSupply to drum.waterIn;
        connection detergentSupply to dispenser.detergentIn;
        connection dispenser.detergentOut to drum.detergentIn;
        connection motor.driveOut to drum.driveIn;
        connection heater.thermalOut to drum.thermalIn;
        connection tempSensor.thermalOut to heater.thermalIn;
        connection drum.wastewaterOut to pump.drainIn;
        connection pump.drainOut to wastewater;
        connection electrical to motor.electricalIn;
        connection electrical to heater.electricalIn;
        connection electrical to pump.electricalIn;
        connection clothesInput to drum.clothesIn;
        connection drum.wetClothesOut to wetClothesOutput;

        state machine WasherBehavior {
            state standby {
                entry { currentStatus := "standby"; cycleComplete := false; }
            }
            state filling {
                entry { currentStatus := "filling"; }
            }
            state washing {
                entry { currentStatus := "washing"; }
            }
            state rinsing {
                entry { currentStatus := "rinsing"; }
            }
            state spinning {
                entry { currentStatus := "spinning"; }
            }
            state draining {
                entry { currentStatus := "draining"; }
            }
            state complete {
                entry { currentStatus := "complete"; cycleComplete := true; }
            }

            transition standby -> filling
                when control.command == "start_wash";
            transition filling -> washing
                when drum.currentLoadMass > 0;
            transition washing -> rinsing
                when control.command == "next_phase";
            transition rinsing -> spinning
                when control.command == "next_phase";
            transition spinning -> draining
                when control.command == "next_phase";
            transition draining -> complete
                when pump.currentFlowRate == 0;
            transition complete -> standby
                when control.command == "reset";
        }
    }

    // ===== Clothes Dryer =====

    part def ClothesDryer {
        attribute selectedHeat : DryHeatLevel = DryHeatLevel::medium;
        attribute setDrumSpeed : RotationalSpeedValue = 50;
        attribute targetMoisture : MoisturePercent = 5.0;
        attribute currentStatus : String = "standby";
        attribute cycleComplete : Boolean = false;

        port electrical : ElectricalPort;
        port exhaust : ExhaustPort;
        port clothesInput : WetClothesInPort;
        port dryClothesOutput : DryClothesPort;
        port control : ControlPort;

        part drum : DryerDrum;
        part motor : DryerMotor;
        part heater : HeatingElement;
        part fan : BlowerFan;
        part moistureSensor : MoistureSensor;
        part tempSensor : TemperatureSensor;

        connection clothesInput to drum.clothesIn;
        connection motor.driveOut to drum.driveIn;
        connection heater.thermalOut to drum.thermalIn;
        connection tempSensor.thermalOut to heater.thermalIn;
        connection fan.airOut to drum.airIn;
        connection drum.exhaustOut to exhaust;
        connection moistureSensor.moistureOut to drum.moistureIn;
        connection electrical to motor.electricalIn;
        connection electrical to heater.electricalIn;
        connection electrical to fan.electricalIn;
        connection drum.clothesOut to dryClothesOutput;

        state machine DryerBehavior {
            state standby {
                entry { currentStatus := "standby"; cycleComplete := false; }
            }
            state heating {
                entry { currentStatus := "heating"; }
            }
            state tumbling {
                entry { currentStatus := "tumbling"; }
            }
            state monitoring {
                entry { currentStatus := "monitoring"; }
            }
            state cooldown {
                entry { currentStatus := "cooldown"; }
            }
            state complete {
                entry { currentStatus := "complete"; cycleComplete := true; }
            }

            transition standby -> heating
                when control.command == "start_dry";
            transition heating -> tumbling
                when tempSensor.measuredTemp >= heater.setTemp;
            transition tumbling -> monitoring
                when drum.currentSpeed > 0;
            transition monitoring -> cooldown
                when moistureSensor.measuredMoisture <= targetMoisture;
            transition cooldown -> complete
                when control.command == "cooldown_done";
            transition complete -> standby
                when control.command == "reset";
        }
    }

    // ===== Central Controller =====

    part def CentralController {
        attribute maxTotalPower : PowerValue = 4000.0;
        attribute currentTotalPower : PowerValue;
        attribute washerActive : Boolean = false;
        attribute dryerActive : Boolean = false;
        attribute systemMode : String = "standby";
        attribute electricalLoadOK : Boolean = true;

        port electrical : ElectricalPort;
        port washerControl : ControlPort;
        port dryerControl : ControlPort;

        action def CoordinatePower {
            in washerPower : PowerValue;
            in dryerPower : PowerValue;
            out totalPower : PowerValue;
            out loadOK : Boolean;
        }

        state machine ControllerBehavior {
            state standby {
                entry { systemMode := "standby"; washerActive := false; dryerActive := false; }
            }
            state managingWash {
                entry { systemMode := "managingWash"; washerActive := true; dryerActive := false; }
            }
            state managingDry {
                entry { systemMode := "managingDry"; washerActive := false; dryerActive := true; }
            }
            state coordinating {
                entry { systemMode := "coordinating"; washerActive := true; dryerActive := true; }
            }

            transition standby -> managingWash
                when washerControl.status == "start_wash";
            transition managingWash -> managingDry
                when washerControl.status == "complete";
            transition managingDry -> standby
                when dryerControl.status == "complete";
            transition coordinating -> standby
                when currentTotalPower <= maxTotalPower;
        }
    }

    // ===== Smart Laundry System =====

    part def SmartLaundrySystem {
        attribute systemStatus : String = "standby";

        port electrical : ElectricalPort;
        port waterSupply : WaterSupplyPort;
        port wastewater : WastewaterPort;
        port exhaust : ExhaustPort;
        port clothesInput : DirtyClothesPort;
        port dryClothesOutput : DryClothesPort;
        port control : ControlPort;

        part controller : CentralController;
        part washer : WashingMachine;
        part dryer : ClothesDryer;

        connection electrical to controller.electrical;
        connection electrical to washer.electrical;
        connection electrical to dryer.electrical;
        connection waterSupply to washer.waterSupply;
        connection washer.wastewater to wastewater;
        connection dryer.exhaust to exhaust;
        connection clothesInput to washer.clothesInput;
        connection washer.wetClothesOutput to dryer.clothesInput;
        connection dryer.dryClothesOutput to dryClothesOutput;
        connection control to controller.washerControl;
        connection controller.washerControl to washer.control;
        connection controller.dryerControl to dryer.control;

        state machine SystemBehavior {
            state standby {
                entry { systemStatus := "standby"; }
            }
            state washing {
                entry { systemStatus := "washing"; }
            }
            state drying {
                entry { systemStatus := "drying"; }
            }
            state completed {
                entry { systemStatus := "completed"; }
            }

            transition standby -> washing
                when control.command == "start_cycle";
            transition washing -> drying
                when washer.cycleComplete == true;
            transition drying -> completed
                when dryer.cycleComplete == true;
            transition completed -> standby
                when control.command == "reset";
        }
    }

    // ===== Requirements =====

    requirement def FullAutomationReq {
        doc /* The smart laundry system shall automate the entire washing and drying process. */
    }
    requirement def WashCyclesReq {
        doc /* The washing machine shall support normal, delicate, and heavy-duty cycles. */
    }
    requirement def WaterTempControlReq {
        doc /* The washing machine shall precisely control water temperature during the wash cycle. */
    }
    requirement def MoistureSensorReq {
        doc /* The dryer shall include a moisture sensor that ends the cycle when clothes are dry. */
    }
    requirement def DryHeatLevelsReq {
        doc /* The dryer shall support low, medium, and high heat settings. */
    }
    requirement def EnergyCoordinationReq {
        doc /* The central controller shall coordinate power usage to avoid circuit overload. */
    }
    requirement def HouseholdUtilitiesReq {
        doc /* The system shall connect to standard household electrical, water, and drainage systems. */
    }
    requirement def SystemLifecycleReq {
        doc /* The system shall operate through standby, washing, drying, and back to standby states. */
    }

    requirement LaundrySystemRequirements {
        requirement r1 : FullAutomationReq;
        requirement r2 : WashCyclesReq;
        requirement r3 : WaterTempControlReq;
        requirement r4 : MoistureSensorReq;
        requirement r5 : DryHeatLevelsReq;
        requirement r6 : EnergyCoordinationReq;
        requirement r7 : HouseholdUtilitiesReq;
        requirement r8 : SystemLifecycleReq;
    }
}
