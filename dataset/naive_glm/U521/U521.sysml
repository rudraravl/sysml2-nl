package PrecisionFluidPumpingSubsystem {
    public import ISQ::*;
    
    // ===== Value Types =====
    value type Voltage :> Real { unit 'V'; }
    value type Frequency :> Real { unit 'Hz'; }
    value type FlowRate :> Real { unit 'mL/min'; }
    value type Pressure :> Real { unit 'kPa'; }
    value type Volume :> Real { unit 'mL'; }
    value type Temperature :> Real { unit 'degC'; }
    value type Dimension :> Real { unit 'mm'; }
    
    // ===== Item Types =====
    item def Liquid {
        attribute density : Real = 1.0;
        attribute viscosity : Real = 1.0;
    }
    
    item def ControlSignal {
        attribute voltage : Voltage;
        attribute frequency : Frequency;
    }
    
    item def SensorReading {
        attribute flowRate : FlowRate;
        attribute pressure : Pressure;
    }
    
    // ===== Port Definitions =====
    port def FluidPort {
        attribute pressure : Pressure;
        flow of liquid : Liquid;
    }
    
    port def ControlPort {
        out signal : ControlSignal;
    }
    
    port def SensorPort {
        out reading : SensorReading;
    }
    
    port def CommandPort {
        in command : CommandKind;
    }
    
    enum def CommandKind { START; STOP; EMERGENCY_STOP; RESET; }
    
    // ===== Requirements =====
    requirement def PumpingRequirement {
        subject pump : ImpedancePump;
        requirement {
            /* The pump shall transfer liquid from source to destination at a controlled rate. */
        }
    }
    
    requirement def ClosedLoopControlRequirement {
        subject controller : PumpController;
        attribute targetFlow : FlowRate;
        attribute tolerance : FlowRate = 0.5 [mL/min];
        requirement {
            /* The controller shall adjust actuator voltage and frequency to maintain target flow within tolerance. */
        }
    }
    
    requirement def SafetyRequirement {
        subject system : PumpingSubsystem;
        requirement {
            /* The system shall support emergency stop and reset procedures. */
        }
    }
    
    // ===== Parts =====
    part def SourceReservoir {
        attribute capacity : Volume = 500 [mL];
        attribute currentVolume : Volume;
        port fluidOut : FluidPort;
        
        action def dispenseFluid {
            in amount : Volume;
            out dispensed : Liquid;
        }
    }
    
    part def DestinationReceiver {
        attribute capacity : Volume = 500 [mL];
        attribute currentVolume : Volume;
        port fluidIn : FluidPort;
        
        action def receiveFluid {
            in received : Liquid;
        }
    }
    
    part def CheckValve {
        attribute isOpen : Boolean;
        port inlet : FluidPort;
        port outlet : FluidPort;
        
        action def regulateFlow {
            in flowIn : Liquid;
            out flowOut : Liquid;
            if flowIn != null {
                isOpen = true;
                flowOut = flowIn;
            } else {
                isOpen = false;
                flowOut = null;
            }
        }
    }
    
    part def PiezoelectricActuator {
        attribute maxVoltage : Voltage = 200 [V];
        attribute maxFrequency : Frequency = 1000 [Hz];
        attribute currentVoltage : Voltage;
        attribute currentFrequency : Frequency;
        port controlIn : ControlPort;
        
        action def vibrate {
            in voltage : Voltage;
            in frequency : Frequency;
            currentVoltage = voltage;
            currentFrequency = frequency;
        }
    }
    
    part def FlexibleMembrane {
        attribute thickness : Dimension = 0.5 [mm];
        attribute displacement : Dimension;
        port actuationSide;
        port chamberSide;
        
        action def oscillate {
            in amplitude : Dimension;
            displacement = amplitude;
        }
    }
    
    part def PumpChamber {
        attribute volume : Volume = 2 [mL];
        attribute currentVolume : Volume;
        port membraneSide;
        port inletSide : FluidPort;
        port outletSide : FluidPort;
        
        action def expand {
            out drawnFluid : Liquid;
        }
        
        action def contract {
            out pushedFluid : Liquid;
        }
    }
    
    part def ImpedancePump {
        part actuator : PiezoelectricActuator;
        part membrane : FlexibleMembrane;
        part chamber : PumpChamber;
        part inletValve : CheckValve;
        part outletValve : CheckValve;
        
        port fluidInlet : FluidPort;
        port fluidOutlet : FluidPort;
        port controlInput : ControlPort;
        
        connection actuatorToMembrane connect actuator.controlSide to membrane.actuationSide;
        connection membraneToChamber connect membrane.chamberSide to chamber.membraneSide;
        connection inletToChamber connect fluidInlet to inletValve.inlet;
        connection inletValveToChamber connect inletValve.outlet to chamber.inletSide;
        connection chamberToOutletValve connect chamber.outletSide to outletValve.inlet;
        connection outletValveToPort connect outletValve.outlet to fluidOutlet;
        
        action def pumpCycle {
            in control : ControlSignal;
            out pumpedFluid : Liquid;
            then actuator.vibrate(control.voltage, control.frequency);
            then membrane.oscillate(actuator.currentVoltage / 100 [V] * 0.1 [mm]);
            then chamber.expand();
            then chamber.contract();
        }
    }
    
    part def PressureSensor {
        attribute measuredPressure : Pressure;
        port fluidConnection : FluidPort;
        port sensorOut : SensorPort;
        
        action def measurePressure {
            in fluid : Liquid;
            out reading : Pressure;
            measuredPressure = fluidConnection.pressure;
            reading = measuredPressure;
        }
    }
    
    part def FlowSensor {
        attribute measuredFlowRate : FlowRate;
        port fluidConnection : FluidPort;
        port sensorOut : SensorPort;
        
        action def measureFlow {
            in fluid : Liquid;
            out reading : FlowRate;
            measuredFlowRate = fluidConnection.pressure * 0.1 [mL/min/kPa];
            reading = measuredFlowRate;
        }
    }
    
    part def PumpController {
        attribute targetFlowRate : FlowRate = 50 [mL/min];
        attribute actualFlowRate : FlowRate;
        attribute actualPressure : Pressure;
        attribute tolerance : FlowRate = 2 [mL/min];
        attribute outputVoltage : Voltage = 100 [V];
        attribute outputFrequency : Frequency = 500 [Hz];
        
        port sensorInput : SensorPort;
        port controlOutput : ControlPort;
        port commandInput : CommandPort;
        
        action def computeControl {
            in target : FlowRate;
            in measured : FlowRate;
            out voltage : Voltage;
            out frequency : Frequency;
            local error : FlowRate = target - measured;
            if error > tolerance {
                voltage = outputVoltage + 5 [V];
                frequency = outputFrequency + 10 [Hz];
            } else if error < -tolerance {
                voltage = outputVoltage - 5 [V];
                frequency = outputFrequency - 10 [Hz];
            } else {
                voltage = outputVoltage;
                frequency = outputFrequency;
            }
        }
        
        action def monitorAndAdjust {
            in reading : SensorReading;
            actualFlowRate = reading.flowRate;
            actualPressure = reading.pressure;
            then computeControl(targetFlowRate, actualFlowRate, outputVoltage, outputFrequency);
        }
    }
    
    // ===== State Machine =====
    state def PumpingStateMachine {
        entry action initialize { /* Initialize subsystem */ }
        
        state idle {
            entry action enterIdle { /* System idle, actuators off */ }
            transition idle_to_priming first idle if commandInput.command == CommandKind::START then priming;
        }
        
        state priming {
            entry action enterPriming {
                /* Fill pump chamber, run actuator at low frequency */
                outputVoltage = 50 [V];
                outputFrequency = 200 [Hz];
            }
            do action primePump {
                /* Actuate pump to remove air and fill chamber */
            }
            transition priming_to_running first priming if chamber.currentVolume >= chamber.volume * 0.9 then running;
        }
        
        state running {
            entry action enterRunning { /* Enter main running mode */ }
            
            state normal {
                entry action enterNormal { /* Steady-state pumping */ }
                transition normal_to_adjusting first normal if abs(targetFlowRate - actualFlowRate) > tolerance then adjusting;
            }
            
            state adjusting {
                entry action enterAdjusting { /* Adjusting voltage/frequency */ }
                do action adjustFlow {
                    computeControl(targetFlowRate, actualFlowRate, outputVoltage, outputFrequency);
                }
                transition adjusting_to_normal first adjusting if abs(targetFlowRate - actualFlowRate) <= tolerance then normal;
            }
            
            transition running_to_shutdown first running if commandInput.command == CommandKind::STOP then shutdown;
            transition running_to_estop first running if commandInput.command == CommandKind::EMERGENCY_STOP then emergencyStop;
        }
        
        state shutdown {
            entry action enterShutdown {
                /* Gradually reduce voltage and frequency */
                outputVoltage = 0 [V];
                outputFrequency = 0 [Hz];
            }
            transition shutdown_to_idle first shutdown then idle;
        }
        
        state emergencyStop {
            entry action enterEStop {
                /* Immediately cut power to actuator */
                outputVoltage = 0 [V];
                outputFrequency = 0 [Hz];
            }
            transition estop_to_reset first emergencyStop if commandInput.command == CommandKind::RESET then reset;
        }
        
        state reset {
            entry action enterReset { /* Reset all parameters and clear faults */ }
            do action resetSystem {
                actualFlowRate = 0 [mL/min];
                actualPressure = 0 [kPa];
                outputVoltage = 0 [V];
                outputFrequency = 0 [Hz];
            }
            transition reset_to_idle first reset then idle;
        }
    }
    
    // ===== Top-level Subsystem =====
    part def PumpingSubsystem {
        attribute systemName : String = "PrecisionFluidPumpingSubsystem";
        
        part source : SourceReservoir;
        part pump : ImpedancePump;
        part destination : DestinationReceiver;
        part pressureSensor : PressureSensor;
        part flowSensor : FlowSensor;
        part controller : PumpController;
        
        port externalCommand : CommandPort;
        port targetFlowInput;
        
        // Fluid connections
        connection sourceToPump connect source.fluidOut to pump.fluidInlet;
        connection pumpToPressureSensor connect pump.fluidOutlet to pressureSensor.fluidConnection;
        connection pressureSensorToFlowSensor connect pressureSensor.fluidConnection to flowSensor.fluidConnection;
        connection flowSensorToDestination connect flowSensor.fluidConnection to destination.fluidIn;
        
        // Sensor to controller connections
        connection pressureToController connect pressureSensor.sensorOut to controller.sensorInput;
        connection flowToController connect flowSensor.sensorOut to controller.sensorInput;
        
        // Controller to pump connection
        connection controllerToPump connect controller.controlOutput to pump.controlInput;
        
        // External command to controller
        connection commandToController connect externalCommand to controller.commandInput;
        
        // Requirements satisfaction
        satisfy PumpingRequirement by pump;
        satisfy ClosedLoopControlRequirement by controller;
        satisfy SafetyRequirement by PumpingSubsystem;
        
        // State machine behavior
        exhibit PumpingStateMachine;
    }
}
