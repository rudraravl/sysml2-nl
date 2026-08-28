package 'Bush Pump System' {
    private import ScalarValues::*;

    attribute def Length :> Real;
    attribute def FlowRate :> Real;
    attribute def Volume :> Real;
    attribute def Force :> Real;

    item def Water;

    port def WaterInPort {
        in item water : Water;
    }
    port def WaterOutPort {
        out item water : Water;
    }
    port def MechanicalPort {
        in appliedForce : Force;
        out displacement : Length;
    }

    part def Handle {
        port userInterface : MechanicalPort;
        port rodAttachment : MechanicalPort;
    }

    part def PumpRod {
        port handleEnd : MechanicalPort;
        port pistonEnd : MechanicalPort;
    }

    part def Valve {
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
        attribute isOpen : Boolean = false;
    }

    part def Piston {
        port rodConnection : MechanicalPort;
        part pistonValve : Valve;
        port lowerChamber : WaterInPort;
        port upperChamber : WaterOutPort;
    }

    part def PumpCylinder {
        port wellInlet : WaterInPort;
        port risingPipeConnection : WaterOutPort;
        part footValve : Valve;
        part piston : Piston;
    }

    part def RisingPipe {
        port lowerConnection : WaterInPort;
        port upperConnection : WaterOutPort;
    }

    part def DischargeSpout {
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
    }

    part def StorageTank {
        port waterIn : WaterInPort;
        attribute capacity : Volume = 200;
        attribute currentVolume : Volume = 0;
    }

    part def Well {
        port waterSupply : WaterOutPort;
        attribute depth : Length = 40;
    }

    action def PushHandleDown { out force : Force; }
    action def PullHandleUp { out force : Force; }
    action def CloseFootValve {}
    action def OpenPistonValve {}
    action def TransferWaterAbovePiston {}
    action def ClosePistonValve {}
    action def OpenFootValve {}
    action def LiftWaterColumn {}
    action def DrawNewWater {}

    state def PumpCycle {
        state Idle;
        state Downstroke;
        state Upstroke;
        transition from Idle to Downstroke;
        transition from Downstroke to Upstroke;
        transition from Upstroke to Downstroke;
    }

    requirement def DepthRequirement {
        doc /* The pump shall operate effectively at depths up to 40 meters. */
        attribute maxDepth : Length = 40;
        constraint { maxDepth >= 40 }
    }

    requirement def FlowRateRequirement {
        doc /* The pump shall deliver a minimum continuous flow rate of 12 liters per minute. */
        attribute minFlowRate : FlowRate = 12;
        constraint { minFlowRate >= 12 }
    }

    part bushPump {
        satisfy DepthRequirement;
        satisfy FlowRateRequirement;

        part handle : Handle;
        part pumpRod : PumpRod;
        part cylinder : PumpCylinder;
        part risingPipe : RisingPipe;
        part dischargeSpout : DischargeSpout;
        part storageTank : StorageTank;
        part well : Well;

        bind handle.rodAttachment = pumpRod.handleEnd;
        bind pumpRod.pistonEnd = cylinder.piston.rodConnection;

        flow of Water from well.waterSupply.water to cylinder.wellInlet.water;
        flow of Water from cylinder.wellInlet.water to cylinder.footValve.waterIn.water;
        flow of Water from cylinder.footValve.waterOut.water to cylinder.piston.lowerChamber.water;
        flow of Water from cylinder.piston.lowerChamber.water to cylinder.piston.pistonValve.waterIn.water;
        flow of Water from cylinder.piston.pistonValve.waterOut.water to cylinder.piston.upperChamber.water;
        flow of Water from cylinder.piston.upperChamber.water to cylinder.risingPipeConnection.water;
        flow of Water from cylinder.risingPipeConnection.water to risingPipe.lowerConnection.water;
        flow of Water from risingPipe.upperConnection.water to dischargeSpout.waterIn.water;
        flow of Water from dischargeSpout.waterOut.water to storageTank.waterIn.water;

        state pumpCycle : PumpCycle;
    }
}
