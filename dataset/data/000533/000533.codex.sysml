package AspiratorSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure;
    attribute def FlowRate;
    attribute def Volume;
    attribute def Power;
    attribute def Time;
    attribute def Speed;
    attribute def Temperature;

    item def Air {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
    }

    item def AspiratedFluid {
        attribute volume : Volume;
        attribute viscosityClass : String;
        attribute contaminationLevel : String;
    }

    item def ElectricalEnergy {
        attribute voltage : Real;
        attribute current : Real;
        attribute power : Power;
    }

    item def ControlSignal {
        attribute command : String;
        attribute requestedVacuum : Pressure;
    }

    item def AlarmSignal {
        attribute alarmCode : String;
        attribute severity : String;
    }

    port def FluidInletPort {
        in item fluid : AspiratedFluid;
        in item air : Air;
    }

    port def FluidOutletPort {
        out item fluid : AspiratedFluid;
        out item air : Air;
    }

    port def ElectricalPowerPort {
        in item energy : ElectricalEnergy;
    }

    port def ControlInputPort {
        in item signal : ControlSignal;
    }

    port def AlarmOutputPort {
        out item alarm : AlarmSignal;
    }

    port def ExhaustPort {
        out item air : Air;
    }

    part def SuctionTip {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;

        attribute innerDiameter : Real = 6.0;
        attribute length : Real = 250.0;
        attribute isSterile : Boolean = true;
    }

    part def SuctionTubing {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;

        attribute innerDiameter : Real = 8.0;
        attribute length : Real = 1800.0;
        attribute kinkDetected : Boolean = false;
        attribute maximumSafeVacuum : Pressure;
    }

    part def VacuumPump {
        port inlet : FluidInletPort;
        port exhaust : ExhaustPort;
        port power : ElectricalPowerPort;
        port control : ControlInputPort;

        attribute targetVacuum : Pressure;
        attribute measuredVacuum : Pressure;
        attribute nominalFlowRate : FlowRate;
        attribute motorSpeed : Speed;
        attribute running : Boolean = false;

        action def StartPump {
            out success : Boolean;
        }

        action def StopPump {
            out success : Boolean;
        }

        action def RegulateVacuum {
            in requestedVacuum : Pressure;
            out achievedVacuum : Pressure;
        }

        state def PumpOperatingState {
            state off;
            state starting;
            state running;
            state regulating;
            state stopping;
            state faulted;

            entry; then off;

            transition off_to_starting
                first off
                accept ControlSignal
                if signal.command == "start"
                then starting;

            transition starting_to_running
                first starting
                then running;

            transition running_to_regulating
                first running
                accept ControlSignal
                if signal.command == "setVacuum"
                then regulating;

            transition regulating_to_running
                first regulating
                then running;

            transition running_to_stopping
                first running
                accept ControlSignal
                if signal.command == "stop"
                then stopping;

            transition stopping_to_off
                first stopping
                then off;

            transition any_to_faulted
                first running
                if measuredVacuum > maximumSafeVacuum
                then faulted;
        }

        perform action startPump : StartPump;
        perform action stopPump : StopPump;
        perform action regulateVacuum : RegulateVacuum;
        exhibit state pumpState : PumpOperatingState;
    }

    part def CollectionCanister {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;

        attribute capacity : Volume;
        attribute collectedVolume : Volume;
        attribute fillFraction : Real;
        attribute overflowProtected : Boolean = true;

        action def SeparateFluidFromAir {
            in incomingFluid : AspiratedFluid;
            out retainedFluid : AspiratedFluid;
            out outgoingAir : Air;
        }

        action def DetectFullCondition {
            out isFull : Boolean;
        }

        perform action separation : SeparateFluidFromAir;
        perform action fullDetection : DetectFullCondition;
    }

    part def HydrophobicFilter {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;

        attribute poreSizeMicrometers : Real = 0.2;
        attribute saturated : Boolean = false;
        attribute pressureDrop : Pressure;

        action def BlockLiquidCarryover {
            in incomingFluid : AspiratedFluid;
            out protectedAirFlow : Air;
        }

        perform action blockCarryover : BlockLiquidCarryover;
    }

    part def VacuumRegulator {
        port controlIn : ControlInputPort;
        port controlOut : ControlInputPort;

        attribute userSetVacuum : Pressure;
        attribute minimumVacuum : Pressure;
        attribute maximumVacuum : Pressure;
        attribute regulationTolerance : Pressure;

        action def ClampVacuumCommand {
            in requestedVacuum : Pressure;
            out safeVacuum : Pressure;
        }

        perform action clampCommand : ClampVacuumCommand;
    }

    part def UserInterface {
        port commandOut : ControlInputPort;
        port alarmIn : AlarmOutputPort;

        attribute powerButtonPressed : Boolean = false;
        attribute setVacuumLevel : Pressure;
        attribute displayedVacuum : Pressure;
        attribute displayedFillLevel : Real;

        action def AcceptOperatorCommand {
            out command : ControlSignal;
        }

        action def DisplayStatus {
            in measuredVacuum : Pressure;
            in fillLevel : Real;
        }

        perform action acceptCommand : AcceptOperatorCommand;
        perform action displayStatus : DisplayStatus;
    }

    part def SensorModule {
        port alarmOut : AlarmOutputPort;

        attribute measuredVacuum : Pressure;
        attribute measuredFlowRate : FlowRate;
        attribute canisterFillLevel : Real;
        attribute filterPressureDrop : Pressure;
        attribute occlusionDetected : Boolean;
        attribute canisterFullDetected : Boolean;

        action def MonitorAspirationPath {
            out vacuum : Pressure;
            out flow : FlowRate;
            out fillLevel : Real;
            out alarm : AlarmSignal;
        }

        perform action monitorPath : MonitorAspirationPath;
    }

    part def PowerSupply {
        port output : ElectricalPowerPort;

        attribute inputVoltage : Real = 120.0;
        attribute outputVoltage : Real = 24.0;
        attribute maximumPower : Power;
        attribute batteryBackupAvailable : Boolean = true;
        attribute batteryRuntime : Time;
    }

    part def Aspirator {
        port patientInterface : FluidInletPort;
        port exhaust : ExhaustPort;
        port mainsPower : ElectricalPowerPort;
        port operatorControl : ControlInputPort;
        port alarmOutput : AlarmOutputPort;

        attribute primaryFunction : String =
            "Generate controlled negative pressure to remove unwanted fluid, secretions, and entrained air from a target site and collect the fluid safely in a sealed canister.";
        attribute operatingVacuumRangeLow : Pressure;
        attribute operatingVacuumRangeHigh : Pressure;
        attribute maximumCollectionVolume : Volume;
        attribute nominalAspirationFlow : FlowRate;
        attribute continuousOperationTime : Time;

        part tip : SuctionTip;
        part tubing : SuctionTubing;
        part canister : CollectionCanister {
            attribute capacity = maximumCollectionVolume;
        }
        part filter : HydrophobicFilter;
        part pump : VacuumPump;
        part regulator : VacuumRegulator;
        part ui : UserInterface;
        part sensors : SensorModule;
        part powerSupply : PowerSupply;

        connection patient_to_tip
            connect patientInterface to tip.inlet;

        connection tip_to_tubing
            connect tip.outlet to tubing.inlet;

        connection tubing_to_canister
            connect tubing.outlet to canister.inlet;

        connection canister_to_filter
            connect canister.outlet to filter.inlet;

        connection filter_to_pump
            connect filter.outlet to pump.inlet;

        connection pump_to_exhaust
            connect pump.exhaust to exhaust;

        connection mains_to_powerSupply
            connect mainsPower to powerSupply.output;

        connection powerSupply_to_pump
            connect powerSupply.output to pump.power;

        connection operator_to_ui
            connect operatorControl to ui.commandOut;

        connection ui_to_regulator
            connect ui.commandOut to regulator.controlIn;

        connection regulator_to_pump
            connect regulator.controlOut to pump.control;

        connection sensors_to_alarm
            connect sensors.alarmOut to alarmOutput;

        connection alarm_to_ui
            connect alarmOutput to ui.alarmIn;

        action def AspirateMaterial {
            in sourceFluid : AspiratedFluid;
            out collectedFluid : AspiratedFluid;
            out dischargedAir : Air;

            first start;
            then applyVacuum;
            then drawFluid;
            then separateFluid;
            then filterAir;
            then exhaustAir;
            then finish;

            action start;
            action applyVacuum;
            action drawFluid;
            action separateFluid;
            action filterAir;
            action exhaustAir;
            action finish;
        }

        action def ShutdownSafely {
            out pumpStopped : Boolean;
            out sealedPathMaintained : Boolean;
        }

        perform action aspirate : AspirateMaterial;
        perform action shutdown : ShutdownSafely;

        state def AspiratorLifecycle {
            state unpowered;
            state standby;
            state aspirating;
            state canisterFull;
            state occluded;
            state alarmed;
            state shutdown;

            entry; then unpowered;

            transition unpowered_to_standby
                first unpowered
                accept ElectricalEnergy
                then standby;

            transition standby_to_aspirating
                first standby
                accept ControlSignal
                if signal.command == "start"
                then aspirating;

            transition aspirating_to_standby
                first aspirating
                accept ControlSignal
                if signal.command == "stop"
                then standby;

            transition aspirating_to_canisterFull
                first aspirating
                if canister.fillFraction >= 0.95
                then canisterFull;

            transition aspirating_to_occluded
                first aspirating
                if sensors.occlusionDetected
                then occluded;

            transition canisterFull_to_alarmed
                first canisterFull
                then alarmed;

            transition occluded_to_alarmed
                first occluded
                then alarmed;

            transition alarmed_to_standby
                first alarmed
                accept ControlSignal
                if signal.command == "acknowledge"
                then standby;

            transition standby_to_shutdown
                first standby
                accept ControlSignal
                if signal.command == "powerOff"
                then shutdown;
        }

        exhibit state lifecycle : AspiratorLifecycle;
    }

    requirement def PrimaryFunctionRequirement {
        subject aspirator : Aspirator;

        doc
            /* The aspirator shall provide controlled negative pressure at its patient interface to remove fluid and entrained air from a target site and route the aspirated material into a collection canister. */

        require constraint {
            aspirator.primaryFunction ==
            "Generate controlled negative pressure to remove unwanted fluid, secretions, and entrained air from a target site and collect the fluid safely in a sealed canister."
        }
    }

    requirement def VacuumControlRequirement {
        subject aspirator : Aspirator;

        doc
            /* The aspirator shall regulate suction pressure within the configured operating range during aspiration. */

        require constraint {
            aspirator.pump.measuredVacuum >= aspirator.operatingVacuumRangeLow and
            aspirator.pump.measuredVacuum <= aspirator.operatingVacuumRangeHigh
        }
    }

    requirement def CollectionRequirement {
        subject aspirator : Aspirator;

        doc
            /* The aspirator shall retain aspirated liquid in the collection canister and prevent liquid carryover into the vacuum pump. */

        require constraint {
            aspirator.canister.collectedVolume <= aspirator.canister.capacity and
            aspirator.filter.saturated == false
        }
    }

    requirement def OverflowProtectionRequirement {
        subject aspirator : Aspirator;

        doc
            /* The aspirator shall detect a near-full canister and transition to an alarmed safe condition before overflow reaches the pump inlet. */

        require constraint {
            aspirator.canister.fillFraction < 1.0
        }
    }

    requirement def OcclusionDetectionRequirement {
        subject aspirator : Aspirator;

        doc
            /* The aspirator shall detect aspiration-path occlusion using vacuum and flow measurements and provide an alarm output. */

        require constraint {
            aspirator.sensors.occlusionDetected implies
            aspirator.lifecycle == aspirator::AspiratorLifecycle::alarmed
        }
    }

    requirement def ElectricalPowerRequirement {
        subject aspirator : Aspirator;

        doc
            /* The aspirator shall operate from a regulated internal electrical supply capable of powering the vacuum pump and control electronics. */

        require constraint {
            aspirator.powerSupply.outputVoltage == 24.0 and
            aspirator.powerSupply.maximumPower >= aspirator.pump.nominalFlowRate
        }
    }

    requirement def UserControlRequirement {
        subject aspirator : Aspirator;

        doc
            /* The operator shall be able to start suction, stop suction, and set a target vacuum level through the user interface. */

        require constraint {
            aspirator.ui.setVacuumLevel >= aspirator.regulator.minimumVacuum and
            aspirator.ui.setVacuumLevel <= aspirator.regulator.maximumVacuum
        }
    }

    satisfy PrimaryFunctionRequirement by Aspirator;
    satisfy VacuumControlRequirement by Aspirator;
    satisfy CollectionRequirement by Aspirator;
    satisfy OverflowProtectionRequirement by Aspirator;
    satisfy OcclusionDetectionRequirement by Aspirator;
    satisfy ElectricalPowerRequirement by Aspirator;
    satisfy UserControlRequirement by Aspirator;

    part aspiratorSystem : Aspirator {
        attribute operatingVacuumRangeLow = 20.0;
        attribute operatingVacuumRangeHigh = 80.0;
        attribute maximumCollectionVolume = 2000.0;
        attribute nominalAspirationFlow = 30.0;
        attribute continuousOperationTime = 480.0;

        part pump {
            attribute targetVacuum = 60.0;
            attribute measuredVacuum = 60.0;
            attribute nominalFlowRate = 30.0;
            attribute motorSpeed = 3600.0;
        }

        part regulator {
            attribute userSetVacuum = 60.0;
            attribute minimumVacuum = 20.0;
            attribute maximumVacuum = 80.0;
            attribute regulationTolerance = 3.0;
        }

        part canister {
            attribute capacity = 2000.0;
            attribute collectedVolume = 0.0;
            attribute fillFraction = 0.0;
        }

        part powerSupply {
            attribute maximumPower = 150.0;
            attribute batteryRuntime = 45.0;
        }
    }

}