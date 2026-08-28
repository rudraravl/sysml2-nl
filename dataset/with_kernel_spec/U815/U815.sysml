package 'Photoresistor Light Sensing System' {
    private import ScalarValues::*;

    value def Illuminance :> Real;
    value def Resistance :> Real;
    value def Voltage :> Real;

    enum def LightCondition {
        dark;
        dim;
        bright;
    }

    port def LightInputPort {
        in light : Illuminance;
    }
    port def ResistanceInputPort {
        in resistance : Resistance;
    }
    port def ResistanceOutputPort {
        out resistance : Resistance;
    }
    port def VoltageInputPort {
        in voltage : Voltage;
    }
    port def VoltageOutputPort {
        out voltage : Voltage;
    }
    port def ConditionOutputPort {
        out condition : LightCondition;
    }

    part def Photoresistor {
        port lightPort : LightInputPort;
        port resistancePort : ResistanceOutputPort;

        attribute darkResistance : Resistance = 1000000.0;
        attribute brightResistance : Resistance = 1000.0;

        action senseLight {
            in light = lightPort.light;
            out resistance = resistancePort.resistance;
        }
    }

    part def VoltageDivider {
        port resistancePort : ResistanceInputPort;
        port voltagePort : VoltageOutputPort;

        attribute fixedResistance : Resistance = 10000.0;
        attribute supplyVoltage : Voltage = 5.0;

        action convertToVoltage {
            in resistance = resistancePort.resistance;
            in supply = supplyVoltage;
            in rFixed = fixedResistance;
            out voltage = voltagePort.voltage;
        }
    }

    state def ConditionStates {
        in voltage : Voltage;
        in lowThreshold : Voltage;
        in highThreshold : Voltage;

        entry; then dark;
        state dark;
        transition dark_to_dim from dark to dim when voltage > lowThreshold;
        state dim;
        transition dim_to_bright from dim to bright when voltage >= highThreshold;
        transition dim_to_dark from dim to dark when voltage <= lowThreshold;
        state bright;
        transition bright_to_dim from bright to dim when voltage < highThreshold;
    }

    part def SignalConditioner {
        port voltagePort : VoltageInputPort;
        port conditionPort : ConditionOutputPort;
        port rawVoltagePort : VoltageOutputPort;

        attribute lowThreshold : Voltage = 1.0;
        attribute highThreshold : Voltage = 4.0;

        exhibit conditionStates : ConditionStates {
            in voltage = voltagePort.voltage;
            in lowThreshold = lowThreshold;
            in highThreshold = highThreshold;
        }

        action passRawVoltage {
            in voltage = voltagePort.voltage;
            out raw = rawVoltagePort.voltage;
        }
    }

    part def LightSensingSystem {
        part photoresistor : Photoresistor;
        part voltageDivider : VoltageDivider;
        part signalConditioner : SignalConditioner;

        port ambientLightPort : LightInputPort;
        port analogVoltagePort : VoltageOutputPort;
        port lightConditionPort : ConditionOutputPort;

        connect ambientLightPort to photoresistor.lightPort;
        connect photoresistor.resistancePort to voltageDivider.resistancePort;
        connect voltageDivider.voltagePort to signalConditioner.voltagePort;
        connect signalConditioner.rawVoltagePort to analogVoltagePort;
        connect signalConditioner.conditionPort to lightConditionPort;
    }

    requirement def LightSensingRequirement {
        subject module : LightSensingSystem;
        doc /* The system shall measure ambient light intensity and convert it into useful electrical signals. */
    }

    requirement def DarkConditionDetection {
        subject conditioner : SignalConditioner;
        doc /* The system shall classify light levels below the low voltage threshold as 'dark'. */
    }

    requirement def BrightConditionDetection {
        subject conditioner : SignalConditioner;
        doc /* The system shall classify light levels above the high voltage threshold as 'bright'. */
    }

    requirement def AnalogOutputAvailability {
        subject module : LightSensingSystem;
        doc /* The system shall provide a raw analog voltage output proportional to light intensity. */
    }
}
