package UrinalSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def FlowRate :> ISQ::flowRate {
        unit = L / min;
    }

    attribute def Volume :> ISQ::volume {
        unit = L;
    }

    attribute def Duration :> ISQ::time {
        unit = s;
    }

    attribute def WaterPressure :> ISQ::pressure {
        unit = kPa;
    }

    attribute def Percentage :> ScalarValues::Real {
        unit = one;
    }

    item def Urine {
        attribute volume : Volume;
        attribute contaminantLoad : Percentage;
    }

    item def FlushWater {
        attribute volume : Volume;
        attribute pressure : WaterPressure;
    }

    item def Wastewater {
        attribute volume : Volume;
        attribute dilutionRatio : Percentage;
    }

    item def Odor {
        attribute intensity : Percentage;
    }

    port def FluidInletPort {
        in item water : FlushWater;
    }

    port def WasteOutletPort {
        out item wastewater : Wastewater;
    }

    port def UserInterfacePort {
        in event userPresenceDetected;
        in event manualFlushRequested;
        out event flushAcknowledged;
    }

    port def MaintenancePort {
        out event clogDetected;
        out event lowWaterSealDetected;
        in event serviceReset;
    }

    part def UrinalSystem {
        attribute nominalFlushVolume : Volume = 1.9 [L];
        attribute maxFlushDuration : Duration = 8 [s];
        attribute minSupplyPressure : WaterPressure = 140 [kPa];
        attribute maxSupplyPressure : WaterPressure = 550 [kPa];
        attribute requiredDrainFlowRate : FlowRate = 18 [L/min];

        port waterSupply : FluidInletPort;
        port drainOutlet : WasteOutletPort;
        port userInterface : UserInterfacePort;
        port maintenance : MaintenancePort;

        part bowl : Bowl;
        part flushValve : FlushValve;
        part trapSeal : TrapSeal;
        part drainAdapter : DrainAdapter;
        part presenceSensor : PresenceSensor;
        part controller : FlushController;
        part deodorizingSurface : DeodorizingSurface;

        connect waterSupply.water to flushValve.waterIn;
        connect flushValve.waterOut to bowl.rinseWaterIn;
        connect bowl.collectedWasteOut to trapSeal.wasteIn;
        connect trapSeal.wasteOut to drainAdapter.wasteIn;
        connect drainAdapter.wasteOut to drainOutlet.wastewater;
        connect presenceSensor.presenceEvent to controller.presenceInput;
        connect userInterface.manualFlushRequested to controller.manualFlushInput;
        connect controller.flushCommand to flushValve.openCommand;
        connect controller.flushAcknowledgement to userInterface.flushAcknowledged;
        connect trapSeal.clogAlarm to maintenance.clogDetected;
        connect trapSeal.lowSealAlarm to maintenance.lowWaterSealDetected;
        connect maintenance.serviceReset to controller.serviceResetInput;
    }

    part def Bowl {
        attribute retainedSplashFraction : Percentage = 0.02;
        attribute minimumRinseCoverage : Percentage = 0.95;
        attribute surfaceSlopeAngle : Real = 12.0;

        in item rinseWaterIn : FlushWater;
        in item urineIn : Urine;
        out item collectedWasteOut : Wastewater;
        out item odorEmission : Odor;

        action collectAndDirectWaste {
            in item urine : Urine;
            in item rinseWater : FlushWater;
            out item wastewater : Wastewater;

            first start;
            then mix;
            then directToTrap;
            then done;

            action mix {
                wastewater.volume = urine.volume + rinseWater.volume;
                wastewater.dilutionRatio = rinseWater.volume / wastewater.volume;
            }
        }
    }

    part def FlushValve {
        attribute openDuration : Duration = 5 [s];
        attribute flushVolume : Volume = 1.9 [L];
        attribute inletPressure : WaterPressure;
        attribute valveFlowRate : FlowRate = 22 [L/min];

        in item waterIn : FlushWater;
        out item waterOut : FlushWater;
        in event openCommand;

        state def ValveState {
            state closed;
            state opening;
            state open;
            state closing;

            initial then closed;

            transition closed_to_opening
                first closed
                accept openCommand
                then opening;

            transition opening_to_open
                first opening
                then open;

            transition open_to_closing
                first open
                after openDuration
                then closing;

            transition closing_to_closed
                first closing
                then closed;
        }

        action meterFlushWater {
            in item suppliedWater : FlushWater;
            out item meteredWater : FlushWater;

            meteredWater.volume = flushVolume;
            meteredWater.pressure = suppliedWater.pressure;
        }
    }

    part def TrapSeal {
        attribute sealDepth : Real = 50.0;
        attribute minimumSealDepth : Real = 25.0;
        attribute clogRestriction : Percentage = 0.0;

        in item wasteIn : Wastewater;
        out item wasteOut : Wastewater;
        out event clogAlarm;
        out event lowSealAlarm;

        state def TrapCondition {
            state sealed;
            state lowSeal;
            state restricted;
            state serviceRequired;

            initial then sealed;

            transition sealed_to_lowSeal
                first sealed
                if sealDepth < minimumSealDepth
                then lowSeal;

            transition sealed_to_restricted
                first sealed
                if clogRestriction > 0.65
                then restricted;

            transition lowSeal_to_serviceRequired
                first lowSeal
                then serviceRequired;

            transition restricted_to_serviceRequired
                first restricted
                then serviceRequired;
        }

        action preserveOdorBarrier {
            in item wastewater : Wastewater;
            out item dischargedWastewater : Wastewater;

            dischargedWastewater.volume = wastewater.volume;
            dischargedWastewater.dilutionRatio = wastewater.dilutionRatio;
        }
    }

    part def DrainAdapter {
        attribute drainDiameter : Real = 50.0;
        attribute minimumSlope : Real = 0.02;

        in item wasteIn : Wastewater;
        out item wasteOut : Wastewater;

        action conveyToBuildingDrain {
            in item localWastewater : Wastewater;
            out item buildingWastewater : Wastewater;

            buildingWastewater.volume = localWastewater.volume;
            buildingWastewater.dilutionRatio = localWastewater.dilutionRatio;
        }
    }

    part def PresenceSensor {
        attribute detectionRange : Real = 0.75;
        attribute detectionConfidence : Percentage = 0.98;
        attribute dwellTimeThreshold : Duration = 3 [s];

        out event presenceEvent;

        state def SensorState {
            state idle;
            state detecting;
            state occupied;
            state released;

            initial then idle;

            transition idle_to_detecting
                first idle
                accept userPresenceDetected
                then detecting;

            transition detecting_to_occupied
                first detecting
                after dwellTimeThreshold
                then occupied;

            transition occupied_to_released
                first occupied
                then released;

            transition released_to_idle
                first released
                then idle;
        }
    }

    part def FlushController {
        attribute automaticFlushDelay : Duration = 2 [s];
        attribute lockoutPeriod : Duration = 12 [s];
        attribute serviceModeEnabled : Boolean = false;

        in event presenceInput;
        in event manualFlushInput;
        in event serviceResetInput;
        out event flushCommand;
        out event flushAcknowledgement;

        state def ControlState {
            state ready;
            state occupied;
            state waitingToFlush;
            state flushing;
            state lockout;
            state serviceMode;

            initial then ready;

            transition ready_to_occupied
                first ready
                accept presenceInput
                then occupied;

            transition occupied_to_waitingToFlush
                first occupied
                then waitingToFlush;

            transition waitingToFlush_to_flushing
                first waitingToFlush
                after automaticFlushDelay
                send flushCommand
                then flushing;

            transition ready_to_flushing_manual
                first ready
                accept manualFlushInput
                send flushCommand
                then flushing;

            transition flushing_to_lockout
                first flushing
                send flushAcknowledgement
                then lockout;

            transition lockout_to_ready
                first lockout
                after lockoutPeriod
                then ready;

            transition any_to_serviceMode
                first ready
                if serviceModeEnabled
                then serviceMode;

            transition serviceMode_to_ready
                first serviceMode
                accept serviceResetInput
                then ready;
        }
    }

    part def DeodorizingSurface {
        attribute odorReductionEfficiency : Percentage = 0.75;
        attribute serviceLifeFlushes : Integer = 25000;

        in item odorIn : Odor;
        out item odorOut : Odor;

        action reduceOdor {
            in item untreatedOdor : Odor;
            out item treatedOdor : Odor;

            treatedOdor.intensity = untreatedOdor.intensity * (1.0 - odorReductionEfficiency);
        }
    }

    action def ReceiveUrine {
        in item urine : Urine;
        out item directedUrine : Urine;

        directedUrine.volume = urine.volume;
        directedUrine.contaminantLoad = urine.contaminantLoad;
    }

    action def FlushAndRinse {
        in item water : FlushWater;
        in item urine : Urine;
        out item wastewater : Wastewater;

        wastewater.volume = water.volume + urine.volume;
        wastewater.dilutionRatio = water.volume / wastewater.volume;
    }

    action def DischargeWastewater {
        in item wastewater : Wastewater;
        out item dischargedWastewater : Wastewater;

        dischargedWastewater.volume = wastewater.volume;
        dischargedWastewater.dilutionRatio = wastewater.dilutionRatio;
    }

    action def PrimaryUrinalFunction {
        in item userUrine : Urine;
        in item suppliedFlushWater : FlushWater;
        out item dischargedWastewater : Wastewater;

        action receive : ReceiveUrine {
            in urine = userUrine;
        }

        action flush : FlushAndRinse {
            in urine = receive.directedUrine;
            in water = suppliedFlushWater;
        }

        action discharge : DischargeWastewater {
            in wastewater = flush.wastewater;
            out dischargedWastewater = dischargedWastewater;
        }

        first receive;
        then flush;
        then discharge;
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /* The urinal system shall receive urine from a user, rinse the bowl with a controlled volume of flush water, dilute and convey the resulting wastewater through a trap seal, and discharge it to the building sanitary drain while maintaining an odor barrier. */

        subject urinal : UrinalSystem;

        require constraint {
            urinal.nominalFlushVolume <= 3.8 [L]
        }

        require constraint {
            urinal.requiredDrainFlowRate >= 18 [L/min]
        }
    }

    requirement def OdorBarrierRequirement {
        doc
        /* The trap seal shall maintain sufficient retained liquid depth to prevent sewer gas migration during normal operation. */

        subject trap : TrapSeal;

        require constraint {
            trap.sealDepth >= trap.minimumSealDepth
        }
    }

    requirement def SupplyPressureRequirement {
        doc
        /* The flush valve shall operate with building water supply pressure within the specified range. */

        subject urinal : UrinalSystem;

        require constraint {
            urinal.minSupplyPressure <= urinal.flushValve.inletPressure and
            urinal.flushValve.inletPressure <= urinal.maxSupplyPressure
        }
    }

    requirement def RinseCoverageRequirement {
        doc
        /* The bowl shall distribute flush water across the wetted surface sufficiently to remove residual urine and reduce odor generation. */

        subject bowl : Bowl;

        require constraint {
            bowl.minimumRinseCoverage >= 0.95
        }
    }

    requirement def AutomaticFlushRequirement {
        doc
        /* The controller shall issue a flush command after valid user presence has ended and the automatic flush delay has elapsed. */

        subject controller : FlushController;

        require constraint {
            controller.automaticFlushDelay <= 5 [s]
        }
    }

    satisfy PrimaryFunctionRequirement by UrinalSystem;
    satisfy OdorBarrierRequirement by TrapSeal;
    satisfy SupplyPressureRequirement by FlushValve;
    satisfy RinseCoverageRequirement by Bowl;
    satisfy AutomaticFlushRequirement by FlushController;

    part publicUrinal : UrinalSystem {
        attribute nominalFlushVolume = 1.9 [L];
        attribute maxFlushDuration = 8 [s];
        attribute requiredDrainFlowRate = 18 [L/min];

        part bowl {
            attribute retainedSplashFraction = 0.02;
            attribute minimumRinseCoverage = 0.97;
        }

        part flushValve {
            attribute openDuration = 5 [s];
            attribute flushVolume = 1.9 [L];
            attribute valveFlowRate = 22 [L/min];
            attribute inletPressure = 275 [kPa];
        }

        part trapSeal {
            attribute sealDepth = 50.0;
            attribute minimumSealDepth = 25.0;
            attribute clogRestriction = 0.0;
        }

        part presenceSensor {
            attribute detectionRange = 0.75;
            attribute detectionConfidence = 0.98;
            attribute dwellTimeThreshold = 3 [s];
        }

        part controller {
            attribute automaticFlushDelay = 2 [s];
            attribute lockoutPeriod = 12 [s];
            attribute serviceModeEnabled = false;
        }

        part deodorizingSurface {
            attribute odorReductionEfficiency = 0.75;
            attribute serviceLifeFlushes = 25000;
        }
    }
}