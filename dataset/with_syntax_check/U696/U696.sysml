package GeophoneSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def GroundVelocity :> ISQ::SpeedValue;
    attribute def OutputVoltage :> ISQ::VoltageValue;
    attribute def SeismicFrequency :> ISQ::FrequencyValue;
    attribute def Sensitivity :> Real;
    attribute def CoilResistance :> ISQ::ElectricalResistanceValue;
    attribute def NaturalFrequency :> ISQ::FrequencyValue;
    attribute def DampingRatio :> Real;

    item def SeismicWave {
        attribute velocity : GroundVelocity;
        attribute frequency : SeismicFrequency;
        attribute amplitude : ISQ::LengthValue;
    }

    item def ElectricalSignal {
        attribute voltage : OutputVoltage;
        attribute frequency : SeismicFrequency;
    }

    port def SeismicInputPort {
        in item seismicInput : SeismicWave;
    }

    port def ElectricalOutputPort {
        out item electricalOutput : ElectricalSignal;
    }

    part def InertialMass {
        attribute mass : ISQ::MassValue;
        attribute suspensionStiffness : Real;
    }

    part def Coil {
        attribute numberOfTurns : Integer;
        attribute resistance : CoilResistance;
        attribute wireDiameter : ISQ::LengthValue;
    }

    part def PermanentMagnet {
        attribute magneticFluxDensity : Real;
        attribute material : String;
    }

    part def SpringSuspension {
        attribute stiffness : Real;
        attribute dampingCoefficient : DampingRatio;
        attribute naturalFrequency : NaturalFrequency;
    }

    part def HousingCase {
        attribute material : String;
        attribute waterproofRating : String;
        attribute mass : ISQ::MassValue;
    }

    action def ConvertSeismicMotionToVoltage {
        in seismicInput : SeismicWave;
        out electricalOutput : ElectricalSignal;
        attribute conversionSensitivity : Sensitivity;
    }

    action def FilterSignal {
        in rawSignal : ElectricalSignal;
        out filteredSignal : ElectricalSignal;
        attribute lowCutFrequency : SeismicFrequency;
        attribute highCutFrequency : SeismicFrequency;
    }

    state def GeophoneOperatingStates {
        entry; then idle;

        state idle;

        accept seismicEvent : SeismicWave
            then sensing;

        state sensing {
            do action convertMotion : ConvertSeismicMotionToVoltage;
        }

        then outputting;

        state outputting {
            do action filterAndOutput : FilterSignal;
        }

        then idle;
    }

    part def Geophone {
        attribute sensitivity : Sensitivity;
        attribute naturalFrequency : NaturalFrequency;
        attribute dampingRatio : DampingRatio;
        attribute coilResistance : CoilResistance;
        attribute operatingTemperatureRange : ISQ::TemperatureValue[2];

        port seismicInput : SeismicInputPort;
        port electricalOutput : ElectricalOutputPort;

        part housing : HousingCase {
            attribute material = "Stainless Steel";
            attribute waterproofRating = "IP68";
            attribute mass = 0.5 [SI::kg];
        }

        part inertialMass : InertialMass {
            attribute mass = 0.02 [SI::kg];
            attribute suspensionStiffness = 1000.0;
        }

        part coil : Coil {
            attribute numberOfTurns = 2000;
            attribute resistance = 375.0 [SI::'Ω'];
            attribute wireDiameter = 0.05 [SI::mm];
        }

        part magnet : PermanentMagnet {
            attribute magneticFluxDensity = 1.2;
            attribute material = "Neodymium";
        }

        part suspension : SpringSuspension {
            attribute stiffness = 800.0;
            attribute dampingCoefficient = 0.7;
            attribute naturalFrequency = 10.0 [SI::Hz];
        }

        perform action detectGroundMotion : ConvertSeismicMotionToVoltage;
    }

    part geophoneSystem : Geophone {
        attribute sensitivity = 28.0;
        attribute naturalFrequency = 10.0 [SI::Hz];
        attribute dampingRatio = 0.7;
        attribute coilResistance = 375.0 [SI::'Ω'];
        attribute operatingTemperatureRange = (-40.0 [SI::'°C'], 85.0 [SI::'°C']);

        perform action operateGeophone {
            first start;
            then merge continueMonitoring;
            then action sense : ConvertSeismicMotionToVoltage {
                in seismicInput;
                out electricalOutput;
            }
            then decide;
                if sense.electricalOutput.voltage > 0.001 [SI::V] then processSignal;
            action processSignal : FilterSignal {
                in rawSignal = sense.electricalOutput;
                out filteredSignal;
                attribute lowCutFrequency = 1.0 [SI::Hz];
                attribute highCutFrequency = 200.0 [SI::Hz];
            }
            then continueMonitoring;
        }
    }

    requirement def SeismicDetectionRequirement {
        doc /* The geophone shall detect ground motion with velocities 
               ranging from 0.001 mm/s to 100 mm/s. */

        subject geophone : Geophone;

        require constraint {
            geophone.sensitivity >= 0.001
        }
    }

    requirement def FrequencyResponseRequirement {
        doc /* The geophone shall operate effectively across a frequency 
               range of 1 Hz to 250 Hz. */

        subject geophone : Geophone;

        require constraint {
            geophone.naturalFrequency >= 1.0 [SI::Hz]
        }
    }

    requirement def SensitivityRequirement {
        doc /* The geophone shall provide a minimum sensitivity of 
               28 V/(m/s) at its natural frequency. */

        subject geophone : Geophone;

        require constraint {
            geophone.sensitivity >= 28.0
        }
    }

    requirement geophoneSystemRequirements {
        doc /* The geophone system shall convert ground motion into 
               electrical signals for seismic monitoring applications. */

        require seismicDetection : SeismicDetectionRequirement;
        require frequencyResponse : FrequencyResponseRequirement;
        require sensitivity : SensitivityRequirement;
    }
}
