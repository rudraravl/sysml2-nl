package TreadlePumpingSubsystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure {
        :> scalar;
        unit = Pa;
    }

    attribute def FlowRate {
        :> scalar;
        unit = m^3 / s;
    }

    attribute def Volume {
        :> scalar;
        unit = m^3;
    }

    attribute def Length {
        :> scalar;
        unit = m;
    }

    attribute def Force {
        :> scalar;
        unit = N;
    }

    attribute def Frequency {
        :> scalar;
        unit = Hz;
    }

    attribute def Efficiency {
        :> scalar;
    }

    attribute def Temperature {
        :> scalar;
        unit = K;
    }

    item def Fluid {
        attribute density : MassDensity;
        attribute dynamicViscosity : DynamicViscosity;
        attribute temperature : Temperature;
        attribute suspendedSolidsFraction : Real;
    }

    item def MechanicalWork {
        attribute energy : Energy;
        attribute strokeForce : Force;
    }

    item def PumpedFluid :> Fluid {
        attribute pressure : Pressure;
        attribute volumetricFlowRate : FlowRate;
        attribute volumeMoved : Volume;
    }

    port def FluidPort {
        inout item fluid : PumpedFluid;
        attribute portPressure : Pressure;
    }

    port def MechanicalInputPort {
        in item treadleWork : MechanicalWork;
        attribute cadence : Frequency;
    }

    part def FootTreadle {
        attribute treadleLength : Length = 0.85 [m];
        attribute pedalTravel : Length = 0.28 [m];
        attribute maximumUserForce : Force = 650 [N];

        port mechanicalOutput : MechanicalInputPort;

        action transmitFootForce {
            in item userWork : MechanicalWork;
            out item linkageWork : MechanicalWork;
        }
    }

    part def RockerLinkage {
        attribute leverRatio : Real = 2.4;
        attribute pivotFrictionEfficiency : Efficiency = 0.92;

        port mechanicalInput : MechanicalInputPort;
        port mechanicalOutput : MechanicalInputPort;

        action convertTreadleMotion {
            in item treadleWork : MechanicalWork;
            out item pistonWork : MechanicalWork;
        }
    }

    part def PumpCylinder {
        attribute boreDiameter : Length = 0.075 [m];
        attribute strokeLength : Length = 0.18 [m];
        attribute clearanceVolume : Volume = 0.000025 [m^3];
        attribute ratedPressure : Pressure = 250000 [Pa];

        port suctionPort : FluidPort;
        port dischargePort : FluidPort;
        port mechanicalInput : MechanicalInputPort;

        part piston {
            attribute sealFrictionForce : Force = 35 [N];
            attribute pistonArea : Area = 0.00442 [m^2];
        }

        action displaceFluid {
            in item pistonWork : MechanicalWork;
            inout item cylinderFluid : PumpedFluid;
            out item dischargedFluid : PumpedFluid;
        }
    }

    part def CheckValve {
        attribute crackingPressure : Pressure = 1200 [Pa];
        attribute reverseLeakageRate : FlowRate = 0.000001 [m^3 / s];
        attribute openFlowCoefficient : Real = 0.78;

        port upstream : FluidPort;
        port downstream : FluidPort;

        state def ValveState {
            state closed;
            state opening;
            state open;
            state closing;

            transition first closed;
            transition closed_to_opening
                first closed then opening
                if downstream.portPressure + crackingPressure < upstream.portPressure;

            transition opening_to_open
                first opening then open;

            transition open_to_closing
                first open then closing
                if downstream.portPressure >= upstream.portPressure;

            transition closing_to_closed
                first closing then closed;
        }

        action regulateOneWayFlow {
            in item inletFluid : PumpedFluid;
            out item outletFluid : PumpedFluid;
        }
    }

    part def IntakeStrainer {
        attribute meshOpening : Length = 0.0015 [m];
        attribute cloggingPressureDropLimit : Pressure = 15000 [Pa];

        port rawWaterInlet : FluidPort;
        port filteredOutlet : FluidPort;

        action removeDebris {
            in item rawFluid : PumpedFluid;
            out item strainedFluid : PumpedFluid;
        }
    }

    part def SuctionLine {
        attribute internalDiameter : Length = 0.04 [m];
        attribute length : Length = 4.0 [m];
        attribute maximumSuctionLift : Length = 7.0 [m];

        port inlet : FluidPort;
        port outlet : FluidPort;
    }

    part def DischargeLine {
        attribute internalDiameter : Length = 0.032 [m];
        attribute length : Length = 12.0 [m];
        attribute maximumDeliveryHead : Length = 18.0 [m];

        port inlet : FluidPort;
        port outlet : FluidPort;
    }

    part def OutletNozzle {
        attribute outletDiameter : Length = 0.025 [m];

        port inlet : FluidPort;
        port deliveredWaterOutlet : FluidPort;
    }

    part def Frame {
        attribute baseLength : Length = 1.20 [m];
        attribute baseWidth : Length = 0.48 [m];
        attribute allowableLoad : Force = 1200 [N];
    }

    part def TreadlePumpSubsystem {
        attribute nominalCadence : Frequency = 1.0 [Hz];
        attribute nominalFlowRate : FlowRate = 0.00055 [m^3 / s];
        attribute minimumFlowRate : FlowRate = 0.00035 [m^3 / s];
        attribute maximumOperatingPressure : Pressure = 220000 [Pa];
        attribute hydraulicEfficiency : Efficiency = 0.72;
        attribute totalMovedVolume : Volume;

        port sourceInlet : FluidPort;
        port deliveryOutlet : FluidPort;
        port humanPowerInput : MechanicalInputPort;

        part frame : Frame;
        part leftTreadle : FootTreadle;
        part rightTreadle : FootTreadle;
        part linkage : RockerLinkage;
        part cylinder : PumpCylinder;
        part intakeStrainer : IntakeStrainer;
        part suctionLine : SuctionLine;
        part suctionCheckValve : CheckValve;
        part dischargeCheckValve : CheckValve;
        part dischargeLine : DischargeLine;
        part outletNozzle : OutletNozzle;

        connect sourceInlet to intakeStrainer.rawWaterInlet;
        connect intakeStrainer.filteredOutlet to suctionLine.inlet;
        connect suctionLine.outlet to suctionCheckValve.upstream;
        connect suctionCheckValve.downstream to cylinder.suctionPort;
        connect cylinder.dischargePort to dischargeCheckValve.upstream;
        connect dischargeCheckValve.downstream to dischargeLine.inlet;
        connect dischargeLine.outlet to outletNozzle.inlet;
        connect outletNozzle.deliveredWaterOutlet to deliveryOutlet;

        connect humanPowerInput to leftTreadle.mechanicalOutput;
        connect humanPowerInput to rightTreadle.mechanicalOutput;
        connect leftTreadle.mechanicalOutput to linkage.mechanicalInput;
        connect rightTreadle.mechanicalOutput to linkage.mechanicalInput;
        connect linkage.mechanicalOutput to cylinder.mechanicalInput;

        state def PumpOperatingState {
            state idle;
            state priming;
            state suctionStroke;
            state dischargeStroke;
            state steadyPumping;
            state blockedDischarge;
            state dryRun;
            state stopped;

            transition initial_to_idle first idle;

            transition idle_to_priming
                first idle then priming
                if humanPowerInput.cadence > 0.2 [Hz];

            transition priming_to_suction
                first priming then suctionStroke
                if cylinder.suctionPort.fluid.volumeMoved > 0.0001 [m^3];

            transition suction_to_discharge
                first suctionStroke then dischargeStroke;

            transition discharge_to_steady
                first dischargeStroke then steadyPumping
                if deliveryOutlet.fluid.volumetricFlowRate >= minimumFlowRate;

            transition steady_to_suction
                first steadyPumping then suctionStroke
                if humanPowerInput.cadence >= 0.5 [Hz];

            transition any_to_blocked
                first steadyPumping then blockedDischarge
                if deliveryOutlet.portPressure > maximumOperatingPressure;

            transition priming_to_dryrun
                first priming then dryRun
                if sourceInlet.fluid.volumeMoved == 0 [m^3];

            transition blocked_to_stopped
                first blockedDischarge then stopped
                if humanPowerInput.cadence == 0 [Hz];

            transition dryrun_to_stopped
                first dryRun then stopped
                if humanPowerInput.cadence == 0 [Hz];

            transition steady_to_stopped
                first steadyPumping then stopped
                if humanPowerInput.cadence == 0 [Hz];
        }

        action pumpCycle {
            in item footWork : MechanicalWork;
            in item sourceFluid : PumpedFluid;
            out item deliveredFluid : PumpedFluid;

            first start;
            then strainWater;
            then drawWater;
            then compressAndDischarge;
            then deliverWater;

            action start {
                out item treadleWork : MechanicalWork;
            }

            action strainWater {
                in item sourceFluid : PumpedFluid;
                out item strainedFluid : PumpedFluid;
            }

            action drawWater {
                in item strainedFluid : PumpedFluid;
                out item cylinderCharge : PumpedFluid;
            }

            action compressAndDischarge {
                in item cylinderCharge : PumpedFluid;
                in item treadleWork : MechanicalWork;
                out item pressurizedFluid : PumpedFluid;
            }

            action deliverWater {
                in item pressurizedFluid : PumpedFluid;
                out item deliveredFluid : PumpedFluid;
            }

            flow sourceFluid to strainWater.sourceFluid;
            flow strainWater.strainedFluid to drawWater.strainedFluid;
            flow drawWater.cylinderCharge to compressAndDischarge.cylinderCharge;
            flow footWork to compressAndDischarge.treadleWork;
            flow compressAndDischarge.pressurizedFluid to deliverWater.pressurizedFluid;
            flow deliverWater.deliveredFluid to deliveredFluid;
        }
    }

    requirement def MoveFluidRequirement {
        subject pump : TreadlePumpSubsystem;

        require constraint {
            pump.deliveryOutlet.fluid.volumetricFlowRate >= pump.minimumFlowRate
        }

        require constraint {
            pump.deliveryOutlet.portPressure <= pump.maximumOperatingPressure
        }
    }

    requirement def HumanPoweredRequirement {
        subject pump : TreadlePumpSubsystem;

        require constraint {
            pump.humanPowerInput.cadence >= 0.5 [Hz] and
            pump.humanPowerInput.cadence <= 1.5 [Hz]
        }
    }

    requirement def OneWayFlowRequirement {
        subject pump : TreadlePumpSubsystem;

        require constraint {
            pump.suctionCheckValve.reverseLeakageRate <= 0.000001 [m^3 / s] and
            pump.dischargeCheckValve.reverseLeakageRate <= 0.000001 [m^3 / s]
        }
    }

    requirement def SuctionLiftRequirement {
        subject pump : TreadlePumpSubsystem;

        require constraint {
            pump.suctionLine.maximumSuctionLift <= 7.0 [m]
        }
    }

    requirement def DeliveryHeadRequirement {
        subject pump : TreadlePumpSubsystem;

        require constraint {
            pump.dischargeLine.maximumDeliveryHead >= 18.0 [m]
        }
    }

    requirement def StructuralSupportRequirement {
        subject pump : TreadlePumpSubsystem;

        require constraint {
            pump.frame.allowableLoad >=
            pump.leftTreadle.maximumUserForce + pump.rightTreadle.maximumUserForce
        }
    }

    requirement def PumpingSubsystemRequirement {
        subject pump : TreadlePumpSubsystem;

        require MoveFluidRequirement {
            subject pump = PumpingSubsystemRequirement::pump;
        }

        require HumanPoweredRequirement {
            subject pump = PumpingSubsystemRequirement::pump;
        }

        require OneWayFlowRequirement {
            subject pump = PumpingSubsystemRequirement::pump;
        }

        require SuctionLiftRequirement {
            subject pump = PumpingSubsystemRequirement::pump;
        }

        require DeliveryHeadRequirement {
            subject pump = PumpingSubsystemRequirement::pump;
        }

        require StructuralSupportRequirement {
            subject pump = PumpingSubsystemRequirement::pump;
        }
    }

    part treadlePumpSystem : TreadlePumpSubsystem {
        attribute nominalCadence = 1.0 [Hz];
        attribute nominalFlowRate = 0.00055 [m^3 / s];
        attribute minimumFlowRate = 0.00035 [m^3 / s];
        attribute maximumOperatingPressure = 220000 [Pa];
        attribute hydraulicEfficiency = 0.72;
    }

    satisfy PumpingSubsystemRequirement by treadlePumpSystem;
}