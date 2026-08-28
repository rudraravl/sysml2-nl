package TreadlePumpSystem {
    import ScalarValues::*;
    
    item def Water;
    
    attribute def Pressure :> Real { unit 'Pa'; }
    attribute def Volume :> Real { unit 'm3'; }
    attribute def FlowRate :> Real { unit 'm3/s'; }
    attribute def Force :> Real { unit 'N'; }
    attribute def Length :> Real { unit 'm'; }
    
    port def WaterPort;
    port def MechanicalPort {
        attribute displacement : Length;
        attribute appliedForce : Force;
    }
    
    part def CheckValve {
        port inlet : WaterPort;
        port outlet : WaterPort;
        attribute isOpen : Boolean;
        attribute crackingPressure : Pressure;
    }
    
    part def Piston {
        port rodAttachment : MechanicalPort;
        port chamberFace : MechanicalPort;
        attribute position : Length;
    }
    
    part def PistonChamber {
        port inlet : WaterPort;
        port outlet : WaterPort;
        port pistonSeal : MechanicalPort;
        part piston : Piston;
        part inletValve : CheckValve;
        part outletValve : CheckValve;
        
        connect inlet to inletValve.inlet;
        connect inletValve.outlet to piston.chamberFace;
        connect piston.chamberFace to outletValve.inlet;
        connect outletValve.outlet to outlet;
        connect pistonSeal to piston.chamberFace;
    }
    
    part def Treadle {
        port pedal : MechanicalPort;
        port rodMount : MechanicalPort;
    }
    
    part def ConnectingRod {
        port upperEnd : MechanicalPort;
        port lowerEnd : MechanicalPort;
    }
    
    part def TreadlePumpAssembly {
        port inletPort : WaterPort;
        port outletPort : WaterPort;
        
        part leftTreadle : Treadle;
        part rightTreadle : Treadle;
        part leftRod : ConnectingRod;
        part rightRod : ConnectingRod;
        part leftChamber : PistonChamber;
        part rightChamber : PistonChamber;
        
        connect leftTreadle.rodMount to leftRod.upperEnd;
        connect leftRod.lowerEnd to leftChamber.piston.rodAttachment;
        connect rightTreadle.rodMount to rightRod.upperEnd;
        connect rightRod.lowerEnd to rightChamber.piston.rodAttachment;
        
        connect inletPort to leftChamber.inlet;
        connect inletPort to rightChamber.inlet;
        connect leftChamber.outlet to outletPort;
        connect rightChamber.outlet to outletPort;
    }
    
    part def WaterSource {
        port outlet : WaterPort;
        item waterSupply : Water;
        attribute availableVolume : Volume;
    }
    
    part def DeliveryPipe {
        port inlet : WaterPort;
        port outlet : WaterPort;
        attribute length : Length;
    }
    
    part def DeliveryTank {
        port inlet : WaterPort;
        attribute capacity : Volume;
        attribute storedVolume : Volume;
        item storedWater : Water;
    }
    
    part def Operator {
        part leftFoot : MechanicalPort;
        part rightFoot : MechanicalPort;
    }
    
    state def PumpOperation {
        action def PrimePump;
        action def DriveLeftPistonDown;
        action def PullRightPistonUp;
        action def DriveRightPistonDown;
        action def PullLeftPistonUp;
        action def MonitorOperator;
        
        entry; then idle;
        
        state idle {
            do action MonitorOperator;
        }
        transition idle_to_priming
            first idle
            accept StartPumping
            then priming;
        
        state priming {
            do action PrimePump;
        }
        transition priming_to_operating
            first priming
            accept ChambersFilled
            then operating;
        
        state operating {
            entry; then leftStroke;
            
            state leftStroke {
                do action DriveLeftPistonDown;
                do action PullRightPistonUp;
            }
            transition leftStroke_to_rightStroke
                first leftStroke
                accept RightTreadleDown
                then rightStroke;
            
            state rightStroke {
                do action DriveRightPistonDown;
                do action PullLeftPistonUp;
            }
            transition rightStroke_to_leftStroke
                first rightStroke
                accept LeftTreadleDown
                then leftStroke;
        }
        transition operating_to_idle
            first operating
            accept StopPumping
            then idle;
    }
    
    part def TreadlePumpSystem {
        part operator : Operator;
        part source : WaterSource;
        part pump : TreadlePumpAssembly;
        part pipe : DeliveryPipe;
        part tank : DeliveryTank;
        
        connect operator.leftFoot to pump.leftTreadle.pedal;
        connect operator.rightFoot to pump.rightTreadle.pedal;
        connect source.outlet to pump.inletPort;
        connect pump.outletPort to pipe.inlet;
        connect pipe.outlet to tank.inlet;
        
        state pumpOperation : PumpOperation;
    }
    
    part system : TreadlePumpSystem;
    
    requirement liftWaterReq {
        doc /* The pump shall lift water from the source to the delivery tank using human power applied via treadles. */
    }
    requirement continuousFlowReq {
        doc /* The dual-cylinder design shall provide a more continuous water flow compared to a single-piston pump by alternating suction and discharge strokes. */
    }
    requirement preventBackflowReq {
        doc /* Each check valve shall prevent backflow of water, ensuring unidirectional flow from source to delivery tank. */
    }
    requirement stateTransitionReq {
        doc /* The system shall transition from idle to priming upon operator start, proceed to operating after chambers are filled, alternate between left and right strokes, and return to idle upon stop. */
    }
    
    satisfy liftWaterReq by system.pump;
    satisfy continuousFlowReq by system.pump;
    satisfy preventBackflowReq by system.pump;
    satisfy stateTransitionReq by system.pumpOperation;
}
