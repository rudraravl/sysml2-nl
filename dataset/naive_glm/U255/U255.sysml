package ICG_System {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types with Units =====

    valueType ElectricCurrentValue :> Real {
        :>> unit = 'mA'; // milliamps
    }

    valuetype SafeCurrentLimit :> ElectricCurrentValue = 1.0[mA];
    valuetype NominalExcitationCurrent :> ElectricCurrentValue = 4.0[mA];

    valueType AC_Frequency :> Real {
        :>>
