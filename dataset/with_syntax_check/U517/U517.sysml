package 'Hydraulic Compressor System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def PressureSetpoint :> ISQ::PressureValue;
    attribute def FlowRate :> ISQ::VolumeFlowRateValue;
    attribute def MotorSpeed :> ISQ::AngularVelocityValue;
    attribute def Temperature :> ISQ::TemperatureValue;
    
    item def HydraulicFluid {
        attribute viscosity : Real;
        attribute density : ISQ::DensityValue;
        attribute operatingTemperature : Temperature;
    }
    
    item def StartCommand;
    item def StopCommand;
    item def EmergencyStop;
    
    port def FluidPort {
        attribute pressure : ISQ::PressureValue;
        attribute flowRate : FlowRate;
        attribute temperature : Temperature;
    }
    
    port def PowerPort {
        attribute voltage : ISQ::ElectricPotentialValue;
        attribute current : ISQ::ElectricCurrentValue;
    }
    
    port def MechanicalPort {
        attribute torque : ISQ::TorqueValue;
        attribute speed : MotorSpeed;
    }
    
    port def ControlPort {
        in attribute commandSignal : Real;
        out attribute statusFeedback : Real;
    }
    
    part def FluidReservoir {
        attribute capacity : ISQ::VolumeValue;
        attribute currentLevel : ISQ::VolumeValue;
        attribute fluidProperties : HydraulicFluid;
        port fluidOut : ~FluidPort;
        port fluidIn : ~FluidPort;
    }
    
    part def ElectricMotor {
        attribute ratedPower : ISQ::PowerValue;
        attribute efficiency : Real;
        port powerIn : ~PowerPort;
        port shaftOut : ~MechanicalPort;
        port controlIn : ~ControlPort;
    }
    
    part def HydraulicPump {
        attribute displacement : ISQ::VolumeValue;
        attribute maxPressure : ISQ::PressureValue;
        attribute efficiency : Real;
        port shaftIn : ~MechanicalPort;
        port fluidIn : ~FluidPort;
        port fluidOut : ~FluidPort;
    }
    
    part def PressureReliefValve {
        attribute setPoint : ISQ::PressureValue;
        attribute crackingPressure : ISQ::PressureValue;
        port fluidIn : ~FluidPort;
        port fluidReturn : ~FluidPort;
    }
    
    part def PressureSensor {
        attribute range : ISQ::PressureValue;
        attribute accuracy : Real;
        port sensing : ~FluidPort;
        port signalOut : ~ControlPort;
    }
    
    part def ControlValve {
        attribute position : Real;
        port fluidIn : ~FluidPort;
        port fluidOut : ~FluidPort;
        port control : ~ControlPort;
    }
    
    part def SystemController {
        attribute targetPressure : PressureSetpoint;
        attribute hysteresis : ISQ::PressureValue;
        port controlOut : ~ControlPort;
        port sensorIn : ~ControlPort;
        port motorControl : ~ControlPort;
    }
    
    part def Accumulator {
        attribute volume : ISQ::VolumeValue;
        attribute precharge : ISQ::PressureValue;
        port fluidPort : ~FluidPort;
    }
    
    action def MonitorPressure {
        in currentPressure : ISQ::PressureValue;
        in targetPressure : ISQ::PressureValue;
        out pressureError : ISQ::PressureValue;
    }
    
    action def AdjustMotorSpeed {
        in pressureError : ISQ::PressureValue;
        in currentSpeed : MotorSpeed;
        out commandSpeed : MotorSpeed;
    }
    
    action def CompressFluid {
        in fluidIn : HydraulicFluid;
        in motorTorque : ISQ::TorqueValue;
        in motorSpeed : MotorSpeed;
        out pressurizedFluid : ISQ::PressureValue;
        out flowRate : FlowRate;
    }
    
    action def RegulateFlow {
        in commandedPosition : Real;
        in currentFlowRate : FlowRate;
        out valvePosition : Real;
    }
    
    action def ProtectSystem {
        in systemPressure : ISQ::PressureValue;
        in maxPressure : ISQ::PressureValue;
        in fluidTemperature : Temperature;
        in maxTemperature : Temperature;
        out emergencyShutdown : Boolean;
    }
    
    action def OperateHydraulicCompressor {
        in targetPressure : ISQ::PressureValue;
        in fluidProperties : HydraulicFluid;
        out systemPressure : ISQ::PressureValue;
        out deliveredFlow : FlowRate;
        
        first start;
        then accept startCmd : StartCommand;
        then action initializeSystem {
            action checkFluidLevel;
            then action primeSystem;
            then action startMotor;
        }
        then merge operatingLoop;
        
        action monitorAndControl {
            action monitor : MonitorPressure {
                in currentPressure;
                in targetPressure;
                out pressureError;
            }
            flow monitor.pressureError to adjustSpeed.pressureError;
            
            action adjustSpeed : AdjustMotorSpeed {
                in pressureError;
                in currentSpeed;
                out commandSpeed;
            }
            flow adjustSpeed.commandSpeed to compress.motorSpeed;
            
            action compress : CompressFluid {
                in fluidIn = fluidProperties;
                in motorTorque;
                in motorSpeed;
                out pressurizedFluid;
                out flowRate;
            }
            flow compress.pressurizedFluid to regulate.currentFlowRate;
            
            action regulate : RegulateFlow {
                in commandedPosition;
                in currentFlowRate;
                out valvePosition;
            }
            
            action protect : ProtectSystem {
                in systemPressure = compress.pressurizedFluid;
                in maxPressure;
                in fluidTemperature;
                in maxTemperature;
                out emergencyShutdown;
            }
        }
        then decide;
            if monitorAndControl.protect.emergencyShutdown then emergencyShutdownAction;
            if not monitorAndControl.protect.emergencyShutdown then checkStopCommand;
        
        action checkStopCommand {
            accept stopCmd : StopCommand;
        }
        then normalShutdown;
        
        action emergencyShutdownAction : EmergencyStop;
        then done;
        
        action normalShutdown {
            action rampDownMotor;
            then action closeValves;
            then action stopMotor;
        }
        then done;
        
        then operatingLoop;
    }
    
    part def HydraulicCompressor {
        doc /* 
            A hydraulic compressor system that pressurizes hydraulic fluid from reservoir pressure
            to a specified operating pressure for delivery to downstream hydraulic actuators and systems.
        */
        
        attribute operatingPressure : ISQ::PressureValue;
        attribute maxSystemPressure : ISQ::PressureValue;
        attribute nominalFlowRate : FlowRate;
        attribute currentSystemPressure : ISQ::PressureValue;
        
        port powerSource : PowerPort;
        port systemOutput : FluidPort;
        
        perform action operate : OperateHydraulicCompressor {
            in targetPressure = operatingPressure;
            in fluidProperties = reservoir.fluidProperties;
            out systemPressure = currentSystemPressure;
            out deliveredFlow;
        }
        
        part reservoir : FluidReservoir {
            attribute capacity = 200.0 [L];
            attribute currentLevel = 180.0 [L];
        }
        
        part motor : ElectricMotor {
            attribute ratedPower = 15000.0 [W];
            attribute efficiency = 0.92;
            perform operate.monitorAndControl.compress;
        }
        
        part pump : HydraulicPump {
            attribute displacement = 50.0 [mL];
            attribute maxPressure = 25000000.0 [Pa];
            attribute efficiency = 0.88;
            perform operate.monitorAndControl.compress;
        }
        
        part reliefValve : PressureReliefValve {
            attribute setPoint = 26000000.0 [Pa];
            attribute crackingPressure = 25500000.0 [Pa];
        }
        
        part pressureSensor : PressureSensor {
            attribute range = 30000000.0 [Pa];
            attribute accuracy = 0.005;
            perform operate.monitorAndControl.monitor;
        }
        
        part controlValve : ControlValve {
            attribute position = 0.5;
            perform operate.monitorAndControl.regulate;
        }
        
        part controller : SystemController {
            attribute targetPressure = 20000000.0 [Pa];
            attribute hysteresis = 500000.0 [Pa];
            perform operate.monitorAndControl.adjustSpeed;
            perform operate.monitorAndControl.protect;
        }
        
        part accumulator : Accumulator {
            attribute volume = 10.0 [L];
            attribute precharge = 15000000.0 [Pa];
        }
        
        connect motor.shaftOut to pump.shaftIn;
        connect reservoir.fluidOut to pump.fluidIn;
        connect pump.fluidOut to controlValve.fluidIn;
        connect controlValve.fluidOut to systemOutput;
        connect pump.fluidOut to reliefValve.fluidIn;
        connect reliefValve.fluidReturn to reservoir.fluidIn;
        connect pump.fluidOut to accumulator.fluidPort;
        connect pump.fluidOut to pressureSensor.sensing;
        connect pressureSensor.signalOut to controller.sensorIn;
        connect controller.controlOut to controlValve.control;
        connect controller.motorControl to motor.controlIn;
        connect powerSource to motor.powerIn;
    }
    
    requirement def SystemPerformanceRequirement {
        doc /* The hydraulic compressor system shall maintain output pressure within specified tolerance. */
        subject compressorSystem : HydraulicCompressor;
        require constraint pressureStability {
            compressorSystem.operatingPressure >= 19500000.0 [Pa] and
            compressorSystem.operatingPressure <= 20500000.0 [Pa]
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The system shall not exceed maximum safe operating pressure. */
        subject compressorSystem : HydraulicCompressor;
        require constraint pressureLimit {
            compressorSystem.currentSystemPressure <= compressorSystem.maxSystemPressure
        }
    }
    
    requirement def EfficiencyRequirement {
        doc /* The system shall operate at minimum 85% overall efficiency. */
        subject compressorSystem : HydraulicCompressor;
        require constraint minimumEfficiency {
            compressorSystem.motor.efficiency >= 0.85
        }
    }
    
    requirement <'HC-001'> primaryFunctionRequirement : SystemPerformanceRequirement {
        doc /* 
            The hydraulic compressor system shall compress hydraulic fluid from reservoir pressure
            to the specified operating pressure and deliver it at the required flow rate to downstream
            hydraulic actuators and systems. The system shall maintain stable pressure regulation
            through continuous monitoring and feedback control while protecting against overpressure
            conditions through integrated relief mechanisms.
        */
        subject hydraulicCompressorSystem : HydraulicCompressor;
        assume constraint fluidAvailable {
            hydraulicCompressorSystem.reservoir.currentLevel >= 50.0 [L]
        }
        require pressureStability;
    }
    
    requirement <'HC-002'> safetyRequirement : SafetyRequirement {
        doc /* System shall incorporate pressure relief and emergency shutdown capabilities. */
        subject hydraulicCompressorSystem : HydraulicCompressor;
        require pressureLimit;
    }
    
    part hydraulicCompressorSystem : HydraulicCompressor {
        attribute operatingPressure = 20000000.0 [Pa];
        attribute maxSystemPressure = 27000000.0 [Pa];
        attribute nominalFlowRate = 0.001 [m^3/s];
        attribute currentSystemPressure = 20000000.0 [Pa];
    }
}
