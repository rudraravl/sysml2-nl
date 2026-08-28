package IndiaMarkIIHandPump {
    private import ISQ::*;
    private import ScalarValues::*;

    package Definitions {
        item def Water;

        port def WaterInPort {
            in item water : Water;
        }

        port def WaterOutPort {
            out item water : Water;
        }

        port def WaterFlowPort {
            in item waterIn : Water;
            out item waterOut : Water;
        }

        port def MechanicalPort {
            attribute force : ForceValue;
            attribute displacement : LengthValue;
        }

        part def HandleAssembly {
            port userPort : MechanicalPort;
            port rodPort : MechanicalPort;
            attribute length : LengthValue;
            attribute leverageRatio : Real;
        }

        part def PumpRod {
            port topPort : MechanicalPort;
            port bottomPort : MechanicalPort;
            attribute length : LengthValue;
            attribute material : String;
        }

        part def Borehole {
            port waterSupply : WaterOutPort;
            item groundwater : Water;
            attribute depth : LengthValue;
            attribute waterTableDepth : LengthValue;
        }

        part def FootValve {
            port inlet : WaterInPort;
            port outlet : WaterOutPort;
            attribute isOpen : Boolean;
        }

        part def PistonAssembly {
            port rodConnection : MechanicalPort;
            port cylinderPort : WaterFlowPort;
            attribute strokeLength : LengthValue;
            attribute valveOpen : Boolean;
        }

        part def CylinderBarrel {
            port lowerInlet : WaterInPort;
            port upperOutlet : WaterOutPort;
            port rodConnector : MechanicalPort;
            part footValve : FootValve;
            part piston : PistonAssembly;
            attribute innerDiameter : LengthValue;
            attribute length : LengthValue;
        }

        part def RisingMain {
            port inlet : WaterInPort;
            port outlet : WaterOutPort;
            attribute length : LengthValue;
            attribute diameter : LengthValue;
        }

        part def DischargeSpout {
            port inlet : WaterInPort;
            port outlet : WaterOutPort;
            attribute height : LengthValue;
        }

        part def IndiaMarkII {
            port dischargePort : WaterOutPort;
            part handle : HandleAssembly;
            part rod : PumpRod;
            part borehole : Borehole;
            part cylinder : CylinderBarrel;
            part risingMain : RisingMain;
            part spout : DischargeSpout;
        }

        action def Upstroke {
            in handleForce : ForceValue;
            out liftedWater : Water;
        }

        action def Downstroke {
            in handleForce : ForceValue;
            out liftedWater : Water;
        }

        state def PumpCycle;

        requirement def ReliableWaterSupply {
            doc /* The system shall provide a reliable supply of drinking water from a borehole using manual power without external energy. */
        }

        requirement def ManualOperation {
            doc /* The system shall be operable by a single person using the handle assembly to lift water from depths exceeding 30 meters. */
        }
    }

    package Usages {
        private import Definitions::*;

        part pumpSystem : IndiaMarkII {
            connection handleToRod connect handle.rodPort to rod.topPort;
            connection rodToPiston connect rod.bottomPort to cylinder.piston.rodConnection;

            flow of water : Water
                from borehole.waterSupply.water
                to cylinder.footValve.inlet.water;
            flow of water : Water
                from cylinder.footValve.outlet.water
                to cylinder.lowerInlet.water;
            flow of water : Water
                from cylinder.upperOutlet.water
                to risingMain.inlet.water;
            flow of water : Water
                from risingMain.outlet.water
                to spout.inlet.water;
            flow of water : Water
                from spout.outlet.water
                to dischargePort.water;

            state pumpCycle : PumpCycle {
                entry; then idle;
                state idle;
                state upstroke {
                    perform action upstrokeAction : Upstroke {
                        in handleForce = handle.userPort.force;
                        out liftedWater : Water;
                    }
                }
                state downstroke {
                    perform action downstrokeAction : Downstroke {
                        in handleForce = handle.userPort.force;
                        out liftedWater : Water;
                    }
                }
                state discharging;

                transition first idle then upstroke;
                transition first upstroke then downstroke;
                transition first downstroke then upstroke;
                transition first downstroke then discharging;
                transition first discharging then idle;
            }

            satisfy ReliableWaterSupply;
            satisfy ManualOperation;
        }
    }
}
