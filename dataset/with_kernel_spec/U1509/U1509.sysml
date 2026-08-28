package 'Steam Turbine Power Generation System' {
    private import ScalarValues::Real;
    private import ScalarValues::Integer;
    private import ScalarValues::Boolean;

    attribute def PressureValue :> Real { unit = "Pa"; }
    attribute def TempValue :> Real { unit = "K"; }
    attribute def VoltageValue :> Real { unit = "V"; }
    attribute def FrequencyValue :> Real { unit = "Hz"; }
    attribute def SpeedValue :> Real { unit = "rpm"; }
    attribute def PowerValue :> Real { unit = "W"; }
    attribute def MassFlowValue :> Real { unit = "kg/s"; }

    item def Water {
        attribute temperature : TempValue;
    }
    item def Steam {
        attribute pressure : PressureValue;
        attribute temperature : TempValue;
    }
    item def SuperheatedSteam :> Steam;
    item def ExhaustSteam :> Steam;
    item def Condensate :> Water;
    item def CoolingWater :> Water;
    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute frequency : FrequencyValue;
    }
    item def MechanicalEnergy {
        attribute rotationalSpeed : SpeedValue;
        attribute torque : Real;
    }
    item def Fuel;

    port def SteamOutPort {
        out item steam : SuperheatedSteam;
    }
    port def SteamInPort {
        in item steam : SuperheatedSteam;
    }
    port def ExhaustSteamOutPort {
        out item steam : ExhaustSteam;
    }
    port def ExhaustSteamInPort {
        in item steam : ExhaustSteam;
    }
    port def WaterOutPort {
        out item water : Condensate;
    }
    port def WaterInPort {
        in item water : Condensate;
    }
    port def CoolingWaterInPort {
        in item coolingWater : CoolingWater;
    }
    port def CoolingWaterOutPort {
        out item coolingWater : CoolingWater;
    }
    port def MechanicalShaftPort {
        out item shaft : MechanicalEnergy;
    }
    port def MechanicalShaftInPort {
        in item shaft : MechanicalEnergy;
    }
    port def ElectricalOutPort {
        out item power : ElectricalPower;
    }
    port def ElectricalInPort {
        in item power : ElectricalPower;
    }
    port def FuelInPort {
        in item fuel : Fuel;
    }

    action def GenerateHeat {
        in fuel : Fuel;
        out heatPower : PowerValue;
    }
    action def BoilWater {
        in water : Water;
        in heatPower : PowerValue;
        out saturatedSteam : Steam;
    }
    action def SuperheatSteam {
        in steam : Steam;
        in heatPower : PowerValue;
        out superheatedSteam : SuperheatedSteam;
    }
    action def ExpandSteam {
        in highPressureSteam : SuperheatedSteam;
        out exhaustSteam : ExhaustSteam;
        out shaftEnergy : MechanicalEnergy;
    }
    action def GenerateElectricity {
        in shaftEnergy : MechanicalEnergy;
        out electricPower : ElectricalPower;
    }
    action def CondenseSteamAction {
        in exhaustSteam : ExhaustSteam;
        in coolingWater : CoolingWater;
        out condensate : Condensate;
        out heatedCoolingWater : CoolingWater;
    }
    action def CoolSystem {
        in coolingWater : CoolingWater;
        out heatedCoolingWater : CoolingWater;
    }
    action def PumpWater {
        in water : Condensate;
        out pressurizedWater : Condensate;
    }
    action def GovernSpeed {
        in currentSpeed : SpeedValue;
        out throttlePosition : Real;
    }

    state def SpeedControlState {
        attribute currentSpeed : SpeedValue;
        attribute targetSpeed : SpeedValue;
        attribute throttlePosition : Real;
        
        state idle;
        state regulating;
        state overspeed;
        transition from idle to regulating [currentSpeed > 0.0];
        transition from regulating to overspeed [currentSpeed > targetSpeed * 1.1];
        transition from overspeed to idle [throttlePosition <= 0.0];
    }

    state def VacuumControlState {
        attribute currentPressure : PressureValue;
        attribute maxPressure : PressureValue;
        
        state monitoring;
        state evacuating;
        transition from monitoring to evacuating [currentPressure > maxPressure];
        transition from evacuating to monitoring [currentPressure <= maxPressure];
    }

    part def SteamBoiler {
        port fuelIn : FuelInPort;
        port waterIn : WaterInPort;
        port steamOut : SteamOutPort;

        attribute heatPower : PowerValue;
        item saturatedSteam : Steam;

        part combustionChamber;
        part drum;
        part superheater;

        perform action generateHeat : GenerateHeat {
            in fuel = fuelIn.fuel;
            out heatPower = heatPower;
        }
        perform action boil : BoilWater {
            in water = waterIn.water;
            in heatPower = heatPower;
            out saturatedSteam = saturatedSteam;
        }
        perform action superheat : SuperheatSteam {
            in steam = saturatedSteam;
            in heatPower = heatPower;
            out superheatedSteam = steamOut.steam;
        }
    }

    part def SteamTurbine {
        port steamIn : SteamInPort;
        port steamOut : ExhaustSteamOutPort;
        port shaftOut : MechanicalShaftPort;

        part rotor {
            attribute bladeStages : Integer = 3;
        }
        part statorCasing;
        part blades;

        perform action expand : ExpandSteam {
            in highPressureSteam = steamIn.steam;
            out exhaustSteam = steamOut.steam;
            out shaftEnergy = shaftOut.shaft;
        }

        part governor {
            attribute currentSpeed : SpeedValue;
            attribute targetSpeed : SpeedValue = 3000.0;
            attribute throttlePosition : Real;

            perform action govern : GovernSpeed {
                in currentSpeed = currentSpeed;
                out throttlePosition = throttlePosition;
            }

            state speedControl : SpeedControlState;
        }
    }

    part def ElectricalGenerator {
        port shaftIn : MechanicalShaftInPort;
        port electricalOut : ElectricalOutPort;
        port coolingWaterIn : CoolingWaterInPort;
        port coolingWaterOut : CoolingWaterOutPort;

        part rotorField {
            attribute excitationCurrent : Real;
        }
        part statorWinding;
        part coolingMechanism;

        attribute outputFrequency : FrequencyValue = 50.0;
        attribute outputVoltage : VoltageValue = 11000.0;

        perform action convert : GenerateElectricity {
            in shaftEnergy = shaftIn.shaft;
            out electricPower = electricalOut.power;
        }
        perform action cool : CoolSystem {
            in coolingWater = coolingWaterIn.coolingWater;
            out heatedCoolingWater = coolingWaterOut.coolingWater;
        }
    }

    part def SteamCondenser {
        port steamIn : ExhaustSteamInPort;
        port waterOut : WaterOutPort;
        port coolingWaterIn : CoolingWaterInPort;
        port coolingWaterOut : CoolingWaterOutPort;

        part tubeBundle;

        part hotwell {
            item condensate : Condensate;
            attribute level : Real;
        }

        perform action condense : CondenseSteamAction {
            in exhaustSteam = steamIn.steam;
            in coolingWater = coolingWaterIn.coolingWater;
            out condensate = hotwell.condensate;
            out heatedCoolingWater = coolingWaterOut.coolingWater;
        }

        part vacuumSystem {
            attribute currentPressure : PressureValue;
            attribute maxPressure : PressureValue = 5000.0;

            state vacuumControl : VacuumControlState;
        }
    }

    part def FeedwaterPump {
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
        perform action pump : PumpWater {
            in water = waterIn.water;
            out pressurizedWater = waterOut.water;
        }
    }

    part def PowerGrid {
        port electricalIn : ElectricalInPort;
        attribute nominalFrequency : FrequencyValue = 50.0;
        attribute nominalVoltage : VoltageValue = 11000.0;
    }

    part def CoolingWaterSource {
        port supplyPort : CoolingWaterOutPort;
    }

    part def CoolingWaterSink {
        port returnPort : CoolingWaterInPort;
    }

    requirement 'Grid Synchronization Requirement' {
        doc /* The generator output shall be synchronized to the grid at 50 Hz with a voltage of 11 kV. */
        attribute targetFrequency : FrequencyValue = 50.0;
        attribute targetVoltage : VoltageValue = 11000.0;
    }

    requirement 'Steam Pressure Requirement' {
        doc /* The boiler shall produce superheated steam at a minimum pressure of 10 MPa and temperature of 540 C. */
        attribute minPressure : PressureValue = 10000000.0;
        attribute minTemperature : TempValue = 813.15;
    }

    requirement 'Condenser Vacuum Requirement' {
        doc /* The condenser shall maintain a vacuum pressure below 5 kPa to maximize thermal efficiency. */
        attribute maxPressure : PressureValue = 5000.0;
    }

    requirement 'Turbine Speed Requirement' {
        doc /* The turbine shall maintain a rotational speed of 3000 rpm for 50 Hz grid operation. */
        attribute nominalSpeed : SpeedValue = 3000.0;
    }

    part powerPlant {
        part boiler : SteamBoiler;
        part turbine : SteamTurbine;
        part generator : ElectricalGenerator;
        part condenser : SteamCondenser;
        part feedwaterPump : FeedwaterPump;
        part grid : PowerGrid;
        part coolingSource : CoolingWaterSource;
        part coolingSink : CoolingWaterSink;

        flow of SuperheatedSteam
            from boiler.steamOut.steam to turbine.steamIn.steam;

        flow of ExhaustSteam
            from turbine.steamOut.steam to condenser.steamIn.steam;

        flow of MechanicalEnergy
            from turbine.shaftOut.shaft to generator.shaftIn.shaft;

        flow of ElectricalPower
            from generator.electricalOut.power to grid.electricalIn.power;

        flow of Condensate
            from condenser.waterOut.water to feedwaterPump.waterIn.water;

        flow of Condensate
            from feedwaterPump.waterOut.water to boiler.waterIn.water;

        flow of CoolingWater
            from coolingSource.supplyPort.coolingWater to condenser.coolingWaterIn.coolingWater;

        flow of CoolingWater
            from condenser.coolingWaterOut.coolingWater to coolingSink.returnPort.coolingWater;

        flow of CoolingWater
            from coolingSource.supplyPort.coolingWater to generator.coolingWaterIn.coolingWater;

        flow of CoolingWater
            from generator.coolingWaterOut.coolingWater to coolingSink.returnPort.coolingWater;
    }

    satisfy 'Grid Synchronization Requirement' by powerPlant.generator;
    satisfy 'Steam Pressure Requirement' by powerPlant.boiler;
    satisfy 'Condenser Vacuum Requirement' by powerPlant.condenser;
    satisfy 'Turbine Speed Requirement' by powerPlant.turbine;
}
