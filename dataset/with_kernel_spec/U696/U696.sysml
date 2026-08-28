package GeophoneSystem {
    private import SI::s;
    private import SI::V;
    private import SI::Hz;
    private import SI::degC;
    private import SI::kg;
    private import SI::m;
    private import ISQ::VelocityValue;
    private import ISQ::VoltageValue;
    private import ISQ::FrequencyValue;
    private import ISQ::ThermodynamicTemperatureValue;
    private import ISQ::MassValue;
    private import ScalarValues::Integer;
    private import ScalarValues::String;
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;

    item def GroundMotion {
        attribute velocity : VelocityValue;
    }

    item def ElectricalSignal {
        attribute voltage : VoltageValue;
        attribute frequency : FrequencyValue;
    }

    item def RawElectricalSignal :> ElectricalSignal;
    item def FilteredElectricalSignal :> ElectricalSignal;

    part def Housing {
        attribute material : String = "Stainless Steel";
        attribute waterproof : Boolean = true;
        attribute minOperatingTemp : ThermodynamicTemperatureValue = -40 [degC];
        attribute maxOperatingTemp : ThermodynamicTemperatureValue = 85 [degC];
    }

    part def Magnet {
        attribute material : String = "Neodymium";
    }

    part def InertialMass {
        attribute mass : MassValue = 0.1 [kg];
        part magnet : Magnet;
    }

    part def SpringSystem {
        attribute springConstant : Real = 150.0;
    }

    calc def InduceVoltage {
        in motion : GroundMotion;
        in sensitivity : Real;
        return raw : RawElectricalSignal;
        assert constraint { raw.voltage == sensitivity * motion.velocity }
    }

    part def Coil {
        attribute turns : Integer = 1200;
        attribute wireMaterial : String = "Copper";
        attribute sensitivity : Real = 28.8;

        in port motionIn : GroundMotion;
        out port rawSignalOut : RawElectricalSignal;

        calc induce : InduceVoltage;

        state CoilBehavior {
            entry; then idle;
            state idle;
            accept motion : GroundMotion via motionIn
                then sensing;
            state sensing;
            accept after 0.001 [s]
                then idle;
        }
    }

    calc def FilterSignal {
        in raw : RawElectricalSignal;
        in lowCutoff : FrequencyValue;
        in highCutoff : FrequencyValue;
        return filtered : FilteredElectricalSignal;
        assert constraint {
            (raw.frequency >= lowCutoff and raw.frequency <= highCutoff) implies
                filtered.voltage == raw.voltage
        }
        assert constraint {
            (raw.frequency < lowCutoff or raw.frequency > highCutoff) implies
                filtered.voltage == 0 [V]
        }
    }

    part def SignalFilter {
        attribute lowCutoff : FrequencyValue = 1 [Hz];
        attribute highCutoff : FrequencyValue = 200 [Hz];

        in port rawSignalIn : RawElectricalSignal;
        out port filteredSignalOut : FilteredElectricalSignal;

        calc filterCalc : FilterSignal;

        state FilterBehavior {
            entry; then idle;
            state idle;
            accept raw : RawElectricalSignal via rawSignalIn
                then filtering;
            state filtering;
            accept after 0.001 [s]
                then idle;
        }
    }

    part def Geophone {
        part housing : Housing;
        part inertialMass : InertialMass;
        part springSystem : SpringSystem;
        part coil : Coil;
        part signalFilter : SignalFilter;

        in port seismicInput : GroundMotion;
        out port signalOutput : FilteredElectricalSignal;

        connect seismicInput to coil.motionIn;
        connect coil.rawSignalOut to signalFilter.rawSignalIn;
        connect signalFilter.filteredSignalOut to signalOutput;

        state GeophoneBehavior {
            entry; then idle;
            state idle;
            accept seismicEvent : GroundMotion via seismicInput
                then sensing;
            state sensing;
            accept after 0.01 [s]
                then filtering;
            state filtering;
            accept after 0.01 [s]
                then outputting;
            state outputting;
            accept after 0.01 [s]
                then idle;
        }
    }

    part geophone : Geophone;

    requirement <'REQ-001'> detectGroundVibrations {
        doc /* The geophone shall detect ground vibrations and convert them into a measurable electrical signal. */
        subject geo :>> geophone;
    }

    requirement <'REQ-002'> frequencyRange {
        doc /* The system shall filter the raw signal to pass only frequencies between 1 Hz and 200 Hz. */
        subject filterSubj :>> geophone.signalFilter;
        assert constraint {
            filterSubj.lowCutoff == 1 [Hz] and
            filterSubj.highCutoff == 200 [Hz]
        }
    }

    requirement <'REQ-003'> temperatureRange {
        doc /* The geophone shall operate reliably across environmental temperatures from -40 degC to 85 degC. */
        subject housingSubj :>> geophone.housing;
        assert constraint {
            housingSubj.minOperatingTemp <= -40 [degC] and
            housingSubj.maxOperatingTemp >= 85 [degC]
        }
    }

    requirement <'REQ-004'> environmentalProtection {
        doc /* The housing shall be waterproof and constructed of stainless steel. */
        subject housingSubj :>> geophone.housing;
        assert constraint {
            housingSubj.material == "Stainless Steel" and
            housingSubj.waterproof == true
        }
    }

    requirement <'REQ-005'> voltageProportionality {
        doc /* The output signal voltage shall be directly proportional to ground velocity. */
        subject coilSubj :>> geophone.coil;
        assert constraint {
            coilSubj.sensitivity > 0
        }
    }

    satisfy detectGroundVibrations by geophone;
    satisfy frequencyRange by geophone.signalFilter;
    satisfy temperatureRange by geophone.housing;
    satisfy environmentalProtection by geophone.housing;
    satisfy voltageProportionality by geophone.coil;
}
