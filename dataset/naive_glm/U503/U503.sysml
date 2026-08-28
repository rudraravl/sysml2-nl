package PumpingSubsystem {
    import ScalarValues::*;
    import ISQ::*;
    import Quantities::Quantity;
    
    // ---- Value Types with Units ----
    value type Voltage :> Real { unit "V"; }
    value type Current :> Real { unit "A"; }
    value type Pressure :> Real { unit "kPa"; }
    value type FlowRate :> Real { unit "L/min"; }
    value type Temperature :> Real { unit "degC"; }
    value type RotationalSpeed :> Real { unit "rpm"; }
    value type Power :> Real { unit "W"; }
    value type Duration :> Real { unit "s"; }
    
    // ---- Item Types ----
    item def Fuel;
    item def ElectricalPower {
        value voltage : Voltage;
        value current : Current;
    }
    item def ControlSignal {
        value command : String;
        value setpoint : FlowRate;
    }
    item def SensorReading {
        value measuredValue : Real;
        value unit : String;
        value valid : Boolean;
    }
    item def FaultEvent {
        value faultType : String;
        value timestamp : Duration;
    }
    
    // ---- Attribute Definitions ----
    attribute def SafePressureLimit { value limit : Pressure = 650 [kPa]; }
    attribute def OperatingPressureLimit { value limit : Pressure = 600 [kPa]; }
    attribute def TargetFlowRate { value target : FlowRate = 150 [L/min]; }
    attribute def MaxOperatingTemp { value limit : Temperature = 85 [degC]; }
    attribute def SupplyVoltage { value nominal : Voltage = 24 [V]; }
    
    // ---- Port Definitions ----
    port def FluidPort {
        out item fuel : Fuel;
        in value pressure : Pressure;
        in value flow : FlowRate;
    }
    port def ElectricalPort {
        out item power : ElectricalPower;
    }
    port def ControlPort {
        out item signal : ControlSignal;
        in item reading : SensorReading;
    }
    port def SensorPort {
        out item reading : SensorReading;
    }
    
    // ---- Requirements ----
    requirement def PumpingRequirement {
        subject pumpSystem : PumpingSubsystem;
        objective {
            doc "The pumping subsystem shall transfer fuel from a supply tank to a receiving vessel at a controlled flow rate."
        }
    }
    
    requirement def FlowRateRequirement :> PumpingRequirement {
        doc "The pump shall deliver fuel at a target flow rate of 150 L/min."
        constraint { pumpSystem.deliveredFlow == 150 [L/min] }
    }
    
    requirement def PressureRequirement :> PumpingRequirement {
        doc "The pump shall handle pressures up to 600 kPa during normal operation."
        constraint { pumpSystem.outletPressure <= 600 [kPa] }
    }
    
    requirement def ReliefValveRequirement :> PumpingRequirement {
        doc "A relief valve shall open automatically when system pressure exceeds 650 kPa."
        constraint { pumpSystem.reliefValveOpen implies pumpSystem.outletPressure > 650 [kPa] }
    }
    
    requirement def SafetyRequirement :> PumpingRequirement {
        doc "The pump shall enter a faulted state on over-pressure, over-temperature, or cavitation and require manual reset."
    }
    
    requirement def MotorVoltageRequirement :> PumpingRequirement {
        doc "The pump motor shall operate on 24V DC electrical supply."
        constraint { pumpSystem.motorVoltage == 24 [V] }
    }
    
    // ---- Part Definitions ----
    part def SupplyTank {
        port fluidOut : FluidPort;
        attribute fuelLevel : Volume;
    }
    
    part def ReceivingVessel {
        port fluidIn : FluidPort;
        attribute capacity : Volume;
    }
    
    part def CheckValve {
        attribute name : String;
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute crackingPressure : Pressure = 5 [kPa];
        attribute isOpen : Boolean;
        
        action def CheckFlow {
            in fuelIn : Fuel;
            out fuelOut : Fuel;
            if fuelIn != null then {
                if pressure > crackingPressure then { isOpen = true; } else { isOpen = false; }
            }
        }
    }
    
    part def ReliefValve {
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute setPressure : Pressure = 650 [kPa];
        attribute isOpen : Boolean = false;
        
        action def MonitorPressure {
            in currentPressure : Pressure;
            if currentPressure > setPressure then { isOpen = true; }
            else if currentPressure < (setPressure - 20 [kPa]) then { isOpen = false; }
        }
    }
    
    part def PressureSensor {
        attribute name : String;
        port sensorOut : SensorPort;
        port fluidConnection : FluidPort;
        attribute range : Pressure = 0..1000 [kPa];
        attribute accuracy : Real = 0.5; // percent
        attribute calibrated : Boolean = true;
        
        action def MeasurePressure :> SensorReading {
            out reading : SensorReading;
        }
    }
    
    part def FlowMeter {
        port sensorOut : SensorPort;
        port fluidConnection : FluidPort;
        attribute range : FlowRate = 0..300 [L/min];
        attribute accuracy : Real = 1.0;
        
        action def MeasureFlow :> SensorReading {
            out reading : SensorReading;
        }
    }
    
    part def TemperatureSensor {
        port sensorOut : SensorPort;
        port fluidConnection : FluidPort;
        attribute range : Temperature = -40..150 [degC];
        attribute accuracy : Real = 0.5;
        
        action def MeasureTemperature :> SensorReading {
            out reading : SensorReading;
        }
    }
    
    part def ElectricMotor {
        port electricalIn : ElectricalPort;
        port mechanicalOut;
        attribute nominalVoltage : Voltage = 24 [V];
        attribute nominalCurrent : Current = 30 [A];
        attribute ratedPower : Power = 500 [W];
        attribute maxSpeed : RotationalSpeed = 4000 [rpm];
        attribute currentSpeed : RotationalSpeed;
        attribute enabled : Boolean;
        
        action def Drive {
            in power : ElectricalPower;
            out torque;
            if enabled then { currentSpeed = maxSpeed * (power.voltage / nominalVoltage); }
        }
    }
    
    part def FuelPump {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port mechanicalIn;
        attribute ratedFlow : FlowRate = 150 [L/min];
        attribute ratedPressure : Pressure = 600 [kPa];
        attribute currentFlow : FlowRate;
        attribute currentPressure : Pressure;
        attribute currentTemp : Temperature;
        
        action def PumpFluid {
            in fuelIn : Fuel;
            in torque;
            out fuelOut : Fuel;
            currentFlow = ratedFlow;
            currentPressure = ratedPressure;
        }
    }
    
    part def PumpController {
        port controlOut : ControlPort;
        port sensorIn1 : SensorPort; // inlet pressure
        port sensorIn2 : SensorPort; // outlet pressure
        port sensorIn3 : SensorPort; // flow
        port sensorIn4 : SensorPort; // temperature
        port motorControl;
        
        attribute targetFlow : FlowRate = 150 [L/min];
        attribute maxPressure : Pressure = 600 [kPa];
        attribute maxTemp : Temperature = 85 [degC];
        attribute manualResetRequired : Boolean = false;
        attribute faultActive : Boolean = false;
        
        // State Machine
        state def PumpControllerStates {
            entry; then idle;
            
            state idle {
                entry { doc "Pump is off, awaiting start command."; }
                accept StartCommand then starting;
            }
            
            state starting {
                entry { doc "Energizing motor and initializing."; }
                do { send MotorEnable; }
                then priming;
            }
            
            state priming {
                entry { doc "Priming pump to establish flow."; }
                do { monitorPrime(); }
                accept PrimeComplete then running;
                accept FaultDetected then faulted;
            }
            
            state running {
                entry { doc "Normal operation, regulating flow."; }
                do { regulateFlow(); }
                accept StopCommand then idle;
                accept FaultDetected then faulted;
            }
            
            state faulted {
                entry { doc "Safe state, requires manual reset."; }
                do { disableMotor(); }
                accept ManualReset then idle;
            }
        }
        
        action def regulateFlow {
            in inletPressure : Pressure;
            in outletPressure : Pressure;
            in flow : FlowRate;
            in temp : Temperature;
            out motorCommand : ControlSignal;
            
            // Check fault conditions
            if outletPressure > 650 [kPa] then { faultActive = true; }
            if temp > 85 [degC] then { faultActive = true; }
            if flow < 10 [L/min] and outletPressure < 50 [kPa] then { faultActive = true; } // cavitation
            
            // PID-like adjustment
            if not faultActive then {
                if flow < targetFlow then { motorCommand.setpoint = targetFlow; }
                else if flow > targetFlow then { motorCommand.setpoint = targetFlow; }
            }
        }
        
        action def monitorPrime {
            in inletPressure : Pressure;
            in flow : FlowRate;
            if inletPressure > 20 [kPa] and flow > 5 [L/min] then { send PrimeComplete; }
        }
        
        action def disableMotor {
            send MotorDisable;
        }
    }
    
    // ---- Main System ----
    part def PumpingSubsystem {
        // Requirements satisfaction
        satisfy FlowRateRequirement by pump;
        satisfy PressureRequirement by pump;
        satisfy ReliefValveRequirement by reliefValve;
        satisfy SafetyRequirement by controller;
        satisfy MotorVoltageRequirement by motor;
        
        // Ports
        port supplyConnection : FluidPort;
        port deliveryConnection : FluidPort;
        port powerInput : ElectricalPort;
        port commandInput : ControlPort;
        
        // Attributes
        attribute deliveredFlow : FlowRate;
        attribute outletPressure : Pressure;
        attribute motorVoltage : Voltage = 24 [V];
        attribute reliefValveOpen : Boolean;
        
        // Parts
        part supplyTank : SupplyTank {
            attribute fuelLevel : Volume = 200 [L];
        }
        
        part inletCheckValve : CheckValve {
            attribute name = "InletCheckValve";
            attribute crackingPressure : Pressure = 5 [kPa];
        }
        
        part inletPressureSensor : PressureSensor {
            attribute name = "InletPressureSensor";
        }
        
        part pump : FuelPump {
            attribute ratedFlow : FlowRate = 150 [L/min];
            attribute ratedPressure : Pressure = 600 [kPa];
        }
        
        part motor : ElectricMotor {
            attribute nominalVoltage : Voltage = 24 [V];
            attribute ratedPower : Power = 500 [W];
        }
        
        part outletPressureSensor : PressureSensor {
            attribute name = "OutletPressureSensor";
        }
        
        part flowMeter : FlowMeter {
            attribute range : FlowRate = 0..300 [L/min];
        }
        
        part temperatureSensor : TemperatureSensor {
            attribute range : Temperature = -40..150 [degC];
        }
        
        part reliefValve : ReliefValve {
            attribute setPressure : Pressure = 650 [kPa];
        }
        
        part outletCheckValve : CheckValve {
            attribute name = "OutletCheckValve";
            attribute crackingPressure : Pressure = 5 [kPa];
        }
        
        part receivingVessel : ReceivingVessel {
            attribute capacity : Volume = 500 [L];
        }
        
        part controller : PumpController {
            attribute targetFlow : FlowRate = 150 [L/min];
            attribute maxPressure : Pressure = 600 [kPa];
            attribute maxTemp : Temperature = 85 [degC];
        }
        
        // Connections - Fluid Path
        connection supplyToInletCheck : FluidPort connect supplyTank.fluidOut to inletCheckValve.inlet;
        connection inletCheckToPump : FluidPort connect inletCheckValve.outlet to pump.fluidIn;
        connection pumpToOutletCheck : FluidPort connect pump.fluidOut to outletCheckValve.inlet;
        connection outletCheckToFlowMeter : FluidPort connect outletCheckValve.outlet to flowMeter.fluidConnection;
        connection flowMeterToRelief : FluidPort connect flowMeter.fluidConnection to reliefValve.inlet;
        connection reliefToDelivery : FluidPort connect reliefValve.outlet to deliveryConnection;
        connection deliveryToVessel : FluidPort connect deliveryConnection to receivingVessel.fluidIn;
        
        // Connections - Sensor taps
        connection inletPressureTap : FluidPort connect inletCheckValve.outlet to inletPressureSensor.fluidConnection;
        connection outletPressureTap : FluidPort connect pump.fluidOut to outletPressureSensor.fluidConnection;
        connection tempSensorTap : FluidPort connect pump.fluidOut to temperatureSensor.fluidConnection;
        
        // Connections - Sensor to Controller
        connection inletPressureToController : SensorPort connect inletPressureSensor.sensorOut to controller.sensorIn1;
        connection outletPressureToController : SensorPort connect outletPressureSensor.sensorOut to controller.sensorIn2;
        connection flowToController : SensorPort connect flowMeter.sensorOut to controller.sensorIn3;
        connection tempToController : SensorPort connect temperatureSensor.sensorOut to controller.sensorIn4;
        
        // Connections - Electrical
        connection powerToMotor : ElectricalPort connect powerInput to motor.electricalIn;
        
        // Connections - Mechanical
        connection motorToPump connect motor.mechanicalOut to pump.mechanicalIn;
        
        // Connections - Control
        connection controllerToMotor connect controller.motorControl to motor;
        connection commandToController : ControlPort connect commandInput to controller.controlOut;
        
        // Behavior
        behavior stateMachine : PumpControllerStates {
            // Instantiates the controller state behavior
        }
        
        // Allocation
        allocate controller.stateMachine to controller;
    }
}
