package VacuumInsulatedEvaporatorModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Temperature_C :> Real {
        unit = "degC";
    }

    attribute def Pressure_kPa :> Real {
        unit = "kPa";
    }

    attribute def HeatFlow_kW :> Real {
        unit = "kW";
    }

    attribute def MassFlow_kgPerH :> Real {
        unit = "kg/h";
    }

    attribute def Volume_L :> Real {
        unit = "L";
    }

    attribute def Concentration_percent :> Real {
        unit = "%";
    }

    attribute def Thickness_mm :> Real {
        unit = "mm";
    }

    attribute def Level_percent :> Real {
        unit = "%";
    }

    attribute def Power_kW :> Real {
        unit = "kW";
    }

    attribute def Time_s :> Real {
        unit = "s";
    }

    item def FeedLiquid {
        attribute inletTemperature : Temperature_C;
        attribute dissolvedSolids : Concentration_percent;
        attribute volatileFraction : Concentration_percent;
        attribute flowRate : MassFlow_kgPerH;
    }

    item def ConcentrateLiquid {
        attribute outletTemperature : Temperature_C;
        attribute dissolvedSolids : Concentration_percent;
        attribute flowRate : MassFlow_kgPerH;
    }

    item def VaporStream {
        attribute vaporTemperature : Temperature_C;
        attribute absolutePressure : Pressure_kPa;
        attribute flowRate : MassFlow_kgPerH;
    }

    item def Condensate {
        attribute temperature : Temperature_C;
        attribute flowRate : MassFlow_kgPerH;
        attribute residualSolids : Concentration_percent;
    }

    item def ThermalEnergy {
        attribute heatRate : HeatFlow_kW;
        attribute supplyTemperature : Temperature_C;
    }

    item def ElectricalPower {
        attribute activePower : Power_kW;
        attribute voltage : Real;
    }

    item def ControlSignal {
        attribute value : Real;
        attribute valid : Boolean;
    }

    item def AlarmSignal {
        attribute active : Boolean;
        attribute severity : Integer;
        attribute messageCode : Integer;
    }

    port def LiquidInletPort {
        in item liquid : FeedLiquid;
    }

    port def ConcentrateOutletPort {
        out item liquid : ConcentrateLiquid;
    }

    port def VaporPort {
        out item vapor : VaporStream;
    }

    port def CondensateOutletPort {
        out item condensate : Condensate;
    }

    port def ThermalPort {
        in item heat : ThermalEnergy;
    }

    port def ElectricalPort {
        in item power : ElectricalPower;
    }

    port def SignalInputPort {
        in item signal : ControlSignal;
    }

    port def SignalOutputPort {
        out item signal : ControlSignal;
    }

    port def AlarmOutputPort {
        out item alarm : AlarmSignal;
    }

    part def VacuumInsulatedEvaporator {

        attribute designFeedRate : MassFlow_kgPerH = 1200;
        attribute nominalOperatingPressure : Pressure_kPa = 18;
        attribute nominalBoilingTemperature : Temperature_C = 58;
        attribute targetConcentrateSolids : Concentration_percent = 45;
        attribute maximumShellTemperature : Temperature_C = 85;
        attribute vacuumJacketPressure : Pressure_kPa = 0.02;
        attribute maximumHeatLoss : HeatFlow_kW = 1.5;
        attribute evaporatorVolume : Volume_L = 850;

        port feedIn : LiquidInletPort;
        port concentrateOut : ConcentrateOutletPort;
        port vaporOut : VaporPort;
        port condensateOut : CondensateOutletPort;
        port heatIn : ThermalPort;
        port electricalIn : ElectricalPort;
        port startCommand : SignalInputPort;
        port setpointInput : SignalInputPort;
        port statusOutput : SignalOutputPort;
        port alarmOutput : AlarmOutputPort;

        part evaporationChamber : EvaporationChamber;
        part vacuumInsulationAssembly : VacuumInsulationAssembly;
        part heatingAssembly : HeatingAssembly;
        part vaporSeparator : VaporSeparator;
        part condenser : Condenser;
        part vacuumPumpPackage : VacuumPumpPackage;
        part feedPump : FeedPump;
        part concentratePump : ConcentratePump;
        part instrumentation : InstrumentationSet;
        part controller : EvaporatorController;
        part safetySystem : SafetySystem;

        connect feedIn to feedPump.feedIn;
        connect feedPump.feedOut to evaporationChamber.feedIn;
        connect heatIn to heatingAssembly.heatIn;
        connect heatingAssembly.thermalOutput to evaporationChamber.heatIn;
        connect evaporationChamber.twoPhaseOutlet to vaporSeparator.twoPhaseIn;
        connect vaporSeparator.liquidOut to concentratePump.liquidIn;
        connect concentratePump.liquidOut to concentrateOut;
        connect vaporSeparator.vaporOut to condenser.vaporIn;
        connect condenser.condensateOut to condensateOut;
        connect condenser.nonCondensableOut to vacuumPumpPackage.suctionIn;
        connect vacuumPumpPackage.exhaustOut to vaporOut;
        connect electricalIn to controller.powerIn;
        connect instrumentation.measurementOutput to controller.measurementInput;
        connect startCommand to controller.startInput;
        connect setpointInput to controller.setpointInput;
        connect controller.feedPumpCommand to feedPump.commandIn;
        connect controller.concentratePumpCommand to concentratePump.commandIn;
        connect controller.heatCommand to heatingAssembly.commandIn;
        connect controller.vacuumCommand to vacuumPumpPackage.commandIn;
        connect controller.statusOutput to statusOutput;
        connect safetySystem.alarmOut to alarmOutput;
        connect instrumentation.pressureSignal to safetySystem.pressureInput;
        connect instrumentation.temperatureSignal to safetySystem.temperatureInput;
        connect instrumentation.levelSignal to safetySystem.levelInput;

        perform action evaporateUnderVacuum;
        exhibit state machine operatingStateMachine;

        action evaporateUnderVacuum {
            in item feed : FeedLiquid;
            in item suppliedHeat : ThermalEnergy;
            out item concentrate : ConcentrateLiquid;
            out item vapor : VaporStream;
            out item condensedWater : Condensate;

            first startVacuum;
            then admitFeed;
            then transferHeat;
            then flashAndBoil;
            then separateVaporAndLiquid;
            then condenseVapor;
            then dischargeConcentrate;

            action startVacuum {
                out attribute chamberPressure : Pressure_kPa = nominalOperatingPressure;
            }

            action admitFeed {
                in item feed : FeedLiquid;
                out attribute chamberLevel : Level_percent;
            }

            action transferHeat {
                in item suppliedHeat : ThermalEnergy;
                out attribute liquidTemperature : Temperature_C = nominalBoilingTemperature;
            }

            action flashAndBoil {
                in attribute chamberPressure : Pressure_kPa;
                in attribute liquidTemperature : Temperature_C;
                out item generatedVapor : VaporStream;
            }

            action separateVaporAndLiquid {
                in item generatedVapor : VaporStream;
                out item concentrate : ConcentrateLiquid;
                out item dryVapor : VaporStream;
            }

            action condenseVapor {
                in item dryVapor : VaporStream;
                out item condensedWater : Condensate;
            }

            action dischargeConcentrate {
                in item concentrate : ConcentrateLiquid;
                out item deliveredConcentrate : ConcentrateLiquid;
            }
        }

        state machine operatingStateMachine {
            state Off;
            state Evacuating;
            state Preheating;
            state Feeding;
            state Evaporating;
            state ConcentrateDischarge;
            state Standby;
            state Faulted;
            state Cleaning;

            initial then Off;

            transition Off_to_Evacuating
                first Off
                accept startCommand.signal
                if startCommand.signal.valid and startCommand.signal.value == 1
                then Evacuating;

            transition Evacuating_to_Preheating
                first Evacuating
                if instrumentation.chamberPressure <= nominalOperatingPressure
                then Preheating;

            transition Preheating_to_Feeding
                first Preheating
                if instrumentation.chamberTemperature >= nominalBoilingTemperature - 3
                then Feeding;

            transition Feeding_to_Evaporating
                first Feeding
                if instrumentation.chamberLevel >= 35
                then Evaporating;

            transition Evaporating_to_ConcentrateDischarge
                first Evaporating
                if instrumentation.concentrateSolids >= targetConcentrateSolids
                then ConcentrateDischarge;

            transition ConcentrateDischarge_to_Evaporating
                first ConcentrateDischarge
                if instrumentation.chamberLevel >= 30
                then Evaporating;

            transition Evaporating_to_Standby
                first Evaporating
                if startCommand.signal.valid and startCommand.signal.value == 0
                then Standby;

            transition Standby_to_Evaporating
                first Standby
                if startCommand.signal.valid and startCommand.signal.value == 1
                then Evaporating;

            transition Any_to_Faulted
                first Off, Evacuating, Preheating, Feeding, Evaporating, ConcentrateDischarge, Standby, Cleaning
                if safetySystem.tripActive
                then Faulted;

            transition Faulted_to_Off
                first Faulted
                if safetySystem.tripActive == false and startCommand.signal.value == 0
                then Off;

            transition Off_to_Cleaning
                first Off
                if controller.cleaningRequested
                then Cleaning;

            transition Cleaning_to_Off
                first Cleaning
                if controller.cleaningComplete
                then Off;
        }
    }

    part def EvaporationChamber {
        attribute workingVolume : Volume_L = 850;
        attribute shellDesignPressure : Pressure_kPa = 250;
        attribute normalOperatingPressure : Pressure_kPa = 18;
        attribute normalOperatingTemperature : Temperature_C = 58;
        attribute liquidLevel : Level_percent;
        attribute chamberPressure : Pressure_kPa;
        attribute chamberTemperature : Temperature_C;

        port feedIn : LiquidInletPort;
        port heatIn : ThermalPort;
        port twoPhaseOutlet : VaporPort;
    }

    part def VacuumInsulationAssembly {
        attribute innerWallThickness : Thickness_mm = 3;
        attribute outerWallThickness : Thickness_mm = 2;
        attribute vacuumSpacePressure : Pressure_kPa = 0.02;
        attribute effectiveThermalConductance : Real = 0.004;
        attribute heatLossAtNominalOperation : HeatFlow_kW = 1.2;

        part innerVesselWall : VesselWall;
        part outerJacketWall : VesselWall;
        part evacuatedAnnulus : EvacuatedAnnulus;
        part multilayerRadiationBarrier : RadiationBarrier;
        part getterCartridge : GetterCartridge;
    }

    part def VesselWall {
        attribute wallThickness : Thickness_mm;
        attribute maximumAllowableTemperature : Temperature_C = 120;
        attribute materialThermalConductivity : Real;
    }

    part def EvacuatedAnnulus {
        attribute residualGasPressure : Pressure_kPa = 0.02;
        attribute annulusVolume : Volume_L = 120;
        attribute leakRateLimit : Real = 0.00001;
    }

    part def RadiationBarrier {
        attribute layerCount : Integer = 24;
        attribute emissivity : Real = 0.04;
    }

    part def GetterCartridge {
        attribute adsorptionCapacity : Real = 15;
        attribute serviceTemperatureLimit : Temperature_C = 100;
    }

    part def HeatingAssembly {
        attribute nominalHeatDuty : HeatFlow_kW = 95;
        attribute maximumHeatDuty : HeatFlow_kW = 120;
        attribute heatTransferSurfaceArea : Real = 14.5;

        port heatIn : ThermalPort;
        port commandIn : SignalInputPort;
        port thermalOutput : ThermalPort;

        part heatExchanger : InternalHeatExchanger;
        part modulatingValve : HeatInputValve;
    }

    part def InternalHeatExchanger {
        attribute surfaceArea : Real = 14.5;
        attribute foulingFactor : Real = 0.0002;
        attribute maximumWallTemperature : Temperature_C = 95;
    }

    part def HeatInputValve {
        attribute commandPosition : Real;
        attribute failClosed : Boolean = true;
        attribute maximumFlowCoefficient : Real = 18;
    }

    part def VaporSeparator {
        attribute demisterEfficiency : Concentration_percent = 99.5;
        attribute maximumVaporVelocity : Real = 3.2;
        attribute entrainmentLimit : Concentration_percent = 0.02;

        port twoPhaseIn : VaporPort;
        port vaporOut : VaporPort;
        port liquidOut : ConcentrateOutletPort;

        part cyclonicInlet : CyclonicInlet;
        part demisterPad : DemisterPad;
        part concentrateSump : ConcentrateSump;
    }

    part def CyclonicInlet {
        attribute separationEfficiency : Concentration_percent = 92;
    }

    part def DemisterPad {
        attribute removalEfficiency : Concentration_percent = 99.5;
        attribute pressureDrop : Pressure_kPa = 0.4;
    }

    part def ConcentrateSump {
        attribute holdUpVolume : Volume_L = 95;
        attribute minimumPumpableLevel : Level_percent = 15;
    }

    part def Condenser {
        attribute condensationDuty : HeatFlow_kW = 88;
        attribute condensateOutletTemperature : Temperature_C = 38;
        attribute nonCondensableLoad : MassFlow_kgPerH = 3;

        port vaporIn : VaporPort;
        port condensateOut : CondensateOutletPort;
        port nonCondensableOut : VaporPort;

        part condensingSurface : CondensingSurface;
        part condensateReceiver : CondensateReceiver;
    }

    part def CondensingSurface {
        attribute surfaceArea : Real = 18;
        attribute coolantInletTemperature : Temperature_C = 25;
        attribute coolantOutletTemperature : Temperature_C = 34;
    }

    part def CondensateReceiver {
        attribute receiverVolume : Volume_L = 160;
        attribute highLevelAlarm : Level_percent = 85;
    }

    part def VacuumPumpPackage {
        attribute pumpingCapacity : Real = 140;
        attribute ultimatePressure : Pressure_kPa = 3;
        attribute nominalMotorPower : Power_kW = 4.5;

        port suctionIn : VaporPort;
        port exhaustOut : VaporPort;
        port commandIn : SignalInputPort;

        part liquidRingPump : LiquidRingVacuumPump;
        part sealFluidSeparator : SealFluidSeparator;
        part checkValve : VacuumCheckValve;
    }

    part def LiquidRingVacuumPump {
        attribute motorPower : Power_kW = 4.5;
        attribute suctionPressure : Pressure_kPa;
        attribute dischargePressure : Pressure_kPa = 101.3;
    }

    part def SealFluidSeparator {
        attribute separatorVolume : Volume_L = 60;
        attribute carryoverLimit : Concentration_percent = 0.1;
    }

    part def VacuumCheckValve {
        attribute crackingPressure : Pressure_kPa = 0.2;
        attribute reverseLeakageLimit : Real = 0.001;
    }

    part def FeedPump {
        attribute ratedFlow : MassFlow_kgPerH = 1500;
        attribute motorPower : Power_kW = 1.5;

        port feedIn : LiquidInletPort;
        port feedOut : LiquidInletPort;
        port commandIn : SignalInputPort;
    }

    part def ConcentratePump {
        attribute ratedFlow : MassFlow_kgPerH = 600;
        attribute motorPower : Power_kW = 1.1;

        port liquidIn : ConcentrateOutletPort;
        port liquidOut : ConcentrateOutletPort;
        port commandIn : SignalInputPort;
    }

    part def InstrumentationSet {
        attribute chamberPressure : Pressure_kPa;
        attribute chamberTemperature : Temperature_C;
        attribute chamberLevel : Level_percent;
        attribute concentrateSolids : Concentration_percent;
        attribute jacketVacuumPressure : Pressure_kPa;
        attribute heatInputRate : HeatFlow_kW;

        port measurementOutput : SignalOutputPort;
        port pressureSignal : SignalOutputPort;
        port temperatureSignal : SignalOutputPort;
        port levelSignal : SignalOutputPort;

        part pressureTransmitter : PressureTransmitter;
        part temperatureElement : TemperatureElement;
        part levelTransmitter : LevelTransmitter;
        part densityMeter : DensityMeter;
        part jacketVacuumGauge : VacuumGauge;
    }

    part def PressureTransmitter {
        attribute rangeLow : Pressure_kPa = 0;
        attribute rangeHigh : Pressure_kPa = 120;
        attribute accuracy : Real = 0.25;
    }

    part def TemperatureElement {
        attribute rangeLow : Temperature_C = 0;
        attribute rangeHigh : Temperature_C = 120;
        attribute accuracy : Temperature_C = 0.3;
    }

    part def LevelTransmitter {
        attribute rangeLow : Level_percent = 0;
        attribute rangeHigh : Level_percent = 100;
        attribute accuracy : Real = 0.5;
    }

    part def DensityMeter {
        attribute solidsRangeLow : Concentration_percent = 0;
        attribute solidsRangeHigh : Concentration_percent = 65;
        attribute accuracy : Concentration_percent = 0.5;
    }

    part def VacuumGauge {
        attribute rangeLow : Pressure_kPa = 0;
        attribute rangeHigh : Pressure_kPa = 1;
        attribute accuracy : Real = 1;
    }

    part def EvaporatorController {
        attribute targetPressure : Pressure_kPa = 18;
        attribute targetTemperature : Temperature_C = 58;
        attribute targetLevel : Level_percent = 55;
        attribute targetSolids : Concentration_percent = 45;
        attribute cleaningRequested : Boolean = false;
        attribute cleaningComplete : Boolean = false;

        port powerIn : ElectricalPort;
        port startInput : SignalInputPort;
        port setpointInput : SignalInputPort;
        port measurementInput : SignalInputPort;
        port feedPumpCommand : SignalOutputPort;
        port concentratePumpCommand : SignalOutputPort;
        port heatCommand : SignalOutputPort;
        port vacuumCommand : SignalOutputPort;
        port statusOutput : SignalOutputPort;

        perform action regulateEvaporation;

        action regulateEvaporation {
            in attribute measuredPressure : Pressure_kPa;
            in attribute measuredTemperature : Temperature_C;
            in attribute measuredLevel : Level_percent;
            in attribute measuredSolids : Concentration_percent;
            out item feedCommand : ControlSignal;
            out item heatCommand : ControlSignal;
            out item vacuumCommand : ControlSignal;
            out item dischargeCommand : ControlSignal;

            action regulateVacuum {
                in attribute measuredPressure : Pressure_kPa;
                out item vacuumCommand : ControlSignal;
            }

            action regulateHeat {
                in attribute measuredTemperature : Temperature_C;
                out item heatCommand : ControlSignal;
            }

            action regulateLevel {
                in attribute measuredLevel : Level_percent;
                out item feedCommand : ControlSignal;
            }

            action regulateConcentration {
                in attribute measuredSolids : Concentration_percent;
                out item dischargeCommand : ControlSignal;
            }
        }
    }

    part def SafetySystem {
        attribute tripActive : Boolean = false;
        attribute highPressureTrip : Pressure_kPa = 45;
        attribute highTemperatureTrip : Temperature_C = 90;
        attribute lowLevelTrip : Level_percent = 8;
        attribute highLevelTrip : Level_percent = 92;
        attribute jacketVacuumLossAlarm : Pressure_kPa = 0.5;

        port pressureInput : SignalInputPort;
        port temperatureInput : SignalInputPort;
        port levelInput : SignalInputPort;
        port alarmOut : AlarmOutputPort;

        exhibit state machine safetyStateMachine;

        state machine safetyStateMachine {
            state Normal;
            state Alarmed;
            state Tripped;

            initial then Normal;

            transition Normal_to_Alarmed
                first Normal
                if pressureInput.signal.value > 35 or temperatureInput.signal.value > 82
                then Alarmed;

            transition Alarmed_to_Normal
                first Alarmed
                if pressureInput.signal.value <= 30 and temperatureInput.signal.value <= 78
                then Normal;

            transition Alarmed_to_Tripped
                first Alarmed
                if pressureInput.signal.value >= highPressureTrip or temperatureInput.signal.value >= highTemperatureTrip or levelInput.signal.value <= lowLevelTrip or levelInput.signal.value >= highLevelTrip
                then Tripped;

            transition Normal_to_Tripped
                first Normal
                if pressureInput.signal.value >= highPressureTrip or temperatureInput.signal.value >= highTemperatureTrip or levelInput.signal.value <= lowLevelTrip or levelInput.signal.value >= highLevelTrip
                then Tripped;

            transition Tripped_to_Normal
                first Tripped
                if pressureInput.signal.value < 30 and temperatureInput.signal.value < 75 and levelInput.signal.value > 15 and levelInput.signal.value < 80
                then Normal;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The vacuum insulated evaporator shall concentrate a liquid feed by evaporating volatile solvent at reduced pressure while minimizing external heat loss through a vacuum insulation assembly. */
    }

    requirement def ReducedPressureBoilingRequirement {
        doc /* The evaporator shall maintain the evaporation chamber at or below 25 kPa absolute during normal evaporation to reduce boiling temperature and protect heat-sensitive feed material. */
    }

    requirement def ThermalEfficiencyRequirement {
        doc /* The vacuum insulation assembly shall limit steady-state heat loss to no more than 1.5 kW at nominal operating temperature. */
    }

    requirement def ConcentrateQualityRequirement {
        doc /* The evaporator shall discharge concentrate when dissolved solids reach 45 percent plus or minus 2 percent. */
    }

    requirement def VaporCondensationRequirement {
        doc /* The system shall condense generated vapor into a separate condensate stream with residual solids below 0.05 percent. */
    }

    requirement def SafetyShutdownRequirement {
        doc /* The safety system shall place the evaporator in a tripped state when chamber pressure, temperature, or liquid level exceeds defined safe operating limits. */
    }

    requirement def HighLevelPrimaryFunction {
        doc /* At a high level, the system's primary function is to remove solvent from a feed liquid by vacuum-assisted evaporation, producing a concentrated liquid product and a recoverable condensate stream with reduced energy loss due to vacuum insulation. */
    }

    satisfy PrimaryFunctionRequirement by VacuumInsulatedEvaporator;
    satisfy ReducedPressureBoilingRequirement by VacuumPumpPackage;
    satisfy ReducedPressureBoilingRequirement by EvaporationChamber;
    satisfy ThermalEfficiencyRequirement by VacuumInsulationAssembly;
    satisfy ConcentrateQualityRequirement by EvaporatorController;
    satisfy ConcentrateQualityRequirement by VaporSeparator;
    satisfy VaporCondensationRequirement by Condenser;
    satisfy SafetyShutdownRequirement by SafetySystem;
    satisfy HighLevelPrimaryFunction by VacuumInsulatedEvaporator;

    constraint def MassBalance {
        in feedMassFlow : MassFlow_kgPerH;
        in concentrateMassFlow : MassFlow_kgPerH;
        in vaporMassFlow : MassFlow_kgPerH;
        feedMassFlow == concentrateMassFlow + vaporMassFlow;
    }

    constraint def SolidsBalance {
        in feedMassFlow : MassFlow_kgPerH;
        in feedSolids : Concentration_percent;
        in concentrateMassFlow : MassFlow_kgPerH;
        in concentrateSolids : Concentration_percent;
        feedMassFlow * feedSolids == concentrateMassFlow * concentrateSolids;
    }

    constraint def InsulationPerformance {
        in heatLoss : HeatFlow_kW;
        in limit : HeatFlow_kW;
        heatLoss <= limit;
    }

    constraint def VacuumOperatingEnvelope {
        in chamberPressure : Pressure_kPa;
        in maximumPressure : Pressure_kPa;
        chamberPressure <= maximumPressure;
    }

    part vacuumInsulatedEvaporatorSystem : VacuumInsulatedEvaporator {
        attribute designFeedRate = 1200;
        attribute nominalOperatingPressure = 18;
        attribute nominalBoilingTemperature = 58;
        attribute targetConcentrateSolids = 45;
        attribute maximumHeatLoss = 1.5;
    }

    assert constraint MassBalance {
        feedMassFlow = 1200;
        concentrateMassFlow = 533;
        vaporMassFlow = 667;
    }

    assert constraint SolidsBalance {
        feedMassFlow = 1200;
        feedSolids = 20;
        concentrateMassFlow = 533;
        concentrateSolids = 45;
    }

    assert constraint InsulationPerformance {
        heatLoss = 1.2;
        limit = 1.5;
    }

    assert constraint VacuumOperatingEnvelope {
        chamberPressure = 18;
        maximumPressure = 25;
    }
}