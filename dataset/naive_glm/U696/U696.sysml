package GeophoneSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types ----
    value type GroundVelocity :> Real {
        unit 'mm/s';
    }
    value type OutputVoltage :> Real {
        unit 'mV';
    }
    value type SignalFrequency :> Real {
        unit 'Hz';
    }
    value type OperatingTemperature :> Real {
        unit 'degC';
    }
    value type SpringConstant :> Real {
        unit 'N/m';
    }
    value type MagneticFluxDensity :> Real {
        unit 'T';
    }
    value type CoilResistance :> Real {
        unit 'ohm';
    }
    value type MassValue :> Real {
        unit 'g';
    }

    // ---- Item Types ----
    item def SeismicWave {
        attribute groundVelocity : GroundVelocity;
        attribute dominantFrequency : SignalFrequency;
    }
    item def RawElectricalSignal {
        attribute voltage : OutputVoltage;
        attribute frequency : SignalFrequency;
    }
    item def FilteredElectricalSignal {
        attribute voltage : OutputVoltage;
        attribute frequency : SignalFrequency;
    }

    // ---- Port Definitions ----
    port def GroundMotionPort {
        out item seismicInput : SeismicWave;
    }
    port def ElectricalOutputPort {
        out item filteredOutput : FilteredElectricalSignal;
    }

    // ---- Requirements ----
    requirement def GeophoneRequirement {
        subject geo : Geophone;
        requirement detectGroundVibrations {
            doc /* The geophone shall detect ground vibrations and convert them into a measurable electrical signal. */
        }
        requirement voltageProportionalToVelocity {
            doc /* The output voltage shall be directly proportional to the velocity of ground movement. */
        }
        requirement passbandRange {
            doc /* The filtered signal shall pass frequencies between 1 and 200 Hz. */
            attribute minPassband : SignalFrequency = 1 'Hz';
            attribute maxPassband : SignalFrequency = 200 'Hz';
        }
        requirement environmentalRobustness {
            doc /* The device shall operate reliably across a broad spectrum of environmental temperatures. */
            attribute minTemp : OperatingTemperature = -40 'degC';
            attribute maxTemp : OperatingTemperature = 85 'degC';
        }
        requirement waterproofCase {
            doc /* The case shall be durable and waterproof stainless steel. */
        }
    }

    // ---- Part Definitions ----
    part def StainlessSteelCase {
        attribute material : String = "Stainless Steel";
        attribute waterproof : Boolean = true;
    }

    part def NeodymiumMagnet {
        attribute fluxDensity : MagneticFluxDensity = 1.2 'T';
    }

    part def InertialMass {
        part magnet : NeodymiumMagnet;
        attribute massValue : MassValue = 28 'g';
    }

    part def SpringSystem {
        attribute springConstant : SpringConstant = 50 'N/m';
    }

    part def Coil {
        attribute resistance : CoilResistance = 380 'ohm';
        attribute turns : Integer = 2500;
    }

    part def SignalConditioningUnit {
        in item rawSignal : RawElectricalSignal;
        out item filteredSignal : FilteredElectricalSignal;
        attribute minPassband : SignalFrequency = 1 'Hz';
        attribute maxPassband : SignalFrequency = 200 'Hz';

        action filterSignal {
            in raw : RawElectricalSignal = rawSignal;
            out filtered : FilteredElectricalSignal = filteredSignal;
        }
    }

    part def Geophone {
        port groundPort : GroundMotionPort;
        port outputPort : ElectricalOutputPort;

        part case : StainlessSteelCase;
        part inertialMass : InertialMass;
        part springSystem : SpringSystem;
        part coil : Coil;
        part conditioningUnit : SignalConditioningUnit;

        attribute sensitivity : GroundVelocity = 0.001 'mm/s';
        attribute operatingTempMin : OperatingTemperature = -40 'degC';
        attribute operatingTempMax : OperatingTemperature = 85 'degC';

        satisfy GeophoneRequirement {
            subject geo = Geophone::this;
        }

        flow from groundPort.seismicInput to coil;
        flow from coil to conditioningUnit.rawSignal;
        flow from conditioningUnit.filteredSignal to outputPort.filteredOutput;

        state def GeophoneStates {
            entry; 
            state idle;
            state sensing;
            state filtering;
            state outputting;

            transition idle -> sensing when groundPort.seismicInput.groundVelocity > sensitivity;
            transition sensing -> filtering when conditioningUnit.rawSignal.voltage > 0 'mV';
            transition filtering -> outputting when conditioningUnit.filteredSignal.voltage > 0 'mV';
            transition outputting -> idle when groundPort.seismicInput.groundVelocity <= sensitivity;
        }

        exhibit state GeophoneStates;
    }

    // ---- Connections ----
    connection groundToCoil connect Geophone::groundPort::seismicInput to Geophone::coil;
    connection coilToConditioning connect Geophone::coil to Geophone::conditioningUnit::rawSignal;
    connection conditioningToOutput connect Geophone::conditioningUnit::filteredSignal to Geophone::outputPort::filteredOutput;

}
package GeophoneSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types ----
    value type GroundVelocity :> Real {
        unit 'mm/s';
    }
    value type OutputVoltage :> Real {
        unit 'mV';
    }
    value type SignalFrequency :> Real {
        unit 'Hz';
    }
    value type OperatingTemperature :> Real {
        unit 'degC';
    }
    value type SpringConstant :> Real {
        unit 'N/m';
    }
    value type MagneticFluxDensity :> Real {
        unit 'T';
    }
    value type CoilResistance :> Real {
        unit 'ohm';
    }
    value type MassValue :> Real {
        unit 'g';
    }

    // ---- Item Types ----
    item def SeismicWave {
        attribute groundVelocity : GroundVelocity;
        attribute dominantFrequency : SignalFrequency;
    }
    item def RawElectricalSignal {
        attribute voltage : OutputVoltage;
        attribute frequency : SignalFrequency;
    }
    item def FilteredElectricalSignal {
        attribute voltage : OutputVoltage;
        attribute frequency : SignalFrequency;
    }

    // ---- Port Definitions ----
    port def GroundMotionPort {
        out item seismicInput : SeismicWave;
    }
    port def ElectricalOutputPort {
        out item filteredOutput : FilteredElectricalSignal;
    }

    // ---- Requirements ----
    requirement def GeophoneRequirement {
        subject geo : Geophone;
        requirement detectGroundVibrations {
            doc /* The geophone shall detect ground vibrations and convert them into a measurable electrical signal. */
        }
        requirement voltageProportionalToVelocity {
            doc /* The output voltage shall be directly proportional to the velocity of ground movement. */
        }
        requirement passbandRange {
            doc /* The filtered signal shall pass frequencies between 1 and 200 Hz. */
            attribute minPassband : SignalFrequency = 1 'Hz';
            attribute maxPassband : SignalFrequency = 200 'Hz';
        }
        requirement environmentalRobustness {
            doc /* The device shall operate reliably across a broad spectrum of environmental temperatures. */
            attribute minTemp : OperatingTemperature = -40 'degC';
            attribute maxTemp : OperatingTemperature = 85 'degC';
        }
        requirement waterproofCase {
            doc /* The case shall be durable and waterproof stainless steel. */
        }
    }

    // ---- Part Definitions ----
    part def StainlessSteelCase {
        attribute material : String = "Stainless Steel";
        attribute waterproof : Boolean = true;
    }

    part def NeodymiumMagnet {
        attribute fluxDensity : MagneticFluxDensity = 1.2 'T';
    }

    part def InertialMass {
        part magnet : NeodymiumMagnet;
        attribute massValue : MassValue = 28 'g';
    }

    part def SpringSystem {
        attribute springConstant : SpringConstant = 50 'N/m';
    }

    part def Coil {
        attribute resistance : CoilResistance = 380 'ohm';
        attribute turns : Integer = 2500;
    }

    part def SignalConditioningUnit {
        in item rawSignal : RawElectricalSignal;
        out item filteredSignal : FilteredElectricalSignal;
        attribute minPassband : SignalFrequency = 1 'Hz';
        attribute maxPassband : SignalFrequency = 200 'Hz';

        action filterSignal {
            in raw : RawElectricalSignal = rawSignal;
            out filtered : FilteredElectricalSignal = filteredSignal;
        }
    }

    part def Geophone {
        port groundPort : GroundMotionPort;
        port outputPort : ElectricalOutputPort;

        part case : StainlessSteelCase;
        part inertialMass : InertialMass;
        part springSystem : SpringSystem;
        part coil : Coil;
        part conditioningUnit : SignalConditioningUnit;

        attribute sensitivity : GroundVelocity = 0.001 'mm/s';
        attribute operatingTempMin : OperatingTemperature = -40 'degC';
        attribute operatingTempMax : OperatingTemperature = 85 'degC';

        satisfy GeophoneRequirement {
            subject geo = Geophone::this;
        }

        flow from groundPort.seismicInput to coil;
        flow from coil to conditioningUnit.rawSignal;
        flow from conditioningUnit.filteredSignal to outputPort.filteredOutput;

        state def GeophoneStates {
            entry; 
            state idle;
            state sensing;
            state filtering;
            state outputting;

            transition idle -> sensing when groundPort.seismicInput.groundVelocity > sensitivity;
            transition sensing -> filtering when conditioningUnit.rawSignal.voltage > 0 'mV';
            transition filtering -> outputting when conditioningUnit.filteredSignal.voltage > 0 'mV';
            transition outputting -> idle when groundPort.seismicInput.groundVelocity <= sensitivity;
        }

        exhibit state GeophoneStates;
    }

    // ---- Connections ----
    connection groundToCoil connect Geophone::groundPort::seismicInput to Geophone::coil;
    connection coilToConditioning connect Geophone::coil to Geophone::conditioningUnit::rawSignal;
    connection conditioningToOutput connect Geophone::conditioningUnit::filteredSignal to Geophone::outputPort::filteredOutput;

}
