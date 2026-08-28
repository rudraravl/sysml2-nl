package 'Slurry Transport System' {
    private import ScalarValues::*;
    
    item def SolidMaterial;
    item def LiquidMaterial;
    item def Slurry;
    
    item def StartCommand;
    item def ShutdownCommand;
    item def EmergencyStopCommand;
    item def HighPressureAlarm;
    item def PressureNormalized;
    
    value def Viscosity : Real { unit 'cP'; }
    value def FlowRate : Real { unit 'L/min'; }
    value def PressureValue : Real { unit 'bar'; }
    value def MixingSpeed : Real { unit 'rpm'; }
    value def PumpOutput : Real { unit '%'; }
    
    item def ViscosityReading { attribute value : Viscosity; }
    item def FlowRateReading { attribute value : FlowRate; }
    item def PressureReading { attribute value : PressureValue; }
    item def MixingSpeedCmd { attribute value : MixingSpeed; }
    item def PumpOutputCmd { attribute value : PumpOutput; }
    item def ValveCmd { attribute open : Boolean; }
    
    port def SolidMaterialPort { item solid : SolidMaterial; }
    port def LiquidMaterialPort { item liquid : LiquidMaterial; }
    port def SlurryPort { item slurry : Slurry; }
    port def ViscosityDataPort { item data : ViscosityReading; }
    port def FlowDataPort { item data : FlowRateReading; }
    port def PressureDataPort { item data : PressureReading; }
    port def MixingCmdPort { item cmd : MixingSpeedCmd; }
    port def PumpCmdPort { item cmd : PumpOutputCmd; }
    port def ValveCmdPort { item cmd : ValveCmd; }
    port def StartCmdPort { item cmd : StartCommand; }
    port def ShutdownCmdPort { item cmd : ShutdownCommand; }
    port def EmergencyStopCmdPort { item cmd : EmergencyStopCommand; }
    
    part def MixingVessel {
        in port solidIn : SolidMaterialPort;
        in port liquidIn : LiquidMaterialPort;
        out port slurryOut : SlurryPort;
        in port mixingSpeedCmd : MixingCmdPort;
        attribute currentMixingSpeed : MixingSpeed;
    }
    
    part def ViscosityMonitor {
        in port slurryIn : SlurryPort;
        out port slurryOut : SlurryPort;
        out port viscosityData : ViscosityDataPort;
    }
    
    part def CentrifugalPump {
        in port slurryIn : SlurryPort;
        out port slurryOut : SlurryPort;
        in port pumpOutputCmd : PumpCmdPort;
        attribute currentPumpOutput : PumpOutput;
    }
    
    part def FlowMeter {
        in port slurryIn : SlurryPort;
        out port slurryOut : SlurryPort;
        out port flowData : FlowDataPort;
    }
    
    part def Pipeline {
        in port slurryIn : SlurryPort;
        out port slurryOut : SlurryPort;
        out port pressureTap : SlurryPort;
    }
    
    part def PressureSensor {
        in port pipelineIn : SlurryPort;
        out port pressureData : PressureDataPort;
    }
    
    part def SafetyValve {
        in port slurryIn : SlurryPort;
        out port slurryOut : SlurryPort;
        in port valveCmd : ValveCmdPort;
        attribute isOpen : Boolean;
    }
    
    state def ControlStates {
        in mixerCmdPort : MixingCmdPort;
        in pumpCmdPort : PumpCmdPort;
        in valveCmdPort : ValveCmdPort;
        
        entry; then idle;
        state idle;
        transition idle_to_startup
            first idle
            accept StartCommand
            then startup;
        state startup {
            entry action initializeSystem {
                action sendMixingCmd send new MixingSpeedCmd() to mixerCmdPort;
                action sendPumpCmd send new PumpOutputCmd() to pumpCmdPort;
                action sendValveCmd send new ValveCmd() to valveCmdPort;
            }
        }
        transition startup_to_normal
            first startup
            then normalOperation;
        state normalOperation {
            do action monitorAndAdjust { /* Monitor sensors and adjust speeds */ }
        }
        transition normal_to_alarm
            first normalOperation
            accept HighPressureAlarm
            then alarm;
        transition normal_to_shutdown
            first normalOperation
            accept ShutdownCommand
            then shutdown;
        transition normal_to_emergency
            first normalOperation
            accept EmergencyStopCommand
            then emergencyStop;
        state alarm {
            entry action reduceFlow {
                action sendReducedPumpCmd send new PumpOutputCmd() to pumpCmdPort;
            }
        }
        transition alarm_to_normal
            first alarm
            accept PressureNormalized
            then normalOperation;
        transition alarm_to_shutdown
            first alarm
            accept ShutdownCommand
            then shutdown;
        transition alarm_to_emergency
            first alarm
            accept EmergencyStopCommand
            then emergencyStop;
        state shutdown {
            entry action gradualStop {
                action stopMixing send new MixingSpeedCmd() to mixerCmdPort;
                action stopPump send new PumpOutputCmd() to pumpCmdPort;
                action closeValve send new ValveCmd() to valveCmdPort;
            }
        }
        transition shutdown_to_emergency
            first shutdown
            accept EmergencyStopCommand
            then emergencyStop;
        state emergencyStop {
            entry action haltAll {
                action haltMixing send new MixingSpeedCmd() to mixerCmdPort;
                action haltPump send new PumpOutputCmd() to pumpCmdPort;
                action closeValveEmergency send new ValveCmd() to valveCmdPort;
            }
        }
    }
    
    part def Controller {
        in port viscosityIn : ViscosityDataPort;
        in port flowIn : FlowDataPort;
        in port pressureIn : PressureDataPort;
        in port startCmdIn : StartCmdPort;
        in port shutdownCmdIn : ShutdownCmdPort;
        in port emergencyStopCmdIn : EmergencyStopCmdPort;
        out port mixingSpeedCmd : MixingCmdPort;
        out port pumpOutputCmd : PumpCmdPort;
        out port valveCmd : ValveCmdPort;
        
        attribute maxPressure : PressureValue = 10.0;
        attribute currentPressure : PressureValue;
        
        state controlStates : ControlStates {
            in mixerCmdPort = mixingSpeedCmd;
            in pumpCmdPort = pumpOutputCmd;
            in valveCmdPort = valveCmd;
        }
    }
    
    part def SlurryTransportSystem {
        part vessel : MixingVessel;
        part viscosityMonitor : ViscosityMonitor;
        part pump : CentrifugalPump;
        part flowMeter : FlowMeter;
        part pipeline : Pipeline;
        part pressureSensor : PressureSensor;
        part safetyValve : SafetyValve;
        part controller : Controller;
        
        connect vessel.slurryOut to viscosityMonitor.slurryIn;
        connect viscosityMonitor.slurryOut to pump.slurryIn;
        connect pump.slurryOut to flowMeter.slurryIn;
        connect flowMeter.slurryOut to pipeline.slurryIn;
        connect pipeline.slurryOut to safetyValve.slurryIn;
        connect pipeline.pressureTap to pressureSensor.pipelineIn;
        
        connect viscosityMonitor.viscosityData to controller.viscosityIn;
        connect flowMeter.flowData to controller.flowIn;
        connect pressureSensor.pressureData to controller.pressureIn;
        
        connect controller.mixingSpeedCmd to vessel.mixingSpeedCmd;
        connect controller.pumpOutputCmd to pump.pumpOutputCmd;
        connect controller.valveCmd to safetyValve.valveCmd;
    }
    
    requirement def MaintainConsistency {
        doc /* The system shall maintain slurry viscosity within ±5% of the target value. */
    }
    requirement def MaintainFlowRate {
        doc /* The system shall maintain flow rate within ±3% of the target value. */
    }
    requirement def PressureSafety {
        doc /* Pipeline pressure shall not exceed 10 bar. If exceeded, system shall enter alarm state and reduce flow. */
    }
    requirement def EmergencyStopResponse {
        doc /* Upon emergency stop command, all rotating machinery shall halt and safety valves shall close. */
    }
    
    part systemInstance : SlurryTransportSystem {
        requirement req1 : MaintainConsistency;
        requirement req2 : MaintainFlowRate;
        requirement req3 : PressureSafety;
        requirement req4 : EmergencyStopResponse;
        satisfy req1 by controller;
        satisfy req2 by controller;
        satisfy req3 by controller;
        satisfy req4 by controller;
    }
}
