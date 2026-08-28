package SteamTurbinePowerGeneration {
    import ScalarValues::*;
    import ISQ::*;

    value def Pressure :> Real { unit 'Pa'; }
    value def Temperature :> Real { unit 'K'; }
    value def MassFlowRate :> Real { unit 'kg/s'; }
    value def VolumeFlowRate :> Real { unit 'm3/s'; }
    value def RotationalSpeed :> Real { unit 'rpm'; }
    value def Torque :> Real { unit 'N*m'; }
    value def Voltage :> Real { unit 'V'; }
    value def Frequency :> Real { unit 'Hz'; }
    value def Current :> Real { unit 'A'; }
    value def Power :> Real { unit 'W'; }
    value def HeatRate :> Real { unit 'W'; }
    value def FuelFlowRate :> Real { unit 'kg/s'; }

    item def Water {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute flowRate : MassFlowRate;
    }
    item def Steam {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute flowRate : MassFlowRate;
    }
    item def CombustionGas {
        attribute temperature : Temperature;
        attribute flowRate : MassFlowRate;
    }
    item def CoolingWater {
        attribute temperature : Temperature;
        attribute flowRate : VolumeFlowRate;
    }
    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute frequency : Frequency;
        attribute current : Current;
        attribute activePower : Power;
    }

    port def WaterInPort {
        in water : Water;
    }
    port def WaterOutPort {
        out water : Water;
    }
    port def SteamInPort {
        in steam : Steam;
    }
    port def SteamOutPort {
        out steam : Steam;
    }
    port def CoolingWaterInPort {
        in coolingWater : CoolingWater;
    }
    port def CoolingWaterOutPort {
        out coolingWater : CoolingWater;
    }
    port def FuelInPort {
        in fuelFlow : FuelFlowRate;
    }
    port def FlueGasOutPort {
        out flueGas : CombustionGas;
    }
    port def ShaftPort {
        out speed : RotationalSpeed;
        out torque : Torque;
    }
    port def ElectricalOutputPort {
        out power : ElectricalPower;
    }

    part def CombustionChamber {
        port fuelIn : FuelInPort;
        port flueGasOut : FlueGasOutPort;
        attribute heatRelease : HeatRate := 500e6;
        attribute combustionTemperature : Temperature := 1800;
    }

    part def BoilerDrum {
        port feedwaterIn : WaterInPort;
        port saturatedSteamOut : SteamOutPort;
        attribute operatingPressure : Pressure := 16e6;
        attribute waterLevel : Real := 0.5;
    }

    part def Superheater {
        port steamIn : SteamInPort;
        port steamOut : SteamOutPort;
        attribute outletTemperature : Temperature := 813;
        attribute outletPressure : Pressure := 15e6;
    }

    part def SteamBoiler {
        port feedwaterIn : WaterInPort;
        port superheatedSteamOut : SteamOutPort;
        port fuelIn : FuelInPort;
        port flueGasOut : FlueGasOutPort;

        part combustionChamber : CombustionChamber;
        part drum : BoilerDrum;
        part superheater : Superheater;

        connect fuelIn to combustionChamber.fuelIn;
        connect combustionChamber.flueGasOut to flueGasOut;
        connect feedwaterIn to drum.feedwaterIn;
        connect drum.saturatedSteamOut to superheater.steamIn;
        connect superheater.steamOut to superheatedSteamOut;

        attribute boilerEfficiency : Real := 0.88;
        attribute steamMassFlow : MassFlowRate := 200;

        state def BoilerOperatingStates;
        state machine BoilerOperation : BoilerOperatingStates {
            state ColdStartup;
            state Warming;
            state SteadyOperation;
            state Shutdown;
            transition from ColdStartup to Warming
                when fuelIn.fuelFlow > 0;
            transition from Warming to SteadyOperation
                when superheater.outletTemperature >= 800;
            transition from SteadyOperation to Shutdown
                when fuelIn.fuelFlow == 0;
        }
    }

    part def TurbineRotor {
        port shaftOut : ShaftPort;
        attribute ratedSpeed : RotationalSpeed := 3000;
        attribute momentOfInertia : Real := 5000;
    }

    part def TurbineBladeStage {
        attribute stageNumber : Integer;
        attribute bladeCount : Integer;
        attribute pressureDrop : Pressure;
        attribute temperatureDrop : Temperature;
    }

    part class TurbineStator {
        attribute casingPressureRating : Pressure := 18e6;
        attribute casingMaterial : String := "ChromiumSteel";
    }

    part def Governor {
        attribute setpointSpeed : RotationalSpeed := 3000;
        attribute proportionalGain : Real := 0.05;
        attribute integralGain : Real := 0.01;
        action regulateSpeed(in measuredSpeed : RotationalSpeed, out valvePosition : Real);
    }

    part def SteamTurbine {
        port steamIn : SteamInPort;
        port exhaustSteamOut : SteamOutPort;
        port shaftOut : ShaftPort;

        part rotor : TurbineRotor;
        part stator : TurbineStator;
        part bladeStages : TurbineBladeStage[4] {
            attribute stageNumber = #1..#4;
        }
        part governor : Governor;

        connect steamIn to bladeStages[1].inletSteam;
        connect bladeStages[4].outletSteam to exhaustSteamOut;
        connect rotor.shaftOut to shaftOut;

        attribute inletPressure : Pressure := 15e6;
        attribute inletTemperature : Temperature := 813;
        attribute exhaustPressure : Pressure := 5e3;
        attribute exhaustTemperature : Temperature := 311;

        state def TurbineOperatingStates;
        state machine TurbineOperation : TurbineOperatingStates {
            state Standby;
            state Accelerating;
            state Synchronized;
            state Tripped;
            transition from Standby to Accelerating
                when steamIn.steam.pressure > 1e6;
            transition from Accelerating to Synchronized
                when rotor.shaftOut.speed >= governor.setpointSpeed;
            transition from Synchronized to Tripped
                when rotor.shaftOut.speed > 3300;
        }

        action expandSteam(in highPressureSteam : Steam, out lowPressureSteam : Steam, out mechanicalPower : Power);
    }

    part def GeneratorRotorField {
        port excitationIn : in excitationCurrent : Current;
        attribute excitationCurrent : Current := 1500;
        attribute fieldVoltage : Voltage := 500;
    }

    part def GeneratorStatorWinding {
        port electricalOut : ElectricalOutputPort;
        attribute windingVoltage : Voltage := 21000;
        attribute windingCurrent : Current := 12000;
        attribute insulationClass : String := "F";
    }

    part def GeneratorCoolingSystem {
        port coolingWaterIn : CoolingWaterInPort;
        port coolingWaterOut : CoolingWaterOutPort;
        attribute coolingCapacity : HeatRate := 30e6;
        attribute coolantFlow : VolumeFlowRate := 0.5;
    }

    part def ElectricalGenerator {
        port shaftIn : in shaft : ShaftPort;
        port electricalOut : ElectricalOutputPort;
        port coolingWaterIn : CoolingWaterInPort;
        port coolingWaterOut : CoolingWaterOutPort;

        part rotorField : GeneratorRotorField;
        part statorWinding : GeneratorStatorWinding;
        part coolingSystem : GeneratorCoolingSystem;

        connect shaftIn to rotorField;
        connect rotorField to statorWinding;
        connect statorWinding.electricalOut to electricalOut;
        connect coolingWaterIn to coolingSystem.coolingWaterIn;
        connect coolingSystem.coolingWaterOut to coolingWaterOut;

        attribute ratedPower : Power := 250e6;
        attribute outputVoltage : Voltage := 21000;
        attribute outputFrequency : Frequency := 50;
        attribute efficiency : Real := 0.985;

        state def GeneratorOperatingStates;
        state machine GeneratorOperation : GeneratorOperatingStates {
            state Idle;
            state Exciting;
            state Generating;
            state CooledShutdown;
            transition from Idle to Exciting
                when shaftIn.speed > 2500;
            transition from Exciting to Generating
                when statorWinding.windingVoltage >= outputVoltage;
            transition from Generating to CooledShutdown
                when shaftIn.speed < 2500;
        }

        action generateElectricity(in mechanicalPower : Power, out electricalPower : ElectricalPower);
    }

    part def CondenserTubeBundle {
        port coolingWaterIn : CoolingWaterInPort;
        port coolingWaterOut : CoolingWaterOutPort;
        attribute tubeCount : Integer := 10000;
        attribute heatTransferArea : Real := 12000;
        attribute heatTransferRate : HeatRate := 200e6;
    }

    part def VacuumSystem {
        attribute vacuumPressure : Pressure := 5e3;
        attribute pumpCapacity : VolumeFlowRate := 2.0;
        action maintainVacuum(in measuredPressure : Pressure, out pumpCommand : Real);
    }

    part def Hotwell {
        port condensateOut : WaterOutPort;
        attribute level : Real := 0.5;
        attribute capacity : Real := 50;
        attribute condensateTemperature : Temperature := 311;
    }

    part def CondensatePump {
        port condensateIn : WaterInPort;
        port feedwaterOut : WaterOutPort;
        attribute ratedFlow : MassFlowRate := 200;
        attribute dischargePressure : Pressure := 1e6;
        action pumpWater(in inletWater : Water, out outletWater : Water);
    }

    part def SteamCondenser {
        port exhaustSteamIn : SteamInPort;
        port coolingWaterIn : CoolingWaterInPort;
        port coolingWaterOut : CoolingWaterOutPort;
        port feedwaterOut : WaterOutPort;

        part tubeBundle : CondenserTubeBundle;
        part vacuumSystem : VacuumSystem;
        part hotwell : Hotwell;
        part condensatePump : CondensatePump;

        connect exhaustSteamIn to tubeBundle;
        connect coolingWaterIn to tubeBundle.coolingWaterIn;
        connect tubeBundle.coolingWaterOut to coolingWaterOut;
        connect hotwell.condensateOut to condensatePump.condensateIn;
        connect condensatePump.feedwaterOut to feedwaterOut;

        attribute operatingPressure : Pressure := 5e3;
        attribute condensateFlow : MassFlowRate := 200;

        state def CondenserOperatingStates;
        state machine CondenserOperation : CondenserOperatingStates {
            state Off;
            state VacuumEstablished;
            state Condensing;
            transition from Off to VacuumEstablished
                when vacuumSystem.vacuumPressure < 10e3;
            transition from VacuumEstablished to Condensing
                when exhaustSteamIn.steam.flowRate > 0;
            transition from Condensing to Off
                when exhaustSteamIn.steam.flowRate == 0;
        }

        action condenseSteam(in lowPressureSteam : Steam, in coolingWater : CoolingWater, out condensate : Water, out warmedCoolingWater : CoolingWater);
    }

    part def PowerGrid {
        port gridConnection : ElectricalOutputPort;
        attribute gridFrequency : Frequency := 50;
        attribute gridVoltage : Voltage := 400e3;
        attribute demand : Power := 250e6;
    }

    part def CoolingWaterSource {
        port coolingWaterOut : CoolingWaterOutPort;
        attribute supplyTemperature : Temperature := 293;
        attribute supplyFlow : VolumeFlowRate := 5.0;
    }

    part def FuelSupply {
        port fuelOut : FuelInPort;
        attribute fuelFlow : FuelFlowRate := 20;
    }

    part def SteamTurbinePowerPlant {
        port gridConnection : ElectricalOutputPort;

        part boiler : SteamBoiler;
        part turbine : SteamTurbine;
        part generator : ElectricalGenerator;
        part condenser : SteamCondenser;
        part coolingWaterSource : CoolingWaterSource;
        part fuelSupply : FuelSupply;
        part powerGrid : PowerGrid;

        connect fuelSupply.fuelOut to boiler.fuelIn;
        connect boiler.flueGasOut to fuelSupply;
        connect boiler.superheatedSteamOut to turbine.steamIn;
        connect turbine.shaftOut to generator.shaftIn;
        connect turbine.exhaustSteamOut to condenser.exhaustSteamIn;
        connect coolingWaterSource.coolingWaterOut to condenser.coolingWaterIn;
        connect condenser.feedwaterOut to boiler.feedwaterIn;
        connect generator.electricalOut to powerGrid.gridConnection;
        connect powerGrid.gridConnection to gridConnection;

        attribute plantRatedPower : Power := 250e6;
        attribute plantEfficiency : Real := 0.40;
        attribute plantAvailability : Real := 0.92;

        state def PlantOperatingStates;
        state machine PlantOperation : PlantOperatingStates {
            state ColdShutdown;
            state Startup;
            state BaseLoad;
            state LoadFollowing;
            state EmergencyShutdown;
            transition from ColdShutdown to Startup
                when fuelSupply.fuelOut.fuelFlow > 0;
            transition from Startup to BaseLoad
                when generator.electricalOut.power.activePower >= 0.9 * plantRatedPower;
            transition from BaseLoad to LoadFollowing
                when powerGrid.demand < 0.95 * plantRatedPower;
            transition from LoadFollowing to BaseLoad
                when powerGrid.demand >= 0.95 * plantRatedPower;
            transition from BaseLoad to EmergencyShutdown
                when turbine.shaftOut.speed > 3300;
            transition from EmergencyShutdown to ColdShutdown
                when boiler.fuelIn.fuelFlow == 0 and turbine.shaftOut.speed < 100;
        }

        action generatePower(in fuel : FuelFlowRate, in coolingWater : CoolingWater, out electricalPower : ElectricalPower);
    }

    requirement def PlantPerformanceRequirement {
        subject plant : SteamTurbinePowerPlant;
        attribute minEfficiency : Real := 0.38;
        attribute minRatedPower : Power := 240e6;
        attribute gridFrequency : Frequency := 50;
        require plant.plantEfficiency >= minEfficiency;
        require plant.plantRatedPower >= minRatedPower;
        require generator.outputFrequency == gridFrequency;
    }

    requirement def BoilerSteamRequirement {
        subject boiler : SteamBoiler;
        attribute minOutletPressure : Pressure := 14e6;
        attribute minOutletTemperature : Temperature := 800;
        require boiler.superheatedSteamOut.steam.pressure >= minOutletPressure;
        require boiler.superheatedSteamOut.steam.temperature >= minOutletTemperature;
    }

    requirement def TurbineSpeedRequirement {
        subject turbine : SteamTurbine;
        attribute nominalSpeed : RotationalSpeed := 3000;
        attribute maxOverspeed : RotationalSpeed := 3300;
        require turbine.shaftOut.speed == nominalSpeed;
        require turbine.shaftOut.speed <= maxOverspeed;
    }

    requirement def GeneratorOutputRequirement {
        subject generator : ElectricalGenerator;
        attribute requiredVoltage : Voltage := 21000;
        attribute requiredFrequency : Frequency := 50;
        attribute requiredPower : Power := 250e6;
        require generator.electricalOut.power.voltage == requiredVoltage;
        require generator.electricalOut.power.frequency == requiredFrequency;
        require generator.electricalOut.power.activePower >= requiredPower;
    }

    requirement def CondenserVacuumRequirement {
        subject condenser : SteamCondenser;
        attribute maxOperatingPressure : Pressure := 10e3;
        require condenser.operatingPressure <= maxOperatingPressure;
        require condenser.vacuumSystem.vacuumPressure <= maxOperatingPressure;
    }

    requirement def ClosedWaterCycleRequirement {
        subject plant : SteamTurbinePowerPlant;
        require plant.condenser.feedwaterOut.water.flowRate == plant.boiler.superheatedSteamOut.steam.flowRate;
    }
}
