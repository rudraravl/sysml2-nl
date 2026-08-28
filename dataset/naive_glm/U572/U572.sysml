package TreadlePumpSystem {
    import ScalarValues::*;
    
    unit m;
    unit L;
    unit s;
    unit Pa;
    unit N;
    unit kg;
    unit deg;
    unit m2;
    unit L_per_s;
    
    type Length :> Real;
    type Volume :> Real;
    type Time :> Real;
    type Pressure :> Real;
    type Force :> Real;
    type Mass :> Real;
    type Angle :> Real;
    type Area :> Real;
    type FlowRate :> Real;
    
    item def Water;
    item def Air;
    
    port def FluidPort {
        attribute pressure : Pressure;
        flow water : Water;
    }
    
    port def MechanicalPort {
        attribute force : Force;
        attribute displacement : Length;
    }
    
    requirement def PumpRequirement {
        attribute maxLiftHeight : Length;
        attribute targetFlowRate : FlowRate;
        attribute operatorMass : Mass;
    }
    
    part def WaterSource {
        port waterOut : FluidPort;
        attribute waterLevel : Length;
    }
    
    part def DeliveryTank {
        port waterIn : FluidPort;
        attribute capacity : Volume;
        attribute currentVolume : Volume;
    }
    
    part def DeliveryPipe {
        in port inlet : FluidPort;
        out port outlet : FluidPort;
        attribute length : Length;
        attribute diameter : Length;
        attribute flowRate : FlowRate;
    }
    
    part def CheckValve {
        attribute isOpen : Boolean = false;
        attribute crackingPressure : Pressure;
        in port inlet : FluidPort;
        out port outlet : FluidPort;
        
        action def Open {}
        action def Close {}
    }
    
    part def Piston {
        attribute position : Length = 0.0 [m];
        attribute maxStroke : Length = 0.2 [m];
        attribute area : Area = 0.01 [m2];
        in port mechIn : MechanicalPort;
        
        action def DownStroke {
            in item waterIn : Water;
            out item waterOut : Water;
        }
        action def UpStroke {
            out item waterIn : Water;
        }
    }
    
    part def PistonChamber {
        attribute volume : Volume;
        part piston : Piston;
        port chamberInlet : FluidPort;
        port chamberOutlet : FluidPort;
    }
    
    part def ConnectingRod {
        in port treadleEnd : MechanicalPort;
        out port pistonEnd : MechanicalPort;
        attribute length : Length;
    }
    
    part def Treadle {
        in port operatorInput : MechanicalPort;
        out port rodOutput : MechanicalPort;
        attribute currentAngle : Angle = 0.0 [deg];
        attribute maxAngle : Angle = 15.0 [deg];
        
        action def Depress {}
        action def Release {}
    }
    
    part def Operator {
        out port leftFoot : MechanicalPort;
        out port rightFoot : MechanicalPort;
        attribute mass : Mass = 70.0 [kg];
        attribute currentWeight : Force;
        
        action def ShiftWeight {}
    }
    
    part def TreadlePumpAssembly {
        port suctionPort : FluidPort;
        port deliveryPort : FluidPort;
        port leftTreadleInput : MechanicalPort;
        port rightTreadleInput : MechanicalPort;
        
        attribute operatorStarts : Boolean = false;
        attribute chambersFull : Boolean = false;
        attribute operatorStops : Boolean = false;
        
        part leftTreadle : Treadle;
        part rightTreadle : Treadle;
        part leftRod : ConnectingRod;
        part rightRod : ConnectingRod;
        
        part leftChamber : PistonChamber;
        part rightChamber : PistonChamber;
        
        part leftInletValve : CheckValve {
            crackingPressure = 1000.0 [Pa];
        }
        part rightInletValve : CheckValve {
            crackingPressure = 1000.0 [Pa];
        }
        part leftOutletValve : CheckValve {
            crackingPressure = 1000.0 [Pa];
        }
        part rightOutletValve : CheckValve {
            crackingPressure = 1000.0 [Pa];
        }
        
        connection leftTreadleToRod connect leftTreadle.rodOutput to leftRod.treadleEnd;
        connection leftRodToPiston connect leftRod.pistonEnd to leftChamber.piston.mechIn;
        connection rightTreadleToRod connect rightTreadle.rodOutput to rightRod.treadleEnd;
        connection rightRodToPiston connect rightRod.pistonEnd to rightChamber.piston.mechIn;
        
        connection sourceToLeftInlet connect suctionPort to leftInletValve.inlet;
        connection leftInletToChamber connect leftInletValve.outlet to leftChamber.chamberInlet;
        connection leftChamberToOutlet connect leftChamber.chamberOutlet to leftOutletValve.inlet;
        connection leftOutletToDelivery connect leftOutletValve.outlet to deliveryPort;
        
        connection sourceToRightInlet connect suctionPort to rightInletValve.inlet;
        connection rightInletToChamber connect rightInletValve.outlet to rightChamber.chamberInlet;
        connection rightChamberToOutlet connect rightChamber.chamberOutlet to rightOutletValve.inlet;
        connection rightOutletToDelivery connect rightOutletValve.outlet to deliveryPort;
        
        state pumpOperation {
            state idle;
            state priming;
            state operating {
                state leftDownRightUp;
                state rightDownLeftUp;
                transition from leftDownRightUp to rightDownLeftUp;
                transition from rightDownLeftUp to leftDownRightUp;
            }
            transition from idle to priming when operatorStarts == true;
            transition from priming to operating when chambersFull == true;
            transition from operating to idle when operatorStops == true;
        }
    }
    
    part def PumpSystem {
        part operator : Operator;
        part source : WaterSource;
        part pump : TreadlePumpAssembly;
        part pipe : DeliveryPipe;
        part tank : DeliveryTank;
        
        connection operatorLeftToPump connect operator.leftFoot to pump.leftTreadleInput;
        connection operatorRightToPump connect operator.rightFoot to pump.rightTreadleInput;
        connection sourceToPump connect source.waterOut to pump.suctionPort;
        connection pumpToPipe connect pump.deliveryPort to pipe.inlet;
        connection pipeToTank connect pipe.outlet to tank.waterIn;
        
        requirement mainReq : PumpRequirement {
            maxLiftHeight = 5.0 [m];
            targetFlowRate = 1.0 [L_per_s];
            operatorMass = 70.0 [kg];
        }
    }
}
