package MurphyDripSystemModel {
    doc /* System model for a gravity-fed Murphy drip intended to provide controlled continuous fluid administration at low pressure. */

    attribute def Volume {
        :>> scalarValues::Real;
        unit = "mL";
    }

    attribute def FlowRate {
        :>> scalarValues::Real;
        unit = "mL/min";
    }

    attribute def Pressure {
        :>> scalarValues::Real;
        unit = "kPa";
    }

    attribute def Height {
        :>> scalarValues::Real;
        unit = "cm";
    }

    attribute def Temperature {
        :>> scalarValues::Real;
        unit = "degC";
    }

    attribute def TimeDuration {
        :>> scalarValues::Real;
        unit = "min";
    }

    attribute def SterilityStatus {
        :>> scalarValues::String;
    }

    item def InfusionFluid {
        attribute volume : Volume;
        attribute temperature : Temperature;
        attribute sterility : SterilityStatus;
        attribute osmolarity_mOsmPerL : scalarValues::Real;
    }

    item def AirBubble {
        attribute estimatedVolume : Volume;
    }

    item def ClinicianCommand {
        attribute commandName : scalarValues::String;
    }

    port def FluidOutletPort {
        out item fluid : InfusionFluid;
    }

    port def FluidInletPort {
        in item fluid : InfusionFluid;
    }

    port def VentPort {
        in item ambientAir;
        out item displacedAir;
    }

    port def ControlPort {
        in item command : ClinicianCommand;
    }

    port def StatusPort {
        out attribute currentFlowRate : FlowRate;
        out attribute remainingVolume : Volume;
        out attribute alarmActive : scalarValues::Boolean;
    }

    part def FluidReservoir {
        attribute capacity : Volume = 1000 [mL];
        attribute filledVolume : Volume;
        attribute fluidTemperature : Temperature;
        attribute heightAbovePatient : Height;
        attribute sterileBarrierIntact : scalarValues::Boolean;

        port outlet : FluidOutletPort;
        port vent : VentPort;

        perform action maintainHeadPressure {
            in attribute reservoirHeight : Height;
            out attribute hydrostaticPressure : Pressure;
        }
    }

    part def DripChamber {
        attribute chamberVolume : Volume = 20 [mL];
        attribute visibleDropRate_dropsPerMin : scalarValues::Real;
        attribute airSeparationEffective : scalarValues::Boolean;

        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;

        perform action separateAirFromFluid {
            in item incomingFluid : InfusionFluid;
            out item conditionedFluid : InfusionFluid;
            out item trappedAir : AirBubble;
        }
    }

    part def FlowRegulator {
        attribute targetFlowRate : FlowRate;
        attribute actualFlowRate : FlowRate;
        attribute minimumFlowRate : FlowRate = 1 [mL/min];
        attribute maximumFlowRate : FlowRate = 120 [mL/min];
        attribute clampPosition_percentOpen : scalarValues::Real;

        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
        port control : ControlPort;

        perform action regulateFlow {
            in attribute desiredFlowRate : FlowRate;
            in item incomingFluid : InfusionFluid;
            out item meteredFluid : InfusionFluid;
            out attribute regulatedFlowRate : FlowRate;
        }
    }

    part def DeliveryTube {
        attribute internalVolume : Volume = 12 [mL];
        attribute kinkDetected : scalarValues::Boolean;
        attribute primed : scalarValues::Boolean;

        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;

        perform action conductFluid {
            in item regulatedFluid : InfusionFluid;
            out item deliveredFluid : InfusionFluid;
        }
    }

    part def PatientInterface {
        attribute insertionSitePrepared : scalarValues::Boolean;
        attribute interfaceSecured : scalarValues::Boolean;
        attribute localPressure : Pressure;

        port inlet : FluidInletPort;

        perform action transferFluidToPatient {
            in item deliveredFluid : InfusionFluid;
            out attribute acceptedVolume : Volume;
        }
    }

    part def MonitoringSet {
        attribute elapsedInfusionTime : TimeDuration;
        attribute cumulativeDeliveredVolume : Volume;
        attribute lowReservoirAlarm : scalarValues::Boolean;
        attribute flowDeviationAlarm : scalarValues::Boolean;
        attribute occlusionAlarm : scalarValues::Boolean;

        port status : StatusPort;

        perform action evaluateInfusion {
            in attribute commandedFlow : FlowRate;
            in attribute measuredFlow : FlowRate;
            in attribute remainingVolume : Volume;
            in attribute kinkDetected : scalarValues::Boolean;
            out attribute alarmActive : scalarValues::Boolean;
        }
    }

    part def MurphyDrip {
        doc /* Primary function: continuously deliver a prescribed therapeutic fluid by gravity from an elevated reservoir through a visible drip chamber, adjustable regulator, tubing, and patient interface at a controlled low flow rate. */

        attribute prescribedVolume : Volume = 500 [mL];
        attribute prescribedFlowRate : FlowRate = 30 [mL/min];
        attribute maximumSafePressure : Pressure = 12 [kPa];
        attribute minimumReservoirHeight : Height = 40 [cm];
        attribute maximumReservoirHeight : Height = 120 [cm];

        port clinicianControl : ControlPort;
        port systemStatus : StatusPort;

        part reservoir : FluidReservoir;
        part dripChamber : DripChamber;
        part regulator : FlowRegulator;
        part tube : DeliveryTube;
        part patientInterface : PatientInterface;
        part monitor : MonitoringSet;

        connect reservoir.outlet to dripChamber.inlet;
        connect dripChamber.outlet to regulator.inlet;
        connect regulator.outlet to tube.inlet;
        connect tube.outlet to patientInterface.inlet;
        connect clinicianControl to regulator.control;
        connect monitor.status to systemStatus;

        perform action primeSystem {
            in item primingFluid : InfusionFluid;
            out attribute tubePrimed : scalarValues::Boolean;
            out attribute chamberFilled : scalarValues::Boolean;
        }

        perform action startInfusion {
            in attribute prescribedRate : FlowRate;
            in attribute prescribedVolume : Volume;
            out attribute infusionStarted : scalarValues::Boolean;
        }

        perform action stopInfusion {
            out attribute flowStopped : scalarValues::Boolean;
        }

        perform action deliverControlledFluid {
            in item sourceFluid : InfusionFluid;
            in attribute requestedFlowRate : FlowRate;
            out item administeredFluid : InfusionFluid;
            out attribute deliveredVolume : Volume;
        }

        state behavior InfusionLifecycle {
            entry action initialize {
                then reservoir.sterileBarrierIntact = true;
                then tube.primed = false;
                then monitor.cumulativeDeliveredVolume = 0 [mL];
            }

            state Idle;
            state Setup;
            state Priming;
            state Ready;
            state Infusing;
            state Paused;
            state Completed;
            state Alarm;
            state Shutdown;

            transition first Idle;

            transition Idle_to_Setup
                first Idle
                accept ClinicianCommand
                if command.commandName == "prepare"
                then Setup;

            transition Setup_to_Priming
                first Setup
                if reservoir.filledVolume >= prescribedVolume and
                   reservoir.heightAbovePatient >= minimumReservoirHeight and
                   reservoir.heightAbovePatient <= maximumReservoirHeight and
                   patientInterface.insertionSitePrepared
                then Priming;

            transition Priming_to_Ready
                first Priming
                do primeSystem
                if tube.primed and dripChamber.airSeparationEffective
                then Ready;

            transition Ready_to_Infusing
                first Ready
                accept ClinicianCommand
                if command.commandName == "start"
                do startInfusion
                then Infusing;

            transition Infusing_to_Paused
                first Infusing
                accept ClinicianCommand
                if command.commandName == "pause"
                then Paused;

            transition Paused_to_Infusing
                first Paused
                accept ClinicianCommand
                if command.commandName == "resume"
                then Infusing;

            transition Infusing_to_Completed
                first Infusing
                if monitor.cumulativeDeliveredVolume >= prescribedVolume
                do stopInfusion
                then Completed;

            transition Infusing_to_Alarm
                first Infusing
                if monitor.lowReservoirAlarm or
                   monitor.flowDeviationAlarm or
                   monitor.occlusionAlarm or
                   patientInterface.localPressure > maximumSafePressure
                do stopInfusion
                then Alarm;

            transition Alarm_to_Shutdown
                first Alarm
                accept ClinicianCommand
                if command.commandName == "acknowledge"
                then Shutdown;

            transition Completed_to_Shutdown
                first Completed
                accept ClinicianCommand
                if command.commandName == "remove"
                then Shutdown;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The Murphy drip shall provide continuous gravity-assisted administration of prescribed fluid at a controlled low flow rate from an elevated reservoir to the patient interface. */
        subject drip : MurphyDrip;
        require constraint {
            drip.prescribedFlowRate >= 1 [mL/min] and
            drip.prescribedFlowRate <= 120 [mL/min]
        }
    }

    requirement def ReservoirHeightRequirement {
        doc /* The reservoir shall be positioned high enough to create flow and low enough to avoid excessive pressure. */
        subject drip : MurphyDrip;
        require constraint {
            drip.reservoir.heightAbovePatient >= drip.minimumReservoirHeight and
            drip.reservoir.heightAbovePatient <= drip.maximumReservoirHeight
        }
    }

    requirement def AirSeparationRequirement {
        doc /* The drip chamber shall allow visible drop formation and separation of entrained air before fluid enters the regulator. */
        subject chamber : DripChamber;
        require constraint {
            chamber.chamberVolume >= 10 [mL] and
            chamber.airSeparationEffective == true
        }
    }

    requirement def FlowControlRequirement {
        doc /* The regulator shall maintain actual flow within ten percent of the prescribed flow rate during normal infusion. */
        subject drip : MurphyDrip;
        require constraint {
            drip.regulator.actualFlowRate >= drip.prescribedFlowRate * 0.90 and
            drip.regulator.actualFlowRate <= drip.prescribedFlowRate * 1.10
        }
    }

    requirement def LowPressureSafetyRequirement {
        doc /* The drip shall stop infusion or alarm when patient interface pressure exceeds the maximum safe pressure. */
        subject drip : MurphyDrip;
        require constraint {
            drip.patientInterface.localPressure <= drip.maximumSafePressure or
            drip.monitor.alarmActive == true
        }
    }

    requirement def CompletionRequirement {
        doc /* The drip shall terminate normal infusion after the prescribed volume has been delivered. */
        subject drip : MurphyDrip;
        require constraint {
            drip.monitor.cumulativeDeliveredVolume >= drip.prescribedVolume implies
            drip.regulator.actualFlowRate == 0 [mL/min]
        }
    }

    satisfy PrimaryFunctionRequirement by MurphyDrip;
    satisfy ReservoirHeightRequirement by MurphyDrip;
    satisfy AirSeparationRequirement by DripChamber;
    satisfy FlowControlRequirement by FlowRegulator;
    satisfy LowPressureSafetyRequirement by MurphyDrip;
    satisfy CompletionRequirement by MurphyDrip;
}