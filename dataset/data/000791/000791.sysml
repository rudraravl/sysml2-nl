package TGuardSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def Temperature :> ISQ::ThermodynamicTemperatureValue;
    attribute def Pressure :> ISQ::PressureValue;
    attribute def FlowRate :> ISQ::VolumeFlowRateValue;
    attribute def Position :> Real;
    
    enum def OperationalState {
        enum normal;
        enum elevated;
        enum critical;
        enum emergency;
    }
    
    enum def ValveCommand {
        enum fullyOpen;
        enum partiallyOpen;
        enum restricted;
        enum fullyClosed;
    }
    
    port def SensorDataPort {
        out temperature : Temperature;
        out pressure : Pressure;
    }
    
    port def ActuatorCommandPort {
        in command : ValveCommand;
        out position : Position;
    }
    
    port def FluidInterfacePort {
        in inletFlow : FlowRate;
        out outletFlow : FlowRate;
    }
    
    part def TemperatureSensor {
        port output : SensorDataPort;
        attribute measuredTemp : Temperature;
        
        action measureTemperature {
            out temp : Temperature;
        }
    }
    
    part def PressureSensor {
        port output : SensorDataPort;
        attribute measuredPressure : Pressure;
        
        action measurePressure {
            out press : Pressure;
        }
    }
    
    part def ControlValve {
        port commandInput : ActuatorCommandPort;
        port fluidInlet : FluidInterfacePort;
        port fluidOutlet : FluidInterfacePort;
        
        attribute currentPosition : Position;
        attribute currentCommand : ValveCommand;
        
        action actuate {
            in cmd : ValveCommand;
            out pos : Position;
        }
    }
    
    part def ProtectionController {
        port tempInput : SensorDataPort;
        port pressInput : SensorDataPort;
        port valveOutput : ActuatorCommandPort;
        
        attribute state : OperationalState;
        attribute tempLimit : Temperature;
        attribute pressLimit : Pressure;
        
        action determineValveCommand {
            in currentState : OperationalState;
            in temp : Temperature;
            in press : Pressure;
            out cmd : ValveCommand;
        }
    }
    
    part def TGuard {
        doc /* 
            TGuard is an autonomous thermal and pressure protection system designed 
            to safeguard critical fluid processes. Its primary function is to 
            continuously monitor temperature and pressure conditions in real-time, 
            automatically adjusting flow control valves to maintain safe operating 
            parameters and prevent equipment damage or hazardous conditions. The 
            system operates through a closed-loop control strategy, transitioning 
            between operational states and commanding valve positions to ensure 
            process safety without requiring manual intervention.
        */
        
        attribute maximumTemperature : Temperature;
        attribute maximumPressure : Pressure;
        attribute nominalFlowRate : FlowRate;
        
        part temperatureSensor : TemperatureSensor;
        part pressureSensor : PressureSensor;
        part controller : ProtectionController {
            attribute :>> tempLimit = maximumTemperature;
            attribute :>> pressLimit = maximumPressure;
        }
        part controlValve : ControlValve;
        
        connection tempConnection connect 
            temperatureSensor.output to controller.tempInput;
        connection pressConnection connect 
            pressureSensor.output to controller.pressInput;
        connection valveConnection connect 
            controller.valveOutput to controlValve.commandInput;
        
        perform action protectionCycle {
            first start;
            then merge continuousMonitoring;
            
            action continuousMonitoring {
                action acquireData {
                    action getTemperature : temperatureSensor.measureTemperature {
                        out temp : Temperature;
                    }
                    action getPressure : pressureSensor.measurePressure {
                        out press : Pressure;
                    }
                }
                
                then action computeCommand : controller.determineValveCommand {
                    in currentState = controller.state;
                    in temp = acquireData.getTemperature.temp;
                    in press = acquireData.getPressure.press;
                    out cmd : ValveCommand;
                }
                
                then action adjustValve : controlValve.actuate {
                    in cmd = computeCommand.cmd;
                    out pos : Position;
                }
                
                then decide;
                    if controller.state == OperationalState::emergency then haltOperation;
                    if controller.state != OperationalState::emergency then continuousMonitoring;
                
                action haltOperation;
                then done;
            }
        }
    }
    
    requirement def SystemSafetyRequirement {
        doc /* TGuard shall ensure safe operation under all conditions */
        subject system : TGuard;
    }
    
    requirement def TemperatureLimitRequirement :> SystemSafetyRequirement {
        doc /* System shall prevent temperature from exceeding maximum safe limit */
        
        require constraint {
            temperatureSensor.measuredTemp <= maximumTemperature
        }
    }
    
    requirement def PressureLimitRequirement :> SystemSafetyRequirement {
        doc /* System shall prevent pressure from exceeding maximum safe limit */
        
        require constraint {
            pressureSensor.measuredPressure <= maximumPressure
        }
    }
    
    requirement def AutomaticProtectionRequirement :> SystemSafetyRequirement {
        doc /* System shall automatically respond to hazardous conditions */
        
        require constraint {
            controller.state == OperationalState::critical or 
            controller.state == OperationalState::emergency implies 
            controlValve.currentCommand == ValveCommand::restricted or 
            controlValve.currentCommand == ValveCommand::fullyClosed
        }
    }
    
    requirement def EmergencyShutdownRequirement :> SystemSafetyRequirement {
        doc /* System shall execute emergency shutdown when limits are exceeded */
        
        require constraint {
            controller.state == OperationalState::emergency implies 
            controlValve.currentCommand == ValveCommand::fullyClosed
        }
    }
    
    requirement def ContinuousMonitoringRequirement :> SystemSafetyRequirement {
        doc /* System shall continuously monitor process conditions */
        
        require constraint {
            temperatureSensor.measuredTemp != null and 
            pressureSensor.measuredPressure != null
        }
    }
    
    part tguardInstance : TGuard {
        attribute :>> maximumTemperature = 423.15 [SI::K];
        attribute :>> maximumPressure = 2000000.0 [SI::Pa];
        attribute :>> nominalFlowRate = 0.05 [SI::m3_per_s];
    }
    
    requirement tguardSafetyCompliance : SystemSafetyRequirement {
        subject tguardInstance;
        
        require tempLimit : TemperatureLimitRequirement;
        require pressLimit : PressureLimitRequirement;
        require autoProtect : AutomaticProtectionRequirement;
        require emergencyStop : EmergencyShutdownRequirement;
        require monitoring : ContinuousMonitoringRequirement;
    }
}
