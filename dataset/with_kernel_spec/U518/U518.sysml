package HydraulicPumpingSubsystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    item def HydraulicFluid {
        attribute pressure :> ISQ::pressure;
        attribute flowRate :> ISQ::volumeFlowRate;
        attribute temperature :> ISQ::temperature;
        attribute volume :> ISQ::volume;
        attribute density :> ISQ::density;
    }
    
    port def FluidOutPort {
        out item fluid : HydraulicFluid {
            attribute pressure :> ISQ::pressure;
            attribute flowRate :> ISQ::volumeFlowRate;
        }
    }
    
    port def FluidInPort {
        in item fluid : HydraulicFluid {
            attribute pressure :> ISQ::pressure;
            attribute flowRate :> ISQ::volumeFlowRate;
        }
    }
    
    port def FluidTapPort {
        in item fluid : HydraulicFluid;
    }
    
    port def RotationalPort {
        out attribute torque :> ISQ::torque;
        out attribute angularVelocity :> ISQ::angularVelocity;
    }
    
    port def PressureSignalPort {
        out attribute pressureValue :> ISQ::pressure;
    }
    
    port def FlowSignalPort {
        out attribute flowValue :> ISQ::volumeFlowRate;
    }
    
    port def MotorControlPort {
        in attribute speedCommand :> ISQ::angularVelocity;
    }
    
    action def AdjustMotorSpeed {
        in commandedSpeed :> ISQ::angularVelocity;
        out actualSpeed :> ISQ::angularVelocity;
    }
    
    action def ConvertRotationalToPressure {
        in inputTorque :> ISQ::torque;
        in inputSpeed :> ISQ::angularVelocity;
        in lowPressureFluid : HydraulicFluid;
        out highPressureFluid : HydraulicFluid;
    }
    
    action def MonitorPressureAndRelieve {
        in systemPressure :> ISQ::pressure;
        in thresholdPressure :> ISQ::pressure;
        out valveState : Boolean;
    }
    
    action def MeasurePressure {
        in fluidSample : HydraulicFluid;
        out pressureReading :> ISQ::pressure;
    }
    
    action def MeasureFlow {
        in fluidSample : HydraulicFluid;
        out flowReading :> ISQ::volumeFlowRate;
    }
    
    action def ConsumeFluidPower {
        in supplyFluid : HydraulicFluid;
        out exhaustFluid : HydraulicFluid;
    }
    
    action def ControlPressureLoop {
        in measuredPressure :> ISQ::pressure;
        in setpointPressure :> ISQ::pressure;
        in measuredFlow :> ISQ::volumeFlowRate;
        out speedCommand :> ISQ::angularVelocity;
    }
    
    state def PumpStates;
    
    attribute def PumpStartSignal;
    attribute def PumpStopSignal;
    attribute def PumpFaultSignal;
    attribute def FaultClearSignal;
    attribute def PressureNominal;
    
    part def Reservoir {
        attribute capacity :> ISQ::volume;
        attribute currentLevel :> ISQ::volume;
        port fluidOutPort : FluidOutPort;
        port fluidReturnPort : FluidInPort;
    }
    
    part def ElectricMotor {
        attribute speed :> ISQ::angularVelocity;
        attribute targetSpeed :> ISQ::angularVelocity;
        attribute power :> ISQ::power;
        port shaftPort : RotationalPort;
        port controlPort : ~MotorControlPort;
        perform action adjustSpeed : AdjustMotorSpeed;
    }
    
    part def HydraulicPump {
        attribute flowRate :> ISQ::volumeFlowRate;
        attribute efficiency : Real;
        attribute displacementVolume :> ISQ::volume;
        port fluidInPort : ~FluidOutPort;
        port fluidOutPort : FluidOutPort;
        port driveShaftPort : ~RotationalPort;
        perform action convertPower : ConvertRotationalToPressure;
        exhibit state pumpStates : PumpStates;
    }
    
    part def PressureReliefValve {
        attribute pressureThreshold :> ISQ::pressure;
        attribute isOpen : Boolean;
        port highPressurePort : FluidTapPort;
        port reliefOutPort : FluidOutPort;
        perform action monitorAndRelieve : MonitorPressureAndRelieve;
    }
    
    part def PressureSensor {
        attribute measuredPressure :> ISQ::pressure;
        port sensingPort : FluidTapPort;
        port signalOutPort : PressureSignalPort;
        perform action measurePressure : MeasurePressure;
    }
    
    part def FlowSensor {
        attribute measuredFlowRate :> ISQ::volumeFlowRate;
        port sensingPort : FluidTapPort;
        port signalOutPort : FlowSignalPort;
        perform action measureFlow : MeasureFlow;
    }
    
    part def FluidConsumer {
        attribute requiredPressure :> ISQ::pressure;
        attribute consumptionRate :> ISQ::volumeFlowRate;
        port fluidInPort : ~FluidOutPort;
        port fluidOutPort : FluidOutPort;
        perform action consumeFluid : ConsumeFluidPower;
    }
    
    part def ControlSystem {
        attribute targetPressure :> ISQ::pressure;
        attribute pressureTolerance :> ISQ::pressure;
        attribute kp : Real;
        attribute ki : Real;
        port pressureInputPort : ~PressureSignalPort;
        port flowInputPort : ~FlowSignalPort;
        port motorControlPort : MotorControlPort;
        perform action controlPressure : ControlPressureLoop;
    }
    
    part def HydraulicPowerUnit {
        attribute operatingPressure :> ISQ::pressure;
        attribute maxSafetyPressure :> ISQ::pressure;
        attribute targetFlowRate :> ISQ::volumeFlowRate;
        attribute fluidTemperature :> ISQ::temperature;
    }
    
    requirement def MaintainOperatingPressure {
        doc /* System must maintain target pressure within tolerance */
    }
    
    requirement def PreventOverpressure {
        doc /* Relief valve must open before damage occurs */
    }
    
    requirement def DeliverRequiredFlow {
        doc /* System must deliver adequate flow to consumer */
    }
    
    requirement def RespondToDemand {
        doc /* Control system must adjust to pressure variations */
    }
    
    action adjustSpeed : AdjustMotorSpeed;
    action convertPower : ConvertRotationalToPressure;
    action monitorAndRelieve : MonitorPressureAndRelieve;
    action measurePressure : MeasurePressure;
    action measureFlow : MeasureFlow;
    action consumeFluid : ConsumeFluidPower;
    action controlPressure : ControlPressureLoop;
    
    part hydraulicPowerUnit : HydraulicPowerUnit {
        attribute redefines operatingPressure = 20685000.0;
        attribute redefines maxSafetyPressure = 24132000.0;
        attribute redefines targetFlowRate = 0.000833;
        attribute redefines fluidTemperature = 323.15;
        
        part reservoir : Reservoir {
            attribute redefines capacity = 0.1;
            attribute redefines currentLevel = 0.08;
        }
        
        part motor : ElectricMotor {
            attribute redefines power = 15000.0;
            attribute redefines targetSpeed = 157.08;
            
            perform action redefines adjustSpeed {
                in commandedSpeed = controlPort.speedCommand;
                out actualSpeed = speed;
            }
        }
        
        connect motor.shaftPort to pump.driveShaftPort;
        
        part pump : HydraulicPump {
            attribute redefines efficiency = 0.92;
            attribute redefines displacementVolume = 0.000050;
            
            perform action redefines convertPower {
                in inputTorque = driveShaftPort.torque;
                in inputSpeed = driveShaftPort.angularVelocity;
                in lowPressureFluid = fluidInPort.fluid;
                out highPressureFluid = fluidOutPort.fluid;
            }
            
            exhibit state redefines pumpStates : PumpStates {
                entry; then idle;
                
                state idle;
                accept PumpStartSignal
                    then starting;
                
                state starting;
                accept PressureNominal
                    then running;
                accept PumpFaultSignal
                    then faulted;
                
                state running {
                    do convertPower;
                }
                accept PumpStopSignal
                    then idle;
                accept PumpFaultSignal
                    then faulted;
                
                state faulted;
                accept FaultClearSignal
                    then idle;
            }
        }
        
        flow of lowPressureSupply : HydraulicFluid
            from reservoir.fluidOutPort.fluid to pump.fluidInPort.fluid;
        
        part pressureSensor : PressureSensor {
            perform action redefines measurePressure {
                in fluidSample = sensingPort.fluid;
                out pressureReading = measuredPressure;
            }
        }
        
        part flowSensor : FlowSensor {
            perform action redefines measureFlow {
                in fluidSample = sensingPort.fluid;
                out flowReading = measuredFlowRate;
            }
        }
        
        flow of pumpOutput : HydraulicFluid
            from pump.fluidOutPort.fluid to pressureSensor.sensingPort.fluid;
        
        flow of monitoredSupply : HydraulicFluid
            from pressureSensor.sensingPort.fluid to flowSensor.sensingPort.fluid;
        
        part reliefValve : PressureReliefValve {
            attribute redefines pressureThreshold = hydraulicPowerUnit.maxSafetyPressure;
            attribute redefines isOpen = false;
            
            perform action redefines monitorAndRelieve {
                in systemPressure = highPressurePort.fluid.pressure;
                in thresholdPressure = pressureThreshold;
                out valveState = isOpen;
            }
        }
        
        flow of pressureMonitoring : HydraulicFluid
            from flowSensor.sensingPort.fluid to reliefValve.highPressurePort.fluid;
        
        flow of workingFluid : HydraulicFluid
            from reliefValve.highPressurePort.fluid to consumer.fluidInPort.fluid;
        
        flow of reliefPath : HydraulicFluid
            from reliefValve.reliefOutPort.fluid to reservoir.fluidReturnPort.fluid;
        
        part consumer : FluidConsumer {
            attribute redefines requiredPressure = hydraulicPowerUnit.operatingPressure;
            attribute redefines consumptionRate = hydraulicPowerUnit.targetFlowRate;
            
            perform action redefines consumeFluid {
                in supplyFluid = fluidInPort.fluid;
                out exhaustFluid = fluidOutPort.fluid;
            }
        }
        
        flow of returnPath : HydraulicFluid
            from consumer.fluidOutPort.fluid to reservoir.fluidReturnPort.fluid;
        
        part controller : ControlSystem {
            attribute redefines targetPressure = hydraulicPowerUnit.operatingPressure;
            attribute redefines pressureTolerance = 344750.0;
            attribute redefines kp = 0.0001;
            attribute redefines ki = 0.00001;
            
            perform action redefines controlPressure {
                in measuredPressure = pressureInputPort.pressureValue;
                in setpointPressure = targetPressure;
                in measuredFlow = flowInputPort.flowValue;
                out speedCommand = motorControlPort.speedCommand;
            }
        }
        
        connect pressureSensor.signalOutPort to controller.pressureInputPort;
        connect flowSensor.signalOutPort to controller.flowInputPort;
        connect controller.motorControlPort to motor.controlPort;
        
        requirement pressureReq : MaintainOperatingPressure {
            doc /* Operating pressure must be maintained within tolerance band */
            subject pumpAssembly = hydraulicPowerUnit.pump;
            require constraint {
                pressureSensor.measuredPressure >= 
                    hydraulicPowerUnit.operatingPressure - controller.pressureTolerance and
                pressureSensor.measuredPressure <= 
                    hydraulicPowerUnit.operatingPressure + controller.pressureTolerance
            }
        }
        
        requirement safetyReq : PreventOverpressure {
            doc /* Relief valve protects system from overpressure */
            subject safetyValve = hydraulicPowerUnit.reliefValve;
            require constraint {
                pressureSensor.measuredPressure <= hydraulicPowerUnit.maxSafetyPressure
            }
        }
        
        requirement flowReq : DeliverRequiredFlow {
            doc /* Flow rate must meet consumer demand */
            subject pumpAssembly = hydraulicPowerUnit.pump;
            require constraint {
                flowSensor.measuredFlowRate >= consumer.consumptionRate * 0.95 and
                flowSensor.measuredFlowRate <= consumer.consumptionRate * 1.05
            }
        }
        
        requirement responseReq : RespondToDemand {
            doc /* Control system responds to pressure deviations */
            subject controlLoop = hydraulicPowerUnit.controller;
            require constraint {
                controller.controlPressure.speedCommand == 
                    motor.targetSpeed + 
                    controller.kp * (controller.targetPressure - pressureSensor.measuredPressure) +
                    controller.ki * (controller.targetPressure - pressureSensor.measuredPressure)
            }
        }
    }
}
