package BakriBalloonTamponadeSystem {

    private import ScalarValues::*;
    private import SI::*;

    item def SterileSaline;
    item def Blood;

    attribute def Volume :> Real { unit = "mL"; }
    attribute def Pressure :> Real { unit = "mmHg"; }
    attribute def FlowRate :> Real { unit = "mL/min"; }

    occurrence def InsertComplete;
    occurrence def InflationComplete;
    occurrence def BleedingContinues;
    occurrence def BleedingControlled;
    occurrence def ObservationComplete;
    occurrence def DeflationComplete;
    occurrence def ProcedureComplete;

    port def SalineInPort {
        in item saline : SterileSaline;
    }
    port def SalineOutPort {
        out item saline : SterileSaline;
    }
    port def BloodInPort {
        in item blood : Blood;
    }
    port def BloodOutPort {
        out item blood : Blood;
    }
    port def PressureOutPort {
        out attribute pressure : Pressure;
    }
    port def PressureInPort {
        in attribute pressure : Pressure;
    }

    part def Balloon {
        attribute maxVolume : Volume = 500;
        attribute currentVolume : Volume = 0;
        attribute currentPressure : Pressure = 0;
        port inflatePort : SalineInPort;
        port wallPressurePort : PressureOutPort;
    }

    part def Catheter {
        attribute length : Real = 54;
        part inflationLumen {
            port inlet : SalineInPort;
            port outlet : SalineOutPort;
            flow inlet.saline to outlet.saline;
        }
        part drainageLumen {
            port inlet : BloodInPort;
            port outlet : BloodOutPort;
            flow inlet.blood to outlet.blood;
        }
        part pressureLumen {
            port sensePort : PressureInPort;
            port reportPort : PressureOutPort;
            flow sensePort.pressure to reportPort.pressure;
        }
    }

    part def Syringe {
        attribute capacity : Volume = 60;
        attribute currentFill : Volume = 60;
        port outlet : SalineOutPort;
    }

    part def PressureGauge {
        attribute reading : Pressure = 0;
        port sensorPort : PressureInPort;
        port displayPort : PressureOutPort;
        flow sensorPort.pressure to displayPort.pressure;
    }

    part def DrainageBag {
        attribute capacity : Volume = 2000;
        attribute collectedVolume : Volume = 0;
        port inlet : BloodInPort;
    }

    part def Patient {
        part uterus {
            attribute wallPressure : Pressure = 0;
            attribute hemorrhageActive : Boolean = true;
            port cavityPort : BloodOutPort;
            port contactPort : PressureInPort;
        }
    }

    requirement def MaxBalloonVolumeRequirement {
        doc /* The balloon shall hold up to 500 mL of sterile saline solution. */
        attribute maxVolume : Volume = 500;
        attribute balloonVolume : Volume;
        constraint { balloonVolume <= maxVolume }
    }

    requirement def TamponadePressureRequirement {
        doc /* The balloon shall maintain effective tamponade pressure on uterine walls. */
        attribute minEffectivePressure : Pressure = 60;
        attribute maxSafePressure : Pressure = 120;
        attribute balloonPressure : Pressure;
        constraint { balloonPressure >= minEffectivePressure and balloonPressure <= maxSafePressure }
    }

    requirement def DrainageMonitoringRequirement {
        doc /* The drainage channel shall allow continuous monitoring of blood loss. */
        attribute minChannelDiameter : Real = 4.0;
    }

    requirement def HemorrhageControlRequirement {
        doc /* The system shall control postpartum hemorrhage by applying direct pressure to uterine walls. */
    }

    action def InsertCatheterAction {
        in part targetPatient : Patient;
    }
    action def InflateBalloonAction {
        in item saline : SterileSaline;
        in part targetBalloon : Balloon;
        out attribute volume : Volume;
        out attribute pressure : Pressure;
    }
    action def MonitorDrainageAction {
        in attribute collectedVolume : Volume;
        out attribute bleedingControlled : Boolean;
    }
    action def AdjustBalloonVolumeAction {
        in item saline : SterileSaline;
        in part targetBalloon : Balloon;
        out attribute newVolume : Volume;
    }
    action def DeflateBalloonAction {
        in part targetBalloon : Balloon;
        out item saline : SterileSaline;
        out attribute remainingVolume : Volume;
    }
    action def RemoveCatheterAction {
        in part targetCatheter : Catheter;
    }

    action def MonitorBalloonPressure {
        out attribute currentPressure : Pressure;
        out attribute currentVolume : Volume;
    }
    action def InjectSaline {
        in item saline : SterileSaline;
        out attribute injectedVolume : Volume;
    }
    action def StopInflation;

    action def InflateBalloonProcedure {
        first start;
        then merge continueInflation;
        then action monitorPressure : MonitorBalloonPressure;
        then decide;
        if monitorPressure.currentVolume < 500 and monitorPressure.currentPressure < 120 then addSaline;
        if monitorPressure.currentVolume >= 500 or monitorPressure.currentPressure >= 120 then stopInflation;
        action addSaline : InjectSaline;
        then continueInflation;
        action stopInflation : StopInflation;
        then done;
    }

    action def MonitorDrainageProcedure {
        first start;
        then merge checkDrainage;
        then action assessBag : MonitorDrainageAction;
        then decide;
        if assessBag.bleedingControlled == true then reportControlled;
        if assessBag.bleedingControlled == false then reportOngoing;
        action reportControlled;
        then done;
        action reportOngoing;
        then checkDrainage;
    }

    state def TamponadeProcedure {
        entry; then Inserting;

        state Inserting {
            do action insertCatheter;
        }
        accept InsertComplete then Inflating;

        state Inflating {
            do action inflateBalloon;
        }
        accept InflationComplete then Monitoring;

        state Monitoring {
            do action checkDrainage;
        }
        accept BleedingContinues then Adjusting;
        accept BleedingControlled then Maintaining;

        state Adjusting {
            do action addSaline;
        }
        transition first Adjusting then Monitoring;

        state Maintaining {
            do action maintainPressure;
        }
        accept ObservationComplete then Deflating;

        state Deflating {
            do action withdrawSaline;
        }
        accept DeflationComplete then Removing;

        state Removing {
            do action removeCatheter;
        }
        accept ProcedureComplete then done;
    }

    part def BakriTamponadeSystem {
        part balloon : Balloon;
        part catheter : Catheter;
        part syringe : Syringe;
        part pressureGauge : PressureGauge;
        part drainageBag : DrainageBag;
        ref patient : Patient;

        flow syringe.outlet.saline to catheter.inflationLumen.inlet.saline;
        flow catheter.inflationLumen.outlet.saline to balloon.inflatePort.saline;
        flow balloon.wallPressurePort.pressure to catheter.pressureLumen.sensePort.pressure;
        flow catheter.pressureLumen.reportPort.pressure to pressureGauge.sensorPort.pressure;
        flow patient.uterus.cavityPort.blood to catheter.drainageLumen.inlet.blood;
        flow catheter.drainageLumen.outlet.blood to drainageBag.inlet.blood;
        flow balloon.wallPressurePort.pressure to patient.uterus.contactPort.pressure;

        attribute balloonVolume : Volume = balloon.currentVolume;
        attribute balloonPressure : Pressure = balloon.currentPressure;
        attribute drainageTotal : Volume = drainageBag.collectedVolume;

        requirement maxVolReq : MaxBalloonVolumeRequirement {
            attribute balloonVolume : Volume = balloon.currentVolume;
        }
        requirement pressureReq : TamponadePressureRequirement {
            attribute balloonPressure : Pressure = balloon.currentPressure;
        }
        requirement drainageReq : DrainageMonitoringRequirement;
        requirement hemorrhageReq : HemorrhageControlRequirement;

        exhibit tamponadeProcedure : TamponadeProcedure;
    }

    individual def BakriProcedureScenario :> BakriTamponadeSystem;

    individual bakriProcedure : BakriProcedureScenario {
        timeslice insertionPhase {
            :>> balloon.currentVolume = 0;
            :>> balloon.currentPressure = 0;
            :>> drainageBag.collectedVolume = 0;
        }
        then timeslice inflationPhase {
            :>> balloon.currentVolume = 300;
            :>> balloon.currentPressure = 80;
        }
        then timeslice monitoringPhase {
            :>> drainageBag.collectedVolume = 50;
        }
        then timeslice adjustingPhase {
            :>> balloon.currentVolume = 450;
            :>> balloon.currentPressure = 95;
        }
        then timeslice maintainingPhase {
            :>> drainageBag.collectedVolume = 55;
        }
        then timeslice deflationPhase {
            :>> balloon.currentVolume = 0;
            :>> balloon.currentPressure = 0;
        }
        then timeslice removalPhase {
            :>> balloon.currentVolume = 0;
            :>> balloon.currentPressure = 0;
        }
    }
}
