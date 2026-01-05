package 'Piston Pumping Subsystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        attribute def Pressure :> Real;
        attribute def FlowRate :> Real;
        attribute def Frequency :> Real;
        attribute def Displacement :> Real;
        attribute def Volume :> Real;
        
        item def Fluid {
            attribute viscosity : Real;
            attribute density : Real;
            attribute temperature : Real;
        }
        
        port def FluidInPort {
            attribute pressure : Pressure;
            in item fluidSupply : Fluid;
            out item fluidReturn : Fluid;
        }
        
        port def FluidOutPort {
            attribute pressure : Pressure;
            out item fluidSupply : Fluid;
            in item fluidReturn : Fluid;
        }
        
        part def Piston {
            attribute diameter : Real;
            attribute stroke : Real;
            attribute position : Displacement;
            attribute maxDisplacement : Displacement;
        }
        
        part def Cylinder {
            attribute bore : Real;
            attribute volume : Volume;
            item chamberFluid : Fluid;
        }
        
        part def CheckValve {
            attribute crackingPressure : Pressure;
            attribute isOpen : Boolean;
            port inletPort : FluidInPort;
            port outletPort : FluidOutPort;
        }
        
        part def CrankshaftDrive {
            attribute rotationSpeed : Frequency;
            attribute eccentricity : Real;
        }
        
        action def IntakeStroke {
            in pistonPos : Displacement;
            out inletOpen : Boolean;
            out outletOpen : Boolean;
            
            first start;
            then action openInlet {
                out valveState : Boolean = true;
            }
            then action closeOutlet {
                out valveState : Boolean = false;
            }
            then action retractPiston {
                in currentPos : Displacement;
                out newPos : Displacement;
            }
            then done;
        }
        
        action def DischargeStroke {
            in pistonPos : Displacement;
            out inletOpen : Boolean;
            out outletOpen : Boolean;
            
            first start;
            then action closeInlet {
                out valveState : Boolean = false;
            }
            then action openOutlet {
                out valveState : Boolean = true;
            }
            then action advancePiston {
                in currentPos : Displacement;
                out newPos : Displacement;
            }
            then done;
        }
        
        action def PumpCycle {
            in strokeFreq : Frequency;
            out flowOutput : FlowRate;
            
            first start;
            then merge continueOperation;
            
            action intake : IntakeStroke {
                in pistonPos;
                out inletOpen;
                out outletOpen;
            }
            
            then action discharge : DischargeStroke {
                in pistonPos = intake.pistonPos;
                out inletOpen;
                out outletOpen;
            }
            
            then continueOperation;
        }
        
        item def StartCommand;
        item def PrimingComplete;
        item def PistonAtBottomDeadCenter;
        item def PistonAtTopDeadCenter;
        item def StopCommand;
        item def ShutdownComplete;
        
        state def PistonPumpStates {
            entry; then idle;
            
            state idle;
            
            transition idle_to_priming
                first idle
                accept StartCommand
                then priming;
            
            state priming;
            
            transition priming_to_operating
                first priming
                accept PrimingComplete
                then operating;
            
            state operating {
                entry; then intakePhase;
                
                state intakePhase;
                
                transition intake_to_discharge
                    first intakePhase
                    accept PistonAtBottomDeadCenter
                    then dischargePhase;
                
                state dischargePhase;
                
                transition discharge_to_intake
                    first dischargePhase
                    accept PistonAtTopDeadCenter
                    then intakePhase;
            }
            
            transition operating_to_shutdown
                first operating
                accept StopCommand
                then shutdown;
            
            state shutdown;
            
            transition shutdown_to_idle
                first shutdown
                accept ShutdownComplete
                then idle;
        }
        
        part def PistonPump {
            attribute operatingPressure : Pressure;
            attribute maxPressure : Pressure;
            attribute flowRate : FlowRate;
            attribute strokeFrequency : Frequency;
            
            port inletPort : FluidInPort;
            port outletPort : FluidOutPort;
            
            part piston : Piston {
                attribute :>> diameter = 50.0;
                attribute :>> stroke = 75.0;
                attribute :>> maxDisplacement = 75.0;
            }
            
            part cylinder : Cylinder {
                attribute :>> bore = 50.0;
                attribute :>> volume = 147.26;
            }
            
            part inletValve : CheckValve {
                attribute :>> crackingPressure = 2.0;
            }
            
            part outletValve : CheckValve {
                attribute :>> crackingPressure = 3.0;
            }
            
            part drive : CrankshaftDrive {
                attribute :>> rotationSpeed = 10.0;
                attribute :>> eccentricity = 37.5;
            }
            
            flow from inletPort.fluidSupply to inletValve.inletPort.fluidSupply;
            flow from inletValve.outletPort.fluidSupply to cylinder.chamberFluid;
            flow from cylinder.chamberFluid to outletValve.inletPort.fluidSupply;
            flow from outletValve.outletPort.fluidSupply to outletPort.fluidSupply;
            
            perform action pumpOperation : PumpCycle {
                in strokeFreq = strokeFrequency;
                out flowOutput = flowRate;
            }
            
            exhibit state pistonPumpBehavior : PistonPumpStates;
        }
        
        part def FluidReservoir {
            attribute capacity : Volume;
            attribute currentLevel : Volume;
            port reservoirPort : FluidOutPort;
            item storedFluid : Fluid;
        }
        
        part def FluidReceiver {
            attribute capacity : Volume;
            attribute currentLevel : Volume;
            attribute targetPressure : Pressure;
            port receiverPort : FluidInPort;
            item receivedFluid : Fluid;
        }
        
        interface def FluidInterface {
            end port supplierPort : FluidOutPort;
            end port consumerPort : FluidInPort;
        }
        
        requirement def PumpPerformanceRequirement {
            subject pump : PistonPump;
            
            require constraint {
                pump.flowRate >= 10.0 and pump.flowRate <= 100.0
            }
            
            require constraint {
                pump.operatingPressure <= pump.maxPressure
            }
            
            require constraint {
                pump.maxPressure <= 200.0
            }
        }
        
        requirement def ValveOperationRequirement {
            subject valve : CheckValve;
            
            require constraint {
                valve.crackingPressure > 0.0 and valve.crackingPressure < 5.0
            }
        }
    }
    
    package Usages {
        part pumpingSystem {
            part reservoir : Definitions::FluidReservoir {
                attribute :>> capacity = 50.0;
                attribute :>> currentLevel = 45.0;
            }
            
            part pistonPump : Definitions::PistonPump {
                attribute :>> operatingPressure = 150.0;
                attribute :>> maxPressure = 200.0;
                attribute :>> flowRate = 50.0;
                attribute :>> strokeFrequency = 10.0;
            }
            
            part receiver : Definitions::FluidReceiver {
                attribute :>> capacity = 100.0;
                attribute :>> currentLevel = 25.0;
                attribute :>> targetPressure = 150.0;
            }
            
            interface : Definitions::FluidInterface connect
                supplierPort ::> reservoir.reservoirPort to
                consumerPort ::> pistonPump.inletPort;
            
            interface : Definitions::FluidInterface connect
                supplierPort ::> pistonPump.outletPort to
                consumerPort ::> receiver.receiverPort;
            
            satisfy performanceReq : Definitions::PumpPerformanceRequirement {
                subject pump = pistonPump;
            }
            
            satisfy inletValveReq : Definitions::ValveOperationRequirement {
                subject valve = pistonPump.inletValve;
            }
            
            satisfy outletValveReq : Definitions::ValveOperationRequirement {
                subject valve = pistonPump.outletValve;
            }
        }
    }
}
