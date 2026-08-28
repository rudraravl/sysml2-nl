package IndiaMarkIIHandPump {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    item def Water;
    item def Groundwater :> Water;

    port def MechanicalPort {
        in attribute appliedForce : Force;
        out attribute displacement : Length;
    }

    port def FluidPort {
        in item waterIn : Water;
        out item waterOut : Water;
    }

    part def HandleAssembly {
        port mechPort : MechanicalPort;
        attribute handleLength : Length;
        attribute operatorForce : Force;
    }

    part def PumpRod {
        port topPort : MechanicalPort;
        port bottomPort : MechanicalPort;
        attribute rodLength : Length;
    }

    part def Borehole {
        port aquiferPort : FluidPort;
        attribute depth : Length;
        item groundWater : Groundwater;
    }

    part def FootValve {
        port inletPort : FluidPort;
        port outletPort : FluidPort;
        attribute isOpen : Boolean;
    }

    part def PistonAssembly {
        port rodPort : MechanicalPort;
        port upperPort : FluidPort;
        port lowerPort : FluidPort;
        attribute pistonValveOpen : Boolean;
    }

    part def CylinderBarrel {
        port inletPort : FluidPort;
        port outletPort : FluidPort;
        part piston : PistonAssembly;
        part footValve : FootValve;
        
        connection aquiferToFootValve connect inletPort to footValve.inletPort;
        connection footValveToPiston connect footValve.outletPort to piston.lowerPort;
        connection pistonToOutlet connect piston.upperPort to outletPort;
    }

    part def RisingMain {
        port inletPort : FluidPort;
        port outletPort : FluidPort;
        attribute pipeLength : Length;
    }

    part def DischargeSpout {
        port inletPort : FluidPort;
        port outletPort : FluidPort;
        attribute flowRate : VolumeFlowRate;
    }

    part def IndiaMarkIIPump {
        attribute isOperating : Boolean;
        attribute totalLiftHeight : Length;
        
        part handle : HandleAssembly;
        part rod : PumpRod;
        part borehole : Borehole;
        part cylinder : CylinderBarrel;
        part risingMain : RisingMain;
        part spout : DischargeSpout;

        connection handleToRod connect handle.mechPort to rod.topPort;
        connection rodToPiston connect rod.bottomPort to cylinder.piston.rodPort;
        connection aquiferToCylinder connect borehole.aquiferPort to cylinder.inletPort;
        connection cylinderToRisingMain connect cylinder.outletPort to risingMain.inletPort;
        connection risingMainToSpout connect risingMain.outletPort to spout.inletPort;

        state def PumpOperation {
            entry; then idle;
            
            state idle;
            
            state upstroke {
                entry action {
                    cylinder.piston.pistonValveOpen = false;
                    cylinder.footValve.isOpen = true;
                }
                do action {
                    totalLiftHeight = totalLiftHeight + 0.5 [m];
                }
            }
            
            state downstroke {
                entry action {
                    cylinder.piston.pistonValveOpen = true;
                    cylinder.footValve.isOpen = false;
                }
            }
            
            state discharging {
                do action {
                    // Water emerges from discharge spout
                }
            }
            
            transition first idle if isOperating then upstroke;
            transition first upstroke then downstroke;
            transition first downstroke if totalLiftHeight < risingMain.pipeLength then upstroke;
            transition first downstroke if totalLiftHeight >= risingMain.pipeLength then discharging;
            transition first discharging then idle;
        }
        
        part behavior : PumpOperation;
    }

    requirement def ProvideDrinkingWater {
        attribute requiredFlowRate : VolumeFlowRate;
        subject pump : IndiaMarkIIPump;
        requirement {
            doc /* The pump must provide a reliable source of drinking water without external power. */
            assert pump.spout.flowRate >= requiredFlowRate
        }
    }
}
