package LiquidPropellantPropulsionSystem {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    // ============================================================
    // Value Types with Units
    // ============================================================

    value type Mass specializes Real {
        unit :> Kilogram;
    }

    value type Pressure specializes Real {
        unit :> Pascal;
    }

    value type Temperature specializes Real {
        unit :> Kelvin;
    }

    value type Velocity specializes Real {
        unit :> MetrePerSecond;
    }

    value type Force specializes Real {
        unit :> Newton;
    }

    value type Duration specializes Real {
        unit :> Second;
    }

    value type MassFlowRate specializes Real {
        unit :> KilogramPerSecond;
    }

    value type ExpansionRatio specializes Real;

    // ============================================================
    // Item and Attribute Definitions
    // ============================================================

    item def LiquidPropellant;
    item def HighPressurePropellant;
    item def CombustionGas;
    item def AcceleratedExhaust;

    attribute def ThrustCommand {
        attribute desiredThrust : Force;
        attribute firingDuration : Duration;
        attribute enable : Boolean;
        attribute emergencyShutdown : Boolean;
    }

    attribute def TelemetryPacket {
        attribute chamberPressure : Pressure;
        attribute chamberTemperature : Temperature;
        attribute currentThrust : Force;
        attribute propellantRemaining : Mass;
        attribute engineStatus : String;
    }

    attribute def SensorReading {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute propellantMass : Mass;
    }

    attribute def ControlSignal {
        attribute targetFlowRate : MassFlowRate;
        attribute ignitionEnable : Boolean;
        attribute shutdownCommand : Boolean;
    }

    // ============================================================
    // Port Definitions
    // ============================================================

    port def PropellantFlowPort {
        out item propellant : LiquidPropellant;
        attribute flowRate : MassFlowRate;
    }

    port def HighPressureFlowPort {
        in item propellant : HighPressurePropellant;
        attribute flowRate : MassFlowRate;
        attribute pressure : Pressure;
    }

    port def GasFlowPort {
        in item gas : CombustionGas;
        attribute temperature : Temperature;
        attribute pressure : Pressure;
    }

    port def ExhaustFlowPort {
        out item exhaust : AcceleratedExhaust;
        attribute exhaustVelocity : Velocity;
        attribute producedThrust : Force;
    }

    port def CommandReceivePort {
        in attribute command : ThrustCommand;
    }

    port def TelemetrySendPort {
        out attribute telemetry : TelemetryPacket;
    }

    port def SensorReceivePort {
        in attribute reading : SensorReading;
    }

    port def ControlOutPort {
        out attribute signal : ControlSignal;
    }

    // ============================================================
    // Component Part Definitions
    // ============================================================

    part def PropellantTank {
        attribute initialPropellantMass : Mass = 800 [kg];
        attribute currentPropellantMass : Mass = 800 [kg];
        attribute maxCapacity : Mass = 800 [kg];
        attribute tankPressure : Pressure;

        port propellantOut : PropellantFlowPort;

        action def Dispense {
            in requestedFlow : MassFlowRate;
            in deltaTime : Duration;
            out providedFlow : MassFlowRate;
            out remainingMass : Mass;
        }

        action dispensePropellant : Dispense;
    }

    part def PropellantFeedSystem {
        attribute regulatedOutputPressure : Pressure;
        attribute currentFlowRate : MassFlowRate;
        attribute maxFlowRate : MassFlowRate;

        port propellantIn : PropellantFlowPort;
        port propellantOut : HighPressureFlowPort;
        port controlIn : ControlOutPort;

        action def Pressurize {
            in inflow : MassFlowRate;
            in targetFlow : MassFlowRate;
            out outflow : MassFlowRate;
            out outputPressure : Pressure;
        }

        action regulateFlow : Pressurize;
    }

    part def CombustionChamber {
        attribute operatingTemperature : Temperature = 3673.15 [K];
        attribute operatingPressure : Pressure;
        attribute ignited : Boolean = false;

        port propellantIn : HighPressureFlowPort;
        port gasOut : GasFlowPort;
        port sensorOut : SensorReceivePort;
        port ignitionControlIn : ControlOutPort;

        action def Combustion {
            in propellantInflow : MassFlowRate;
            in ignitionCommand : Boolean;
            out gasOutflow : MassFlowRate;
            out chamberTemperature : Temperature;
            out chamberPressureOut : Pressure;
            out ignitedState : Boolean;
        }

        action burn : Combustion;
    }

    part def Nozzle {
        attribute designExitVelocity : Velocity = 4200 [m/s];
        attribute measuredThrust : Force;
        attribute expansionRatio : ExpansionRatio;

        port gasIn : GasFlowPort;
        port exhaustOut : ExhaustFlowPort;

        action def Accelerate {
            in gasInflow : MassFlowRate;
            in gasTemperature : Temperature;
            in gasPressure : Pressure;
            out exhaustVelocityOut : Velocity;
            out thrustOut : Force;
        }

        action accelerateGas : Accelerate;
    }

    part def ThrustController {
        attribute desiredThrust : Force;
        attribute firingDuration : Duration;
        attribute currentStatus : String = "Idle";
        attribute emergencyFlag : Boolean = false;
        attribute lastReading : SensorReading;

        port commandIn : CommandReceivePort;
        port telemetryOut : TelemetrySendPort;
        port sensorIn : SensorReceivePort;
        port chamberControlOut : ControlOutPort;
        port feedControlOut : ControlOutPort;

        action def ProcessCommand {
            in cmd : ThrustCommand;
            out targetFlow : MassFlowRate;
            out duration : Duration;
        }

        action def RegulateThrust {
            in sensorData : SensorReading;
            in desired : Force;
            out adjustedFlow : MassFlowRate;
        }

        action def SendTelemetry {
            in data : SensorReading;
            in thrust : Force;
            in remaining : Mass;
            in status : String;
            out packet : TelemetryPacket;
        }

        state machine ControllerStateMachine {
            state Idle;
            state Starting;
            state Firing;
            state ShuttingDown;
            state EmergencyStop;

            transition from Idle to Starting
                when commandIn.command.enable == true;
            transition from Starting to Firing
                when sensorIn.reading.pressure > 0 [Pa];
            transition from Firing to ShuttingDown
                when firingDuration <= 0 [s];
            transition from Starting to EmergencyStop
                when commandIn.command.emergencyShutdown == true;
            transition from Firing to EmergencyStop
                when emergencyFlag == true;
            transition from ShuttingDown to Idle
                when currentStatus == "Idle";
            transition from EmergencyStop to Idle
                when currentStatus == "Idle";
        }
    }

    // ============================================================
    // Top-Level Engine Part Definition
    // ============================================================

    part def LiquidPropellantEngine {

        part tank : PropellantTank {
            redefine attribute initialPropellantMass = 800 [kg];
            redefine attribute currentPropellantMass = 800 [kg];
        }
        part feedSystem : PropellantFeedSystem;
        part chamber : CombustionChamber;
        part nozzle : Nozzle;
        part controller : ThrustController;

        // External interface ports
        port spacecraftCommand : CommandReceivePort;
        port spacecraftTelemetry : TelemetrySendPort;
        port exhaustPort : ExhaustFlowPort;

        // Internal fluid/gas connections
        connection propellantFeedPath
            connect tank.propellantOut to feedSystem.propellantIn;
        connection highPressureFeedPath
            connect feedSystem.propellantOut to chamber.propellantIn;
        connection gasFlowPath
            connect chamber.gasOut to nozzle.gasIn;
        connection exhaustPath
            connect nozzle.exhaustOut to exhaustPort;

        // Controller command/telemetry routing
        connection commandPath
            connect spacecraftCommand to controller.commandIn;
        connection telemetryPath
            connect controller.telemetryOut to spacecraftTelemetry;
        connection sensorFeedback
            connect chamber.sensorOut to controller.sensorIn;
        connection chamberControlPath
            connect controller.chamberControlOut to chamber.ignitionControlIn;
        connection feedControlPath
            connect controller.feedControlOut to feedSystem.controlIn;

        // Overall engine lifecycle
        state machine EngineLifecycle {
            state Idle;
            state Startup;
            state SteadyThrust;
            state ControlledShutdown;
            state EmergencyShutdown;

            transition from Idle to Startup
                when spacecraftCommand.command.enable == true;
            transition from Startup to SteadyThrust
                when chamber.sensorIn.reading.pressure >= chamber.operatingPressure;
            transition from SteadyThrust to ControlledShutdown
                when controller.firingDuration <= 0 [s];
            transition from ControlledShutdown to Idle
                when chamber.ignited == false;
            transition from Startup to EmergencyShutdown
                when spacecraftCommand.command.emergencyShutdown == true;
            transition from SteadyThrust to EmergencyShutdown
                when controller.emergencyFlag == true;
            transition from EmergencyShutdown to Idle
                when controller.currentStatus == "Idle";
        }
    }

    // ============================================================
    // Requirements
    // ============================================================

    requirement def ProvideControlledThrust {
        doc /* The propulsion system shall generate controlled thrust for in-space maneuvers. */
        attribute minThrust : Force;
        attribute maxThrust : Force;
    }

    requirement def StorePropellant {
        doc /* The propellant tank shall store 800 kg of propellant under pressure. */
        attribute requiredPropellantMass : Mass = 800 [kg];
    }

    requirement def RegulateFeedPressure {
        doc /* The feed system shall pump and regulate propellant to the combustion chamber at high pressure. */
        attribute requiredOutputPressure : Pressure;
    }

    requirement def AchieveCombustion {
        doc /* The combustion chamber shall burn propellant at approximately 3400 degrees Celsius. */
        attribute requiredTemperature : Temperature = 3673.15 [K];
    }

    requirement def AccelerateExhaust {
        doc /* The nozzle shall accelerate exhaust gas to over 4200 meters per second. */
        attribute minExitVelocity : Velocity = 4200 [m/s];
    }

    requirement def ManageOperation {
        doc /* The thrust controller shall manage ignition, regulate flow, and report telemetry. */
    }

    requirement def SafeShutdown {
        doc /* The system shall perform controlled and emergency shutdown procedures. */
    }

    requirement ProvideControlledThrustReq : ProvideControlledThrust {
        subject engine : LiquidPropellantEngine;
        attribute minThrust = 0 [N];
        attribute maxThrust = 50000 [N];
    }

    requirement StorePropellantReq : StorePropellant {
        subject tank : PropellantTank;
        assert tank.initialPropellantMass == 800 [kg];
    }

    requirement RegulateFeedPressureReq : RegulateFeedPressure {
        subject feed : PropellantFeedSystem;
        attribute requiredOutputPressure = 1500000 [Pa];
        assert feed.regulatedOutputPressure >= requiredOutputPressure;
    }

    requirement AchieveCombustionReq : AchieveCombustion {
        subject chamber : CombustionChamber;
        assert chamber.operatingTemperature >= 3673.15 [K];
    }

    requirement AccelerateExhaustReq : AccelerateExhaust {
        subject nozzle : Nozzle;
        assert nozzle.designExitVelocity >= 4200 [m/s];
    }

    requirement ManageOperationReq : ManageOperation {
        subject controller : ThrustController;
        assert controller.currentStatus in {"Idle", "Startup", "Firing", "ShuttingDown", "EmergencyStop"};
    }

    requirement SafeShutdownReq : SafeShutdown {
        subject engine : LiquidPropellantEngine;
        assert EngineLifecycle.EmergencyShutdown.isStateDefined == true;
    }

}
