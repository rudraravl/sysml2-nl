package MetalDetectorSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value def Voltage :> Real { unit 'V'; }
    value def Current :> Real { unit 'A'; }
    value def Frequency :> Real { unit 'Hz'; }
    value def Resistance :> Real { unit 'ohm'; }
    value def Inductance :> Real { unit 'H'; }
    value def Capacitance :> Real { unit 'F'; }
    value def Power :> Real { unit 'W'; }
    value def Energy :> Real { unit 'J'; }
    value def Depth :> Real { unit 'm'; }
    value def Time :> Real { unit 's'; }
    value def Temperature :> Real { unit 'degC'; }
    value def Percent :> Real { unit '%'; }
    value def Amplitude :> Real { unit 'V'; }
    value def PhaseAngle :> Real { unit 'deg'; }
    value def SoundPressureLevel :> Real { unit 'dB'; }

    // ===== Enumerations =====
    enum def MetalCategory {
        ferrous;
        nonFerrous;
        stainlessSteel;
        unknown;
    }

    enum def AlertLevel {
        none;
        low;
        medium;
        high;
    }

    enum def OperatingMode {
        powerOff;
        standby;
        activeScanning;
    }

    enum def ScanSubstate {
        searching;
        targetAcquired;
        alerting;
    }

    enum def PowerState {
        off;
        on;
        lowBattery;
        charging;
    }

    // ===== Item Types =====
    item def ElectromagneticField {
        attribute frequency : Frequency;
        attribute amplitude : Amplitude;
        attribute phase : PhaseAngle;
    }

    item def ReceivedSignal {
        attribute amplitude : Amplitude;
        attribute phase : PhaseAngle;
        attribute noiseLevel : Amplitude;
        attribute timestamp : Time;
    }

    item def Process
