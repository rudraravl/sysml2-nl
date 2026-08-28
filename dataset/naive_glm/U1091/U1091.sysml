package IntegerMillenniumHouse {
    import ScalarValues::*;
    import ISQ::*;
    import ISQEnergy::*;
    import ISQPower::*;
    import ISQVolume::*;
    import ISQTemperature::*;
    import ISQTime::*;

    // ---------- Value types with units ----------
    value type PowerFlow :> Real { unit 'kW'; }
    value type EnergyQty :> Real { unit 'kWh'; }
    value type VolumeFlow :> Real { unit 'm3/h'; }
    value type VolumeQty :> Real { unit 'm3'; }
    value type TempValue :> Real { unit 'degC'; }
    value type PercentEff :> Real { unit '%'; }
    value type CO2Concentration :> Real { unit 'ppm'; }
    value type Illuminance :> Real { unit 'lux'; }
    value type AreaValue :> Real { unit 'm2'; }
    value type UValue :> Real { unit 'W/(m2*K)'; }

    // ---------- Item types ----------
    item def ElectricalEnergy;
    item def FreshAir;
    item def StaleAir;
    item def SupplyAir;
    item def ExhaustAir;
    item def Rainwater;
    item def PotableWater;
    item def NonPotableWater;
    item def DomesticHotWater;
    item def HeatingWater;
    item def CoolingWater;
    item def SolarRadiation;
    item def GroundLoopFluid;

    // ---------- Port definitions ----------
    port def ElectricPort {
        out energy : ElectricalEnergy;
        out power : PowerFlow;
    }
    port def AirPort {
        out air : FreshAir;
        in stale : StaleAir;
    }
    port def WaterPort {
        out water : HeatingWater;
        in return : HeatingWater;
    }
    port def ThermalPort {
        out heat : HeatingWater;
        in cool : CoolingWater;
    }
    port def DataPort {
        out signal : ScalarValues::Real;
    }
    port def ControlPort {
        in command : ScalarValues::Real;
    }

    // ---------- Requirements ----------
    requirement def NearZeroEnergyRequirement {
        doc /* The house shall achieve near-zero annual net energy usage. */
        attribute annualNetEnergy : EnergyQty;
        constraint { annualNetEnergy <= 10.0 [kWh] }
    }

    requirement def ComfortRequirement {
        attribute indoorTemp : TempValue;
        attribute co2Level : CO2Concentration;
        constraint { indoorTemp >= 19.0 [degC] and indoorTemp <= 24.0 [degC] }
        constraint { co2Level <= 1000.0 [ppm] }
    }

    requirement def AirtightnessRequirement {
        attribute airLeakageRate : VolumeFlow;
        constraint { airLeakageRate <= 0.6 [m3/h] }
    }

    requirement def HeatRecoveryRequirement {
        attribute recoveryEfficiency : PercentEff;
        constraint { recoveryEfficiency >= 90.0 [%] }
    }

    requirement def EnvelopeInsulationRequirement {
        attribute wallUValue : UValue;
        attribute roofUValue : UValue;
        constraint { wallUValue <= 0.15 [W/(m2*K)] }
        constraint { roofUValue <= 0.10 [W/(m2*K)] }
    }

    // ---------- Part definitions ----------
    part def PassiveHouseEnvelope {
        attribute wallUValue : UValue = 0.12 [W/(m2*K)];
        attribute roofUValue : UValue = 0.08 [W/(m2*K)];
        attribute floorUValue : UValue = 0.10 [W/(m2*K)];
        attribute thermalMass : Real = 2500.0; // kJ/K
        attribute airtightness : VolumeFlow = 0.5 [m3/h];
        port def ExteriorPort {
            out radiation : SolarRadiation;
        }
        port exterior : ExteriorPort;
        part tripleGlazedWindows {
            attribute glazingUValue : UValue = 0.7 [W/(m2*K)];
            attribute solarHeatGainCoeff : Real = 0.5;
            attribute totalArea : AreaValue = 25.0 [m2];
        }
        satisfy EnvelopeInsulationRequirement by wallUValue, roofUValue;
        satisfy AirtightnessRequirement by airtightness;
    }

    part def PhotovoltaicArray {
        attribute peakPower : PowerFlow = 8.0 [kW];
        attribute arrayArea : AreaValue = 50.0 [m2];
        attribute efficiency : PercentEff = 22.0 [%];
        port dcOutput : ElectricPort;
        port solarInput :> ExteriorPort {
            in radiation : SolarRadiation;
        }
        action def GenerateElectricity {
            in solar : SolarRadiation;
            out electricity : ElectricalEnergy;
            out power : PowerFlow;
        }
    }

    part def GroundSourceHeatPump {
        attribute heatingCapacity : PowerFlow = 6.0 [kW];
        attribute coolingCapacity : PowerFlow = 5.0 [kW];
        attribute coefficientOfPerformance : Real = 4.5;
        attribute groundLoopTemp : TempValue = 12.0 [degC];
        port electricInput : ElectricPort;
        port heatingOutput : WaterPort;
        port coolingOutput : WaterPort;
        port groundLoop :> WaterPort {
            out fluid : GroundLoopFluid;
            in return : GroundLoopFluid;
        }
        action def OperateHeating {
            in electricity : ElectricalEnergy;
            out heatingWater : HeatingWater;
        }
        action def OperateCooling {
            in electricity : ElectricalEnergy;
            out coolingWater : CoolingWater;
        }
        state def OperatingMode {
            initial state Off;
            state Heating;
            state Cooling;
            transition from Off to Heating when electricInput.power > 0.0 [kW];
            transition from Heating to Cooling when heatingOutput.water.temp > 24.0 [degC];
            transition from Cooling to Off when electricInput.power == 0.0 [kW];
        }
    }

    part def MVHRSystem {
        attribute heatRecoveryEfficiency : PercentEff = 92.0 [%];
        attribute maxFlowRate : VolumeFlow = 350.0 [m3/h];
        attribute filterEfficiency : PercentEff = 95.0 [%];
        port supplyAir :> AirPort {
            out supply : SupplyAir;
        }
        port exhaustAir :> AirPort {
            in exhaust : ExhaustAir;
        }
        port electricInput : ElectricPort;
        satisfy HeatRecoveryRequirement by heatRecoveryEfficiency;
        action def ExchangeHeat {
            in stale : StaleAir;
            in fresh : FreshAir;
            out supply : SupplyAir;
            out exhaust : ExhaustAir;
        }
    }

    part def ThermalEnergyStorageTank {
        attribute tankVolume : VolumeQty = 500.0 [m3];
        attribute insulationUValue : UValue = 0.05 [W/(m2*K)];
        attribute storedTemp : TempValue = 60.0 [degC];
        attribute maxTemp : TempValue = 85.0 [degC];
        attribute minTemp : TempValue = 35.0 [degC];
        port chargePort : WaterPort;
        port dischargePort : WaterPort;
        state def ChargeState {
            initial state Idle;
            state Charging;
            state Discharging;
            transition from Idle to Charging when chargePort.water.temp > storedTemp;
            transition from Charging to Idle when storedTemp >= maxTemp;
            transition from Idle to Discharging when dischargePort.return.temp < storedTemp;
            transition from Discharging to Idle when storedTemp <= minTemp;
        }
    }

    part def LEDLightingSystem {
        attribute totalPower : PowerFlow = 0.8 [kW];
        attribute luminousEfficacy : Real = 120.0; // lm/W
        attribute targetIlluminance : Illuminance = 300.0 [lux];
        port electricInput : ElectricPort;
        port controlInput : ControlPort;
        action def Illuminate {
            in electricity : ElectricalEnergy;
            in command : ScalarValues::Real;
            out light : Illuminance;
        }
    }

    part def RainwaterHarvestingSystem {
        attribute collectionArea : AreaValue = 120.0 [m2];
        attribute storageVolume : VolumeQty = 5.0 [m3];
        attribute currentLevel : VolumeQty = 2.5 [m3];
        port rainwaterInput :> AirPort {
            in rain : Rainwater;
        }
        port nonPotableOutput :> WaterPort {
            out water : NonPotableWater;
        }
        action def CollectRainwater {
            in rain : Rainwater;
            out stored : NonPotableWater;
        }
        action def DistributeNonPotable {
            in stored : NonPotableWater;
            out water : NonPotableWater;
        }
    }

    part def OccupancySensor {
        attribute detectionRange : AreaValue = 20.0 [m2];
        attribute responseTime : Real = 0.5; // seconds
        port dataOutput : DataPort;
        action def DetectOccupancy {
            out occupancySignal : ScalarValues::Real;
        }
    }

    part def EnvironmentalMonitor {
        attribute measuredTemp : TempValue = 21.0 [degC];
        attribute measuredCO2 : CO2Concentration = 600.0 [ppm];
        attribute measuredHumidity : PercentEff = 45.0 [%];
        port tempOutput : DataPort;
        port co2Output : DataPort;
        port humidityOutput : DataPort;
        action def MeasureEnvironment {
            out temp : TempValue;
            out co2 : CO2Concentration;
            out humidity : PercentEff;
        }
    }

    part def BuildingManagementSystem {
        attribute optimizationInterval : Real = 60.0; // seconds
        attribute occupancyThreshold : Real = 0.5;
        port tempInput : DataPort;
        port co2Input : DataPort;
        port occupancyInput : DataPort;
        port heatPumpControl : ControlPort;
        port mvhrControl : ControlPort;
        port lightingControl : ControlPort;
        action def OptimizeSystems {
            in temp : TempValue;
            in co2 : CO2Concentration;
            in occupancy : ScalarValues::Real;
            in solarPower : PowerFlow;
            out heatPumpCommand : ScalarValues::Real;
            out mvhrCommand : ScalarValues::Real;
            out lightingCommand : ScalarValues::Real;
            // Decision logic
            if occupancy > occupancyThreshold {
                if temp < 19.0 [degC] { heatPumpCommand = 1.0; }
                else if temp > 24.0 [degC] { heatPumpCommand = -1.0; }
                else { heatPumpCommand = 0.0; }
                if co2 > 800.0 [ppm] { mvhrCommand = 1.0; }
                else { mvhrCommand = 0.5; }
                lightingCommand = 1.0;
            } else {
                heatPumpCommand = 0.0;
                mvhrCommand = 0.2;
                lightingCommand = 0.0;
            }
        }
        state def BMSState {
            initial state Monitoring;
            state Analyzing;
            state Commanding;
            transition from Monitoring to Analyzing when tempInput.signal != 0.0;
            transition from Analyzing to Commanding when true;
            transition from Commanding to Monitoring when true;
        }
    }

    // ---------- Top-level house ----------
    part def IntegerMillenniumHouse {
        satisfy NearZeroEnergyRequirement;
        satisfy ComfortRequirement;

        part envelope : PassiveHouseEnvelope;
        part pvArray : PhotovoltaicArray;
        part heatPump : GroundSourceHeatPump;
        part mvhr : MVHRSystem;
        part thermalStore : ThermalEnergyStorageTank;
        part lighting : LEDLightingSystem;
        part rainwaterSystem : RainwaterHarvestingSystem;
        part bms : BuildingManagementSystem;
        part occupancySensors[4] : OccupancySensor;
        part envMonitors[6] : EnvironmentalMonitor;

        // Electrical connections
        connection pvArray.dcOutput to heatPump.electricInput;
        connection pvArray.dcOutput to mvhr.electricInput;
        connection pvArray.dcOutput to lighting.electricInput;

        // Thermal connections
        connection heatPump.heatingOutput to thermalStore.chargePort;
        connection thermalStore.dischargePort to mvhr.supplyAir;

        // Air connections
        connection mvhr.supplyAir to envelope.exterior;

        // Water connections
        connection rainwaterSystem.nonPotableOutput to heatPump.groundLoop;

        // Data connections
        connection occupancySensors[1].dataOutput to bms.occupancyInput;
        connection occupancySensors[2].dataOutput to bms.occupancyInput;
        connection occupancySensors[3].dataOutput to bms.occupancyInput;
        connection occupancySensors[4].dataOutput to bms.occupancyInput;
        connection envMonitors[1].tempOutput to bms.tempInput;
        connection envMonitors[2].tempOutput to bms.tempInput;
        connection envMonitors[3].co2Output to bms.co2Input;
        connection envMonitors[4].co2Output to bms.co2Input;
        connection envMonitors[5].tempOutput to bms.tempInput;
        connection envMonitors[6].co2Output to bms.co2Input;

        // Control connections
        connection bms.heatPumpControl to heatPump.electricInput;
        connection bms.mvhrControl to mvhr.electricInput;
        connection bms.lightingControl to lighting.controlInput;

        // Solar connection
        connection envelope.exterior to pvArray.solarInput;
    }
}
