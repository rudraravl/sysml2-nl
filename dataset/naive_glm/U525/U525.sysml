package InjectionPumpingSubsystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    
    value type PressureValue :> Real {
        unit 'Pa';
    }
    
    value type FlowRateValue :> Real {
        unit 'm3/s';
    }
    
    value type VoltageValue :> Real {
        unit 'V';
    }
    
    value type CurrentValue :> Real {
        unit 'A';
    }
    
    value type AngularVelocityValue :> Real {
        unit 'rad/s';
    }
    
    value type TemperatureValue :> Real {
        unit 'K';
    }
    
    value type DutyCycleValue :> Real {
        unit '%';
    }
    
    value type PressureThresholdValue :> PressureValue;
    
    // ===== Item Types =====
    
    item def HydraulicFluid {
        attribute density : Real = 850 [kg/m3];
        attribute viscosity : Real = 0.015 [Pa*s];
        attribute bulkModulus : Real = 1.5e9 [Pa];
    }
    
    item def PressurizedFluid :> HydraulicFluid {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }
    
    // ===== Port Definitions =====
    
    port def FluidPort {
        in item fluid : HydraulicFluid;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }
    
    port def BidirectionalFluidPort {
        in item inflow : HydraulicFluid;
        out item outflow : HydraulicFluid;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }
    
    port def ElectricalPowerPort {
        in attribute voltage : VoltageValue;
        in attribute current : CurrentValue;
    }
    
    port def ControlSignalPort {
        in attribute motorSpeedCmd : AngularVelocityValue;
        in attribute enable : Boolean;
    }
    
    port def SensorDataPort {
        out attribute pressureReading : PressureValue;
        out attribute flowReading : FlowRateValue;
        out attribute status : String;
    }
    
    port def CommandPort {
        in attribute targetPressure : PressureValue;
        in attribute targetFlowRate : FlowRateValue;
        in attribute modeCommand : String;
    }
    
    // ===== Requirements =====
    
    requirement def PressurizationRequirement {
        doc /* The system shall pressurize fluid to a precise target level. */
        attribute targetPressure : PressureValue = 200e5 [Pa];
        subject pumpSystem : InjectionPumpSystem;
        requirement {
            subject pumpSystem;
            constraint { pumpSystem.dischargePressure >= targetPressure }
        }
    }
    
    requirement def FlowRateRequirement {
        doc /* The system shall deliver fluid at a consistent specified flow rate. */
        attribute targetFlowRate : FlowRateValue = 1.0e-4 [m3/s];
        subject pumpSystem : InjectionPumpSystem;
        requirement {
            subject pumpSystem;
            constraint { abs(pumpSystem.deliveredFlowRate - targetFlowRate) <= 0.05 * targetFlowRate }
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The system shall vent excess pressure if it exceeds a critical safety threshold. */
        attribute safetyThreshold : PressureThresholdValue = 250e5 [Pa];
        subject pumpSystem : InjectionPumpSystem;
        requirement {
            subject pumpSystem;
            constraint { pumpSystem.maxSystemPressure <= safetyThreshold }
        }
    }
    
    requirement def StateTransitionRequirement {
        doc /* The system shall operate through idle, priming, pumping, flushing, and fault states. */
        subject controller : PumpController;
        requirement {
            subject controller;
            constraint { controller.currentState in {'idle', 'priming', 'pumping', 'flushing', 'fault'} }
        }
    }
    
    // ===== Component Definitions =====
    
    part def SupplyReservoir {
        port fluidOut : FluidPort;
        attribute capacity : Volume = 0.05 [m3];
        attribute currentLevel : Volume;
        attribute fluid : HydraulicFluid;
        
        action def SupplyFluid {
            in reqFlow : FlowRateValue;
            out suppliedFluid : HydraulicFluid;
        }
    }
    
    part def Plunger {
        attribute strokeLength : Length = 0.01 [m];
        attribute diameter : Length = 0.005 [m];
        attribute displacementPerStroke : Volume = 3.14 * (diameter/2)^2 * strokeLength;
    }
    
    part def Cam {
        attribute lobeCount : Integer = 3;
        attribute baseRadius : Length = 0.02 [m];
        attribute liftHeight : Length = 0.008 [m];
    }
    
    part def CheckValve {
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute crackingPressure : PressureValue = 0.5e5 [Pa];
        attribute isOpen : Boolean;
        
        action def OpenValve {
            in deltaPressure : PressureValue;
            then if deltaPressure >= crackingPressure then isOpen = true else isOpen = false;
        }
    }
    
    part def PumpMotor {
        port powerIn : ElectricalPowerPort;
        port controlIn : ControlSignalPort;
        port mechanicalOut : MechanicalOutputPort;
        attribute nominalVoltage : VoltageValue = 24 [V];
        attribute maxSpeed : AngularVelocityValue = 500 [rad/s];
        attribute currentSpeed : AngularVelocityValue;
        attribute isEnergized : Boolean;
        
        action def DriveMotor {
            in speedCommand : AngularVelocityValue;
            in enableSignal : Boolean;
            then if enableSignal == true {
                isEnergized = true;
                currentSpeed = speedCommand;
            } else {
                isEnergized = false;
                currentSpeed = 0 [rad/s];
            }
        }
    }
    
    port def MechanicalOutputPort {
        out attribute torque : Real;
        out attribute speed : AngularVelocityValue;
    }
    
    part def InjectionPump {
        port suctionPort : FluidPort;
        port dischargePort : FluidPort;
        port motorControlPort : ControlSignalPort;
        port motorPowerPort : ElectricalPowerPort;
        
        part plunger : Plunger;
        part cam : Cam;
        part inletValve : CheckValve;
        part outletValve : CheckValve;
        part motor : PumpMotor;
        
        attribute suctionPressure : PressureValue;
        attribute dischargePressure : PressureValue;
        attribute pumpFlowRate : FlowRateValue;
        attribute efficiency : Real = 0.85;
        
        action def PumpCycle {
            in motorSpeed : AngularVelocityValue;
            in suctionFluid : HydraulicFluid;
            out dischargeFluid : PressurizedFluid;
            
            // Intake stroke
            then action intakeStroke {
                in fluid : HydraulicFluid = suctionFluid;
                out drawnFluid : HydraulicFluid;
                then inletValve.OpenValve(suctionPressure - plunger.displacementPerStroke);
            }
            
            // Compression stroke
            then action compressionStroke {
                in fluid : HydraulicFluid = intakeStroke.drawnFluid;
                out pressurizedFluid : PressurizedFluid;
                then outletValve.OpenValve(dischargePressure - suctionPressure);
            }
            
            // Discharge stroke
            then action dischargeStroke {
                in fluid : PressurizedFluid = compressionStroke.pressurizedFluid;
                out deliveredFluid : PressurizedFluid;
            }
        }
        
        action def OperatePump {
            in motorSpeed : AngularVelocityValue;
            in enable : Boolean;
            in suctionFluid : HydraulicFluid;
            out dischargeFluid : PressurizedFluid;
            
            then motor.DriveMotor(motorSpeed, enable);
            then if motor.isEnergized {
                PumpCycle(motor.currentSpeed, suctionFluid);
            }
        }
    }
    
    part def DischargeManifold {
        port inletPort : FluidPort;
        port outletPort1 : FluidPort;
        port outletPort2 : FluidPort;
        attribute internalVolume : Volume = 0.002 [m3];
        attribute manifoldPressure : PressureValue;
        attribute distributionRatio1 : Real = 0.5;
        attribute distributionRatio2 : Real = 0.5;
        
        action def DistributeFlow {
            in inflow : PressurizedFluid;
            out outflow1 : PressurizedFluid;
            out outflow2 : PressurizedFluid;
            then {
                outflow1.flowRate = inflow.flowRate * distributionRatio1;
                outflow2.flowRate = inflow.flowRate * distributionRatio2;
                outflow1.pressure = inflow.pressure;
                outflow2.pressure = inflow.pressure;
            }
        }
    }
    
    part def PressureTransducer {
        port fluidPort : FluidPort;
        port dataOut : SensorDataPort;
        attribute calibrationFactor : Real = 1.0;
        attribute measuredPressure : PressureValue;
        attribute operatingRange : PressureValue = 300e5 [Pa];
        attribute isFunctional : Boolean = true;
        
        action def MeasurePressure {
            in fluidPressure : PressureValue;
            out reading : PressureValue;
            then if isFunctional {
                measuredPressure = fluidPressure * calibrationFactor;
                reading = measuredPressure;
                dataOut.pressureReading = reading;
                dataOut.status = "ok";
            } else {
                dataOut.status = "fault";
            }
        }
    }
    
    part def FlowMeter {
        port fluidPort : FluidPort;
        port dataOut : SensorDataPort;
        attribute measuredFlowRate : FlowRateValue;
        attribute maxFlowRate : FlowRateValue = 5.0e-4 [m3/s];
        attribute isFunctional : Boolean = true;
        
        action def MeasureFlow {
            in fluidFlow : FlowRateValue;
            out reading : FlowRateValue;
            then if isFunctional {
                measuredFlowRate = fluidFlow;
                reading = measuredFlowRate;
                dataOut.flowReading = reading;
                dataOut.status = "ok";
            } else {
                dataOut.status = "fault";
            }
        }
    }
    
    part def ReliefValve {
        port inletPort : FluidPort;
        port ventPort : FluidPort;
        attribute safetyThreshold : PressureThresholdValue = 250e5 [Pa];
        attribute isOpen : Boolean = false;
        attribute ventFlowRate : FlowRateValue;
        
        action def MonitorPressure {
            in linePressure : PressureValue;
            then if linePressure >= safetyThreshold {
                isOpen = true;
                ventFlowRate = (linePressure - safetyThreshold) * 1e-9 [m3/s];
            } else {
                isOpen = false;
                ventFlowRate = 0 [m3/s];
            }
        }
    }
    
    part def PumpController {
        port commandPort : CommandPort;
        port suctionSensorPort : SensorDataPort;
        port dischargeSensorPort : SensorDataPort;
        port flowSensorPort : SensorDataPort;
        port motorControlOut : ControlSignalPort;
        port motorPowerOut : ElectricalPowerPort;
        
        attribute targetPressure : PressureValue;
        attribute targetFlowRate : FlowRateValue;
        attribute currentState : String = "idle";
        
        // PID parameters
        attribute Kp : Real = 2.0;
        attribute Ki : Real = 0.5;
        attribute Kd : Real = 0.1;
        attribute integralError : Real = 0.0;
        attribute previousError : Real = 0.0;
        attribute dt : Real = 0.01 [s];
        
        attribute computedMotorSpeed : AngularVelocityValue;
        attribute supplyVoltage : VoltageValue = 24 [V];
        attribute supplyCurrent : CurrentValue = 10 [A];
        
        action def ComputePID {
            in measuredPressure : PressureValue;
            in measuredFlow : FlowRateValue;
            in targetP : PressureValue;
            in targetQ : FlowRateValue;
            out motorCommand : AngularVelocityValue;
            
            attribute pressureError : Real;
            attribute flowError : Real;
            attribute derivativeError : Real;
            attribute combinedError : Real;
            
            then {
                pressureError = (targetP - measuredPressure) / targetP;
                flowError = (targetQ - measuredFlow) / targetQ;
                combinedError = 0.6 * pressureError + 0.4 * flowError;
                integralError = integralError + combinedError * dt;
                derivativeError = (combinedError - previousError) / dt;
                previousError = combinedError;
                motorCommand = Kp * combinedError + Ki * integralError + Kd * derivativeError;
                if motorCommand < 0 [rad/s] { motorCommand = 0 [rad/s]; }
                if motorCommand > 500 [rad/s] { motorCommand = 500 [rad/s]; }
            }
        }
        
        state machine ControllerStateMachine {
            
            state idle {
                entry {
                    currentState = "idle";
                    computedMotorSpeed = 0 [rad/s];
                    motorControlOut.motorSpeedCmd = 0 [rad/s];
                    motorControlOut.enable = false;
                }
                on commandPort.modeCommand == "prime" transition to priming;
                on commandPort.modeCommand == "flush" transition to flushing;
            }
            
            state priming {
                entry {
                    currentState = "priming";
                    computedMotorSpeed = 50 [rad/s];
                    motorControlOut.motorSpeedCmd = computedMotorSpeed;
                    motorControlOut.enable = true;
                }
                on commandPort.modeCommand == "pump" transition to pumping;
                on dischargeSensorPort.pressureReading > 1e5 [Pa] transition to pumping;
                on commandPort.modeCommand == "stop" transition to idle;
            }
            
            state pumping {
                entry {
                    currentState = "pumping";
                    targetPressure = commandPort.targetPressure;
                    targetFlowRate = commandPort.targetFlowRate;
                }
                
                do {
                    ComputePID(
                        dischargeSensorPort.pressureReading,
                        flowSensorPort.flowReading,
                        targetPressure,
                        targetFlowRate,
                        computedMotorSpeed
                    );
                    motorControlOut.motorSpeedCmd = computedMotorSpeed;
                    motorControlOut.enable = true;
                }
                
                on dischargeSensorPort.pressureReading >= 250e5 [Pa] transition to fault;
                on commandPort.modeCommand == "flush" transition to flushing;
                on commandPort.modeCommand == "stop" transition to idle;
            }
            
            state flushing {
                entry {
                    currentState = "flushing";
                    computedMotorSpeed = 100 [rad/s];
                    motorControlOut.motorSpeedCmd = computedMotorSpeed;
                    motorControlOut.enable = true;
                }
                on commandPort.modeCommand == "stop" transition to idle;
                on commandPort.modeCommand == "pump" transition to pumping;
            }
            
            state fault {
                entry {
                    currentState = "fault";
                    computedMotorSpeed = 0 [rad/s];
                    motorControlOut.motorSpeedCmd = 0 [rad/s];
                    motorControlOut.enable = false;
                }
                on commandPort.modeCommand == "reset" transition to idle;
            }
        }
        
        action def SupplyPower {
            then {
                motorPowerOut.voltage = supplyVoltage;
                motorPowerOut.current = supplyCurrent;
            }
        }
    }
    
    // ===== System Assembly =====
    
    part def InjectionPumpSystem {
        satisfy PressurizationRequirement;
        satisfy FlowRateRequirement;
        satisfy SafetyRequirement;
        satisfy StateTransitionRequirement;
        
        attribute dischargePressure : PressureValue;
        attribute deliveredFlowRate : FlowRateValue;
        attribute maxSystemPressure : PressureValue;
        
        part reservoir : SupplyReservoir {
            attribute currentLevel : Volume = 0.04 [m3];
        }
        
        part pump : InjectionPump;
        part manifold : DischargeManifold;
        part controller : PumpController;
        part suctionPressureSensor : PressureTransducer;
        part dischargePressureSensor : PressureTransducer;
        part flowMeter : FlowMeter;
        part reliefValve : ReliefValve;
        
        // Fluid connections
        connection reservoir.fluidOut to pump.suctionPort;
        connection pump.dischargePort to manifold.inletPort;
        connection pump.dischargePort to reliefValve.inletPort;
        connection manifold.outletPort1 to flowMeter.fluidPort;
        connection reliefValve.ventPort to reservoir.fluidOut;
        
        // Sensor connections
        connection pump.suctionPort to suctionPressureSensor.fluidPort;
        connection pump.dischargePort to dischargePressureSensor.fluidPort;
        connection suctionPressureSensor.dataOut to controller.suctionSensorPort;
        connection dischargePressureSensor.dataOut to controller.dischargeSensorPort;
        connection flowMeter.dataOut to controller.flowSensorPort;
        
        // Control connections
        connection controller.motorControlOut to pump.motorControlPort;
        connection controller.motorPowerOut to pump.motorPowerPort;
        
        // System-level behavior
        action def SystemOperation {
            in targetPressure : PressureValue;
            in targetFlowRate : FlowRateValue;
            in modeCommand : String;
            
            then {
                controller.commandPort.targetPressure = targetPressure;
                controller.commandPort.targetFlowRate = targetFlowRate;
                controller.commandPort.modeCommand = modeCommand;
                controller.ControllerStateMachine();
                controller.SupplyPower();
                pump.OperatePump(
                    controller.motorControlOut.motorSpeedCmd,
                    controller.motorControlOut.enable,
                    reservoir.fluidOut.fluid
                );
                manifold.DistributeFlow(pump.dischargePort.fluid);
                reliefValve.MonitorPressure(pump.dischargePort.pressure);
                dischargePressure = pump.dischargePressure;
                deliveredFlowRate = manifold.outletPort1.flowRate;
                maxSystemPressure = pump.dischargePressure;
            }
        }
    }
    
}
