package HumphreyPumpSubsystem {
    import ScalarValues::*;

    // ============ Value Types ============
    value type Volume :> Real { doc /* Unit: m3 */ }
    value type Pressure :> Real { doc /* Unit: Pa */ }
    value type Temperature :> Real { doc /* Unit: K */ }
    value type VolFlowRate :> Real { doc /* Unit: m3/s */ }
    value type Energy :> Real { doc /* Unit: J */ }
    value type Frequency :> Real { doc /* Unit: Hz */ }
    value type Duration :> Real { doc /* Unit: s */ }
    value type Length :> Real { doc /* Unit: m */ }
    value type Velocity :> Real { doc /* Unit: m/s */ }
    value type EquivalenceRatio :> Real { doc /* Dimensionless */ }
    value type Density :> Real { doc /* Unit: kg/m3 */ }

    // ============ Item Definitions ============
    item def Water {
        doc /* Fluid to be pumped. */
        attribute temperature : Temperature;
        attribute density : Density;
    }

    item def FuelAirMixture {
        doc /* Combustible fuel-air mixture admitted into the combustion chamber. */
        attribute volume : Volume;
        attribute equivalenceRatio : EquivalenceRatio;
        attribute pressure : Pressure;
    }

    item def ExhaustGas {
        doc /* Spent combustion byproduct gases expelled from the chamber. */
        attribute pressure : Pressure;
        attribute temperature : Temperature;
    }

    item def IgnitionSpark {
        doc /* Spark event produced by the ignition system. */
        attribute energy : Energy;
        attribute timing : Duration;
    }

    item def ControlCommand {
        doc /* Electronic control signal for ignition timing. */
        attribute command : String;
        attribute cyclePhase : String;
    }

    // ============ Port Definitions ============
    port def FluidPort {
        in item : Water;
        out item : Water;
        attribute flowRate : VolFlowRate;
        attribute pressure : Pressure;
    }

    port def FuelPort {
        in item : FuelAirMixture;
        attribute flowRate : VolFlowRate;
        attribute pressure : Pressure;
    }

    port def ExhaustPort {
        out item : ExhaustGas;
        attribute pressure : Pressure;
    }

    port def SparkPort {
        out item : IgnitionSpark;
    }

    port def ControlPort {
        in item : ControlCommand;
    }

    // ============ Connection Definitions ============
    connection def FluidConnection {
        end source : FluidPort;
        end target : FluidPort;
    }

    connection def FuelConnection {
        end source : FuelPort;
        end target : FuelPort;
    }

    connection def SparkConnection {
        end source : SparkPort;
        end target : SparkPort;
    }

    connection def ExhaustConnection {
        end source : ExhaustPort;
        end target : ExhaustPort;
    }

    connection def ControlConnection {
        end source : ControlPort;
        end target : ControlPort;
    }

    // ============ Action Definitions ============
    action def IntakeFuelAdmissionAction {
        doc /* Draw water through the inlet check valve and admit a fresh fuel-air charge while the water column oscillates backward, creating a partial vacuum. */
        in inletFlow : VolFlowRate;
        in fuelFlow : VolFlowRate;
        out drawnWaterVolume : Volume;
        out admittedFuelVolume : Volume;
        out chamberPressure : Pressure;
        attribute vacuumPressure : Pressure;
    }

    action def IgnitionCombustionAction {
        doc /* Close valves and fire the ignition spark to ignite the trapped fuel-air mixture, causing rapid gas expansion and a pressure spike. */
        in spark : IgnitionSpark;
        in fuelCharge : FuelAirMixture;
        out exhaustGas : ExhaustGas;
        out peakPressure : Pressure;
        out peakTemperature : Temperature;
        attribute ignitionDelay : Duration;
    }

    action def DischargePowerAction {
        doc /* High chamber pressure acts on the water column surface, forcing it through the outlet check valve toward the elevated discharge tank. */
        in chamberPressure : Pressure;
        out dischargedVolume : Volume;
        out dischargeVelocity : Velocity;
        attribute strokeDuration : Duration;
    }

    action def ExhaustAction {
        doc /* The momentum of the discharged water column carries it forward, dropping chamber pressure below atmospheric. The backward oscillation pushes spent exhaust gases out of the chamber. */
        in chamberPressure : Pressure;
        out expelledGasVolume : Volume;
        out exhaustGas : ExhaustGas;
        attribute oscillationPeriod : Duration;
    }

    // ============ State Machine Definition ============
    state def PumpCycleStates {
        doc /* The repeating four-phase cycle of a Humphrey pump: Intake and Fuel Admission, Ignition and Combustion, Discharge (Power Stroke), and Exhaust. */

        attribute atmosphericPressure : Pressure;
        attribute ignitionPressure : Pressure;
        attribute chamberPressure : Pressure;
        attribute waterColumnPosition : Length;
        attribute dischargeComplete : Boolean;
        attribute valvesClosed : Boolean;
        attribute intakeComplete : Boolean;
        attribute exhaustComplete : Boolean;

        state IntakeFuelAdmission {
            doc /* The water column oscillates back from prior-cycle momentum, creating a partial vacuum. Water is drawn in through the inlet check valve, and a fresh fuel-air charge is simultaneously admitted from the fuel supply. */
            entry action doIntake : IntakeFuelAdmissionAction;
            do action monitorIntake : IntakeFuelAdmissionAction;
            exit action sealValves : IntakeFuelAdmissionAction;
        }

        state IgnitionCombustion {
            doc /* With both check valves closed, the ignition system fires a spark. The trapped fuel-air mixture ignites, rapidly expanding gas and producing a massive pressure spike inside the chamber. */
            entry action doIgnition : IgnitionCombustionAction;
            do action monitorCombustion : IgnitionCombustionAction;
        }

        state DischargePower {
            doc /* The high pressure acts directly on the water column surface, powerfully forcing it down and out through the outlet check valve toward the higher-elevation discharge tank. */
            entry action doDischarge : DischargePowerAction;
            do action monitorDischarge : DischargePowerAction;
            exit action markDischargeComplete : DischargePowerAction;
        }

        state Exhaust {
            doc /* The momentum of the discharged water carries the column forward, causing chamber pressure to drop below atmospheric. The water column then oscillates back, pushing spent exhaust gases out through the exhaust port. This backward motion leads directly into the next intake phase. */
            entry action doExhaust : ExhaustAction;
            do action monitorExhaust : ExhaustAction;
            exit action resetCycle : ExhaustAction;
        }

        transition from IntakeFuelAdmission to IgnitionCombustion when valvesClosed == true;
        transition from IgnitionCombustion to DischargePower when chamberPressure >= ignitionPressure;
        transition from DischargePower to Exhaust when dischargeComplete == true;
        transition from Exhaust to IntakeFuelAdmission when chamberPressure < atmosphericPressure;
    }

    // ============ Part Definitions ============
    part def SourceReservoir {
        doc /* A lower-elevation reservoir storing the fluid to be pumped. */
        attribute elevation : Length;
        attribute storedVolume : Volume;
        attribute fluidTemperature : Temperature;
        port fluidOut : FluidPort;
    }

    part def DischargeTank {
        doc /* An elevated collection tank where the pumped fluid is delivered. */
        attribute elevation : Length;
        attribute storedVolume : Volume;
        port fluidIn : FluidPort;
    }

    part def FuelSupplySystem {
        doc /* Provides a metered fuel-air mixture to the combustion chamber for each cycle. */
        attribute fuelPressure : Pressure;
        attribute fuelVolume : Volume;
        attribute nominalEquivalenceRatio : EquivalenceRatio;
        port fuelOut : FuelPort;
    }

    part def InletCheckValve {
        doc /* A one-way check valve allowing fluid to be drawn into the combustion chamber from the source reservoir; prevents backflow toward the source. */
        attribute isOpen : Boolean;
        attribute allowsDirection : String;
        attribute crackingPressure : Pressure;
        attribute responseTime : Duration;
        port upstream : FluidPort;
        port downstream : FluidPort;
    }

    part def OutletCheckValve {
        doc /* A one-way check valve allowing fluid to be pushed from the combustion chamber to the discharge tank; prevents backflow into the chamber. */
        attribute isOpen : Boolean;
        attribute allowsDirection : String;
        attribute crackingPressure : Pressure;
        attribute responseTime : Duration;
        port upstream : FluidPort;
        port downstream : FluidPort;
    }

    part def IgnitionSystem {
        doc /* An electronically controlled ignition system that delivers a high-energy spark to the combustion chamber at precise moments in the cycle. */
        attribute sparkEnergy : Energy;
        attribute timingPrecision : Duration;
        attribute operatingFrequency : Frequency;
        attribute ignitionDelay : Duration;
        port sparkOut : SparkPort;
        port controlIn : ControlPort;
    }

    part def CombustionChamber {
        doc /* A large J- or U-shaped chamber serving as both the cylinder and the pumping mechanism. It holds the oscillating water column and contains the combustion event. */
        attribute shape : String;
        attribute chamberVolume : Volume;
        attribute chamberPressure : Pressure;
        attribute chamberTemperature : Temperature;
        attribute waterColumnVelocity : Velocity;
        attribute waterColumnPosition : Length;
        attribute maxOperatingPressure : Pressure;
        attribute atmosphericPressure : Pressure;
        attribute ignitionPressure : Pressure;
        port waterInlet : FluidPort;
        port waterOutlet : FluidPort;
        port fuelInlet : FuelPort;
        port exhaustPort : ExhaustPort;
        port sparkInput : SparkPort;
    }

    part def HumphreyPump {
        doc /* A Humphrey pump: an internal combustion water pump that operates without pistons, crankshafts, or other major moving mechanical parts. Combustion pressure acts directly on a water column to produce pulsating flow. */

        attribute operatingFrequency : Frequency;
        attribute atmosphericPressure : Pressure;
        attribute ignitionPressure : Pressure;
        attribute cyclePeriod : Duration;
        attribute cycleCount : Integer;

        part combustionChamber : CombustionChamber {
            doc /* The core J- or U-shaped pumping chamber. */
        }

        part ignition : IgnitionSystem {
            doc /* Electronically controlled spark ignition. */
        }

        part inletValve : InletCheckValve {
            doc /* Inlet one-way valve from the source reservoir. */
        }

        part outletValve : OutletCheckValve {
            doc /* Outlet one-way valve to the discharge tank. */
        }

        port sourcePort : FluidPort;
        port dischargePort : FluidPort;
        port fuelPort : FuelPort;
        port exhaustPort : ExhaustPort;
        port controlPort : ControlPort;

        connection : FluidConnection connect sourcePort to inletValve.upstream;
        connection : FluidConnection connect inletValve.downstream to combustionChamber.waterInlet;
        connection : FluidConnection connect combustionChamber.waterOutlet to outletValve.upstream;
        connection : FluidConnection connect outletValve.downstream to dischargePort;
        connection : FuelConnection connect fuelPort to combustionChamber.fuelInlet;
        connection : SparkConnection connect ignition.sparkOut to combustionChamber.sparkInput;
        connection : ExhaustConnection connect combustionChamber.exhaustPort to exhaustPort;
        connection : ControlConnection connect controlPort to ignition.controlIn;

        state pumpCycle : PumpCycleStates;
    }

    // ============ Top-Level System ============
    part def HumphreyPumpSystem {
        doc /* The complete Humphrey pump subsystem consisting of a source reservoir, the Humphrey pump, a fuel supply system, and an elevated discharge tank. */

        part sourceReservoir : SourceReservoir {
            doc /* Lower-elevation source holding the fluid to be pumped. */
            attribute elevation : Length;
        }

        part humphreyPump : HumphreyPump {
            doc /* The Humphrey pump itself with all internal components. */
        }

        part fuelSupply : FuelSupplySystem {
            doc /* Provides the fuel-air mixture to the pump. */
        }

        part dischargeTank : DischargeTank {
            doc /* Elevated destination tank where the pumped fluid is collected. */
            attribute elevation : Length;
        }

        connection : FluidConnection connect sourceReservoir.fluidOut to humphreyPump.sourcePort;
        connection : FluidConnection connect humphreyPump.dischargePort to dischargeTank.fluidIn;
        connection : FuelConnection connect fuelSupply.fuelOut to humphreyPump.fuelPort;
    }

    // ============ Requirement Definitions ============
    requirement def PumpFluidRequirement {
        doc /* The system shall pump fluid from a lower-elevation source reservoir to a higher-elevation discharge tank using combustion-driven pressure pulses. */
        subject system : HumphreyPumpSystem;
        attribute sourceElevation : Length;
        attribute destinationElevation : Length;
        constraint { destinationElevation > sourceElevation }
    }

    requirement def NoMechanicalMovingPartsRequirement {
        doc /* The pump shall operate without pistons, crankshafts, or other major moving mechanical parts. The only motion is the oscillating water column. */
        subject pump : HumphreyPump;
        attribute hasPiston : Boolean;
        attribute hasCrankshaft : Boolean;
        attribute hasRotatingMechanism : Boolean;
        attribute hasValves : Boolean;
        constraint { hasPiston == false and hasCrankshaft == false and hasRotatingMechanism == false }
    }

    requirement def IntakeCheckValveRequirement {
        doc /* The inlet check valve shall allow fluid to be drawn into the combustion chamber from the source reservoir during the intake phase and shall prevent backflow at all other times. */
        subject inletValve : InletCheckValve;
        attribute allowsIntakeFlow : Boolean;
        attribute preventsBackflow : Boolean;
        constraint { allowsIntakeFlow == true and preventsBackflow == true }
    }

    requirement def OutletCheckValveRequirement {
        doc /* The outlet check valve shall allow fluid to be pushed out to the discharge tank during the power stroke and shall prevent backflow at all other times. */
        subject outletValve : OutletCheckValve;
        attribute allowsDischargeFlow : Boolean;
        attribute preventsBackflow : Boolean;
        constraint { allowsDischargeFlow == true and preventsBackflow == true }
    }

    requirement def IgnitionSystemRequirement {
        doc /* The ignition system shall deliver a spark of sufficient energy to reliably ignite the fuel-air mixture at the precise moment determined by the cycle phase. */
        subject ignition : IgnitionSystem;
        attribute sparkEnergy : Energy;
        attribute timingPrecision : Duration;
        attribute minSparkEnergy : Energy;
        constraint { sparkEnergy >= minSparkEnergy }
    }

    requirement def CombustionPressureRequirement {
        doc /* Combustion of the fuel-air mixture shall produce a peak pressure inside the chamber sufficient to drive the water column to the discharge tank elevation. */
        subject chamber : CombustionChamber;
        attribute peakPressure : Pressure;
        attribute requiredDischargePressure : Pressure;
        constraint { peakPressure >= requiredDischargePressure }
    }

    requirement def CycleContinuityRequirement {
        doc /* The pump cycle shall repeat continuously. The exhaust phase shall transition directly into the next intake phase without interruption, maintaining rhythmic oscillation of the water column. */
        subject pump : HumphreyPump;
        attribute cyclePeriod : Duration;
        attribute operatingFrequency : Frequency;
        constraint { operatingFrequency > 0 }
    }

    requirement def FuelAdmissionRequirement {
        doc /* A fresh charge of fuel-air mixture shall be admitted into the combustion chamber during each intake phase, timed to coincide with the water column oscillation creating a partial vacuum. */
        subject fuelSupply : FuelSupplySystem;
        attribute fuelPressure : Pressure;
        attribute chamberVacuumPressure : Pressure;
        constraint { fuelPressure > chamberVacuumPressure }
    }

    // ============ Requirement Usages ============
    requirement reqPumpFluid : PumpFluidRequirement {
        attribute sourceElevation = 0;
        attribute destinationElevation = 50;
    }

    requirement reqNoMovingParts : NoMechanicalMovingPartsRequirement {
        attribute hasPiston = false;
        attribute hasCrankshaft = false;
        attribute hasRotatingMechanism = false;
        attribute hasValves = true;
    }

    requirement reqIntakeValve : IntakeCheckValveRequirement {
        attribute allowsIntakeFlow = true;
        attribute preventsBackflow = true;
    }

    requirement reqOutletValve : OutletCheckValveRequirement {
        attribute allowsDischargeFlow = true;
        attribute preventsBackflow = true;
    }

    requirement reqIgnition : IgnitionSystemRequirement {
        attribute sparkEnergy = 0.5;
        attribute minSparkEnergy = 0.1;
        attribute timingPrecision = 0.001;
    }

    requirement reqCombustion : CombustionPressureRequirement {
        attribute requiredDischargePressure = 600000;
    }

    requirement reqCycle : CycleContinuityRequirement {
        attribute operatingFrequency = 0.5;
        attribute cyclePeriod = 2.0;
    }

    requirement reqFuelAdmission : FuelAdmissionRequirement {
        attribute fuelPressure = 150000;
        attribute chamberVacuumPressure = 80000;
    }

    // ============ System Instance and Satisfaction ============
    part systemInstance : HumphreyPumpSystem;

    satisfy reqPumpFluid by systemInstance;
    satisfy reqNoMovingParts by systemInstance.humphreyPump;
    satisfy reqIntakeValve by systemInstance.humphreyPump.inletValve;
    satisfy reqOutletValve by systemInstance.humphreyPump.outletValve;
    satisfy reqIgnition by systemInstance.humphreyPump.ignition;
    satisfy reqCombustion by systemInstance.humphreyPump.combustionChamber;
    satisfy reqCycle by systemInstance.humphreyPump;
    satisfy reqFuelAdmission by systemInstance.fuelSupply;
}
