package ConcretePumpingSubsystem {
    import ScalarValues::*;

    public value type Pressure :> Real { unit 'Pa'; }
    public value type FlowRate :> Real { unit 'm3/s'; }
    public value type Volume :> Real { unit 'm3'; }
    public value type Length :> Real { unit 'm'; }
    public value type Mass :> Real { unit 'kg'; }
    public value type Power :> Real { unit 'W'; }
    public value type Voltage :> Real { unit 'V'; }
    public value type Current :> Real { unit 'A'; }
    public value type AggregateSize :> Real { unit 'mm'; }
    public value type Slump :> Real { unit 'mm'; }
    public value type RotationalSpeed :> Real { unit 'rpm'; }
    public value type Duration :> Real { unit 's'; }

    item def Concrete {
        attribute aggregateSize : AggregateSize = 20.0;
        attribute slump : Slump = 120.0;
        attribute density : Mass = 2400.0;
    }

    item def HydraulicFluid;
    item def ElectricalEnergy;

    enum def OperatorCommand {
        start;
        stop;
        increaseSpeed;
        decreaseSpeed;
    }

    enum def SystemState {
        stopped;
        priming;
        normalOperation;
        faulted;
        shutdown;
        cleaning;
    }

    port def ConcreteOutPort {
        out item concrete : Concrete;
        attribute flowRate : FlowRate;
    }

    port def ConcreteInPort {
        in item concrete : Concrete;
        attribute flowRate : FlowRate;
    }

    port def HydraulicPowerOutPort {
        out attribute pressure : Pressure;
        out attribute flow : FlowRate;
    }

    port def HydraulicPowerInPort {
        in attribute pressure : Pressure;
        in attribute flow : FlowRate;
    }

    port def ElectricalInPort {
        in attribute voltage : Voltage;
        in attribute current : Current;
    }

    port def CommandInPort {
        in attribute command : OperatorCommand;
        in attribute targetSpeed : RotationalSpeed;
    }

    port def CommandOutPort {
        out attribute command : OperatorCommand;
        out attribute targetSpeed : RotationalSpeed;
    }

    port def PressureSignalOutPort {
        out attribute pressureReading : Pressure;
    }

    port def PressureSignalInPort {
        in attribute pressureReading : Pressure;
    }

    port def FlowSignalOutPort {
        out attribute flowReading : FlowRate;
    }

    port def FlowSignalInPort {
        in attribute flowReading : FlowRate;
    }

    requirement def ConcreteHandlingRequirement {
        doc /* The system shall handle concrete within specified aggregate and slump ranges. */
        subject subsystem : ConcretePumpingSubsystem;
        attribute maxAggregateSize : AggregateSize = 40.0;
        attribute minSlump : Slump = 50.0;
        attribute maxSlump : Slump = 200.0;
        constraint { subsystem.handledConcrete.aggregateSize <= maxAggregateSize }
        constraint { subsystem.handledConcrete.slump >= minSlump }
        constraint { subsystem.handledConcrete.slump <= maxSlump }
    }

    requirement def DeliveryFlowRequirement {
        doc /* The system shall deliver concrete at a minimum flow rate. */
        subject subsystem : ConcretePumpingSubsystem;
        attribute minFlowRate : FlowRate = 0.05;
        constraint { subsystem.deliveredFlowRate >= minFlowRate }
    }

    requirement def SafetyPressureRequirement {
        doc /* The system shall detect and respond to excessive pressure faults. */
        subject subsystem : ConcretePumpingSubsystem;
        attribute maxSafePressure : Pressure = 20000000.0;
        constraint { subsystem.pumpPressure <= maxSafePressure }
    }

    requirement def LifecycleRequirement {
        doc /* The pump shall follow the defined operational lifecycle states. */
        subject subsystem : ConcretePumpingSubsystem;
        constraint { subsystem.pumpState == SystemState::stopped or
                     subsystem.pumpState == SystemState::priming or
                     subsystem.pumpState == SystemState::normalOperation or
                     subsystem.pumpState == SystemState::faulted or
                     subsystem.pumpState == SystemState::shutdown or
                     subsystem.pumpState == SystemState::cleaning }
    }

    part def ConcreteHopper {
        port concreteOut : ConcreteOutPort;
        attribute capacity : Volume = 1.5;
        attribute currentVolume : Volume = 0.0;
        attribute outletFlowRate : FlowRate = 0.06;

        action def DispenseConcrete {
            out item dispensedConcrete : Concrete;
        }

        perform action dispense : DispenseConcrete;
    }

    part def HydraulicPowerPack {
        port electricalIn : ElectricalInPort;
        port hydraulicOut : HydraulicPowerOutPort;
        attribute ratedPower : Power = 90000.0;
        attribute outputPressure : Pressure = 25000000.0;
        attribute outputFlow : FlowRate = 0.001;
        attribute efficiency : Real = 0.85;

        action def ConvertEnergy {
            in electricalEnergy : ElectricalEnergy;
            out hydraulicFluid : HydraulicFluid;
        }

        perform action convert : ConvertEnergy;
    }

    part def ConcretePump {
        port concreteIn : ConcreteInPort;
        port concreteOut : ConcreteOutPort;
        port hydraulicIn : HydraulicPowerInPort;
        port controlIn : CommandInPort;
        port pressureTap : ConcreteOutPort;
        port flowTap : ConcreteOutPort;

        attribute maxPressure : Pressure = 20000000.0;
        attribute nominalFlowRate : FlowRate = 0.06;
        attribute currentSpeed : RotationalSpeed = 0.0;
        attribute targetSpeed : RotationalSpeed = 0.0;
        attribute primingTimer : Duration = 0.0;
        attribute primingDuration : Duration = 10.0;
        attribute cleaningTimer : Duration = 0.0;
        attribute cleaningDuration : Duration = 30.0;
        attribute shutdownTimer : Duration = 0.0;
        attribute shutdownDuration : Duration = 5.0;
        attribute faultDetected : Boolean = false;
        attribute currentState : SystemState = SystemState::stopped;

        action def PumpConcrete {
            in item incomingConcrete : Concrete;
            in hydraulicPressure : Pressure;
            out item pressurizedConcrete : Concrete;
            out outputPressure : Pressure;
            out outputFlowRate : FlowRate;
        }

        perform action pump : PumpConcrete;

        state machine PumpLifecycle {
            state stopped;
            state priming;
            state normalOperation;
            state faulted;
            state shutdown;
            state cleaning;

            transition stopped -> priming
                when controlIn.command == OperatorCommand::start;

            transition priming -> normalOperation
                when primingTimer >= primingDuration;

            transition normalOperation -> faulted
                when faultDetected;

            transition normalOperation -> shutdown
                when controlIn.command == OperatorCommand::stop;

            transition faulted -> shutdown
                when controlIn.command == OperatorCommand::stop;

            transition shutdown -> cleaning
                when shutdownTimer >= shutdownDuration;

            transition cleaning -> stopped
                when cleaningTimer >= cleaningDuration;
        }
    }

    part def DeliveryHose {
        port concreteIn : ConcreteInPort;
        port concreteOut : ConcreteOutPort;
        attribute length : Length = 30.0;
        attribute diameter : Length = 0.125;
        attribute maxPressure : Pressure = 15000000.0;
        attribute pressureDrop : Pressure = 1000000.0;
    }

    part def DischargePoint {
        port concreteIn : ConcreteInPort;
        attribute location : String = "Foundation";
        attribute totalDelivered : Volume = 0.0;
    }

    part def PumpController {
        port operatorCommand : CommandInPort;
        port pumpControl : CommandOutPort;
        port pressureInput : PressureSignalInPort;
        port flowInput : FlowSignalInPort;

        attribute targetSpeed : RotationalSpeed = 0.0;
        attribute maxSafePressure : Pressure = 18000000.0;
        attribute faultDetected : Boolean = false;

        action def MonitorAndControl {
            in pressureReading : Pressure;
            in flowReading : FlowRate;
            in operatorCmd : OperatorCommand;
            out pumpCmd : OperatorCommand;
            out newTargetSpeed : RotationalSpeed;
            out faultFlag : Boolean;
        }

        perform action monitor : MonitorAndControl;
    }

    part def PressureSensor {
        port sensingPort : ConcreteInPort;
        port signalOut : PressureSignalOutPort;
        attribute maxRange : Pressure = 25000000.0;
        attribute accuracy : Real = 0.01;

        action def MeasurePressure {
            in item concrete : Concrete;
            out pressureReading : Pressure;
        }

        perform action measure : MeasurePressure;
    }

    part def FlowSensor {
        port sensingPort : ConcreteInPort;
        port signalOut : FlowSignalOutPort;
        attribute maxRange : FlowRate = 0.2;
        attribute accuracy : Real = 0.02;

        action def MeasureFlow {
            in item concrete : Concrete;
            out flowReading : FlowRate;
        }

        perform action measure : MeasureFlow;
    }

    part def ConcretePumpingSubsystem {
        part hopper : ConcreteHopper;
        part pump : ConcretePump;
        part powerPack : HydraulicPowerPack;
        part hose : DeliveryHose;
        part discharge : DischargePoint;
        part controller : PumpController;
        part pressureSensor : PressureSensor;
        part flowSensor : FlowSensor;

        attribute handledConcrete : Concrete;
        attribute deliveredFlowRate : FlowRate = 0.06;
        attribute pumpPressure : Pressure = 0.0;
        attribute pumpState : SystemState = SystemState::stopped;

        port externalPower : ElectricalInPort;
        port operatorInterface : CommandInPort;

        connection powerPack.electricalIn to externalPower;
        connection operatorInterface to controller.operatorCommand;
        connection hopper.concreteOut to pump.concreteIn;
        connection powerPack.hydraulicOut to pump.hydraulicIn;
        connection pump.concreteOut to hose.concreteIn;
        connection hose.concreteOut to discharge.concreteIn;
        connection controller.pumpControl to pump.controlIn;
        connection pump.pressureTap to pressureSensor.sensingPort;
        connection pump.flowTap to flowSensor.sensingPort;
        connection pressureSensor.signalOut to controller.pressureInput;
        connection flowSensor.signalOut to controller.flowInput;

        satisfy ConcreteHandlingRequirement;
        satisfy DeliveryFlowRequirement;
        satisfy SafetyPressureRequirement;
        satisfy LifecycleRequirement;
    }
}
