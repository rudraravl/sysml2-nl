package BernoulliFlowSystem {
    attribute def StartCommand;
    attribute def StopCommand;

    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;

    attribute def PressureValue :> ISQ::PressureValue;
    attribute def VelocityValue :> ISQ::SpeedValue;
    attribute def ElevationValue :> ISQ::LengthValue;
    attribute def DensityValue :> ISQ::DensityValue;
    attribute def FlowRateValue :> ISQ::VolumeFlowRateValue;
    attribute def AreaValue :> ISQ::AreaValue;
    attribute def VolumeValue :> ISQ::VolumeValue;
    attribute def PowerValue :> ISQ::PowerValue;
    attribute def AccelerationValue :> ISQ::AccelerationValue;

    item def FluidState {
        attribute pressure : PressureValue;
        attribute velocity : VelocityValue;
        attribute elevation : ElevationValue;
    }

    port def FluidPort {
        attribute fluidState : FluidState;
        attribute flowRate : FlowRateValue;
    }

    constraint def BernoulliEquation {
        in state1 : FluidState;
        in state2 : FluidState;
        in density : DensityValue;
        in gravity : AccelerationValue;

        state1.pressure + 0.5 * density * (state1.velocity ** 2) + density * gravity * state1.elevation ==
        state2.pressure + 0.5 * density * (state2.velocity ** 2) + density * gravity * state2.elevation
    }

    constraint def ContinuityEquation {
        in flowRate1 : FlowRateValue;
        in flowRate2 : FlowRateValue;

        flowRate1 == flowRate2
    }

    part def PressureSensor {
        attribute measuredPressure : PressureValue;
        port sensePort : FluidPort;
    }

    part def VelocitySensor {
        attribute measuredVelocity : VelocityValue;
        port sensePort : FluidPort;
    }

    part def FlowMeter {
        attribute measuredFlowRate : FlowRateValue;
        port sensePort : FluidPort;
    }

    part def VenturiTube {
        attribute inletDiameter : ElevationValue;
        attribute throatDiameter : ElevationValue;
        attribute inletElevation : ElevationValue;
        attribute throatElevation : ElevationValue;

        port inlet : FluidPort;
        port throat : FluidPort;
        port outlet : FluidPort;
    }

    part def ControlValve {
        attribute opening : Real;
        attribute maxOpening : Real = 1.0;
        attribute minOpening : Real = 0.0;

        port upstream : FluidPort;
        port downstream : FluidPort;
    }

    part def FluidReservoir {
        attribute capacity : VolumeValue;
        attribute currentLevel : ElevationValue;
        attribute surfacePressure : PressureValue;

        port outlet : FluidPort;
    }

    part def Pump {
        attribute powerRating : PowerValue;
        attribute efficiency : Real;
        attribute headPressure : PressureValue;

        port suction : FluidPort;
        port discharge : FluidPort;
    }

    action def MonitorFlowConditions {
        in fluidDensity : DensityValue;
        in gravity : AccelerationValue;

        out inletState : FluidState;
        out throatState : FluidState;
        out energyBalance : Real;
    }

    action def CalculateFlowRate {
        in inletState : FluidState;
        in throatState : FluidState;
        in density : DensityValue;
        in inletArea : AreaValue;
        in throatArea : AreaValue;

        out calculatedFlowRate : FlowRateValue;
    }

    action def AdjustValve {
        in currentFlowRate : FlowRateValue;
        in targetFlowRate : FlowRateValue;
        in currentOpening : Real;

        out newOpening : Real;
    }

    state def SystemOperationStates {
        entry; then idle;

        idle : State {
            entry assign systemStatus = "Standby";
        }

        transition idle_to_startup
            first idle
            accept StartCommand
            then startup;

        startup : State {
            entry assign systemStatus = "Initializing";
        }

        transition startup_to_operating
            first startup
            if systemPressure > minOperatingPressure
            then operating;

        operating : State {
            entry assign systemStatus = "Normal Operation";
        }

        transition operating_to_alarm
            first operating
            if pressureDrop > maxAllowedDrop
            then alarm;

        alarm : State {
            entry assign systemStatus = "Alarm Condition";
        }

        transition alarm_to_operating
            first alarm
            if pressureDrop <= maxAllowedDrop
            then operating;

        transition operating_to_shutdown
            first operating
            accept StopCommand
            then shutdown;

        shutdown : State {
            entry assign systemStatus = "Shutting Down";
        }

        transition shutdown_to_idle
            first shutdown
            then idle;

        attribute systemStatus : String;
        attribute systemPressure : PressureValue;
        attribute pressureDrop : Real;
        attribute maxAllowedDrop : Real;
        attribute minOperatingPressure : Real;
    }

    action def ControlFlowSystem {
        first start;
        then merge monitorLoop;

        action monitor : MonitorFlowConditions {
            in fluidDensity;
            in gravity;
            out inletState;
            out throatState;
            out energyBalance;
        }

        then action calculate : CalculateFlowRate {
            in inletState = monitor.inletState;
            in throatState = monitor.throatState;
            in density;
            in inletArea;
            in throatArea;
            out calculatedFlowRate;
        }

        then decide;
            if abs(calculate.calculatedFlowRate - targetFlowRate) > tolerance then adjust;
            if abs(calculate.calculatedFlowRate - targetFlowRate) <= tolerance then monitorLoop;

        action adjust : AdjustValve {
            in currentFlowRate = calculate.calculatedFlowRate;
            in targetFlowRate;
            in currentOpening;
            out newOpening;
        }

        then monitorLoop;
        then done;
    }

    part def BernoulliFlowSystemAssembly;

    part bernoulliFlowSystem : BernoulliFlowSystemAssembly {
        doc /*
         * A fluid flow measurement and control system based on Bernoulli's principle.
         * The system uses a Venturi tube to create a pressure differential that is
         * proportional to flow rate. It continuously monitors pressure and velocity
         * at multiple points, calculates flow rate using Bernoulli's equation, and
         * adjusts control valves to maintain desired flow conditions.
         */

        attribute operatingFluid : String = "Water";
        attribute fluidDensity : DensityValue = 1000.0 [kg/(m^3)];
        attribute gravity : AccelerationValue = 9.81 [m/(s^2)];
        attribute targetFlowRate : FlowRateValue = 0.05 [m^3/s];
        attribute tolerance : Real = 0.001;

        part sourceReservoir : FluidReservoir {
            attribute :>> capacity = 50.0 [m^3];
            attribute :>> currentLevel = 10.0 [m];
            attribute :>> surfacePressure = 101325.0 [Pa];
        }

        part feedPump : Pump {
            attribute :>> powerRating = 7500.0 [W];
            attribute :>> efficiency = 0.82;
            attribute :>> headPressure = 250000.0 [Pa];
        }

        part venturi : VenturiTube {
            attribute :>> inletDiameter = 0.15 [m];
            attribute :>> throatDiameter = 0.075 [m];
            attribute :>> inletElevation = 2.0 [m];
            attribute :>> throatElevation = 2.0 [m];
        }

        part controlValve : ControlValve {
            attribute :>> opening = 0.5;
            attribute :>> maxOpening = 1.0;
            attribute :>> minOpening = 0.1;
        }

        part inletPressureSensor : PressureSensor;
        part inletVelocitySensor : VelocitySensor;
        part inletFlowMeter : FlowMeter;

        part throatPressureSensor : PressureSensor;
        part throatVelocitySensor : VelocitySensor;

        part outletPressureSensor : PressureSensor;
        part outletFlowMeter : FlowMeter;

        connection reservoirToPump connect
            sourceReservoir.outlet to feedPump.suction;

        connection pumpToVenturi connect
            feedPump.discharge to venturi.inlet;

        connection venturiToValve connect
            venturi.outlet to controlValve.upstream;

        connection inletSensing1 connect
            venturi.inlet to inletPressureSensor.sensePort;

        connection inletSensing2 connect
            venturi.inlet to inletVelocitySensor.sensePort;

        connection inletSensing3 connect
            venturi.inlet to inletFlowMeter.sensePort;

        connection throatSensing1 connect
            venturi.throat to throatPressureSensor.sensePort;

        connection throatSensing2 connect
            venturi.throat to throatVelocitySensor.sensePort;

        connection outletSensing1 connect
            venturi.outlet to outletPressureSensor.sensePort;

        connection outletSensing2 connect
            venturi.outlet to outletFlowMeter.sensePort;

        assert constraint bernoulliPrinciple : BernoulliEquation {
            in state1 = venturi.inlet.fluidState;
            in state2 = venturi.throat.fluidState;
            in density = fluidDensity;
            in gravity = gravity;
        }

        assert constraint flowContinuity : ContinuityEquation {
            in flowRate1 = venturi.inlet.flowRate;
            in flowRate2 = venturi.throat.flowRate;
        }

        perform action systemControl : ControlFlowSystem;

        exhibit state systemBehavior : SystemOperationStates;
    }

    requirement <'REQ-100'> primaryFunction {
        doc /*
         * The Bernoulli flow system shall measure and control fluid flow rate
         * by applying Bernoulli's principle to relate pressure differential
         * across a Venturi tube to volumetric flow rate.
         */
        subject system : BernoulliFlowSystemAssembly;
    }

    requirement <'REQ-101'> energyConservation {
        doc /*
         * The system shall maintain energy conservation along the flow path
         * according to Bernoulli's equation for incompressible, steady flow.
         */
        subject system :>> bernoulliFlowSystem;

        require constraint {
            system.bernoulliPrinciple
        }
    }

    requirement <'REQ-102'> flowMeasurement {
        doc /*
         * The system shall continuously measure pressure and velocity at
         * inlet and throat positions to calculate flow rate with accuracy
         * within specified tolerance.
         */
        subject venturi :>> bernoulliFlowSystem.venturi;

        assume constraint {
            venturi.inletDiameter > venturi.throatDiameter
        }
    }

    requirement <'REQ-103'> flowControl {
        doc /*
         * The system shall automatically adjust the control valve to
         * maintain target flow rate within tolerance limits.
         */
        subject valve :>> bernoulliFlowSystem.controlValve;

        require constraint {
            valve.opening >= valve.minOpening and
            valve.opening <= valve.maxOpening
        }
    }

    requirement <'REQ-104'> continuousOperation {
        doc /*
         * The system shall operate continuously, monitoring flow conditions
         * and adjusting control parameters to maintain stable operation.
         */
        subject system :>> bernoulliFlowSystem;
    }

    satisfy primaryFunction by bernoulliFlowSystem;
    satisfy energyConservation by bernoulliFlowSystem;
    satisfy flowMeasurement by bernoulliFlowSystem.venturi;
    satisfy flowControl by bernoulliFlowSystem.controlValve;
    satisfy continuousOperation by bernoulliFlowSystem.systemBehavior;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;
    private import BernoulliFlowSystem::*;

    part bernoulliFlowSystem : PressureSensor {
        exhibit state sm : SystemOperationStates;
    }

    action orchestrator {
        attribute testFluidDensity : DensityValue;
        attribute testGravity : AccelerationValue;
        action monitorProbe : MonitorFlowConditions {
            in fluidDensity = testFluidDensity;
            in gravity = testGravity;
        }
        attribute testStartCommand : StartCommand;
        attribute testStopCommand : StopCommand;
        action triggerStartCommand send testStartCommand to bernoulliFlowSystem;
        action triggerStopCommand send testStopCommand to bernoulliFlowSystem;
        first monitorProbe;
        then triggerStartCommand;
        then triggerStopCommand;
    }
}
