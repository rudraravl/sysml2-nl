package LifeSupportSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percent :> Real {
        unit = "%";
    }

    attribute def VolumeFlowRate :> Real {
        unit = "L/min";
    }

    attribute def Pressure :> Real {
        unit = "kPa";
    }

    attribute def Temperature :> Real {
        unit = "degC";
    }

    attribute def MassConcentration :> Real {
        unit = "mg/m^3";
    }

    attribute def EnergyCapacity :> Real {
        unit = "Wh";
    }

    item def BreathingGas {
        attribute oxygenFraction : Percent;
        attribute carbonDioxideFraction : Percent;
        attribute humidity : Percent;
        attribute temperature : Temperature;
        attribute pressure : Pressure;
        attribute flowRate : VolumeFlowRate;
    }

    item def ExhaledGas :> BreathingGas {
        attribute co2Load : MassConcentration;
    }

    item def PurifiedGas :> BreathingGas {
        attribute contaminantLevel : MassConcentration;
    }

    item def ElectricalPower {
        attribute voltage : Real { unit = "V"; }
        attribute current : Real { unit = "A"; }
        attribute availableCapacity : EnergyCapacity;
    }

    item def Coolant {
        attribute temperature : Temperature;
        attribute flowRate : VolumeFlowRate;
    }

    item def CondensateWater {
        attribute volume : Real { unit = "L"; }
        attribute microbialLoad : Real { unit = "CFU/mL"; }
    }

    port def GasInPort {
        in item gasIn : BreathingGas;
    }

    port def GasOutPort {
        out item gasOut : BreathingGas;
    }

    port def ExhaledGasInPort {
        in item exhaledIn : ExhaledGas;
    }

    port def PurifiedGasOutPort {
        out item purifiedOut : PurifiedGas;
    }

    port def PowerInPort {
        in item powerIn : ElectricalPower;
    }

    port def WaterOutPort {
        out item waterOut : CondensateWater;
    }

    port def CoolantPort {
        inout item coolant : Coolant;
    }

    port def DataPort {
        inout item statusMessage : SystemStatus;
    }

    item def SystemStatus {
        attribute oxygenPartialPressure : Pressure;
        attribute carbonDioxidePartialPressure : Pressure;
        attribute cabinPressure : Pressure;
        attribute cabinTemperature : Temperature;
        attribute cabinHumidity : Percent;
        attribute faultCode : FaultCode;
        attribute operatingMode : OperatingMode;
    }

    enum def OperatingMode {
        enum standby;
        enum startup;
        enum nominalSupport;
        enum highDemandSupport;
        enum emergencySupport;
        enum shutdown;
        enum faulted;
    }

    enum def FaultCode {
        enum none;
        enum lowOxygenReserve;
        enum highCarbonDioxide;
        enum lowPressure;
        enum highTemperature;
        enum scrubberSaturated;
        enum fanFailure;
        enum powerFailure;
        enum sensorDisagreement;
    }

    part def OxygenStorageAssembly {
        attribute storedOxygenMass : Real { unit = "kg"; }
        attribute tankPressure : Pressure;
        attribute regulatorOutletPressure : Pressure;

        port power : PowerInPort;
        port oxygenOut : GasOutPort;

        action def RegulateOxygen {
            in attribute requestedFlow : VolumeFlowRate;
            out item oxygenSupply : BreathingGas;
            attribute targetOutletPressure : Pressure = 250.0;
        }
    }

    part def CarbonDioxideRemovalAssembly {
        attribute scrubberCapacityRemaining : Percent;
        attribute inletCO2Concentration : MassConcentration;
        attribute outletCO2Concentration : MassConcentration;
        attribute pressureDrop : Pressure;

        port exhaledGasIn : ExhaledGasInPort;
        port purifiedGasOut : PurifiedGasOutPort;
        port power : PowerInPort;

        action def RemoveCarbonDioxide {
            in item contaminatedGas : ExhaledGas;
            out item cleanedGas : PurifiedGas;
            attribute maximumOutletCO2 : MassConcentration = 5.0;
        }
    }

    part def AirCirculationAssembly {
        attribute fanSpeed : Real { unit = "rpm"; }
        attribute deliveredFlowRate : VolumeFlowRate;
        attribute redundancyAvailable : Boolean;

        port intake : GasInPort;
        port discharge : GasOutPort;
        port power : PowerInPort;

        action def CirculateCabinAtmosphere {
            in item cabinGas : BreathingGas;
            out item mixedGas : BreathingGas;
            attribute minimumFlowRate : VolumeFlowRate = 60.0;
        }
    }

    part def ThermalHumidityControlAssembly {
        attribute heatRemovalRate : Real { unit = "W"; }
        attribute humiditySetpoint : Percent = 45.0;
        attribute temperatureSetpoint : Temperature = 22.0;

        port gasIn : GasInPort;
        port gasOut : GasOutPort;
        port condensateOut : WaterOutPort;
        port coolantLoop : CoolantPort;
        port power : PowerInPort;

        action def ConditionAtmosphere {
            in item warmHumidGas : BreathingGas;
            out item conditionedGas : BreathingGas;
            out item removedWater : CondensateWater;
        }
    }

    part def AtmosphereMonitoringAssembly {
        attribute measuredOxygenPartialPressure : Pressure;
        attribute measuredCarbonDioxidePartialPressure : Pressure;
        attribute measuredCabinPressure : Pressure;
        attribute measuredTemperature : Temperature;
        attribute measuredHumidity : Percent;
        attribute sensorHealth : Percent;

        port sampleIn : GasInPort;
        port statusOut : DataPort;
        port power : PowerInPort;

        action def AnalyzeAtmosphere {
            in item sample : BreathingGas;
            out item status : SystemStatus;
        }
    }

    part def ControlComputer {
        attribute currentMode : OperatingMode;
        attribute activeFault : FaultCode;
        attribute oxygenFlowCommand : VolumeFlowRate;
        attribute fanSpeedCommand : Real { unit = "rpm"; }
        attribute scrubberBypassCommanded : Boolean;

        port sensorData : DataPort;
        port commandData : DataPort;
        port power : PowerInPort;

        action def ControlLifeSupport {
            in item monitoredStatus : SystemStatus;
            out attribute commandedMode : OperatingMode;
            out attribute commandedOxygenFlow : VolumeFlowRate;
            out attribute commandedFanSpeed : Real { unit = "rpm"; }
        }
    }

    part def BackupPowerAssembly {
        attribute batteryCapacity : EnergyCapacity = 2400.0;
        attribute stateOfCharge : Percent;
        attribute outputVoltage : Real { unit = "V"; }

        port powerOut : PowerInPort;

        action def SupplyEmergencyPower {
            out item backupPower : ElectricalPower;
        }
    }

    part def CrewCabinAtmosphere {
        attribute internalVolume : Real { unit = "m^3"; }
        attribute oxygenPartialPressure : Pressure;
        attribute carbonDioxidePartialPressure : Pressure;
        attribute totalPressure : Pressure;
        attribute temperature : Temperature;
        attribute relativeHumidity : Percent;

        port cabinGasOut : GasOutPort;
        port cabinGasIn : GasInPort;
        port exhaledGasOut : ExhaledGasInPort;
    }

    part def LifeSupportSystem {
        doc
        /* Primary high-level function: maintain a habitable enclosed atmosphere for crew by supplying oxygen, removing carbon dioxide, circulating and conditioning breathing gas, controlling temperature and humidity, monitoring atmospheric health, and entering emergency modes when required. */

        attribute supportedCrewCount : Integer = 4;
        attribute minimumMissionDuration : Real { unit = "h"; } = 72.0;
        attribute nominalOxygenPartialPressure : Pressure = 21.3;
        attribute maximumCarbonDioxidePartialPressure : Pressure = 0.7;
        attribute nominalCabinPressure : Pressure = 101.3;
        attribute nominalTemperature : Temperature = 22.0;
        attribute nominalHumidity : Percent = 45.0;

        port cabinReturn : ExhaledGasInPort;
        port cabinSupply : GasOutPort;
        port externalPower : PowerInPort;
        port thermalInterface : CoolantPort;
        port telemetry : DataPort;

        part cabin : CrewCabinAtmosphere {
            attribute internalVolume = 42.0;
            attribute oxygenPartialPressure = 21.3;
            attribute carbonDioxidePartialPressure = 0.4;
            attribute totalPressure = 101.3;
            attribute temperature = 22.0;
            attribute relativeHumidity = 45.0;
        }

        part oxygenStorage : OxygenStorageAssembly {
            attribute storedOxygenMass = 18.0;
            attribute tankPressure = 20000.0;
            attribute regulatorOutletPressure = 250.0;
        }

        part co2Removal : CarbonDioxideRemovalAssembly {
            attribute scrubberCapacityRemaining = 100.0;
            attribute inletCO2Concentration = 2500.0;
            attribute outletCO2Concentration = 300.0;
            attribute pressureDrop = 1.5;
        }

        part circulation : AirCirculationAssembly {
            attribute fanSpeed = 3200.0;
            attribute deliveredFlowRate = 80.0;
            attribute redundancyAvailable = true;
        }

        part thermalHumidityControl : ThermalHumidityControlAssembly;

        part monitor : AtmosphereMonitoringAssembly {
            attribute measuredOxygenPartialPressure = 21.3;
            attribute measuredCarbonDioxidePartialPressure = 0.4;
            attribute measuredCabinPressure = 101.3;
            attribute measuredTemperature = 22.0;
            attribute measuredHumidity = 45.0;
            attribute sensorHealth = 100.0;
        }

        part controller : ControlComputer {
            attribute currentMode = OperatingMode::nominalSupport;
            attribute activeFault = FaultCode::none;
            attribute oxygenFlowCommand = 2.0;
            attribute fanSpeedCommand = 3200.0;
            attribute scrubberBypassCommanded = false;
        }

        part backupPower : BackupPowerAssembly {
            attribute stateOfCharge = 100.0;
            attribute outputVoltage = 28.0;
        }

        connect cabin.exhaledGasOut to cabinReturn;
        connect cabinReturn to co2Removal.exhaledGasIn;
        connect co2Removal.purifiedGasOut to thermalHumidityControl.gasIn;
        connect oxygenStorage.oxygenOut to circulation.intake;
        connect thermalHumidityControl.gasOut to circulation.intake;
        connect circulation.discharge to cabinSupply;
        connect cabinSupply to cabin.cabinGasIn;
        connect cabin.cabinGasOut to monitor.sampleIn;

        connect externalPower to oxygenStorage.power;
        connect externalPower to co2Removal.power;
        connect externalPower to circulation.power;
        connect externalPower to thermalHumidityControl.power;
        connect externalPower to monitor.power;
        connect externalPower to controller.power;

        connect backupPower.powerOut to controller.power;
        connect thermalInterface to thermalHumidityControl.coolantLoop;
        connect monitor.statusOut to controller.sensorData;
        connect controller.commandData to telemetry;

        action def MaintainHabitableAtmosphere {
            in item exhaledCabinGas : ExhaledGas;
            in item electricalPower : ElectricalPower;
            inout item coolantFlow : Coolant;
            out item breathableCabinGas : BreathingGas;
            out item systemStatus : SystemStatus;

            first start;
            then analyzeAtmosphere : monitor.AnalyzeAtmosphere;
            then removeCO2 : co2Removal.RemoveCarbonDioxide;
            then regulateO2 : oxygenStorage.RegulateOxygen;
            then conditionGas : thermalHumidityControl.ConditionAtmosphere;
            then circulateGas : circulation.CirculateCabinAtmosphere;
            then computeControl : controller.ControlLifeSupport;
            then provideSupply;
        }

        state def LifeSupportOperatingState {
            entry action controller.ControlLifeSupport;

            state off;
            state startup;
            state nominal;
            state highDemand;
            state emergency;
            state shutdown;
            state faulted;

            transition initial then off;

            transition off_to_startup
                first off
                accept StartCommand
                then startup;

            transition startup_to_nominal
                first startup
                if monitor.measuredCabinPressure >= 95.0 and
                   monitor.measuredOxygenPartialPressure >= 19.5 and
                   monitor.sensorHealth >= 90.0
                then nominal;

            transition nominal_to_highDemand
                first nominal
                if monitor.measuredOxygenPartialPressure < 20.0 or
                   monitor.measuredCarbonDioxidePartialPressure > 0.6
                then highDemand;

            transition highDemand_to_nominal
                first highDemand
                if monitor.measuredOxygenPartialPressure >= 21.0 and
                   monitor.measuredCarbonDioxidePartialPressure <= 0.5
                then nominal;

            transition nominal_to_emergency
                first nominal
                if monitor.measuredOxygenPartialPressure < 18.0 or
                   monitor.measuredCabinPressure < 85.0 or
                   monitor.measuredCarbonDioxidePartialPressure > 1.0
                then emergency;

            transition highDemand_to_emergency
                first highDemand
                if monitor.measuredOxygenPartialPressure < 18.0 or
                   monitor.measuredCabinPressure < 85.0 or
                   monitor.measuredCarbonDioxidePartialPressure > 1.0
                then emergency;

            transition any_to_faulted
                first nominal
                if controller.activeFault != FaultCode::none
                then faulted;

            transition emergency_to_faulted
                first emergency
                if backupPower.stateOfCharge < 10.0 or
                   circulation.redundancyAvailable == false
                then faulted;

            transition commanded_shutdown
                first nominal
                accept ShutdownCommand
                then shutdown;

            transition shutdown_to_off
                first shutdown
                then off;
        }
    }

    requirement def MaintainHabitableAtmosphereRequirement {
        doc
        /* The life-support system shall maintain a habitable atmosphere for the supported crew during nominal and emergency operation. */

        subject lss : LifeSupportSystem;

        require constraint {
            lss.cabin.oxygenPartialPressure >= 19.5 and
            lss.cabin.oxygenPartialPressure <= 23.5 and
            lss.cabin.carbonDioxidePartialPressure <= 0.7 and
            lss.cabin.totalPressure >= 95.0 and
            lss.cabin.totalPressure <= 103.0 and
            lss.cabin.temperature >= 18.0 and
            lss.cabin.temperature <= 27.0 and
            lss.cabin.relativeHumidity >= 30.0 and
            lss.cabin.relativeHumidity <= 70.0
        }
    }

    requirement def OxygenSupplyRequirement {
        doc
        /* The system shall supply enough oxygen for four crew members for at least seventy-two hours without external resupply. */

        subject lss : LifeSupportSystem;

        require constraint {
            lss.supportedCrewCount == 4 and
            lss.minimumMissionDuration >= 72.0 and
            lss.oxygenStorage.storedOxygenMass >= 16.0
        }
    }

    requirement def CarbonDioxideRemovalRequirement {
        doc
        /* The carbon dioxide removal assembly shall reduce outlet carbon dioxide concentration below the safe limit while maintaining acceptable pressure drop. */

        subject remover : CarbonDioxideRemovalAssembly;

        require constraint {
            remover.outletCO2Concentration <= 500.0 and
            remover.pressureDrop <= 3.0 and
            remover.scrubberCapacityRemaining >= 5.0
        }
    }

    requirement def EmergencyModeRequirement {
        doc
        /* The system shall enter emergency support when cabin oxygen, pressure, or carbon dioxide exceeds safe bounds. */

        subject lss : LifeSupportSystem;

        require constraint {
            if lss.monitor.measuredOxygenPartialPressure < 18.0 or
               lss.monitor.measuredCabinPressure < 85.0 or
               lss.monitor.measuredCarbonDioxidePartialPressure > 1.0
            then lss.controller.currentMode == OperatingMode::emergencySupport
        }
    }

    requirement def MonitoringRequirement {
        doc
        /* The monitoring assembly shall provide oxygen, carbon dioxide, pressure, temperature, humidity, fault, and mode status to the controller. */

        subject monitor : AtmosphereMonitoringAssembly;

        require constraint {
            monitor.sensorHealth >= 90.0
        }
    }

    satisfy MaintainHabitableAtmosphereRequirement by LifeSupportSystem;
    satisfy OxygenSupplyRequirement by LifeSupportSystem::oxygenStorage;
    satisfy CarbonDioxideRemovalRequirement by CarbonDioxideRemovalAssembly;
    satisfy EmergencyModeRequirement by LifeSupportSystem::controller;
    satisfy MonitoringRequirement by AtmosphereMonitoringAssembly;
}