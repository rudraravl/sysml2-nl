package HydraulicPowerUnitModel {
    // Value Types
    value def Pressure = Real { unit 'Pa'; }
    value def Temperature = Real { unit 'K'; }
    value def FlowRate = Real { unit 'm3/s'; }
    value def Voltage = Real { unit 'V'; }
    value def Current = Real { unit 'A'; }
    value def RotationalSpeed = Real { unit 'rad/s'; }
    value def Volume = Real { unit 'm3'; }

    // Items
    item def HydraulicFluid;
    item def ElectricalPower;
    item def ControlSignal;
    item def StartCommand;
    item def StopCommand;

    // Ports
    port def FluidPort {
        in item fluid: HydraulicFluid;
        attr pressure: Pressure;
        attr flowRate: FlowRate;
    }
    port def ElecPort {
        in item power: ElectricalPower;
        attr voltage: Voltage;
        attr current: Current;
    }
    port def MechPort {
        attr speed: RotationalSpeed;
    }
    port def SignalOutPort {
        out item signal: ControlSignal;
        attr value: Real;
    }

    // Parts
    part def Reservoir {
        attr capacity: Volume;
        port fluidOut: FluidPort;
        port fluidReturn: FluidPort;
    }

    part def ElectricMotor {
        attr phaseCount: Integer = 3;
        port powerIn: ElecPort;
        port shaftOut: MechPort;
    }

    part def RotaryVanePump {
        attr displacement: FlowRate;
        attr eccentricity: Real;
        attr vaneMaterial: String = "Carbon Composite";
        port fluidIn: FluidPort;
        port fluidOut: FluidPort;
        port shaftIn: MechPort;
    }

    part def CheckValve {
        port fluidIn: FluidPort;
        port fluidOut: FluidPort;
    }

    part def InletFilter {
        attr filtrationRating: Real;
        port fluidIn: FluidPort;
        port fluidOut: FluidPort;
    }

    part def OutletFilter {
        attr filtrationRating: Real;
        port fluidIn: FluidPort;
        port fluidOut: FluidPort;
    }

    part def PressureReliefValve {
        attr threshold: Pressure = 20000000;
        port fluidIn: FluidPort;
        port fluidOut: FluidPort;
    }

    part def PressureSensor {
        port fluidIn: FluidPort;
        port signalOut: SignalOutPort;
    }

    part def TemperatureSensor {
        port fluidIn: FluidPort;
        port signalOut: SignalOutPort;
    }

    part def FlowMeter {
        port fluidIn: FluidPort;
        port fluidOut: FluidPort;
        port signalOut: SignalOutPort;
    }

    part def HydraulicPowerUnit {
        port powerIn: ElecPort;
        port fluidOut: FluidPort;
        port controlOut: SignalOutPort;

        part reservoir: Reservoir;
        part motor: ElectricMotor;
        part pump: RotaryVanePump;
        part checkValve: CheckValve;
        part inletFilter: InletFilter;
        part outletFilter: OutletFilter;
        part reliefValve: PressureReliefValve;
        part inletPressureSensor: PressureSensor;
        part dischargePressureSensor: PressureSensor;
        part tempSensor: TemperatureSensor;
        part flowMeter: FlowMeter;

        // Connections
        connect powerIn to motor.powerIn;
        connect motor.shaftOut to pump.shaftIn;
        
        connect reservoir.fluidOut to checkValve.fluidIn;
        connect checkValve.fluidOut to inletFilter.fluidIn;
        connect inletFilter.fluidOut to inletPressureSensor.fluidIn;
        connect inletPressureSensor.fluidIn to pump.fluidIn;
        
        connect pump.fluidOut to reliefValve.fluidIn;
        connect reliefValve.fluidOut to reservoir.fluidReturn;
        
        connect pump.fluidOut to outletFilter.fluidIn;
        connect outletFilter.fluidOut to dischargePressureSensor.fluidIn;
        connect dischargePressureSensor.fluidIn to tempSensor.fluidIn;
        connect tempSensor.fluidIn to flowMeter.fluidIn;
        connect flowMeter.fluidOut to fluidOut;

        // Behaviors
        state def HPUStates {
            entry; then Idle;
            state Idle;
            state Priming;
            state Running;
            state ShuttingDown;
            
            state Fault {
                state HighPressureFault;
                state LowFlowFault;
                state OverheatingFault;
                state CavitationFault;
                state MotorOverloadFault;
                state MechanicalDamageFault;
            }
            
            transition t_Idle_to_Priming
                first Idle
                accept StartCommand
                then Priming;
                
            transition t_Priming_to_Running
                from Priming
                if inletPressureSensor.signalOut.value > 0
                then Running;
                
            transition t_Running_to_ShuttingDown
                from Running
                accept StopCommand
                then ShuttingDown;
                
            transition t_ShuttingDown_to_Idle
                from ShuttingDown
                if flowMeter.signalOut.value == 0
                then Idle;
                
            transition t_Running_to_HighPressureFault
                from Running
                if dischargePressureSensor.signalOut.value > 20000000
                then Fault::HighPressureFault;
                
            transition t_Running_to_LowFlowFault
                from Running
                if flowMeter.signalOut.value < 0.001
                then Fault::LowFlowFault;
                
            transition t_Running_to_OverheatingFault
                from Running
                if tempSensor.signalOut.value > 350
                then Fault::OverheatingFault;
                
            transition t_Running_to_CavitationFault
                from Running
                if inletPressureSensor.signalOut.value < 50000
                then Fault::CavitationFault;
                
            transition t_Running_to_MotorOverloadFault
                from Running
                if powerIn.current > 50
                then Fault::MotorOverloadFault;
                
            transition t_Running_to_MechanicalDamageFault
                from Running
                if pump.shaftIn.speed < 100
                then Fault::MechanicalDamageFault;
                
            transition t_Fault_to_ShuttingDown
                from Fault
                then ShuttingDown;
        }
        
        exhibit HPUStates;
    }

    // Requirements
    requirement def PressurizeFluid {
        subject hpu: HydraulicPowerUnit;
        objective: "The HPU shall deliver hydraulic fluid at a pressure of at least 15 MPa.";
    }
    
    requirement def PreventOverpressure {
        subject hpu: HydraulicPowerUnit;
        objective: "The HPU shall prevent system pressure from exceeding 20 MPa via a relief valve.";
    }
    
    requirement def MonitorSystem {
        subject hpu: HydraulicPowerUnit;
        objective: "The HPU shall monitor inlet pressure, discharge pressure, temperature, and flow rate.";
    }
}
