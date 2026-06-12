package DrillingMudSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Density :> ScalarQuantityValue {
        unit = "kg/m^3";
    }

    attribute def DynamicViscosity :> ScalarQuantityValue {
        unit = "Pa*s";
    }

    attribute def Pressure :> ScalarQuantityValue {
        unit = "Pa";
    }

    attribute def FlowRate :> ScalarQuantityValue {
        unit = "m^3/s";
    }

    attribute def Temperature :> ScalarQuantityValue {
        unit = "K";
    }

    attribute def Volume :> ScalarQuantityValue {
        unit = "m^3";
    }

    attribute def MassFraction :> ScalarQuantityValue {
        unit = "1";
    }

    attribute def ParticleSize :> ScalarQuantityValue {
        unit = "m";
    }

    item def DrillingMud {
        attribute density : Density;
        attribute plasticViscosity : DynamicViscosity;
        attribute yieldPoint : Pressure;
        attribute temperature : Temperature;
        attribute solidsFraction : MassFraction;
        attribute waterFraction : MassFraction;
        attribute oilFraction : MassFraction;
        attribute additiveFraction : MassFraction;
    }

    item def DrillCuttings {
        attribute meanParticleSize : ParticleSize;
        attribute solidsDensity : Density;
        attribute massFractionInReturnFlow : MassFraction;
    }

    item def MudAdditive {
        attribute concentration : MassFraction;
        attribute densityContribution : Density;
        attribute viscosityContribution : DynamicViscosity;
    }

    item def PressureSignal {
        attribute measuredPressure : Pressure;
        attribute sampleTime : Time;
    }

    item def FlowSignal {
        attribute measuredFlowRate : FlowRate;
        attribute sampleTime : Time;
    }

    item def DensitySignal {
        attribute measuredDensity : Density;
        attribute sampleTime : Time;
    }

    port def MudInletPort {
        in item mudIn : DrillingMud;
    }

    port def MudOutletPort {
        out item mudOut : DrillingMud;
    }

    port def ReturnMudPort {
        in item returnMud : DrillingMud;
        in item cuttings : DrillCuttings;
    }

    port def AdditivePort {
        in item additive : MudAdditive;
    }

    port def SignalOutPort {
        out item signal : PressureSignal;
        out item flowSignal : FlowSignal;
        out item densitySignal : DensitySignal;
    }

    port def ControlCommandPort {
        in attribute pumpSpeedCommand : Real;
        in attribute additiveValveCommand : Real;
        in attribute bypassValveCommand : Real;
    }

    action def MixMud {
        in item baseMud : DrillingMud;
        in item additive : MudAdditive;
        out item conditionedMud : DrillingMud;

        attribute targetDensity : Density = 1200 [kg/m^3];
        attribute targetViscosity : DynamicViscosity = 0.045 [Pa*s];
    }

    action def PumpMud {
        in item mudSupply : DrillingMud;
        out item pressurizedMud : DrillingMud;

        attribute dischargePressure : Pressure;
        attribute commandedFlowRate : FlowRate;
    }

    action def CarryCuttings {
        in item downholeMud : DrillingMud;
        in item generatedCuttings : DrillCuttings;
        out item returnFlow : DrillingMud;

        attribute minimumAnnularVelocity : FlowRate = 0.055 [m^3/s];
    }

    action def SeparateSolids {
        in item contaminatedMud : DrillingMud;
        in item entrainedCuttings : DrillCuttings;
        out item cleanedMud : DrillingMud;
        out item separatedCuttings : DrillCuttings;

        attribute maximumResidualSolidsFraction : MassFraction = 0.06 [1];
    }

    action def MonitorMudProperties {
        in item mudSample : DrillingMud;
        out item densityReading : DensitySignal;
        out item flowReading : FlowSignal;
        out item pressureReading : PressureSignal;
    }

    state def MudCirculationStateMachine {
        state idle;
        state preparingMud;
        state circulating;
        state conditioningReturnMud;
        state alarm;
        state shutdown;

        entry action initializeInventory;
        then idle;

        transition idle_to_preparing
            first idle
            accept StartCirculation
            then preparingMud;

        transition preparing_to_circulating
            first preparingMud
            accept MudPropertiesWithinLimits
            then circulating;

        transition circulating_to_conditioning
            first circulating
            accept ReturnMudDetected
            then conditioningReturnMud;

        transition conditioning_to_circulating
            first conditioningReturnMud
            accept SolidsRemoved
            then circulating;

        transition circulating_to_alarm
            first circulating
            accept PressureOutOfRange
            then alarm;

        transition alarm_to_circulating
            first alarm
            accept FaultCleared
            then circulating;

        transition alarm_to_shutdown
            first alarm
            accept EmergencyStop
            then shutdown;

        transition circulating_to_shutdown
            first circulating
            accept StopCirculation
            then shutdown;
    }

    part def MudMixingTank {
        attribute workingVolume : Volume = 35 [m^3];
        attribute minimumOperatingVolume : Volume = 8 [m^3];
        attribute agitatorPower : Power = 45000 [W];

        port additiveIn : AdditivePort;
        port mudIn : MudInletPort;
        port mudOut : MudOutletPort;

        perform action mix : MixMud;
    }

    part def MudPump {
        attribute ratedFlowRate : FlowRate = 0.075 [m^3/s];
        attribute ratedDischargePressure : Pressure = 34500000 [Pa];
        attribute minimumSuctionPressure : Pressure = 150000 [Pa];

        port suction : MudInletPort;
        port discharge : MudOutletPort;
        port command : ControlCommandPort;

        perform action pump : PumpMud;
    }

    part def DrillString {
        attribute internalFlowCapacity : FlowRate = 0.08 [m^3/s];
        attribute maximumInternalPressure : Pressure = 41000000 [Pa];

        port mudIn : MudInletPort;
        port mudOut : MudOutletPort;
    }

    part def DrillBit {
        attribute nozzlePressureDrop : Pressure = 5200000 [Pa];
        attribute hydraulicCleaningFlowRate : FlowRate = 0.055 [m^3/s];

        port mudIn : MudInletPort;
        port mudOut : MudOutletPort;
    }

    part def Annulus {
        attribute minimumCuttingsTransportFlowRate : FlowRate = 0.055 [m^3/s];
        attribute maximumEquivalentCirculatingDensity : Density = 1750 [kg/m^3];

        port mudAndCuttingsIn : ReturnMudPort;
        port returnMudOut : ReturnMudPort;

        perform action transport : CarryCuttings;
    }

    part def ShaleShaker {
        attribute screenOpening : ParticleSize = 0.000175 [m];
        attribute solidsRemovalEfficiency : Real = 0.82;

        port returnIn : ReturnMudPort;
        port cleanedOut : MudOutletPort;

        perform action separate : SeparateSolids;
    }

    part def Desander {
        attribute cutPoint : ParticleSize = 0.000045 [m];
        attribute solidsRemovalEfficiency : Real = 0.74;

        port returnIn : ReturnMudPort;
        port cleanedOut : MudOutletPort;

        perform action separate : SeparateSolids;
    }

    part def Degasser {
        attribute gasRemovalEfficiency : Real = 0.90;
        attribute maximumProcessingFlowRate : FlowRate = 0.08 [m^3/s];

        port mudIn : MudInletPort;
        port mudOut : MudOutletPort;
    }

    part def MudPropertySensorSuite {
        attribute pressureAccuracy : Pressure = 50000 [Pa];
        attribute densityAccuracy : Density = 5 [kg/m^3];
        attribute flowAccuracy : FlowRate = 0.001 [m^3/s];

        port mudSampleIn : MudInletPort;
        port signalsOut : SignalOutPort;

        perform action monitor : MonitorMudProperties;
    }

    part def MudControlUnit {
        attribute targetMudDensity : Density = 1200 [kg/m^3];
        attribute targetPlasticViscosity : DynamicViscosity = 0.045 [Pa*s];
        attribute targetFlowRate : FlowRate = 0.065 [m^3/s];
        attribute maximumStandpipePressure : Pressure = 32000000 [Pa];

        port sensorSignals : SignalOutPort;
        port commands : ControlCommandPort;

        exhibit state controlState : MudCirculationStateMachine;
    }

    part def DrillingMudCirculationSystem {
        attribute primaryFunction : String =
            "Condition, pressurize, circulate, and recover drilling mud to cool and lubricate the drill bit, transport cuttings to the surface, control wellbore pressure, and maintain borehole stability.";

        attribute nominalMudDensity : Density = 1200 [kg/m^3];
        attribute nominalFlowRate : FlowRate = 0.065 [m^3/s];
        attribute nominalSurfaceTemperature : Temperature = 298 [K];
        attribute maximumAllowableSolidsFraction : MassFraction = 0.06 [1];

        part mixingTank : MudMixingTank;
        part pump : MudPump;
        part drillString : DrillString;
        part bit : DrillBit;
        part annulus : Annulus;
        part shaker : ShaleShaker;
        part desander : Desander;
        part degasser : Degasser;
        part sensors : MudPropertySensorSuite;
        part controller : MudControlUnit;

        port additiveSupply : AdditivePort;
        port wellboreReturn : ReturnMudPort;

        connect additiveSupply to mixingTank.additiveIn;
        connect mixingTank.mudOut to pump.suction;
        connect controller.commands to pump.command;
        connect pump.discharge to drillString.mudIn;
        connect drillString.mudOut to bit.mudIn;
        connect bit.mudOut to annulus.mudAndCuttingsIn;
        connect annulus.returnMudOut to shaker.returnIn;
        connect shaker.cleanedOut to desander.returnIn;
        connect desander.cleanedOut to degasser.mudIn;
        connect degasser.mudOut to mixingTank.mudIn;
        connect degasser.mudOut to sensors.mudSampleIn;
        connect sensors.signalsOut to controller.sensorSignals;

        perform action mudConditioning : MixMud;
        perform action mudPressurization : PumpMud;
        perform action cuttingsTransport : CarryCuttings;
        perform action solidsControl : SeparateSolids;
        perform action propertyMonitoring : MonitorMudProperties;
    }

    requirement def PrimaryMudFunctionRequirement {
        doc /* The drilling mud system shall circulate conditioned drilling mud through the drill string and annulus to cool and lubricate the bit, remove cuttings, control formation pressure, and stabilize the wellbore. */

        subject system : DrillingMudCirculationSystem;

        require constraint {
            system.nominalFlowRate >= 0.055 [m^3/s]
        }
    }

    requirement def DensityControlRequirement {
        doc /* The system shall maintain mud density within the operating window required for hydrostatic well control. */

        subject system : DrillingMudCirculationSystem;

        attribute minimumDensity : Density = 1050 [kg/m^3];
        attribute maximumDensity : Density = 1450 [kg/m^3];

        require constraint {
            system.nominalMudDensity >= minimumDensity and
            system.nominalMudDensity <= maximumDensity
        }
    }

    requirement def SolidsRemovalRequirement {
        doc /* The solids control equipment shall reduce residual drilled-solids concentration in recovered mud to protect pumps, drill string hydraulics, and rheological stability. */

        subject system : DrillingMudCirculationSystem;

        require constraint {
            system.maximumAllowableSolidsFraction <= 0.06 [1]
        }
    }

    requirement def PumpPressureRequirement {
        doc /* The mud pump shall provide sufficient discharge pressure for drill string, bit nozzle, and annular circulation losses without exceeding the standpipe pressure limit. */

        subject system : DrillingMudCirculationSystem;

        require constraint {
            system.pump.ratedDischargePressure >= 30000000 [Pa] and
            system.controller.maximumStandpipePressure <= 32000000 [Pa]
        }
    }

    requirement def MonitoringRequirement {
        doc /* The system shall continuously measure mud pressure, flow rate, and density to support closed-loop control and abnormal-condition detection. */

        subject system : DrillingMudCirculationSystem;

        require constraint {
            system.sensors.pressureAccuracy <= 50000 [Pa] and
            system.sensors.densityAccuracy <= 5 [kg/m^3] and
            system.sensors.flowAccuracy <= 0.001 [m^3/s]
        }
    }

    satisfy PrimaryMudFunctionRequirement by DrillingMudCirculationSystem;
    satisfy DensityControlRequirement by DrillingMudCirculationSystem;
    satisfy SolidsRemovalRequirement by DrillingMudCirculationSystem;
    satisfy PumpPressureRequirement by DrillingMudCirculationSystem;
    satisfy MonitoringRequirement by DrillingMudCirculationSystem;
}