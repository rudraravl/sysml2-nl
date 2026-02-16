package 'StirrupPumpingSubsystem' {
    private import ScalarValues::*;

    package Definitions {
        attribute def Pressure {
            attribute num : Real;
        }

        attribute def FlowRate {
            attribute num : Real;
        }

        attribute def Volume {
            attribute num : Real;
        }

        attribute def Force {
            attribute num : Real;
        }

        attribute def Length {
            attribute num : Real;
        }

        attribute def Frequency {
            attribute num : Real;
        }

        item def Fluid {
            attribute volume : Volume;
            attribute pressure : Pressure;
        }

        port def FluidPort {
            attribute pressure : Pressure;
            out item fluidSupply : Fluid;
            in item fluidReturn : Fluid;
        }

        port def FluidInPort {
            attribute pressure : Pressure;
            in item fluidSupply : Fluid;
            out item fluidReturn : Fluid;
        }

        part def CheckValve {
            port inletPort : FluidInPort;
            port outletPort : FluidPort;
            attribute crackingPressure : Pressure;
            attribute isOpen : Boolean;
        }

        part def Piston {
            attribute diameter : Length;
            attribute strokeLength : Length;
            attribute currentPosition : Length;
            attribute displacementVolume : Volume;
        }

        part def Cylinder {
            port inletPort : FluidInPort;
            port outletPort : FluidPort;
            attribute innerDiameter : Length;
            attribute maxVolume : Volume;
            item containedFluid : Fluid;
        }

        part def Handle {
            attribute leverLength : Length;
            attribute appliedForce : Force;
        }

        part def Footplate {
            attribute baseArea : Real;
            attribute isEngaged : Boolean;
        }

        part def FluidReservoir {
            port outletPort : FluidPort;
            attribute capacity : Volume;
            attribute currentLevel : Volume;
            item storedFluid : Fluid;
        }

        part def DeliveryHose {
            port inletPort : FluidInPort;
            port outletPort : FluidPort;
            attribute hoseLength : Length;
            attribute innerDiameter : Length;
        }

        state def PumpStateMachine {
            entry action initialize;
            do action monitorOperation;
            exit action shutdown;

            state idle;

            transition idleToIntake
                first idle
                accept StartPumpingSignal
                then intakeStroke;

            state intakeStroke {
                entry action openInletValve;
                do action retractPiston;
                exit action closeInletValve;
            }

            transition intakeToDischarge
                first intakeStroke
                accept PistonRetractedSignal
                then dischargeStroke;

            state dischargeStroke {
                entry action openOutletValve;
                do action extendPiston;
                exit action closeOutletValve;
            }

            transition dischargeToContinue
                first dischargeStroke
                accept ContinuePumpingSignal
                then intakeStroke;

            transition dischargeToIdle
                first dischargeStroke
                accept StopPumpingSignal
                then idle;
        }

        part def StirrupPump {
            attribute strokeVolume : Volume;
            attribute maxFlowRate : FlowRate;
            attribute maxPressure : Pressure;
            attribute strokeFrequency : Frequency;

            port suctionPort : FluidInPort;
            port dischargePort : FluidPort;

            part footplate : Footplate {
                attribute :>> baseArea = 0.015;
                attribute :>> isEngaged = false;
            }

            part handle : Handle {
                attribute :>> leverLength {
                    attribute :>> num = 0.6;
                }
                attribute :>> appliedForce {
                    attribute :>> num = 200.0;
                }
            }

            part pumpCylinder : Cylinder {
                attribute :>> innerDiameter {
                    attribute :>> num = 50.0;
                }
                attribute :>> maxVolume {
                    attribute :>> num = 0.5;
                }
            }

            part piston : Piston {
                attribute :>> diameter {
                    attribute :>> num = 49.8;
                }
                attribute :>> strokeLength {
                    attribute :>> num = 250.0;
                }
                attribute :>> currentPosition {
                    attribute :>> num = 0.0;
                }
                attribute :>> displacementVolume {
                    attribute :>> num = 0.49;
                }
            }

            part inletValve : CheckValve {
                attribute :>> crackingPressure {
                    attribute :>> num = 3.0;
                }
                attribute :>> isOpen = false;
            }

            part outletValve : CheckValve {
                attribute :>> crackingPressure {
                    attribute :>> num = 8.0;
                }
                attribute :>> isOpen = false;
            }

            flow from suctionPort.fluidSupply to inletValve.inletPort.fluidSupply;
            flow from inletValve.outletPort.fluidSupply to pumpCylinder.inletPort.fluidSupply;
            flow from pumpCylinder.outletPort.fluidSupply to outletValve.inletPort.fluidSupply;
            flow from outletValve.outletPort.fluidSupply to dischargePort.fluidSupply;

            exhibit state pumpOperation : PumpStateMachine;
        }

        action def IntakeAction {
            in fluidSource : Fluid;
            out fluidToCylinder : Fluid;
            attribute intakeVolume : Volume;

            first start;
            then action openValve;
            then action drawFluid {
                in source = fluidSource;
                out drawn = fluidToCylinder;
            }
            then action closeValve;
            then done;
        }

        action def DischargeAction {
            in fluidFromCylinder : Fluid;
            out fluidDelivered : Fluid;
            attribute dischargeVolume : Volume;

            first start;
            then action openValve;
            then action expelFluid {
                in source = fluidFromCylinder;
                out expelled = fluidDelivered;
            }
            then action closeValve;
            then done;
        }

        action def PumpingCycle {
            in attribute strokeForce : Force;
            out attribute volumePumped : Volume;
            out attribute cycleFlowRate : FlowRate;

            first start;
            then merge readyForStroke;

            then action intake : IntakeAction {
                in fluidSource;
                out fluidToCylinder;
            }

            then action discharge : DischargeAction {
                in fluidFromCylinder = intake.fluidToCylinder;
                out fluidDelivered;
            }

            then decide;
                if continuePumping then readyForStroke;
                if stopPumping then done;

            state continuePumping : Boolean;
            state stopPumping : Boolean;
        }

        action def SystemOperation {
            in attribute requiredFlowRate : FlowRate;
            in attribute requiredPressure : Pressure;
            out attribute actualFlowRate : FlowRate;
            out attribute actualPressure : Pressure;

            first start;
            then action initializeSystem;
            then merge operatingLoop;

            then action checkReservoir {
                out reservoirLevel : Volume;
            }

            then decide;
                if reservoirLevel.num > minimumLevel.num then activatePump;
                if reservoirLevel.num <= minimumLevel.num then shutdownSystem;

            action activatePump : PumpingCycle {
                in strokeForce = operatingForce;
                out volumePumped;
                out cycleFlowRate = actualFlowRate;
            }

            then action measurePressure {
                out pressure : Pressure = actualPressure;
            }

            then decide;
                if pressure.num < requiredPressure.num then operatingLoop;
                if pressure.num >= requiredPressure.num then maintainOperation;

            action maintainOperation;
            then operatingLoop;

            action shutdownSystem;
            then done;

            state minimumLevel : Volume {
                attribute :>> num = 2.0;
            }
            state operatingForce : Force {
                attribute :>> num = 200.0;
            }
        }

        part def PumpingSubsystem {
            attribute targetFlowRate : FlowRate;
            attribute operatingPressure : Pressure;
            attribute systemEfficiency : Real;

            part reservoir : FluidReservoir {
                attribute :>> capacity {
                    attribute :>> num = 25.0;
                }
                attribute :>> currentLevel {
                    attribute :>> num = 20.0;
                }
            }

            part pump : StirrupPump {
                attribute :>> strokeVolume {
                    attribute :>> num = 0.49;
                }
                attribute :>> maxFlowRate {
                    attribute :>> num = 6.0;
                }
                attribute :>> maxPressure {
                    attribute :>> num = 250.0;
                }
                attribute :>> strokeFrequency {
                    attribute :>> num = 12.0;
                }
            }

            part deliveryHose : DeliveryHose {
                attribute :>> hoseLength {
                    attribute :>> num = 5.0;
                }
                attribute :>> innerDiameter {
                    attribute :>> num = 25.0;
                }
            }

            flow of fluid : Fluid from reservoir.outletPort.fluidSupply to pump.suctionPort.fluidSupply;
            flow of fluid : Fluid from pump.dischargePort.fluidSupply to deliveryHose.inletPort.fluidSupply;

            perform action systemOperation : SystemOperation;
        }

        interface def FluidInterface {
            end port supplierPort : FluidPort;
            end port consumerPort : FluidInPort;
        }
    }

    package Requirements {
        requirement def FlowRateRequirement {
            doc /* The stirrup pump shall deliver fluid at a minimum flow rate. */

            subject pump : Definitions::StirrupPump;

            require constraint {
                pump.maxFlowRate.num >= 4.0
            }
        }

        requirement def PressureRequirement {
            doc /* The stirrup pump shall achieve minimum discharge pressure. */

            subject pump : Definitions::StirrupPump;

            require constraint {
                pump.maxPressure.num >= 200.0
            }
        }

        requirement def ValveRequirement {
            doc /* Check valves shall operate at appropriate differential pressures. */

            subject inletValve : Definitions::CheckValve;
            subject outletValve : Definitions::CheckValve;

            require constraint {
                inletValve.crackingPressure.num < outletValve.crackingPressure.num
            }
        }

        requirement def ReservoirCapacityRequirement {
            doc /* The reservoir shall maintain adequate capacity for continuous operation. */

            subject reservoir : Definitions::FluidReservoir;

            require constraint {
                reservoir.capacity.num >= 20.0
            }

            require constraint {
                reservoir.currentLevel.num >= 2.0
            }
        }

        requirement def StrokeVolumeRequirement {
            doc /* The pump stroke volume shall match piston displacement. */

            subject pump : Definitions::StirrupPump;

            require constraint {
                pump.strokeVolume.num == pump.piston.displacementVolume.num
            }
        }
    }

    package Usages {
        part fireServicePumpingSystem : Definitions::PumpingSubsystem {
            attribute :>> targetFlowRate {
                attribute :>> num = 5.0;
            }
            attribute :>> operatingPressure {
                attribute :>> num = 220.0;
            }
            attribute :>> systemEfficiency = 0.78;

            part :>> reservoir {
                item :>> storedFluid : Definitions::Fluid {
                    attribute :>> volume {
                        attribute :>> num = 20.0;
                    }
                    attribute :>> pressure {
                        attribute :>> num = 101.3;
                    }
                }
            }

            satisfy Requirements::FlowRateRequirement by pump;
            satisfy Requirements::PressureRequirement by pump;
            satisfy Requirements::ValveRequirement by pump.inletValve, pump.outletValve;
            satisfy Requirements::ReservoirCapacityRequirement by reservoir;
            satisfy Requirements::StrokeVolumeRequirement by pump;
        }
    }
}
