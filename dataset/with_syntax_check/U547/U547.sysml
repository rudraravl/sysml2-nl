package PumpingSubsystemModel {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    package Definitions {
        item def Fluid {
            attribute density : Real;
            attribute viscosity : Real;
            attribute temperature : Real;
            attribute volume : VolumeValue;
        }
        
        attribute def VolumeValue :> Real;
        attribute def PressureValue :> Real;
        attribute def FlowRateValue :> Real;
        attribute def PowerValue :> Real;
        
        port def FluidPort {
            out item fluidOut : Fluid;
            attribute pressure : PressureValue;
            attribute flowRate : FlowRateValue;
        }
        
        port def FluidInletPort :> ~FluidPort {
            in item fluidIn : Fluid;
        }
        
        port def FluidOutletPort :> FluidPort;
        
        port def PowerPort {
            in attribute powerIn : PowerValue;
        }
        
        port def ControlPort {
            in attribute commandedFlowRate : FlowRateValue;
            out attribute actualFlowRate : FlowRateValue;
            out attribute status : PumpStatus;
        }
        
        enum def PumpStatus {
            enum off;
            enum starting;
            enum running;
            enum stopping;
            enum fault;
        }
        
        part def Motor {
            port powerPort : PowerPort;
            attribute ratedPower : PowerValue;
            attribute efficiency : Real;
            attribute currentSpeed : Real;
        }
        
        part def Impeller {
            attribute diameter : Real;
            attribute bladeCount : Integer;
            attribute rotationalSpeed : Real;
        }
        
        part def PumpHousing {
            port inletPort : FluidInletPort;
            port outletPort : FluidOutletPort;
            attribute inletDiameter : Real;
            attribute outletDiameter : Real;
        }
        
        part def PressureSensor {
            in attribute measuredPressure : PressureValue;
            out attribute pressureReading : PressureValue;
        }
        
        part def FlowSensor {
            in attribute measuredFlow : FlowRateValue;
            out attribute flowReading : FlowRateValue;
        }
        
        part def PumpController {
            port controlPort : ControlPort;
            attribute setPoint : FlowRateValue;
            attribute currentState : PumpStatus;
        }
        
        part def PumpDispenser {
            port inletPort : FluidInletPort;
            port outletPort : FluidOutletPort;
            port powerPort : PowerPort;
            port controlPort : ControlPort;
            
            part motor : Motor;
            part impeller : Impeller;
            part housing : PumpHousing;
            part inletSensor : PressureSensor;
            part outletSensor : PressureSensor;
            part flowSensor : FlowSensor;
            part controller : PumpController;
            
            attribute maxFlowRate : FlowRateValue;
            attribute maxPressure : PressureValue;
            attribute operatingTemperatureRange : Real[2];
            
            bind inletPort = housing.inletPort;
            bind outletPort = housing.outletPort;
            
            perform action pumpOperation : PumpOperation;
            exhibit state pumpStateMachine : PumpStateMachine;
        }
        
        part def FluidReservoir {
            port outletPort : FluidOutletPort;
            attribute capacity : VolumeValue;
            attribute currentLevel : VolumeValue;
            item storedFluid : Fluid;
        }
        
        part def DischargePoint {
            port inletPort : FluidInletPort;
            attribute targetPressure : PressureValue;
        }
        
        part def PipingSegment {
            port inPort : FluidInletPort;
            port outPort : FluidOutletPort;
            attribute length : Real;
            attribute diameter : Real;
            attribute roughness : Real;
        }
        
        action def PumpOperation {
            in fluidIn : Fluid;
            in powerIn : PowerValue;
            in commandedRate : FlowRateValue;
            out fluidOut : Fluid;
            out actualRate : FlowRateValue;
            out operatingStatus : PumpStatus;
            
            first start;
            then action initializePump : InitializePump;
            then merge operationLoop;
            then action monitorConditions : MonitorConditions {
                in currentFluid : Fluid = fluidIn;
                out pressureDelta : PressureValue;
                out flowRate : FlowRateValue;
            }
            then decide;
                if monitorConditions.flowRate < commandedRate then increasePower;
                if monitorConditions.flowRate >= commandedRate then maintainPower;
            action increasePower : AdjustPower {
                in adjustment = 1.1;
            }
            then operationLoop;
            action maintainPower : AdjustPower {
                in adjustment = 1.0;
            }
            then operationLoop;
        }
        
        action def InitializePump {
            first start;
            then action checkPreConditions;
            then action primePump;
            then action startMotor;
            then done;
        }
        
        action def MonitorConditions {
            in currentFluid : Fluid;
            out pressureDelta : PressureValue;
            out flowRate : FlowRateValue;
        }
        
        action def AdjustPower {
            in adjustment : Real;
        }
        
        state def PumpStateMachine {
            entry; then idle;
            
            state idle;
            transition idle_to_starting
                first idle
                accept StartCommand
                then starting;
            
            state starting {
                entry; then priming;
                state priming;
                transition priming_to_accelerating
                    first priming
                    if isPrimed
                    then accelerating;
                state accelerating;
                transition accelerating_done
                    first accelerating
                    if isAtSpeed
                    then done;
            }
            transition starting_to_running
                first starting
                then running;
            
            state running {
                entry; then normalOperation;
                state normalOperation;
                state adjustingFlow;
                transition normal_to_adjusting
                    first normalOperation
                    accept FlowAdjustCommand
                    then adjustingFlow;
                transition adjusting_to_normal
                    first adjustingFlow
                    if flowStabilized
                    then normalOperation;
            }
            
            transition running_to_stopping
                first running
                accept StopCommand
                then stopping;
            
            transition any_to_fault
                first idle
                accept FaultDetected
                then fault;
            
            state stopping {
                entry; then decelerating;
                state decelerating;
                transition decelerating_done
                    first decelerating
                    if isStopped
                    then done;
            }
            transition stopping_to_idle
                first stopping
                then idle;
            
            state fault;
            transition fault_to_idle
                first fault
                accept ResetCommand
                if faultCleared
                then idle;
        }
        
        requirement def PumpingSystemRequirements {
            doc /* The pumping subsystem shall move fluid from source to destination. */
            
            requirement flowRateRequirement {
                doc /* The pump shall deliver fluid at the commanded flow rate within 5% tolerance. */
                subject pump : PumpDispenser;
                require constraint {
                    (pump.flowSensor.flowReading - pump.controlPort.commandedFlowRate).abs() 
                    <= 0.05 * pump.controlPort.commandedFlowRate
                }
            }
            
            requirement pressureRequirement {
                doc /* The pump shall maintain outlet pressure above minimum threshold. */
                subject pump : PumpDispenser;
                attribute minPressure : PressureValue;
                require constraint {
                    pump.outletSensor.pressureReading >= minPressure
                }
            }
            
            requirement reliabilityRequirement {
                doc /* The pump shall operate continuously for minimum 10000 hours. */
                subject pump : PumpDispenser;
                attribute minOperatingHours : Real = 10000.0;
            }
            
            requirement efficiencyRequirement {
                doc /* The pump motor efficiency shall exceed 85%. */
                subject motor : Motor;
                require constraint {
                    motor.efficiency >= 0.85
                }
            }
        }
    }
    
    package Usages {
        part pumpingSubsystem {
            part sourceReservoir : Definitions::FluidReservoir {
                attribute :>> capacity = 5000.0;
                attribute :>> currentLevel = 4500.0;
                item :>> storedFluid : Definitions::Fluid {
                    attribute :>> density = 1000.0;
                    attribute :>> viscosity = 0.001;
                    attribute :>> temperature = 20.0;
                    attribute :>> volume = 4500.0;
                }
            }
            
            part supplyPipe : Definitions::PipingSegment {
                attribute :>> length = 10.0;
                attribute :>> diameter = 0.15;
                attribute :>> roughness = 0.00015;
            }
            
            part pumpDispenser : Definitions::PumpDispenser {
                attribute :>> maxFlowRate = 100.0;
                attribute :>> maxPressure = 500000.0;
                attribute :>> operatingTemperatureRange = (0.0, 60.0);
                
                part :>> motor {
                    attribute :>> ratedPower = 15000.0;
                    attribute :>> efficiency = 0.90;
                    attribute :>> currentSpeed = 0.0;
                }
                
                part :>> impeller {
                    attribute :>> diameter = 0.25;
                    attribute :>> bladeCount = 6;
                    attribute :>> rotationalSpeed = 0.0;
                }
                
                part :>> controller {
                    attribute :>> setPoint = 75.0;
                    attribute :>> currentState = Definitions::PumpStatus::off;
                }
                
                perform action :>> pumpOperation : Definitions::PumpOperation {
                    in :>> fluidIn = inletPort.fluidIn;
                    in :>> powerIn = powerPort.powerIn;
                    in :>> commandedRate = controlPort.commandedFlowRate;
                    out :>> fluidOut = outletPort.fluidOut;
                    out :>> actualRate = controlPort.actualFlowRate;
                    out :>> operatingStatus = controlPort.status;
                }
            }
            
            part dischargePipe : Definitions::PipingSegment {
                attribute :>> length = 15.0;
                attribute :>> diameter = 0.15;
                attribute :>> roughness = 0.00015;
            }
            
            part destination : Definitions::DischargePoint {
                attribute :>> targetPressure = 400000.0;
            }
            
            flow of fluid : Definitions::Fluid
                from sourceReservoir.outletPort.fluidOut 
                to supplyPipe.inPort.fluidIn;
            
            flow of fluid : Definitions::Fluid
                from supplyPipe.outPort.fluidOut 
                to pumpDispenser.inletPort.fluidIn;
            
            flow of fluid : Definitions::Fluid
                from pumpDispenser.outletPort.fluidOut 
                to dischargePipe.inPort.fluidIn;
            
            flow of fluid : Definitions::Fluid
                from dischargePipe.outPort.fluidOut 
                to destination.inletPort.fluidIn;
            
            satisfy requirement systemRequirements : Definitions::PumpingSystemRequirements {
                subject pumpDispenser;
            }
        }
    }
}
