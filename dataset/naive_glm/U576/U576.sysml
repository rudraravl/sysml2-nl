package ClosedLoopHydraulicPowerSystem {

    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value def Pressure :> Real { unit 'Pa'; }
    value def FlowRate :> Real { unit 'm3/s'; }
    value def Volume :> Real { unit 'm3'; }
    value def RotationalSpeed :> Real { unit 'rad/s'; }
    value def Displacement :> Real { unit 'm3/rev'; }
    value def Force :> Real { unit 'N'; }
    value def Length :> Real { unit 'm'; }
    value def Area :> Real { unit 'm2'; }
    value def ControlSignal :> Real { unit '1'; }

    // ===== Items =====
    item def HydraulicFluid;

    // ===== Port Definitions =====
    port def FluidPort {
        in item fluid : HydraulicFluid [0..*];
        attr pressure : Pressure;
        attr flowRate : FlowRate;
    }

    port def PressureSignalPort {
        attr value : Pressure;
    }

    port def FlowSignalPort {
        attr value : FlowRate;
    }

    port def CommandPort {
        attr value : ControlSignal;
    }

    port def MechanicalPort {
        attr force : Force;
        attr position : Length;
    }

    // ===== Component Definitions =====

    part def Reservoir {
        out port supplyPort : FluidPort;
        in port returnPort : FluidPort;
        attr capacity : Volume = 0.05 [m3];
        attr ambientPressure : Pressure = 101325 [Pa];
        attr fluidLevel : Volume = 0.04 [m3];
    }

    part def SupplyFilter {
        in port inlet : FluidPort;
        out port outlet : FluidPort;
        attr filtrationRating : Real = 10;
        attr pressureDrop : Pressure = 20000 [Pa];
    }

    part def CheckValve {
        in port inlet : FluidPort;
        out port outlet : FluidPort;
        attr crackingPressure : Pressure = 5000 [Pa];
        attr isOpen : Boolean = false;
    }

    part def VariableDisplacementPump {
        in port inlet : FluidPort;
        out port outlet : FluidPort;
        in port command : CommandPort;
        attr maxDisplacement : Displacement = 5e-6 [m3/rev];
        attr currentDisplacement : Displacement = 0 [m3/rev];
        attr rotationalSpeed : RotationalSpeed = 150 [rad/s];
        attr safePressureLimit : Pressure = 30e6 [Pa];
        attr isFaulted : Boolean = false;

        state operatingState {
            state stopped;
            state starting;
            state running;
            state faulted;

            transition stopped -> starting
                when command.value > 0;
            transition starting -> running
                after 2 [s];
            transition running -> faulted
                when outlet.pressure > safePressureLimit;
            transition running -> stopped
                when command.value == 0;
            transition faulted -> stopped
                when command.value == 0;
        }
    }

    part def HydraulicActuator {
        in port inlet : FluidPort;
        out port outlet : FluidPort;
        out port mechanicalOutput : MechanicalPort;
        attr pistonArea : Area = 0.005 [m2];
        attr stroke : Length = 0.3 [m];
        attr currentPosition : Length = 0 [m];
        attr extending : Boolean = true;
    }

    part def ReturnFilter {
        in port inlet : FluidPort;
        out port outlet : FluidPort;
        attr filtrationRating : Real = 10;
        attr pressureDrop : Pressure = 20000 [Pa];
    }

    part def PressureReliefValve {
        in port inlet : FluidPort;
        out port outlet : FluidPort;
        attr reliefPressure : Pressure = 28e6 [Pa];
        attr isOpen : Boolean = false;
    }

    part def PressureSensor {
        in port measuredPort : FluidPort;
        out port signal : PressureSignalPort;
        attr accuracy : Pressure = 1000 [Pa];
    }

    part def FlowSensor {
        in port measuredPort : FluidPort;
        out port signal : FlowSignalPort;
        attr accuracy : FlowRate = 1e-6 [m3/s];
    }

    part def DisplacementController {
        in port pressureFeedback : PressureSignalPort;
        in port flowFeedback : FlowSignalPort;
        out port pumpCommand : CommandPort;
        attr targetPressure : Pressure = 20e6 [Pa];
        attr targetFlowRate : FlowRate = 1e-3 [m3/s];
        attr kp : Real = 1e-8;
        attr ki : Real = 1e-9;
        attr integralError : Real = 0;

        action computeCommand {
            in pressureActual : Pressure;
            in flowActual : FlowRate;
            out command : ControlSignal;

            action computePressureError {
                in target : Pressure;
                in actual : Pressure;
                out error : Pressure;
            }

            action computeFlowError {
                in target : FlowRate;
                in actual : FlowRate;
                out error : FlowRate;
            }

            action pidCompute {
                in pressureError : Pressure;
                in flowError : FlowRate;
                out cmd : ControlSignal;
            }

            flow computePressureError.out -> pidCompute.in;
            flow computeFlowError.out -> pidCompute.in;
        }
    }

    // ===== System Assembly =====

    part def ClosedLoopHydraulicPowerSystem {
        part reservoir : Reservoir;
        part supplyFilter : SupplyFilter;
        part checkValve : CheckValve;
        part pump : VariableDisplacementPump;
        part actuator : HydraulicActuator;
        part returnFilter : ReturnFilter;
        part reliefValve : PressureReliefValve;
        part pressureSensor : PressureSensor;
        part flowSensor : FlowSensor;
        part controller : DisplacementController;

        // Supply path: reservoir -> filter -> check valve -> pump
        connection reservoir.supplyPort to supplyFilter.inlet;
        connection supplyFilter.outlet to checkValve.inlet;
        connection checkValve.outlet to pump.inlet;

        // High-pressure path: pump -> actuator
        connection pump.outlet to actuator.inlet;

        // Return path: actuator -> filter -> reservoir
        connection actuator.outlet to returnFilter.inlet;
        connection returnFilter.outlet to reservoir.returnPort;

        // Relief valve branch: pump outlet -> relief -> reservoir
        connection pump.outlet to reliefValve.inlet;
        connection reliefValve.outlet to reservoir.returnPort;

        // Sensor taps at pump outlet
        connection pump.outlet to pressureSensor.measuredPort;
        connection pump.outlet to flowSensor.measuredPort;

        // Feedback signals to controller
        connection pressureSensor.signal to controller.pressureFeedback;
        connection flowSensor.signal to controller.flowFeedback;

        // Command signal to pump
        connection controller.pumpCommand to pump.command;
    }

    // ===== Requirements =====

    requirement def PressureControlRequirement {
        subject system : ClosedLoopHydraulicPowerSystem;
        attribute targetPressure : Pressure = 20e6 [Pa];
        attribute tolerance : Pressure = 500000 [Pa];
        require system.controller.targetPressure == targetPressure;
        require system.pump.outlet.pressure >= targetPressure - tolerance;
        require system.pump.outlet.pressure <= targetPressure + tolerance;
    }

    requirement def FlowControlRequirement {
        subject system : ClosedLoopHydraulicPowerSystem;
        attribute targetFlow : FlowRate = 1e-3 [m3/s];
        attribute tolerance : FlowRate = 5e-5 [m3/s];
        require system.controller.targetFlowRate == targetFlow;
        require system.pump.outlet.flowRate >= targetFlow - tolerance;
        require system.pump.outlet.flowRate <= targetFlow + tolerance;
    }

    requirement def SafetyRequirement {
        subject system : ClosedLoopHydraulicPowerSystem;
        attribute maxSafePressure : Pressure = 30e6 [Pa];
        require system.reliefValve.reliefPressure < maxSafePressure;
        require system.pump.safePressureLimit <= maxSafePressure;
        require system.pump.isFaulted == false;
    }

    requirement def UnidirectionalFlowRequirement {
        subject system : ClosedLoopHydraulicPowerSystem;
        require system.checkValve.isOpen == true;
    }

    requirement def FiltrationRequirement {
        subject system : ClosedLoopHydraulicPowerSystem;
        attribute maxParticleSize : Real = 15;
        require system.supplyFilter.filtrationRating <= maxParticleSize;
        require system.returnFilter.filtrationRating <= maxParticleSize;
    }

    requirement def PumpStateRequirement {
        subject pump : VariableDisplacementPump;
        require pump.command.value >= 0;
        require pump.command.value <= 1;
        require pump.currentDisplacement >= 0 [m3/rev];
        require pump.currentDisplacement <= pump.maxDisplacement;
    }

    requirement def ClosedLoopControlRequirement {
        subject system : ClosedLoopHydraulicPowerSystem;
        require system.controller.pumpCommand.value >= 0;
        require system.controller.pumpCommand.value <= 1;
        require system.pressureSensor.signal.value == system.pump.outlet.pressure;
        require system.flowSensor.signal.value == system.pump.outlet.flowRate;
    }

    requirement def CircuitIntegrityRequirement {
        subject system : ClosedLoopHydraulicPowerSystem;
        require system.reservoir.supplyPort.pressure == system.reservoir.ambientPressure;
        require system.reservoir.returnPort.pressure == system.reservoir.ambientPressure;
    }

}
