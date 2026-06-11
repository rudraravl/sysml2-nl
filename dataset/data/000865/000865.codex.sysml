package DiversPumpPumpingSubsystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    enum def PumpOperatingMode {
        enum off;
        enum priming;
        enum pumping;
        enum recirculating;
        enum draining;
        enum faulted;
    }

    enum def ValvePosition {
        enum open;
        enum closed;
        enum throttled;
    }

    enum def FluidCondition {
        enum clean;
        enum aerated;
        enum contaminated;
        enum debris_laden;
    }

    value def Pressure_kPa {
        unit = "kPa";
        quantityKind = "pressure";
    }

    value def FlowRate_Lpm {
        unit = "L/min";
        quantityKind = "volume flow rate";
    }

    value def Volume_L {
        unit = "L";
        quantityKind = "volume";
    }

    value def Power_W {
        unit = "W";
        quantityKind = "power";
    }

    value def Speed_rpm {
        unit = "rpm";
        quantityKind = "rotational speed";
    }

    value def Length_m {
        unit = "m";
        quantityKind = "length";
    }

    value def Temperature_C {
        unit = "degC";
        quantityKind = "temperature";
    }

    value def Time_s {
        unit = "s";
        quantityKind = "time";
    }

    value def EfficiencyRatio {
        unit = "1";
        quantityKind = "ratio";
    }

    item def WorkingFluid {
        attribute condition : FluidCondition;
        attribute temperature : Temperature_C;
        attribute density_kg_per_m3 : Real;
        attribute dynamicViscosity_mPa_s : Real;
        attribute entrainedAirFraction : EfficiencyRatio;
        attribute debrisParticleSize_mm : Real;
    }

    item def ElectricalPower {
        attribute voltage_V : Real;
        attribute current_A : Real;
        attribute frequency_Hz : Real;
        attribute availablePower : Power_W;
    }

    item def ControlCommand {
        attribute startRequested : Boolean;
        attribute stopRequested : Boolean;
        attribute resetRequested : Boolean;
        attribute targetFlow : FlowRate_Lpm;
        attribute allowRecirculation : Boolean;
    }

    item def PumpStatus {
        attribute mode : PumpOperatingMode;
        attribute measuredFlow : FlowRate_Lpm;
        attribute suctionPressure : Pressure_kPa;
        attribute dischargePressure : Pressure_kPa;
        attribute motorSpeed : Speed_rpm;
        attribute faultActive : Boolean;
        attribute faultCode : String;
    }

    port def FluidPort {
        inout item fluid : WorkingFluid;
        attribute pressure : Pressure_kPa;
        attribute flowRate : FlowRate_Lpm;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def CommandPort {
        in item command : ControlCommand;
    }

    port def StatusPort {
        out item status : PumpStatus;
    }

    part def SuctionStrainer {
        port inlet : FluidPort;
        port outlet : FluidPort;

        attribute meshOpening_mm : Real = 6.0;
        attribute cloggingFraction : EfficiencyRatio;
        attribute pressureDropAtRatedFlow : Pressure_kPa = 8.0;
    }

    part def SuctionHose {
        port inlet : FluidPort;
        port outlet : FluidPort;

        attribute insideDiameter_mm : Real = 75.0;
        attribute length : Length_m = 6.0;
        attribute maximumVacuum : Pressure_kPa = -70.0;
        attribute allowableCollapsePressure : Pressure_kPa = -85.0;
    }

    part def CheckValve {
        port inlet : FluidPort;
        port outlet : FluidPort;

        attribute crackingPressure : Pressure_kPa = 5.0;
        attribute reverseLeakageFlow : FlowRate_Lpm = 0.1;
        attribute position : ValvePosition;
    }

    part def DiverPump {
        port suction : FluidPort;
        port discharge : FluidPort;
        port powerIn : PowerInputPort;
        port commandIn : CommandPort;
        port statusOut : StatusPort;

        attribute operatingMode : PumpOperatingMode;
        attribute ratedFlow : FlowRate_Lpm = 120.0;
        attribute minimumContinuousFlow : FlowRate_Lpm = 25.0;
        attribute maximumDischargePressure : Pressure_kPa = 420.0;
        attribute maximumSuctionLift : Length_m = 7.5;
        attribute nominalSpeed : Speed_rpm = 3450.0;
        attribute hydraulicEfficiency : EfficiencyRatio = 0.62;
        attribute requiredInputPower : Power_W = 1800.0;
        attribute primingVolume : Volume_L = 3.5;
        attribute dryRunLimit : Time_s = 20.0;
        attribute casingTemperatureLimit : Temperature_C = 70.0;

        action startPump {
            in item command : ControlCommand;
            out item status : PumpStatus;

            first startMotor;
            then buildSuction;
            then verifyPrime;

            action startMotor {
                out speed : Speed_rpm;
            }

            action buildSuction {
                in speed : Speed_rpm;
                out suctionPressure : Pressure_kPa;
            }

            action verifyPrime {
                in suctionPressure : Pressure_kPa;
                out primed : Boolean;
            }
        }

        action moveFluid {
            in item incomingFluid : WorkingFluid;
            in requestedFlow : FlowRate_Lpm;
            out item outgoingFluid : WorkingFluid;
            out deliveredFlow : FlowRate_Lpm;

            first drawFromSuction;
            then addPumpEnergy;
            then dischargeFluid;

            action drawFromSuction {
                in item sourceFluid : WorkingFluid;
                out item pumpChamberFluid : WorkingFluid;
            }

            action addPumpEnergy {
                in item pumpChamberFluid : WorkingFluid;
                out item pressurizedFluid : WorkingFluid;
                out pressureRise : Pressure_kPa;
            }

            action dischargeFluid {
                in item pressurizedFluid : WorkingFluid;
                out item deliveredFluid : WorkingFluid;
                out flow : FlowRate_Lpm;
            }
        }

        state pumpStateMachine {
            state off;
            state priming;
            state pumping;
            state recirculating;
            state draining;
            state faulted;

            transition initial then off;

            transition startCommand
                first off
                accept ControlCommand
                if commandIn.command.startRequested
                then priming;

            transition primeEstablished
                first priming
                if suction.pressure < -10.0 and discharge.flowRate >= minimumContinuousFlow
                then pumping;

            transition lowDemand
                first pumping
                if discharge.flowRate < minimumContinuousFlow
                then recirculating;

            transition demandRestored
                first recirculating
                if commandIn.command.targetFlow >= minimumContinuousFlow
                then pumping;

            transition stopCommandFromPumping
                first pumping
                accept ControlCommand
                if commandIn.command.stopRequested
                then draining;

            transition stopCommandFromRecirculating
                first recirculating
                accept ControlCommand
                if commandIn.command.stopRequested
                then draining;

            transition drainComplete
                first draining
                if suction.flowRate == 0.0 and discharge.flowRate == 0.0
                then off;

            transition overPressureFault
                first pumping
                if discharge.pressure > maximumDischargePressure
                then faulted;

            transition dryRunFault
                first priming
                if suction.flowRate == 0.0
                then faulted;

            transition resetFault
                first faulted
                accept ControlCommand
                if commandIn.command.resetRequested
                then off;
        }
    }

    part def DischargeHose {
        port inlet : FluidPort;
        port outlet : FluidPort;

        attribute insideDiameter_mm : Real = 65.0;
        attribute length : Length_m = 12.0;
        attribute workingPressure : Pressure_kPa = 500.0;
        attribute burstPressure : Pressure_kPa = 1500.0;
    }

    part def FlowMeter {
        port inlet : FluidPort;
        port outlet : FluidPort;
        port statusOut : StatusPort;

        attribute measuredFlow : FlowRate_Lpm;
        attribute accuracyPercent : Real = 2.0;
        attribute minimumMeasurableFlow : FlowRate_Lpm = 5.0;
    }

    part def PressureSensor {
        port sensedPort : FluidPort;
        port statusOut : StatusPort;

        attribute measuredPressure : Pressure_kPa;
        attribute accuracy_kPa : Pressure_kPa = 2.0;
        attribute samplePeriod : Time_s = 0.1;
    }

    part def RecirculationBypass {
        port highPressureInlet : FluidPort;
        port lowPressureOutlet : FluidPort;

        attribute valvePosition : ValvePosition;
        attribute setPressure : Pressure_kPa = 380.0;
        attribute bypassFlowCapacity : FlowRate_Lpm = 60.0;
    }

    part def PumpController {
        port commandIn : CommandPort;
        port pumpCommandOut : CommandPort;
        port statusIn : StatusPort;
        port statusOut : StatusPort;

        attribute commandedMode : PumpOperatingMode;
        attribute targetFlow : FlowRate_Lpm;
        attribute shutdownDelay : Time_s = 2.0;
        attribute faultLatchActive : Boolean;

        action regulateFlow {
            in measuredFlow : FlowRate_Lpm;
            in targetFlow : FlowRate_Lpm;
            out speedCommand : Speed_rpm;

            first compareFlow;
            then calculateSpeedTrim;
            then issueCommand;

            action compareFlow {
                out flowError : FlowRate_Lpm;
            }

            action calculateSpeedTrim {
                in flowError : FlowRate_Lpm;
                out speedCommand : Speed_rpm;
            }

            action issueCommand {
                in speedCommand : Speed_rpm;
                out item command : ControlCommand;
            }
        }
    }

    part def PumpingSubsystem {
        port sourceInlet : FluidPort;
        port deliveredOutlet : FluidPort;
        port electricalSupply : PowerInputPort;
        port operatorCommand : CommandPort;
        port subsystemStatus : StatusPort;

        part strainer : SuctionStrainer;
        part suctionHose : SuctionHose;
        part inletCheckValve : CheckValve;
        part diversPump : DiverPump;
        part dischargeHose : DischargeHose;
        part flowMeter : FlowMeter;
        part dischargePressureSensor : PressureSensor;
        part suctionPressureSensor : PressureSensor;
        part bypass : RecirculationBypass;
        part controller : PumpController;

        attribute requiredFlow : FlowRate_Lpm = 100.0;
        attribute deliveredFlow : FlowRate_Lpm;
        attribute sourceFluidLevelAbovePump : Length_m = 1.0;
        attribute totalDynamicHead : Pressure_kPa;
        attribute subsystemEfficiency : EfficiencyRatio;
        attribute availableNpsh : Pressure_kPa;

        connect sourceInlet to strainer.inlet;
        connect strainer.outlet to suctionHose.inlet;
        connect suctionHose.outlet to inletCheckValve.inlet;
        connect inletCheckValve.outlet to diversPump.suction;
        connect diversPump.discharge to dischargeHose.inlet;
        connect dischargeHose.outlet to flowMeter.inlet;
        connect flowMeter.outlet to deliveredOutlet;

        connect diversPump.discharge to dischargePressureSensor.sensedPort;
        connect diversPump.suction to suctionPressureSensor.sensedPort;

        connect diversPump.discharge to bypass.highPressureInlet;
        connect bypass.lowPressureOutlet to diversPump.suction;

        connect electricalSupply to diversPump.powerIn;
        connect operatorCommand to controller.commandIn;
        connect controller.pumpCommandOut to diversPump.commandIn;
        connect diversPump.statusOut to controller.statusIn;
        connect controller.statusOut to subsystemStatus;

        action pumpFromSourceToOutlet {
            in item sourceFluid : WorkingFluid;
            in item command : ControlCommand;
            out item deliveredFluid : WorkingFluid;
            out item status : PumpStatus;

            first admitFluid;
            then primePump;
            then transferFluid;
            then monitorDischarge;

            action admitFluid {
                out item strainedFluid : WorkingFluid;
            }

            action primePump {
                in item strainedFluid : WorkingFluid;
                out primed : Boolean;
            }

            action transferFluid {
                in primed : Boolean;
                out item pressurizedFluid : WorkingFluid;
                out actualFlow : FlowRate_Lpm;
            }

            action monitorDischarge {
                in actualFlow : FlowRate_Lpm;
                out item status : PumpStatus;
            }
        }
    }

    constraint def FlowBalance {
        in suctionFlow : FlowRate_Lpm;
        in dischargeFlow : FlowRate_Lpm;
        in bypassFlow : FlowRate_Lpm;

        suctionFlow == dischargeFlow + bypassFlow;
    }

    constraint def PressureRiseLimit {
        in suctionPressure : Pressure_kPa;
        in dischargePressure : Pressure_kPa;
        in maxRise : Pressure_kPa;

        dischargePressure - suctionPressure <= maxRise;
    }

    constraint def MinimumFlowProtection {
        in deliveredFlow : FlowRate_Lpm;
        in minimumFlow : FlowRate_Lpm;
        in bypassOpen : Boolean;

        deliveredFlow >= minimumFlow or bypassOpen;
    }

    requirement def MoveFluidRequirement {
        subject subsystem : PumpingSubsystem;

        doc "The pumping subsystem shall move working fluid from the source inlet to the delivered outlet using the Diver's pump as the only active hydraulic energy source.";

        require constraint {
            subsystem.deliveredFlow >= subsystem.requiredFlow;
        }
    }

    requirement def RatedFlowRequirement {
        subject pump : DiverPump;

        doc "The Diver's pump shall provide at least 120 L/min under nominal suction and discharge conditions.";

        require constraint {
            pump.ratedFlow >= 120.0;
        }
    }

    requirement def OverPressureProtectionRequirement {
        subject pump : DiverPump;

        doc "The Diver's pump shall enter a faulted state before discharge pressure exceeds 420 kPa.";

        require constraint {
            pump.discharge.pressure <= pump.maximumDischargePressure;
        }
    }

    requirement def DryRunProtectionRequirement {
        subject pump : DiverPump;

        doc "The Diver's pump shall not operate without fluid flow for more than 20 seconds during priming.";

        require constraint {
            pump.dryRunLimit <= 20.0;
        }
    }

    requirement def ReverseFlowRequirement {
        subject valve : CheckValve;

        doc "The inlet check valve shall limit reverse leakage from the pump suction line to no more than 0.1 L/min.";

        require constraint {
            valve.reverseLeakageFlow <= 0.1;
        }
    }

    requirement def BypassProtectionRequirement {
        subject bypass : RecirculationBypass;

        doc "The recirculation bypass shall open when discharge pressure reaches the bypass set pressure and shall return flow to the pump suction path.";

        require constraint {
            bypass.setPressure <= 380.0 and bypass.bypassFlowCapacity >= 60.0;
        }
    }

    requirement def HosePressureRequirement {
        subject hose : DischargeHose;

        doc "The discharge hose shall withstand the maximum Diver's pump discharge pressure with margin.";

        require constraint {
            hose.workingPressure >= 500.0 and hose.burstPressure >= 1500.0;
        }
    }

    requirement def ControlRequirement {
        subject controller : PumpController;

        doc "The controller shall accept operator start, stop, reset, and target-flow commands and shall provide a pump command and subsystem status.";

        require constraint {
            controller.shutdownDelay <= 2.0;
        }
    }

    satisfy MoveFluidRequirement by PumpingSubsystem;
    satisfy RatedFlowRequirement by DiverPump;
    satisfy OverPressureProtectionRequirement by DiverPump;
    satisfy DryRunProtectionRequirement by DiverPump;
    satisfy ReverseFlowRequirement by CheckValve;
    satisfy BypassProtectionRequirement by RecirculationBypass;
    satisfy HosePressureRequirement by DischargeHose;
    satisfy ControlRequirement by PumpController;
}