package HydrocollatorModel {
    import ScalarValues::*;
    import SI::*;

    value def TemperatureCelsius specializes Real {
        doc /* Water or pack temperature in degrees Celsius. */
    }

    value def PowerWatt specializes Real {
        doc /* Electrical power in watts. */
    }

    value def VolumeLiter specializes Real {
        doc /* Water volume in liters. */
    }

    value def TimeMinute specializes Real {
        doc /* Time duration in minutes. */
    }

    value def MassKilogram specializes Real {
        doc /* Mass in kilograms. */
    }

    value def HeatEnergyKilojoule specializes Real {
        doc /* Thermal energy in kilojoules. */
    }

    item def ElectricalEnergy {
        attribute voltage : Real;
        attribute frequency : Real;
        attribute power : PowerWatt;
    }

    item def Water {
        attribute volume : VolumeLiter;
        attribute temperature : TemperatureCelsius;
    }

    item def MoistHeat {
        attribute temperature : TemperatureCelsius;
        attribute energyStored : HeatEnergyKilojoule;
        attribute treatmentDuration : TimeMinute;
    }

    item def HydrocollatorPack {
        attribute mass : MassKilogram;
        attribute targetTemperature : TemperatureCelsius = 71.0;
        attribute currentTemperature : TemperatureCelsius;
        attribute hydrated : Boolean;
        attribute readyForUse : Boolean;
    }

    port def ElectricalInlet {
        in item energy : ElectricalEnergy;
    }

    port def WaterFillPort {
        in item water : Water;
    }

    port def DrainPort {
        out item water : Water;
    }

    port def ThermalPort {
        out item heat : MoistHeat;
    }

    port def SensorSignalPort {
        out attribute measuredTemperature : TemperatureCelsius;
    }

    port def ControlSignalPort {
        out attribute heaterCommand : Boolean;
        out attribute faultCommand : Boolean;
    }

    part def WaterReservoir {
        attribute capacity : VolumeLiter = 31.0;
        attribute minimumSafeVolume : VolumeLiter = 20.0;
        attribute currentVolume : VolumeLiter;
        attribute waterTemperature : TemperatureCelsius;

        port fill : WaterFillPort;
        port drain : DrainPort;
        port thermalOutput : ThermalPort;
    }

    part def ImmersionHeater {
        attribute ratedPower : PowerWatt = 1000.0;
        attribute energized : Boolean;
        attribute surfaceTemperature : TemperatureCelsius;

        port electricalInput : ElectricalInlet;
        port controlInput : ControlSignalPort;
        port heatOutput : ThermalPort;
    }

    part def TemperatureSensor {
        attribute sensedTemperature : TemperatureCelsius;
        attribute measurementAccuracy : TemperatureCelsius = 1.0;

        port signalOutput : SensorSignalPort;
    }

    part def ThermostatController {
        attribute setPoint : TemperatureCelsius = 74.0;
        attribute lowerDeadband : TemperatureCelsius = 71.0;
        attribute upperDeadband : TemperatureCelsius = 77.0;
        attribute overTemperatureLimit : TemperatureCelsius = 82.0;
        attribute heaterEnabled : Boolean;
        attribute faultLatched : Boolean;

        port sensorInput : SensorSignalPort;
        port commandOutput : ControlSignalPort;
    }

    part def PackRack {
        attribute packCapacity : Integer = 8;
        attribute loadedPackCount : Integer;

        part pack[0..8] : HydrocollatorPack;
    }

    part def InsulatedCabinet {
        attribute exteriorSurfaceTemperature : TemperatureCelsius;
        attribute lidClosed : Boolean;
        attribute corrosionResistant : Boolean = true;
    }

    action def HeatWaterBath {
        in item electricalEnergy : ElectricalEnergy;
        inout item bathWater : Water;
        out item heatedWater : Water;

        objective {
            doc /* Convert electrical energy to thermal energy until the water bath reaches the therapeutic operating range. */
        }
    }

    action def HydrateAndHeatPacks {
        in item heatedWater : Water;
        inout item pack : HydrocollatorPack;
        out item moistHeatPack : HydrocollatorPack;

        objective {
            doc /* Transfer heat and moisture from the controlled water bath into reusable therapy packs. */
        }
    }

    action def RegulateBathTemperature {
        in attribute measuredTemperature : TemperatureCelsius;
        out attribute heaterCommand : Boolean;

        objective {
            doc /* Maintain bath temperature between lower and upper thermostat limits. */
        }
    }

    action def DeliverMoistHeatTherapy {
        in item readyPack : HydrocollatorPack;
        out item therapeuticHeat : MoistHeat;

        objective {
            doc /* Provide a heated moist pack suitable for external therapeutic warming of patient tissue. */
        }
    }

    state def HydrocollatorOperatingState {
        entry action initializeSystem;

        state Off;
        state Filling;
        state Heating;
        state Ready;
        state TemperatureRegulating;
        state PackRemoved;
        state Fault;

        transition first Off;

        transition Off_to_Filling
            first Off
            then Filling;

        transition Filling_to_Heating
            first Filling
            then Heating
            if currentVolume >= minimumSafeVolume;

        transition Heating_to_Ready
            first Heating
            then Ready
            if waterTemperature >= 71.0;

        transition Ready_to_Regulating
            first Ready
            then TemperatureRegulating;

        transition Regulating_to_Ready
            first TemperatureRegulating
            then Ready
            if waterTemperature >= 71.0 and waterTemperature <= 77.0;

        transition Ready_to_PackRemoved
            first Ready
            then PackRemoved
            if loadedPackCount > 0;

        transition PackRemoved_to_Regulating
            first PackRemoved
            then TemperatureRegulating;

        transition Any_to_Fault
            first Off
            then Fault
            if waterTemperature > 82.0;
    }

    requirement def PrimaryFunctionRequirement {
        subject hydrocollator : Hydrocollator;

        require constraint {
            hydrocollator.primaryFunction == "Maintain a heated water bath that hydrates reusable packs and supplies controlled moist heat for therapy.";
        }
    }

    requirement def TemperatureControlRequirement {
        subject hydrocollator : Hydrocollator;

        require constraint {
            hydrocollator.reservoir.waterTemperature >= 71.0 and
            hydrocollator.reservoir.waterTemperature <= 77.0;
        }
    }

    requirement def OverTemperatureProtectionRequirement {
        subject hydrocollator : Hydrocollator;

        require constraint {
            hydrocollator.controller.faultLatched == true
            if hydrocollator.reservoir.waterTemperature > 82.0;
        }
    }

    requirement def PackReadinessRequirement {
        subject pack : HydrocollatorPack;

        require constraint {
            pack.readyForUse == true
            if pack.currentTemperature >= 71.0 and pack.hydrated == true;
        }
    }

    part def Hydrocollator {
        attribute primaryFunction : String =
            "Maintain a heated water bath that hydrates reusable packs and supplies controlled moist heat for therapy.";

        attribute nominalBathTemperature : TemperatureCelsius = 74.0;
        attribute therapeuticTemperatureMinimum : TemperatureCelsius = 71.0;
        attribute therapeuticTemperatureMaximum : TemperatureCelsius = 77.0;
        attribute maximumSafeBathTemperature : TemperatureCelsius = 82.0;

        port powerInput : ElectricalInlet;
        port waterInput : WaterFillPort;
        port waterDrain : DrainPort;
        port therapyHeatOutput : ThermalPort;

        part cabinet : InsulatedCabinet;
        part reservoir : WaterReservoir;
        part heater : ImmersionHeater;
        part sensor : TemperatureSensor;
        part controller : ThermostatController;
        part rack : PackRack;

        perform action heatBath : HeatWaterBath;
        perform action hydratePacks : HydrateAndHeatPacks;
        perform action regulateTemperature : RegulateBathTemperature;
        perform action deliverTherapyHeat : DeliverMoistHeatTherapy;

        exhibit state operatingState : HydrocollatorOperatingState;

        connection powerToHeater connect powerInput to heater.electricalInput;
        connection fillToReservoir connect waterInput to reservoir.fill;
        connection reservoirToDrain connect reservoir.drain to waterDrain;
        connection heaterToReservoir connect heater.heatOutput to reservoir.thermalOutput;
        connection sensorToController connect sensor.signalOutput to controller.sensorInput;
        connection controllerToHeater connect controller.commandOutput to heater.controlInput;
        connection reservoirToTherapyOutput connect reservoir.thermalOutput to therapyHeatOutput;
    }

    part hydrocollatorSystem : Hydrocollator {
        reservoir.currentVolume = 28.0;
        reservoir.waterTemperature = 74.0;
        rack.loadedPackCount = 6;
        controller.heaterEnabled = true;
        controller.faultLatched = false;
        cabinet.lidClosed = true;
    }

    satisfy PrimaryFunctionRequirement by hydrocollatorSystem;
    satisfy TemperatureControlRequirement by hydrocollatorSystem;
    satisfy OverTemperatureProtectionRequirement by hydrocollatorSystem;
}