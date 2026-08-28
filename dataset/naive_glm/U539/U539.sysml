package PistonPumpSystem {
    import ISQ::*;
    import ScalarValues::*;
    
    // ===== Value Types =====
    value def PressureValue :> Real {
        unit 'Pa';
    }
    value def VolumeValue :> Real {
        unit 'm3';
    }
    value def FlowRateValue :> Real {
        unit 'm3/s';
    }
    value def RotationalSpeedValue :> Real {
        unit 'rad/s';
    }
    value def LinearPositionValue :> Real {
        unit 'm';
    }
    value def ForceValue :> Real {
        unit 'N';
    }
    value def TorqueValue :> Real {
        unit 'N*m';
    }
    value def AngularPositionValue :> Real {
        unit 'rad';
    }
    
    // ===== Items =====
    item def HydraulicFluid;
    
    // ===== Enumerations =====
    enum def PumpCommand { start; stop; }
    enum def StrokeType { intake; discharge; }
    
    // ===== Port Definitions =====
    port def FluidPort {
        out item fluidOut : HydraulicFluid;
        in item fluidIn : HydraulicFluid;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }
    
    port def MechanicalRotationalPort {
        out attribute torqueOut : TorqueValue;
        out attribute speedOut : RotationalSpeedValue;
        in attribute angularPositionIn : AngularPositionValue;
    }
    
    port def MechanicalLinearPort {
        out attribute forceOut : ForceValue;
        out attribute positionOut : LinearPositionValue;
        in attribute positionIn : LinearPositionValue;
    }
    
    port def CommandPort {
        in attribute command : PumpCommand;
    }
    
    // ===== Requirements =====
    requirement def PumpingRequirement {
        subject pump : PistonPump;
        objective {
            doc /* The pump shall transfer fluid from a low-pressure reservoir to a higher-pressure receiver. */
        }
        require pump.dischargePressure > pump.intakePressure;
    }
    
    requirement def PositiveDisplacementRequirement {
        subject pump : PistonPump;
        objective {
            doc /* The pump shall operate as a positive displacement pump with a fixed volume per cycle. */
        }
        require pump.sweptVolume > 0 [m3];
    }
    
    requirement def TwoStrokeCycleRequirement {
        subject pump : PistonPump;
        objective {
            doc /* The pump shall execute intake and discharge strokes in sequence. */
        }
        require pump.currentStroke in (StrokeType::intake, StrokeType::discharge);
    }
    
    requirement def StateManagementRequirement {
        subject pump : PistonPump;
        objective {
            doc /* The pump shall transition through idle, priming, operating, and shutdown states. */
        }
        require pump.currentState in ('idle', 'priming', 'operating', 'shutdown');
    }
    
    // ===== Part Definitions =====
    part def CrankshaftDrive {
        port rotPort : MechanicalRotationalPort;
        attribute inputTorque : TorqueValue;
        attribute rotationalSpeed : RotationalSpeedValue := 104.72 [rad/s]; // ~1000 RPM
        attribute crankRadius : Real := 0.05 [m];
        attribute currentAngle : AngularPositionValue;
        
        action def ConvertRotationToReciprocation {
            in angle : AngularPositionValue;
            out linearPos : LinearPositionValue;
            out force : ForceValue;
            
            // Crank-slider kinematics: x = r*cos(theta)
            perform ComputePosition;
            perform ComputeForce;
        }
        
        action ComputePosition {
            in angle : AngularPositionValue;
            out pos : LinearPositionValue;
        }
        
        action ComputeForce {
            in angle : AngularPositionValue;
            out f : ForceValue;
        }
    }
    
    part def Piston {
        port linearPort : MechanicalLinearPort;
        attribute diameter : Real := 0.08 [m];
        attribute strokeLength : Real := 0.10 [m];
        attribute currentPos : LinearPositionValue;
        attribute topDeadCenter : LinearPositionValue := 0.0 [m];
        attribute bottomDeadCenter : LinearPositionValue := 0.10 [m];
        attribute area : Real := 0.0050265482 [m2]; // pi*d^2/4
        
        action def MovePiston {
            in targetPos : LinearPositionValue;
            out actualPos : LinearPositionValue;
            out force : ForceValue;
        }
    }
    
    part def Cylinder {
        port fluidPort : FluidPort;
        attribute boreDiameter : Real := 0.08 [m];
        attribute chamberLength : Real := 0.12 [m];
        attribute chamberVolume : VolumeValue;
        attribute sweptVolume : VolumeValue := 0.00050265482 [m3]; // area * stroke
        attribute currentPressure : PressureValue;
        attribute intakePressure : PressureValue := 101325.0 [Pa]; // 1 atm
        attribute dischargePressure : PressureValue := 500000.0 [Pa]; // 5 bar
        
        action def IntakeFluid {
            in volume : VolumeValue;
            out fluid : HydraulicFluid;
        }
        
        action def CompressFluid {
            in fluid : HydraulicFluid;
            out pressurizedFluid : HydraulicFluid;
            out pressure : PressureValue;
        }
    }
    
    part def CheckValve {
        port inletPort : FluidPort;
        port outletPort : FluidPort;
        attribute crackPressure : PressureValue;
        attribute isOpen : Boolean := false;
        attribute flowDirection : String;
        
        action def EvaluateValve {
            in upstreamPressure : PressureValue;
            in downstreamPressure : PressureValue;
            out open : Boolean;
            
            // Valve opens when upstream pressure exceeds downstream by crack pressure
            if upstreamPressure > downstreamPressure + crackPressure {
                assign open := true;
            } else {
                assign open := false;
            }
        }
    }
    
    part def Reservoir {
        port outletPort : FluidPort;
        attribute fluidVolume : VolumeValue := 0.05 [m3];
        attribute fluidLevel : Real := 0.5 [m];
        attribute pressure : PressureValue := 101325.0 [Pa];
        attribute storedFluid : HydraulicFluid;
        
        action def SupplyFluid {
            out fluid : HydraulicFluid;
            out flowRate : FlowRateValue;
        }
    }
    
    part def Receiver {
        port inletPort : FluidPort;
        attribute fluidVolume : VolumeValue := 0.0 [m3];
        attribute maxVolume : VolumeValue := 0.10 [m3];
        attribute pressure : PressureValue := 500000.0 [Pa];
        attribute receivedFluid : HydraulicFluid;
        
        action def ReceiveFluid {
            in fluid : HydraulicFluid;
            in flowRate : FlowRateValue;
        }
    }
    
    part def PistonPump {
        port commandPort : CommandPort;
        port inletPort : FluidPort;
        port outletPort : FluidPort;
        
        attribute intakePressure : PressureValue := 101325.0 [Pa];
        attribute dischargePressure : PressureValue := 500000.0 [Pa];
        attribute sweptVolume : VolumeValue := 0.00050265482 [m3];
        attribute currentStroke : StrokeType;
        attribute currentState : String;
        attribute cycleCount : Integer := 0;
        attribute isPrimed : Boolean := false;
        
        part crankshaft : CrankshaftDrive {
            attribute crankRadius := 0.05 [m];
        }
        part piston : Piston {
            attribute strokeLength := 0.10 [m];
        }
        part cylinder : Cylinder {
            attribute sweptVolume := 0.00050265482 [m3];
        }
        part inletValve : CheckValve {
            attribute crackPressure := 1000.0 [Pa];
            attribute flowDirection := "inlet";
        }
        part outletValve : CheckValve {
            attribute crackPressure := 2000.0 [Pa];
            attribute flowDirection := "outlet";
        }
        
        connection crankToPiston connect crankshaft.rotPort to piston.linearPort;
        connection pistonToCylinder connect piston.linearPort to cylinder.fluidPort;
        connection inletToCylinder connect inletPort to inletValve.inletPort;
        connection inletValveToCylinder connect inletValve.outletPort to cylinder.fluidPort;
        connection cylinderToOutletValve connect cylinder.fluidPort to outletValve.inletPort;
        connection outletValveToPort connect outletValve.outletPort to outletPort;
        
        // ===== State Machine =====
        state def PumpStateMachine {
            entry; then idle;
            
            state idle {
                entry {
                    assign currentState := 'idle';
                    assign isPrimed := false;
                    assign cycleCount := 0;
                }
            }
            
            transition idle_to_priming
                first idle
                accept command : PumpCommand when command == PumpCommand::start
                then priming;
            
            state priming {
                entry {
                    assign currentState := 'priming';
                }
                
                do {
                    // Fill cylinder with fluid from reservoir
                    perform PrimePump;
                }
                
                // After priming is complete, transition to operating
            }
            
            transition priming_to_operating
                first priming
                accept 'primingComplete' when isPrimed == true
                then operating;
            
            state operating {
                entry {
                    assign currentState := 'operating';
                }
                
                do {
                    // Continuously perform pumping cycles
                    perform PumpingCycle;
                }
            }
            
            transition operating_to_shutdown
                first operating
                accept command : PumpCommand when command == PumpCommand::stop
                then shutdown;
            
            state shutdown {
                entry {
                    assign currentState := 'shutdown';
                }
                
                do {
                    // Controlled shutdown sequence
                    perform ControlledShutdown;
                }
            }
            
            transition shutdown_to_idle
                first shutdown
                accept 'shutdownComplete'
                then idle;
        }
        
        // ===== Actions =====
        action def PrimePump {
            out primed : Boolean;
            
            // Open inlet valve and draw fluid into cylinder
            perform OpenInletValve;
            perform DrawFluidIntoCylinder;
            assign primed := true;
        }
        
        action OpenInletValve {
            out valveOpen : Boolean;
        }
        
        action DrawFluidIntoCylinder {
            in volume : VolumeValue := sweptVolume;
            out fluid : HydraulicFluid;
        }
        
        action def PumpingCycle {
            // Perform one complete two-stroke cycle
            perform IntakeStroke;
            perform DischargeStroke;
        }
        
        action def IntakeStroke {
            doc /* Piston retracts, creating low pressure, drawing fluid through inlet valve. */
            
            in pistonPosition : LinearPositionValue;
            out cylinderPressure : PressureValue;
            out intakeFluid : HydraulicFluid;
            
            // Piston moves from TDC to BDC
            perform RetractPiston;
            perform OpenInletCheckValve;
            perform DrawFluid;
            perform CloseOutletCheckValve;
            
            assign currentStroke := StrokeType::intake;
        }
        
        action def DischargeStroke {
            doc /* Piston extends, compressing fluid and forcing it through outlet valve. */
            
            in pistonPosition : LinearPositionValue;
            out cylinderPressure : PressureValue;
            out dischargedFluid : HydraulicFluid;
            
            // Piston moves from BDC to TDC
            perform ExtendPiston;
            perform CloseInletCheckValve;
            perform CompressFluidInCylinder;
            perform OpenOutletCheckValve;
            perform ExpelFluid;
            
            assign currentStroke := StrokeType::discharge;
            assign cycleCount := cycleCount + 1;
        }
        
        action RetractPiston {
            out position : LinearPositionValue;
        }
        
        action ExtendPiston {
            out position : LinearPositionValue;
        }
        
        action OpenInletCheckValve {
            out open : Boolean;
        }
        
        action CloseInletCheckValve {
            out open : Boolean;
        }
        
        action OpenOutletCheckValve {
            out open : Boolean;
        }
        
        action CloseOutletCheckValve {
            out open : Boolean;
        }
        
        action DrawFluid {
            out fluid : HydraulicFluid;
            out volume : VolumeValue;
        }
        
        action CompressFluidInCylinder {
            in fluid : HydraulicFluid;
            out pressurizedFluid : HydraulicFluid;
            out pressure : PressureValue;
        }
        
        action ExpelFluid {
            in fluid : HydraulicFluid;
            out expelledFluid : HydraulicFluid;
            out flowRate : FlowRateValue;
        }
        
        action def ControlledShutdown {
            doc /* Gradually reduce speed and stop the pump. */
            
            perform ReduceSpeed;
            perform CloseValves;
            perform ResetPiston;
        }
        
        action ReduceSpeed {
            out speed : RotationalSpeedValue;
        }
        
        action CloseValves {
            out inletOpen : Boolean;
            out outletOpen : Boolean;
        }
        
        action ResetPiston {
            out position : LinearPositionValue;
        }
        
        // ===== Requirements Satisfaction =====
        satisfy PumpingRequirement {
            subject pistonPump : PistonPump;
        }
        satisfy PositiveDisplacementRequirement {
            subject pistonPump : PistonPump;
        }
        satisfy TwoStrokeCycleRequirement {
            subject pistonPump : PistonPump;
        }
        satisfy StateManagementRequirement {
            subject pistonPump : PistonPump;
        }
    }
    
    // ===== Top-level System Assembly =====
    part def PistonPumpSystem {
        port systemCommandPort : CommandPort;
        
        part reservoir : Reservoir {
            attribute pressure := 101325.0 [Pa];
            attribute fluidVolume := 0.05 [m3];
        }
        
        part pump : PistonPump {
            attribute intakePressure := 101325.0 [Pa];
            attribute dischargePressure := 500000.0 [Pa];
        }
        
        part receiver : Receiver {
            attribute pressure := 500000.0 [Pa];
            attribute maxVolume := 0.10 [m3];
        }
        
        // Fluid connections: Reservoir -> Pump Inlet -> Pump Outlet -> Receiver
        connection reservoirToPump connect reservoir.outletPort to pump.inletPort {
            attribute flowRate : FlowRateValue;
        }
        
        connection pumpToReceiver connect pump.outletPort to receiver.inletPort {
            attribute flowRate : FlowRateValue;
        }
        
        // Command connection
        connection commandToPump connect systemCommandPort to pump.commandPort;
        
        // System-level requirement
        satisfy PumpingRequirement {
            subject pump;
        }
    }
}
