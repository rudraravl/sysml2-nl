package LightSensingSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQ::ElectricPotential;
    import ISQ::ElectricResistance;
    import ISQ::Illuminance;

    // ===== Value Types =====
    value def Voltage :> Real {
        unit volt;
    }
    value def Resistance :> Real {
        unit ohm;
    }
    value def LightIntensity :> Real {
        unit lux;
    }

    // ===== Enumerations =====
    enum def LightCondition {
        dark;
        dim;
        bright;
    }

    // ===== Item Definitions =====
    item def AmbientLight {
        attribute intensity : LightIntensity;
    }

    item def AnalogVoltageSignal {
        attribute voltage : Voltage;
    }

    item def DigitalLightState {
        attribute condition : LightCondition;
    }

    // ===== Requirements =====
    requirement def LightSensingRequirement {
        subject : LightSensingSystem;
        objective {
            doc /* The system shall measure ambient light intensity and convert it into useful electrical signals. */
        }
    }

    requirement def PhotoresistorRequirement {
        subject : Photoresistor;
        attribute darkResistance : Resistance = 1e6 [ohm];
        attribute brightResistance : Resistance = 100 [ohm];
        objective {
            doc /* The photoresistor shall exhibit high resistance in dark conditions and low resistance in bright conditions. */
            assert { subject.resistance >= brightResistance and subject.resistance <= darkResistance; }
        }
    }

    requirement def VoltageDividerRequirement {
        subject : VoltageDivider;
        attribute supplyVoltage : Voltage = 5 [V];
        objective {
            doc /* The voltage divider shall convert photoresistor resistance into a proportional analog voltage. */
            assert { subject.outputVoltage >= 0 [V] and subject.outputVoltage <= supplyVoltage; }
        }
    }

    requirement def SignalConditionerRequirement {
        subject : SignalConditioner;
        attribute lowThreshold : Voltage = 1.5 [V];
        attribute highThreshold : Voltage = 3.5 [V];
        objective {
            doc /* The signal conditioner shall classify light level into dark, dim, or bright based on thresholds. */
        }
    }

    // ===== Component Definitions =====

    part def Photoresistor {
        attribute resistance : Resistance;
        port lightInput : AmbientLight;
        port resistanceOutput : AnalogVoltageSignal;

        requirement photoresistorReq : PhotoresistorRequirement {
            subject = Photoresistor::this;
        }

        action def UpdateResistance {
            in light : AmbientLight;
            out newResistance : Resistance;
            perform {
                // Resistance decreases as light intensity increases
                newResistance = 1e6 [ohm] / (1 + light.intensity / 10 [lux]);
            }
        }

        action updateResistance : UpdateResistance {
            in light = lightInput.received;
            out newResistance = resistance;
        }
    }

    part def VoltageDivider {
        attribute supplyVoltage : Voltage = 5 [V];
        attribute fixedResistor : Resistance = 10000 [ohm];
        attribute outputVoltage : Voltage;
        port resistanceInput : AnalogVoltageSignal;
        port voltageOutput : AnalogVoltageSignal;

        requirement voltageDividerReq : VoltageDividerRequirement {
            subject = VoltageDivider::this;
        }

        action def ConvertToVoltage {
            in photoresistorResistance : Resistance;
            in supply : Voltage;
            in fixedR : Resistance;
            out voltage : Voltage;
            perform {
                voltage = supply * (fixedR / (fixedR + photoresistorResistance));
            }
        }

        action convertToVoltage : ConvertToVoltage {
            in photoresistorResistance = resistanceInput.received.voltage * 0 [ohm]; // placeholder removed below
            in supply = supplyVoltage;
            in fixedR = fixedResistor;
            out voltage = outputVoltage;
        }
    }

    part def SignalConditioner {
        attribute lowThreshold : Voltage = 1.5 [V];
        attribute highThreshold : Voltage = 3.5 [V];
        attribute currentCondition : LightCondition;
        port analogInput : AnalogVoltageSignal;
        port digitalOutput : DigitalLightState;

        requirement signalConditionerReq : SignalConditionerRequirement {
            subject = SignalConditioner::this;
        }

        state def ConditionClassification {
            entry;
            state Dark;
            state Dim;
            state Bright;

            transition from Dark to Dim
                when analogInput.received.voltage >= lowThreshold;
            transition from Dim to Dark
                when analogInput.received.voltage < lowThreshold;
            transition from Dim to Bright
                when analogInput.received.voltage >= highThreshold;
            transition from Bright to Dim
                when analogInput.received.voltage < highThreshold;
        }

        action def ClassifyLight {
            in voltage : Voltage;
            in low : Voltage;
            in high : Voltage;
            out condition : LightCondition;
            perform {
                if voltage < low then
                    condition = LightCondition::dark;
                else if voltage >= high then
                    condition = LightCondition::bright;
                else
                    condition = LightCondition::dim;
            }
        }

        action classifyLight : ClassifyLight {
            in voltage = analogInput.received.voltage;
            in low = lowThreshold;
            in high = highThreshold;
            out condition = currentCondition;
        }
    }

    // ===== System Definition =====
    part def LightSensingSystem {
        port ambientLightPort : AmbientLight;
        port analogOutputPort : AnalogVoltageSignal;
        port digitalOutputPort : DigitalLightState;

        part photoresistor : Photoresistor {
            port lightInput = ambientLightPort;
        }

        part voltageDivider : VoltageDivider {
            port voltageOutput = analogOutputPort;
        }

        part signalConditioner : SignalConditioner {
            port digitalOutput = digitalOutputPort;
        }

        connection photoresistorToDivider connect
            photoresistor.resistanceOutput to voltageDivider.resistanceInput;

        connection dividerToConditioner connect
            voltageDivider.voltageOutput to signalConditioner.analogInput;

        requirement systemReq : LightSensingRequirement {
            subject = LightSensingSystem::this;
        }

        state def SystemOperation {
            entry;
            state Sensing;
            state Processing;
            state Outputting;

            transition from Sensing to Processing
                when photoresistor.resistance != 0 [ohm];
            transition from Processing to Outputting
                when voltageDivider.outputVoltage != 0 [V];
            transition from Outputting to Sensing
                when true;
        }
    }

    // ===== Package-level constraint =====
    constraint def VoltageRangeConstraint {
        in v : Voltage;
        in min : Voltage = 0 [V];
        in max : Voltage = 5 [V];
        assert { v >= min and v <= max; }
    }
}
