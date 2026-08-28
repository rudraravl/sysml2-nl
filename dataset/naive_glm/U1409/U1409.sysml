package ExternalCombustionEngineSystem {

    import ScalarValues::*;

    // ============================================================
    //                    Value Types (with units)
    // ============================================================
    value type Pressure :> Real {
        doc "Pressure expressed in kilopascals (kPa).";
    }
    value type Temperature :> Real {
        doc "Temperature expressed in degrees Celsius (°C).";
    }
    value type MassFlowRate :> Real {
        doc "Mass flow rate in kilograms per second (kg/s).";
    }
    value type VolumeFlowRate :> Real {
        doc "Volume flow rate in liters per second (L/s).";
    }
    value type Torque :> Real {
        doc "Mechanical torque in newton-meters (N·m).";
    }
    value type AngularSpeed :> Real {
        doc "Rotational speed in radians per second (rad/s).";
    }
    value type Power :> Real {
        doc "Mechanical power in kilowatts (kW).";
    }
    value type HeatRate :> Real {
        doc "Thermal power/heat rate in kilowatts-thermal (kW).";
    }
    value type Volume :> Real {
        doc "Volume in liters (L).";
    }
    value type Efficiency :> Real {
        doc "Efficiency expressed as a dimensionless ratio (0 to 1).";
    }
    value type Percent :> Real {
        doc "Percentage value (0 to 100).";
    }
    value type SpecificEnergy :> Real {
        doc "Specific energy in megajoules per kilogram (MJ/kg).";
    }
    value type Duration :> Real {
        doc "Duration in seconds (s).";
    }

    // ============================================================
    //                    Items (Working Fluids)
    // ============================================================
    item def Fuel {
        attribute flowRate : MassFlowRate;
        attribute heatingValue : SpecificEnergy;
    }
    item def Feedwater {
        attribute flowRate : MassFlowRate;
        attribute pressure : Pressure;
        attribute temperature : Temperature;
    }
    item def HighPressureSteam {
        attribute flowRate : MassFlowRate;
        attribute pressure : Pressure;
        attribute temperature : Temperature;
    }
    item def ExhaustSteam {
        attribute flowRate : MassFlowRate;
        attribute pressure : Pressure;
        attribute temperature : Temperature;
    }
    item def Condensate {
        attribute flowRate : MassFlowRate;
        attribute pressure : Pressure;
        attribute temperature : Temperature;
    }
    item def CoolingWater {
        attribute flowRate : VolumeFlowRate;
        attribute inletTemperature : Temperature;
        attribute outletTemperature : Temperature;
    }
    item def CombustionGases {
        attribute flowRate : MassFlowRate;
        attribute temperature : Temperature;
    }

    // ============================================================
    //                         Ports
    // ============================================================
    port def FuelInPort {
        in item Fuel;
        attribute flowRate : MassFlowRate;
    }
    port def CombustionGasOutPort {
        out item CombustionGases;
        attribute flowRate : MassFlowRate;
    }
    port def FeedwaterInPort {
        in item Feedwater;
        attribute flowRate : MassFlowRate;
        attribute pressure : Pressure;
    }
    port def HighPressureSteamOutPort {
        out item HighPressureSteam;
        attribute flowRate : MassFlowRate;
        attribute pressure : Pressure;
        attribute temperature : Temperature;
    }
    port def HighPressureSteamInPort {
        in item HighPressureSteam;
        attribute flowRate : MassFlowRate;
        attribute pressure : Pressure;
        attribute temperature : Temperature;
    }
    port def ExhaustSteamOutPort {
        out item ExhaustSteam;
        attribute flowRate : MassFlowRate;
        attribute pressure : Pressure;
    }
    port def ExhaustSteamInPort {
        in item ExhaustSteam;
        attribute flowRate : MassFlowRate;
        attribute pressure : Pressure;
    }
    port def CondensateOutPort {
        out item Condensate;
        attribute flowRate : MassFlowRate;
        attribute temperature : Temperature;
    }
    port def CondensateInPort {
        in item Condensate;
        attribute flowRate : MassFlowRate;
        attribute temperature : Temperature;
    }
    port def CoolingWaterInPort {
        in item CoolingWater;
        attribute flowRate : VolumeFlowRate;
        attribute inletTemperature : Temperature;
    }
    port def CoolingWaterOutPort {
        out item CoolingWater;
        attribute flowRate : VolumeFlowRate;
        attribute outletTemperature : Temperature;
    }
    port def MechanicalOutputPort {
        attribute torque : Torque;
        attribute speed : AngularSpeed;
        attribute power : Power;
    }

    // ============================================================
    //                         Boiler
    // ============================================================
    part def Boiler {
        doc "A furnace and heat exchanger that combusts fuel and converts pressurized feedwater into high-pressure, high-temperature steam.";
        port fuelIn : FuelInPort;
        port exhaustGasOut : CombustionGasOutPort;
        port waterIn : FeedwaterInPort;
        port steamOut : HighPressureSteamOutPort;

        attribute boilerPressure : Pressure := 100;
        attribute waterLevel : Percent := 50;
        attribute flameTemperature : Temperature := 1200;
        attribute heatInput : HeatRate := 0;
        attribute targetPressure : Pressure := 16000;
        attribute maxSafePressure : Pressure := 20000;
        attribute minWaterLevel : Percent := 20;
        attribute steamOutputFlow : MassFlowRate := 0;
        attribute startupDuration : Duration := 60;

        exhibit state BoilerOperation {
            initial state off {
                entry / boilerPressure := 100;
                entry / steamOutputFlow := 0;
                entry / heatInput := 0;
            }
            state preheating {
                entry / heatInput := 800;
                entry / flameTemperature := 1200;
            }
            state generating {
                entry / steamOutputFlow := 0.5;
                entry / boilerPressure := targetPressure;
            }
            state faulted {
                entry / heatInput := 0;
                entry / steamOutputFlow := 0;
            }

            transition off -> preheating
                on (waterLevel >= minWaterLevel && fuelIn.flowRate > 0);
            transition preheating -> generating
                on (boilerPressure >= targetPressure);
            transition generating -> off
                on (fuelIn.flowRate == 0);
            transition generating -> faulted
                on (boilerPressure > maxSafePressure);
            transition faulted -> off
                on (boilerPressure < 200);
        }
    }

    // ============================================================
    //                      Steam Expander
    // ============================================================
    part def SteamExpander {
        doc "A piston or turbine device that expands high-pressure steam, converting its thermal energy into rotational mechanical torque.";
        port steamIn : HighPressureSteamInPort;
        port exhaustOut : ExhaustSteamOutPort;
        port mechOut : MechanicalOutputPort;

        attribute outputTorque : Torque := 0;
        attribute outputSpeed : AngularSpeed := 0;
        attribute outputPower : Power := 0;
        attribute expansionRatio : Real := 4.0;
        attribute inletPressure : Pressure := 16000;
        attribute exhaustPressure : Pressure := 100;
        attribute minOperatingSpeed : AngularSpeed := 30;

        exhibit state ExpanderOperation {
            initial state idle {
                entry / outputTorque := 0;
                entry / outputSpeed := 0;
                entry / outputPower := 0;
            }
            state accelerating {
                entry / outputSpeed := outputSpeed + 10;
            }
            state running {
                entry / outputPower := (outputTorque * outputSpeed) / 1000;
            }
            state coasting {
                entry / outputTorque := 0;
            }

            transition idle -> accelerating
                on (steamIn.flowRate > 0);
            transition accelerating -> running
                on (outputSpeed >= minOperatingSpeed);
            transition running -> coasting
                on (steamIn.flowRate == 0);
            transition coasting -> idle
                on (outputSpeed == 0);
        }
    }

    // ============================================================
    //                         Condenser
    // ============================================================
    part def Condenser {
        doc "A heat exchanger that condenses low-pressure exhaust steam back into liquid water using an external cooling-water source.";
        port steamIn : ExhaustSteamInPort;
        port coolingIn : CoolingWaterInPort;
        port coolingOut : CoolingWaterOutPort;
        port condensateOut : CondensateOutPort;

        attribute coolingWaterFlow : VolumeFlowRate := 0;
        attribute condensateTemperature : Temperature := 40;
        attribute condensatePressure : Pressure := 100;
        attribute heatRejected : HeatRate := 0;
        attribute condensateFlow : MassFlowRate := 0;

        exhibit state CondenserOperation {
            initial state standby {
                entry / heatRejected := 0;
                entry / condensateFlow := 0;
            }
            state condensing {
                entry / condensateFlow := steamIn.flowRate;
                entry / heatRejected := steamIn.flowRate * 2200;
                entry / condensateTemperature := 40;
            }

            transition standby -> condensing
                on (steamIn.flowRate > 0 && coolingIn.flowRate > 0);
            transition condensing -> standby
                on (steamIn.flowRate == 0);
        }
    }

    // ============================================================
    //                     Feedwater Pump
    // ============================================================
    part def FeedwaterPump {
        doc "A positive-displacement or centrifugal pump that pressurizes liquid condensate and returns it to the boiler, completing the closed loop.";
        port condensateIn : CondensateInPort;
        port waterOut : FeedwaterInPort;

        attribute pumpPressure : Pressure := 16000;
        attribute pumpFlow : MassFlowRate := 0;
        attribute powerConsumption : Power := 0;
        attribute nominalPumpPower : Power := 5;

        exhibit state PumpOperation {
            initial state stopped {
                entry / pumpFlow := 0;
                entry / powerConsumption := 0;
            }
            state pumping {
                entry / pumpFlow := condensateIn.flowRate;
                entry / powerConsumption := nominalPumpPower;
            }

            transition stopped -> pumping
                on (condensateIn.flowRate > 0);
            transition pumping -> stopped
                on (condensateIn.flowRate == 0);
        }
    }

    // ============================================================
    //          External Combustion Engine (System of Systems)
    // ============================================================
    part def ExternalCombustionEngine {
        doc "A closed-loop external combustion engine system that uses water as working fluid and converts thermal energy from fuel combustion into continuous mechanical power output.";
        part boiler : Boiler;
        part expander : SteamExpander;
        part condenser : Condenser;
        part feedpump : FeedwaterPump;

        // External interface ports
        port fuelSupply : FuelInPort;
        port exhaustVent : CombustionGasOutPort;
        port coolingSupply : CoolingWaterInPort;
        port coolingReturn : CoolingWaterOutPort;
        port mechanicalOutput : MechanicalOutputPort;

        // Internal flow connections (closed-loop cycle)
        connection FuelConduit connect fuelSupply to boiler.fuelIn;
        connection ExhaustGasConduit connect boiler.exhaustGasOut to exhaustVent;
        connection HighPressureSteamConduit connect boiler.steamOut to expander.steamIn;
        connection ExhaustSteamConduit connect expander.exhaustOut to condenser.steamIn;
        connection CoolingInConduit connect coolingSupply to condenser.coolingIn;
        connection CoolingOutConduit connect condenser.coolingOut to coolingReturn;
        connection CondensateConduit connect condenser.condensateOut to feedpump.condensateIn;
        connection FeedwaterConduit connect feedpump.waterOut to boiler.waterIn;
        connection ShaftCoupling connect expander.mechOut to mechanicalOutput;

        // System-level attributes
        attribute currentPower : Power := 0;
        attribute thermalEfficiency : Efficiency := 0;
        attribute operatingPressure : Pressure := 100;
        attribute minEfficiency : Efficiency := 0.15;
        attribute nominalPower : Power := 100;
        attribute maxOperatingPressure : Pressure := 20000;
        attribute startSignal : Boolean := false;
        attribute stopSignal : Boolean := false;
        attribute emergencySignal : Boolean := false;

        exhibit state EngineLifecycle {
            initial state idle {
                entry / currentPower := 0;
                entry / thermalEfficiency := 0;
                entry / startSignal := false;
                entry / stopSignal := false;
            }
            state startup {
                entry / boiler.heatInput := 800;
            }
            state operating {
                entry / currentPower := expander.outputPower;
                entry / operatingPressure := boiler.boilerPressure;
                entry / thermalEfficiency := currentPower / boiler.heatInput;
            }
            state shutdown {
                entry / boiler.heatInput := 0;
                entry / currentPower := 0;
            }
            state emergency {
                entry / boiler.heatInput := 0;
                entry / boiler.steamOutputFlow := 0;
            }

            transition idle -> startup
                on (startSignal == true);
            transition startup -> operating
                on (boiler.boilerPressure >= boiler.targetPressure
                     && expander.outputSpeed >= expander.minOperatingSpeed);
            transition operating -> shutdown
                on (stopSignal == true);
            transition operating -> emergency
                on (boiler.boilerPressure > boiler.maxSafePressure
                     || boiler.waterLevel < boiler.minWaterLevel);
            transition emergency -> shutdown
                on (boiler.boilerPressure < 1000);
            transition shutdown -> idle
                on (boiler.boilerPressure < 200);
        }
    }

    // ============================================================
    //                      Requirements
    // ============================================================
    requirement def PressureSafety {
        doc "The boiler pressure must remain within safe operating limits during all phases of operation.";
        subject e : ExternalCombustionEngine;
        requirement pressureLimit {
            e.boiler.boilerPressure <= e.boiler.maxSafePressure;
        }
    }

    requirement def WaterLevelSafety {
        doc "The boiler water level must be maintained at or above the minimum safe level to prevent dry firing.";
        subject e : ExternalCombustionEngine;
        requirement minimumLevel {
            e.boiler.waterLevel >= e.boiler.minWaterLevel;
        }
    }

    requirement def ThermalEfficiencyRequirement {
        doc "The engine must achieve a minimum thermal efficiency of 15 percent during normal operation.";
        subject e : ExternalCombustionEngine;
        requirement minimumEfficiency {
            e.thermalEfficiency >= e.minEfficiency;
        }
    }

    requirement def ClosedLoopMassConservation {
        doc "The closed-loop working fluid cycle must conserve mass; the feedwater flow into the boiler must equal the steam flow out of the boiler during steady operation.";
        subject e : ExternalCombustionEngine;
        requirement massBalance {
            e.boiler.steamOut.flowRate == e.feedpump.waterOut.flowRate;
        }
    }

    requirement def NominalPowerDelivery {
        doc "The engine must deliver at least the nominal mechanical power output during the operating state.";
        subject e : ExternalCombustionEngine;
        requirement minimumPower {
            e.mechanicalOutput.power >= e.nominalPower;
        }
    }

    requirement def ContinuousCycleOperation {
        doc "Once in the operating state, the cycle must sustain itself continuously: steam generation, expansion, condensation, and feedwater return must all remain active.";
        subject e : ExternalCombustionEngine;
        requirement continuous {
            e.boiler.steamOut.flowRate > 0
                && e.expander.steamIn.flowRate > 0
                && e.condenser.condensateOut.flowRate > 0
                && e.feedpump.waterOut.flowRate > 0;
        }
    }

    requirement def SafeEmergencyResponse {
        doc "Upon detection of an over-pressure or low-water condition, the system must transition to a safe emergency state that reduces heat input and halts steam generation.";
        subject e : ExternalCombustionEngine;
        requirement safeShutdown {
            (e.boiler.boilerPressure > e.boiler.maxSafePressure
                or e.boiler.waterLevel < e.boiler.minWaterLevel)
                implies (e.boiler.heatInput == 0
                && e.boiler.steamOutputFlow == 0);
        }
    }

    // ============================================================
    //                      Satisfactions
    // ============================================================
    satisfaction satisfy PressureSafety by ExternalCombustionEngine;
    satisfaction satisfy WaterLevelSafety by ExternalCombustionEngine;
    satisfaction satisfy ThermalEfficiencyRequirement by ExternalCombustionEngine;
    satisfaction satisfy ClosedLoopMassConservation by ExternalCombustionEngine;
    satisfaction satisfy NominalPowerDelivery by ExternalCombustionEngine;
    satisfaction satisfy ContinuousCycleOperation by ExternalCombustionEngine;
    satisfaction satisfy SafeEmergencyResponse by ExternalCombustionEngine;

}
