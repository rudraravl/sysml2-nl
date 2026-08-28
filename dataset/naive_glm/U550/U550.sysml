package HydraulicPumpingSubsystem {
    import ScalarValues::*;
    
    // ---- Value Types with Units ----
    value def Pressure :> Real { unit 'Pa'; }
    value def FlowRate :> Real { unit 'm3/s'; }
    value def Temperature :> Real { unit 'K'; }
    value def RotationalSpeed :> Real { unit 'rad/s'; }
    value def Torque :> Real { unit 'N*m'; }
    value def Volume :> Real { unit 'm3'; }
    value def Voltage :> Real { unit 'V'; }
    value def Current :> Real { unit 'A'; }
    value def Frequency :> Real { unit 'Hz'; }
    value def Power :> Real { unit 'W'; }
    value def Length :> Real { unit 'm'; }
    value def MassDensity :> Real { unit 'kg/m3'; }
    value def DynamicViscosity :> Real { unit 'Pa*s'; }
    
    // ---- Item Definitions ----
    item def HydraulicFluid {
        attribute density : MassDensity = 850 [kg/m3];
        attribute viscosity : DynamicViscosity = 0.04 [Pa*s];
        attribute bulkModulus : Pressure = 1.6e9 [Pa];
    }
    
    item def PressurizedFluid :> HydraulicFluid {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
    }
    
    // ---- Port Definitions ----
    port def FluidPort {
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
        attribute temperature : Temperature;
        item fluid : HydraulicFluid;
    }
    
    port def MechanicalPort {
        attribute torque : Torque;
        attribute speed : RotationalSpeed;
    }
    
    port def ElectricalPort {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute frequency : Frequency;
    }
    
    port def SignalPort {
        attribute value : Real;
        attribute unit : String;
    }
    
    // ---- Enumerations ----
    enum def OperationalState {
        startup;
        priming;
        normalOperation;
        shutdown;
        fault;
    }
    
    enum def FaultType {
        none;
        overpressure;
        highTemperature;
        cavitation;
    }
    
    // ---- Requirement Definitions ----
    requirement def PressurizeFluidRequirement {
        doc /* The subsystem shall generate and deliver a controlled flow of pressurized hydraulic fluid for use in industrial machinery. */
        attribute maxPressure : Pressure = 30e6 [Pa];
        attribute nominalFlowRate : FlowRate = 5e-4 [m3/s];
        attribute minPressure : Pressure = 20e6 [Pa];
        subject subsystem : HydraulicPumpingSubsystem;
        require { subsystem.outputPort.pressure >= minPressure; }
        require { subsystem.outputPort.pressure <= maxPressure; }
        require { subsystem.outputPort.flowRate >= nominalFlowRate; }
    }
    
    requirement def SafetyMonitoringRequirement {
        doc /* The subsystem shall detect overpressure, high temperature, and cavitation fault conditions and enter a safe fault state. */
        attribute overpressureThreshold : Pressure = 32e6 [Pa];
        attribute highTempThreshold : Temperature = 353.15 [K];
        attribute cavitationPressureThreshold : Pressure = 0.5e5 [Pa];
        subject subsystem : HydraulicPumpingSubsystem;
        require { subsystem.systemPressure > overpressureThreshold implies subsystem.currentState == OperationalState::fault; }
        require { subsystem.fluidTemperature > highTempThreshold implies subsystem.currentState == OperationalState::fault; }
        require { subsystem.cavitationDetected == true implies subsystem.currentState == OperationalState::fault; }
    }
    
    requirement def SmoothFlowRequirement {
        doc /* The subsystem shall dampen pressure pulses from individual piston strokes and provide a smooth, consistent output flow. */
        attribute maxPressureRipple : Pressure = 1e6 [Pa];
        subject subsystem : HydraulicPumpingSubsystem;
        require { subsystem.pressureRipple <= maxPressureRipple; }
    }
    
    requirement def StartupSequenceRequirement {
        doc /* The subsystem shall execute a startup sequence including priming to ensure the pump is full of fluid before normal operation. */
        subject subsystem : HydraulicPumpingSubsystem;
        require { subsystem.currentState == OperationalState::startup implies subsystem.currentState' == OperationalState::priming; }
        require { subsystem.currentState == OperationalState::priming implies subsystem.currentState' == OperationalState::normalOperation; }
    }
    
    // ---- Component Part Definitions ----
    
    part def FluidReservoir {
        port outlet : FluidPort;
        port returnInlet : FluidPort;
        attribute capacity : Volume = 0.05 [m3];
        attribute currentVolume : Volume = 0.045 [m3];
        attribute fluid : HydraulicFluid;
        attribute ambientPressure : Pressure = 1.01325e5 [Pa];
        
        action def SupplyFluid {
            in requestFlow : FlowRate;
            out suppliedFluid : HydraulicFluid;
            out supplyPressure : Pressure;
        }
        
        action def ReceiveReturnFluid {
            in returnFluid : HydraulicFluid;
            out newVolume : Volume;
        }
    }
    
    part def ElectricMotor {
        port electricalIn : ElectricalPort;
        port mechanicalOut : MechanicalPort;
        attribute ratedPower : Power = 15000 [W];
        attribute ratedSpeed : RotationalSpeed = 157.08 [rad/s];
        attribute ratedTorque : Torque = 95.49 [N*m];
        attribute ratedVoltage : Voltage = 400 [V];
        attribute ratedCurrent : Current = 26 [A];
        attribute supplyFrequency : Frequency = 50 [Hz];
        attribute efficiency : Real = 0.93;
        attribute isEnergized : Boolean = false;
        
        action def Drive {
            in inputVoltage : Voltage;
            in inputCurrent : Current;
            in inputFrequency : Frequency;
            out outputTorque : Torque;
            out outputSpeed : RotationalSpeed;
        }
        
        action def RampUp {
            in targetSpeed : RotationalSpeed;
            in rampDuration : Real = 5.0 [s];
            out currentSpeed : RotationalSpeed;
        }
    }
    
    part def CheckValve {
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute crackingPressure : Pressure = 5000 [Pa];
        attribute isOpen : Boolean = false;
        attribute flowCoefficient : Real = 0.8;
        
        action def RegulateFlow {
            in inletPressure : Pressure;
            in outletPressure : Pressure;
            in fluid : HydraulicFluid;
            out flowRate : FlowRate;
            out valveState : Boolean;
        }
    }
    
    part def PistonCylinder {
        port intakePort : FluidPort;
        port dischargePort : FluidPort;
        attribute boreDiameter : Length = 0.02 [m];
        attribute strokeLength : Length = 0.015 [m];
        attribute displacement : Volume = 4.712e-6 [m3];
        attribute currentPressure : Pressure;
        attribute cylinderID : Integer;
        
        part intakeValve : CheckValve {
            attribute crackingPressure : Pressure = 2000 [Pa];
        }
        
        part dischargeValve : CheckValve {
            attribute crackingPressure : Pressure = 5000 [Pa];
        }
        
        connection intakeConnect connect intakePort to intakeValve.inlet;
        connection intakeToCylinder connect intakeValve.outlet to dischargeValve.inlet;
        connection dischargeConnect connect dischargeValve.outlet to dischargePort;
        
        action def IntakeStroke {
            in lowPressureFluid : HydraulicFluid;
            in camPosition : Real;
            out drawnVolume : Volume;
            
            perform action drawFluid {
                in fluid : HydraulicFluid;
                out volume : Volume;
            }
        }
        
        action def CompressionStroke {
            in fluidVolume : Volume;
            in camPosition : Real;
            out pressurizedFluid : PressurizedFluid;
            
            perform action compressFluid {
                in volume : Volume;
                out fluid : PressurizedFluid;
            }
            
            perform action expelFluid {
                in fluid : PressurizedFluid;
                out dischargedFluid : PressurizedFluid;
            }
        }
    }
    
    part def RadialPistonPump {
        port driveInput : MechanicalPort;
        port suctionPort : FluidPort;
        port dischargePort : FluidPort;
        
        attribute numberOfPistons : Integer = 7;
        attribute eccentricity : Length = 0.0075 [m];
        attribute theoreticalDisplacementPerRev : Volume = 3.298e-5 [m3];
        attribute volumetricEfficiency : Real = 0.95;
        attribute actualFlowRate : FlowRate;
        attribute dischargePressure : Pressure;
        attribute suctionPressure : Pressure;
        attribute pumpSpeed : RotationalSpeed;
        attribute isPrimed : Boolean = false;
        
        part driveShaft {
            attribute speed : RotationalSpeed;
            attribute torque : Torque;
        }
        
        part camRing {
            attribute eccentricOffset : Length = 0.0075 [m];
            attribute rotationAngle : Real;
        }
        
        part cylinders[7] : PistonCylinder {
            attribute cylinderID : Integer = index;
        }
        
        connection driveToShaft connect driveInput to driveShaft;
        connection shaftToCam connect driveShaft to camRing;
        connection suctionToCylinders connect suctionPort to cylinders[*].intakePort;
        connection cylindersToDischarge connect cylinders[*].dischargePort to dischargePort;
        
        action def PumpCycle {
            in driveTorque : Torque;
            in driveSpeed : RotationalSpeed;
            in suctionFluid : HydraulicFluid;
            out dischargeFluid : PressurizedFluid;
            
            perform action intakePhase {
                in fluid : HydraulicFluid;
                in speed : RotationalSpeed;
                out drawnFluid : HydraulicFluid;
            }
            
            perform action compressionPhase {
                in fluid : HydraulicFluid;
                in speed : RotationalSpeed;
                out pressurizedFluid : PressurizedFluid;
            }
            
            then intakePhase;
            then compressionPhase;
        }
        
        action def PrimePump {
            in lowSpeed : RotationalSpeed = 15.708 [rad/s];
            in suctionFluid : HydraulicFluid;
            out primed : Boolean;
        }
    }
    
    part def Accumulator {
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute totalVolume : Volume = 0.002 [m3];
        attribute prechargePressure : Pressure = 15e6 [Pa];
        attribute gasVolume : Volume;
        attribute fluidVolume : Volume;
        attribute currentPressure : Pressure;
        attribute gasConstant : Real = 1.4;
        
        action def DampenPulses {
            in inflow : PressurizedFluid;
            out outflow : PressurizedFluid;
            
            perform action absorbPulse {
                in fluid : PressurizedFluid;
                out storedFluid : PressurizedFluid;
            }
            
            perform action releaseFluid {
                in storedFluid : PressurizedFluid;
                out outflow : PressurizedFluid;
            }
        }
        
        action def EqualizePressure {
            in systemPressure : Pressure;
            out regulatedPressure : Pressure;
        }
    }
    
    part def ReliefValve {
        port inlet : FluidPort;
        port outlet : FluidPort;
        port controlPort : SignalPort;
        attribute setPressure : Pressure = 32e6 [Pa];
        attribute isOpen : Boolean = false;
        attribute flowCapacity : FlowRate = 1e-3 [m3/s];
        attribute responseTime : Real = 0.01 [s];
        
        action def MonitorPressure {
            in systemPressure : Pressure;
            in controlSignal : Real;
            out valveOpen : Boolean;
        }
        
        action def DivertFluid {
            in fluid : PressurizedFluid;
            out divertedFluid : HydraulicFluid;
        }
        
        action def Close {
            out valveOpen : Boolean = false;
        }
    }
    
    part def PressureTransducer {
        port fluidPort : FluidPort;
        port signalOut : SignalPort;
        attribute range : Pressure = 40e6 [Pa];
        attribute accuracy : Real = 0.005;
        attribute outputSignal : Real;
        
        action def MeasurePressure {
            in fluid : HydraulicFluid;
            in measuredPressure : Pressure;
            out pressureSignal : Real;
        }
    }
    
    part def FlowMeter {
        port fluidPort : FluidPort;
        port signalOut : SignalPort;
        attribute range : FlowRate = 2e-3 [m3/s];
        attribute accuracy : Real = 0.01;
        attribute outputSignal : Real;
        
        action def MeasureFlow {
            in fluid : HydraulicFluid;
            in measuredFlow : FlowRate;
            out flowSignal : Real;
        }
    }
    
    part def TemperatureSensor {
        port fluidPort : FluidPort;
        port signalOut : SignalPort;
        attribute range : Temperature = 423.15 [K];
        attribute accuracy : Real = 0.5;
        attribute outputSignal : Real;
        
        action def MeasureTemperature {
            in fluid : HydraulicFluid;
            in measuredTemp : Temperature;
            out tempSignal : Real;
        }
    }
    
    part def PumpController {
        port pressureInput : SignalPort;
        port flowInput : SignalPort;
        port tempInput : SignalPort;
        port motorControlOut : ElectricalPort;
        port reliefValveControlOut : SignalPort;
        port commandInput : SignalPort;
        port statusOutput : SignalPort;
        
        attribute overpressureThreshold : Pressure = 32e6 [Pa];
        attribute highTempThreshold : Temperature = 353.15 [K];
        attribute cavitationPressureThreshold : Pressure = 0.5e5 [Pa];
        attribute nominalFlowRate : FlowRate = 5e-4 [m3/s];
        attribute cavitationDetected : Boolean = false;
        attribute currentFault : FaultType = FaultType::none;
        attribute motorVoltage : Voltage = 400 [V];
        attribute motorFrequency : Frequency = 50 [Hz];
        attribute primingSpeed : RotationalSpeed = 15.708 [rad/s];
        attribute ratedSpeed : RotationalSpeed = 157.08 [rad/s];
        
        action def ProcessSensorData {
            in pressureValue : Real;
            in flowValue : Real;
            in tempValue : Real;
            out detectedFault : FaultType;
            out motorCommand : Voltage;
            out reliefCommand : Boolean;
        }
        
        action def EvaluateFaults {
            in pressure : Pressure;
            in temperature : Temperature;
            in flow : FlowRate;
            out faultType : FaultType;
            out cavitation : Boolean;
        }
        
        action def GenerateMotorCommand {
            in targetState : OperationalState;
            out voltage : Voltage;
            out frequency : Frequency;
        }
        
        state machine controllerStates {
            state startup {
                entry action InitializeController {
                    out motorVoltage = 0 [V];
                    out currentFault = FaultType::none;
                }
                do action CheckSensors {
                    in pressureInput;
                    in flowInput;
                    in tempInput;
                }
            }
            
            state priming {
                entry action StartPrimingMode {
                    out motorVoltage = 200 [V];
                    out motorFrequency = 20 [Hz];
                }
                do action MonitorPriming {
                    in flowInput;
                    in pressureInput;
                }
            }
            
            state normalOperation {
                entry action EnterNormalMode {
                    out motorVoltage = 400 [V];
                    out motorFrequency = 50 [Hz];
                }
                do action ContinuousMonitoring {
                    in pressureInput;
                    in flowInput;
                    in tempInput;
                    out statusOutput;
                }
            }
            
            state shutdown {
                entry action InitiateShutdown {
                    out motorVoltage = 0 [V];
                    out reliefCommand = true;
                }
                do action DepressurizeSequence {
                    in pressureInput;
                }
            }
            
            state fault {
                entry action EnterSafeFaultState {
                    out motorVoltage = 0 [V];
                    out reliefCommand = true;
                    out statusOutput = currentFault;
                }
                do action AwaitReset {
                    in commandInput;
                }
            }
            
            transition startup_to_priming
                source startup
                target priming
                when { pressureInput.value > 0.5e5 }
                accept StartPriming;
            
            transition priming_to_normal
                source priming
                target normalOperation
                when { flowInput.value > 0.8 * nominalFlowRate }
                accept PrimingComplete;
            
            transition normal_to_fault_overpressure
                source normalOperation
                target fault
                when { pressureInput.value > 32e6 }
                accept OverpressureFault;
            
            transition normal_to_fault_hightemp
                source normalOperation
                target fault
                when { tempInput.value > 353.15 }
                accept HighTemperatureFault;
            
            transition normal_to_fault_cavitation
                source normalOperation
                target fault
                when { pressureInput.value < 0.5e5 }
                accept CavitationFault;
            
            transition normal_to_shutdown
                source normalOperation
                target shutdown
                accept ShutdownCommand;
            
            transition fault_to_shutdown
                source fault
                target shutdown
                accept ShutdownCommand;
            
            transition shutdown_to_startup
                source shutdown
                target startup
                accept RestartCommand;
        }
    }
    
    // ---- Main Subsystem Definition ----
    part def HydraulicPumpingSubsystem {
        port outputPort : FluidPort;
        port electricalInput : ElectricalPort;
        port commandInput : SignalPort;
        port statusOutput : SignalPort;
        
        attribute systemPressure : Pressure;
        attribute systemFlowRate : FlowRate;
        attribute fluidTemperature : Temperature;
        attribute pressureRipple : Pressure;
        attribute currentState : OperationalState = OperationalState::startup;
        attribute nominalFlowRate : FlowRate = 5e-4 [m3/s];
        attribute cavitationDetected : Boolean = false;
        attribute activeFault : FaultType = FaultType::none;
        attribute maxOperatingPressure : Pressure = 30e6 [Pa];
        attribute safePressureLimit : Pressure = 32e6 [Pa];
        attribute maxOperatingTemp : Temperature = 353.15 [K];
        
        // Component parts
        part reservoir : FluidReservoir {
            attribute capacity : Volume = 0.05 [m3];
            attribute currentVolume : Volume = 0.045 [m3];
        }
        
        part motor : ElectricMotor {
            attribute ratedPower : Power = 15000 [W];
            attribute ratedSpeed : RotationalSpeed = 157.08 [rad/s];
        }
        
        part pump : RadialPistonPump {
            attribute numberOfPistons : Integer = 7;
            attribute eccentricity : Length = 0.0075 [m];
        }
        
        part accumulator : Accumulator {
            attribute totalVolume : Volume = 0.002 [m3];
            attribute prechargePressure : Pressure = 15e6 [Pa];
        }
        
        part reliefValve : ReliefValve {
            attribute setPressure : Pressure = 32e6 [Pa];
        }
        
        part pressureTransducer : PressureTransducer;
        part flowMeter : FlowMeter;
        part temperatureSensor : TemperatureSensor;
        part controller : PumpController;
        
        // Internal connections
        connection electricalPower connect electricalInput to motor.electricalIn;
        connection motorControlFromController connect controller.motorControlOut to motor.electricalIn;
        connection mechanicalDrive connect motor.mechanicalOut to pump.driveInput;
        connection suctionLine connect reservoir.outlet to pump.suctionPort;
        connection pumpDischarge connect pump.dischargePort to accumulator.inlet;
        connection accumulatorOutput connect accumulator.outlet to outputPort;
        connection reliefTap connect accumulator.inlet to reliefValve.inlet;
        connection reliefReturn connect reliefValve.outlet to reservoir.returnInlet;
        connection pressureSensingTap connect accumulator.outlet to pressureTransducer.fluidPort;
        connection flowSensingTap connect outputPort to flowMeter.fluidPort;
        connection tempSensingTap connect accumulator.outlet to temperatureSensor.fluidPort;
        connection pressureSignalConnection connect pressureTransducer.signalOut to controller.pressureInput;
        connection flowSignalConnection connect flowMeter.signalOut to controller.flowInput;
        connection tempSignalConnection connect temperatureSensor.signalOut to controller.tempInput;
        connection reliefControlConnection connect controller.reliefValveControlOut to reliefValve.controlPort;
        connection commandConnection connect commandInput to controller.commandInput;
        connection statusConnection connect controller.statusOutput to statusOutput;
        
        // Subsystem state machine
        state machine subsystemStates {
            state startup {
                entry action InitializeSystem {
                    out currentState = OperationalState::startup;
                    out activeFault = FaultType::none;
                }
                do action RampUpMotor {
                    in motor;
                    out pumpSpeed : RotationalSpeed;
                }
            }
            
            state priming {
                entry action BeginPriming {
                    out currentState = OperationalState::priming;
                }
                do action PrimePumpCylinders {
                    in pump;
                    in reservoir;
                    out isPrimed : Boolean;
                }
                exit action VerifyPrimingComplete {
                    in systemFlowRate;
                    out primingConfirmed : Boolean;
                }
            }
            
            state normalOperation {
                entry action EnterNormalOperation {
                    out currentState = OperationalState::normalOperation;
                }
                do action MonitorAndControl {
                    in systemPressure;
                    in systemFlowRate;
                    in fluidTemperature;
                    out motorAdjustments;
                    out reliefValveCommands;
                }
            }
            
            state shutdown {
                entry action BeginShutdown {
                    out currentState = OperationalState::shutdown;
                }
                do action ReduceMotorSpeed {
                    in motor;
                    out currentSpeed : RotationalSpeed;
                }
                do action DepressurizeSystem {
                    in reliefValve;
                    in accumulator;
                    out systemPressure;
                }
                exit action PowerOffMotor {
                    in motor;
                    out isEnergized : Boolean = false;
                }
            }
            
            state fault {
                entry action EnterSafeState {
                    out currentState = OperationalState::fault;
                    out motor.isEnergized = false;
                    out reliefValve.isOpen = true;
                }
                do action AwaitManualIntervention {
                    in commandInput;
                    out readyForReset : Boolean;
                }
            }
            
            transition startup_to_priming
                source startup
                target priming
                when { systemPressure > 0.5e5 }
                accept StartPrimingCommand;
            
            transition priming_to_normal
                source priming
                target normalOperation
                when { systemFlowRate > 0.8 * nominalFlowRate }
                accept PrimingComplete;
            
            transition normal_to_fault_overpressure
                source normalOperation
                target fault
                when { systemPressure > 32e6 }
                accept OverpressureFault {
                    out activeFault = FaultType::overpressure;
                }
            
            transition normal_to_fault_hightemp
                source normalOperation
                target fault
                when { fluidTemperature > 353.15 }
                accept HighTemperatureFault {
                    out activeFault = FaultType::highTemperature;
                }
            
            transition normal_to_fault_cavitation
                source normalOperation
                target fault
                when { systemPressure < 0.5e5 }
                accept CavitationFault {
                    out activeFault = FaultType::cavitation;
                    out cavitationDetected = true;
                }
            
            transition normal_to_shutdown
                source normalOperation
                target shutdown
                accept ShutdownCommand;
            
            transition fault_to_shutdown
                source fault
                target shutdown
                accept ShutdownCommand;
            
            transition shutdown_to_startup
                source shutdown
                target startup
                accept RestartCommand;
        }
        
        // Requirements
        requirement pressurizeFluidReq : PressurizeFluidRequirement;
        requirement safetyMonitoringReq : SafetyMonitoringRequirement;
        requirement smoothFlowReq : SmoothFlowRequirement;
        requirement startupSeqReq : StartupSequenceRequirement;
        
        satisfy pressurizeFluidReq;
        satisfy safetyMonitoringReq;
        satisfy smoothFlowReq;
        satisfy startupSeqReq;
    }
}
