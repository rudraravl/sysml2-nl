package 'Syphon System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package Definitions {
        item def Fluid;

        port def FluidPort {
            out item fluid : Fluid;
        }

        part def SourceReservoir {
            doc /* Elevated container holding fluid to be transferred. */
            attribute capacity : VolumeValue;
            attribute baseElevation : LengthValue;
            attribute fluidLevel : LengthValue;
            port fluidOutPort : FluidPort;
            item fluid : Fluid {
                attribute volume : VolumeValue;
            }
        }

        part def ReceivingReservoir {
            doc /* Lower container to collect transferred fluid. */
            attribute maxVolume : VolumeValue;
            attribute baseElevation : LengthValue;
            attribute fluidLevel : LengthValue;
            port fluidInPort : ~FluidPort;
            item fluid : Fluid {
                attribute volume : VolumeValue;
            }
        }

        part def SyphonTube {
            doc /* Continuous tube arching above the source fluid level, connecting the two reservoirs. */
            attribute length : LengthValue;
            attribute diameter : LengthValue;
            attribute apexHeight : LengthValue;
            port inletPort : ~FluidPort;
            port outletPort : FluidPort;
            item fluid : Fluid {
                attribute volume : VolumeValue;
            }
        }

        action def Prime {
            doc /* Completely fill the tube with fluid to eliminate air pockets. */
            out primed : Boolean;
        }

        action def TransferFluid;

        part def SyphonSystem {
            part source : SourceReservoir;
            part receiver : ReceivingReservoir;
            part tube : SyphonTube;
        }

        requirement def PassiveTransferRequirement {
            doc /* The system shall transfer fluid without external pumps or power, relying solely on gravitational potential energy and atmospheric pressure. */
            subject system : SyphonSystem;
        }

        requirement def PrimingRequirement {
            doc /* The syphon tube shall be completely filled with fluid before active transfer. */
            subject tube : SyphonTube;
            require constraint { tube.fluid.volume > 0 [L] }
        }

        requirement def ApexGeometryRequirement {
            doc /* The tube apex must rise above the source reservoir fluid level to establish the syphon effect. */
            subject tube : SyphonTube;
            subject source : SourceReservoir;
            require constraint { tube.apexHeight > source.fluidLevel }
        }

        requirement def FlowContinuationRequirement {
            doc /* Fluid flow shall continue automatically while the source fluid level exceeds the receiving fluid level. */
            subject source : SourceReservoir;
            subject receiving : ReceivingReservoir;
            require constraint { source.fluidLevel > receiving.fluidLevel }
        }

        requirement def StopConditionRequirement {
            doc /* Transfer shall stop when the source reservoir is depleted, the receiving reservoir is full, or the fluid levels equalize. */
            subject source : SourceReservoir;
            subject receiving : ReceivingReservoir;
            require constraint {
                source.fluid.volume == 0 [L] or
                receiving.fluid.volume >= receiving.maxVolume or
                source.fluidLevel <= receiving.fluidLevel
            }
        }
    }

    package Usages {
        private import Definitions::*;

        part syphon : SyphonSystem {
            attribute primeRequested : Boolean = false;

            part redefines source : SourceReservoir {
                attribute redefines baseElevation = 10 [m];
                attribute redefines capacity = 100 [L];
                attribute redefines fluidLevel = 1.5 [m];
            }

            part redefines tube : SyphonTube {
                attribute redefines length = 5 [m];
                attribute redefines diameter = 0.02 [m];
                attribute redefines apexHeight = 2 [m];
            }

            part redefines receiver : ReceivingReservoir {
                attribute redefines baseElevation = 2 [m];
                attribute redefines maxVolume = 100 [L];
                attribute redefines fluidLevel = 0 [m];
            }

            flow of fluid : Fluid
                from source.fluidOutPort.fluid to tube.inletPort.fluid;
            flow of fluid : Fluid
                from tube.outletPort.fluid to receiver.fluidInPort.fluid;

            state machine operation {
                state idle;
                state priming {
                    entry action primeAction : Prime;
                }
                state active {
                    do action transferAction : TransferFluid;
                }
                state stopped;

                initial -> idle;
                transition from idle to priming when primeRequested;
                transition from priming to active;
                transition from active to stopped when source.fluid.volume == 0 [L] or
                    receiver.fluid.volume >= receiver.maxVolume or
                    source.fluidLevel <= receiver.fluidLevel;
            }

            requirement passiveReq : PassiveTransferRequirement {
                subject system = syphon;
            }
            requirement primingReq : PrimingRequirement {
                subject tube = tube;
            }
            requirement apexReq : ApexGeometryRequirement {
                subject tube = tube;
                subject source = source;
            }
            requirement flowReq : FlowContinuationRequirement {
                subject source = source;
                subject receiving = receiver;
            }
            requirement stopReq : StopConditionRequirement {
                subject source = source;
                subject receiving = receiver;
            }
        }
    }
}
