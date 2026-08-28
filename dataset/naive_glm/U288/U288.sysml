package LungFluteModel {

    import ScalarValues::*;
    import ISQ::*;
    import ISQSpaceTime::*;
    import ISQMechanics::*;

    // ---------- Value Types ----------
    value def FrequencyValue :> Real {
    }
    value def PressureValue :> Real {
    }
    value def LengthValue :> Real {
    }
    value def DiameterValue :> Real {
    }
    value def FlowRateValue :> Real {
    }
    value def AcousticEnergyValue :> Real {
    }

    attribute def Hz :> Real {
    }
    attribute def Pascal :> Real {
    }
    attribute def Centimeter :> Real {
    }
    attribute def LiterPerSecond :> Real {
    }
    attribute def Joule :> Real {
    }

    // ---------- Items ----------
    item def ExhaledAir {
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
    }
    item def AcousticVibration {
        attribute frequency : FrequencyValue;
        attribute energy : AcousticEnergyValue;
    }
    item def AmplifiedAcousticVibration :> AcousticVibration {
    }
    item def Mucus {
        attribute state : MucusState;
    }
    enum def MucusState {
        adherent;
        mobilized;
    }

    // ---------- Interfaces ----------
    interface def AirFlowInterface {
        end in airIn : ExhaledAir;
        end out airOut : ExhaledAir;
    }
    interface def AcousticInterface {
        end out vibration : AcousticVibration;
    }
    interface def AmplifiedAcousticInterface {
        end out amplifiedVibration : AmplifiedAcousticVibration;
    }

    // ---------- Ports ----------
    port def AirInPort {
        in air : ExhaledAir;
    }
    port def AirOutPort {
        out air : ExhaledAir;
    }
    port def AcousticOutPort {
        out vibration : AcousticVibration;
    }
    port def AmplifiedAcousticOutPort {
        out amplifiedVibration : AmplifiedAcousticVibration;
    }

    // ---------- Parts ----------
    part def Mouthpiece {
        attribute material : String = "biocompatible polymer";
        port airIn : AirInPort;
        port airOut : AirOutPort;
        attribute flowResistance : PressureValue = 50.0;
    }
    part def ReedMechanism {
        attribute material : String = "stainless steel reed";
        attribute naturalFrequency : FrequencyValue = 18.0;
        port airIn : AirInPort;
        port acousticOut : AcousticOutPort;
        attribute flutterThreshold : PressureValue = 200.0;
    }
    part def ResonanceChamber {
        attribute length : LengthValue = 15.0;
        attribute diameter : DiameterValue = 3.0;
        port acousticIn : AcousticOutPort;
        port amplifiedOut : AmplifiedAcousticOutPort;
        attribute amplificationFactor : Real = 2.5;
    }
    part def CheckValve {
        attribute crackingPressure : PressureValue = 50.0;
        port airIn : AirInPort;
        port airOut : AirOutPort;
        attribute permitsInhalation : Boolean = false;
    }
    part def PatientAirway {
        port acousticIn : AmplifiedAcousticOutPort;
        attribute mucus : Mucus;
    }

    // ---------- Behaviors ----------
    action def ExhaleAction {
        in exhaledAir : ExhaledAir;
    }
    action def FlutterAction {
        in air : ExhaledAir;
        out vibration : AcousticVibration;
    }
    action def AmplifyAction {
        in vibration : AcousticVibration;
        out amplifiedVibration : AmplifiedAcousticVibration;
    }
    action def MobilizeMucusAction {
        in amplifiedVibration : AmplifiedAcousticVibration;
        inout mucus : Mucus;
    }

    state def def ReedMechanismState {
        entry;
        state Idle;
        state Fluttering;
        transition idle_to_fluttering
            first Idle
            then Fluttering
            if airIn.air.pressure >= flutterThreshold;
        transition fluttering_to_idle
            first Fluttering
            then Idle
            if airIn.air.pressure < flutterThreshold;
    }

    state def def CheckValveState {
        state Closed;
        state Open;
        transition closed_to_open
            first Closed
            then Open
            if airIn.air.pressure >= crackingPressure;
        transition open_to_closed
            first Open
            then Closed
            if airIn.air.pressure < crackingPressure;
    }

    // ---------- Requirements ----------
    requirement def TherapeuticFrequencyRequirement {
        doc "The device shall generate acoustic vibrations at approximately 18 Hz.";
        attribute targetFrequency : FrequencyValue = 18.0;
        attribute tolerance : FrequencyValue = 2.0;
        subject reed : ReedMechanism;
        require reed.naturalFrequency == targetFrequency;
    }
    requirement def OneWayAirflowRequirement {
        doc "The device shall prevent inhalation through the mouthpiece via a check valve.";
        subject valve : CheckValve;
        require valve.permitsInhalation == false;
    }
    requirement def BackpressureRequirement {
        doc "Patient exhalation shall create sufficient backpressure to activate the reed.";
        attribute minBackpressure : PressureValue = 200.0;
        subject air : ExhaledAir;
        require air.pressure >= minBackpressure;
    }
    requirement def AmplificationRequirement {
        doc "The resonance chamber shall amplify the acoustic vibration.";
        subject chamber : ResonanceChamber;
        require chamber.amplificationFactor > 1.0;
    }
    requirement def MucusMobilizationRequirement {
        doc "Acoustic energy shall mobilize adherent mucus in patient airways.";
        subject mucusItem : Mucus;
        require mucusItem.state == MucusState::mobilized;
    }
    requirement def NoExternalPowerRequirement {
        doc "The device shall operate without external power, using only patient exhalation.";
        subject device : LungFlute;
        require device.poweredExternally == false;
    }

    // ---------- Top-level Assembly ----------
    part def LungFlute {
        attribute poweredExternally : Boolean = false;
        attribute therapeuticFrequency : FrequencyValue = 18.0;

        part mouthpiece : Mouthpiece {
            attribute material : String = "biocompatible polymer";
        }
        part reed : ReedMechanism {
            attribute naturalFrequency : FrequencyValue = 18.0;
        }
        part resonanceChamber : ResonanceChamber {
            attribute length : LengthValue = 15.0;
            attribute diameter : DiameterValue = 3.0;
        }
        part checkValve : CheckValve {
            attribute crackingPressure : PressureValue = 50.0;
        }
        part patientAirway : PatientAirway {
            attribute mucus : Mucus = Mucus{state = MucusState::adherent;};
        }

        // Connections
        connection mouthpiece.airOut to reed.airIn;
        connection reed.acousticOut to resonanceChamber.acousticIn;
        connection resonanceChamber.amplifiedOut to patientAirway.acousticIn;
        connection checkValve.airOut to mouthpiece.airIn;

        // Requirements satisfaction
        satisfy TherapeuticFrequencyRequirement by reed;
        satisfy OneWayAirflowRequirement by checkValve;
        satisfy BackpressureRequirement by mouthpiece.airIn.air;
        satisfy AmplificationRequirement by resonanceChamber;
        satisfy MucusMobilizationRequirement by patientAirway.mucus;
        satisfy NoExternalPowerRequirement by LungFlute;

        // Behavior
        action def operate :> Action {
            in patientExhaledAir : ExhaledAir;
            out mobilizedMucus : Mucus;
            action exhale : ExhaleAction {
                in exhaledAir = patientExhaledAir;
            }
            action flutter : FlutterAction {
                in air = exhale.exhaledAir;
                out vibration;
            }
            action amplify : AmplifyAction {
                in vibration = flutter.vibration;
                out amplifiedVibration;
            }
            action mobilize : MobilizeMucusAction {
                in amplifiedVibration = amplify.amplifiedVibration;
                inout mucus = patientAirway.mucus;
            }
        }
    }
}
