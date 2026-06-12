package ReedSwitchSystemModel {

    import ScalarValues::*;
    import ISQ::*;

    value def MagneticFluxDensity :> ISQ::magneticFluxDensity {
        unit = "mT";
    }

    value def ElectricVoltage :> ISQ::electricPotential {
        unit = "V";
    }

    value def ElectricCurrent :> ISQ::electricCurrent {
        unit = "mA";
    }

    value def ElectricalResistance :> ISQ::resistance {
        unit = "ohm";
    }

    value def TimeDuration :> ISQ::time {
        unit = "ms";
    }

    value def Temperature :> ISQ::thermodynamicTemperature {
        unit = "degC";
    }

    enum def ContactState {
        enum open;
        enum closed;
    }

    enum def SwitchOutputLevel {
        enum inactive;
        enum active;
    }

    item def MagneticField {
        attribute fluxDensity : MagneticFluxDensity;
        attribute polarity : String;
    }

    item def ElectricalSignal {
        attribute voltage : ElectricVoltage;
        attribute current : ElectricCurrent;
        attribute level : SwitchOutputLevel;
    }

    item def MechanicalContactCondition {
        attribute state : ContactState;
        attribute contactResistance : ElectricalResistance;
    }

    port def MagneticFieldPort {
        in item field : MagneticField;
    }

    port def ElectricalInputPort {
        in item supply : ElectricalSignal;
    }

    port def ElectricalOutputPort {
        out item output : ElectricalSignal;
    }

    port def ContactSensePort {
        out item condition : MechanicalContactCondition;
    }

    part def PermanentMagnet {
        attribute nominalSurfaceFluxDensity : MagneticFluxDensity = 12.0;
        attribute minimumActuationDistanceFluxDensity : MagneticFluxDensity = 6.0;
        port magneticOutput : MagneticFieldPort;
    }

    part def ReedContactPair {
        attribute openGapResistance : ElectricalResistance = 1000000000.0;
        attribute closedContactResistance : ElectricalResistance = 0.150;
        attribute pullInFluxDensity : MagneticFluxDensity = 6.0;
        attribute dropOutFluxDensity : MagneticFluxDensity = 3.0;
        attribute bounceDuration : TimeDuration = 1.5;
        attribute contactState : ContactState = ContactState::open;

        port magneticInput : MagneticFieldPort;
        port electricalInput : ElectricalInputPort;
        port contactSense : ContactSensePort;

        state def ContactBehavior {
            state openContact;
            state closing;
            state closedContact;
            state opening;

            entry action initializeOpen {
                contactState = ContactState::open;
            }

            transition initial then openContact;

            transition openContact_to_closing
                first openContact
                accept MagneticField
                if magneticInput.field.fluxDensity >= pullInFluxDensity
                then closing;

            transition closing_to_closed
                first closing
                after bounceDuration
                do closeContacts
                then closedContact;

            transition closed_to_opening
                first closedContact
                accept MagneticField
                if magneticInput.field.fluxDensity <= dropOutFluxDensity
                then opening;

            transition opening_to_open
                first opening
                after bounceDuration
                do openContacts
                then openContact;
        }

        action closeContacts {
            out item condition : MechanicalContactCondition {
                state = ContactState::closed;
                contactResistance = closedContactResistance;
            }
        }

        action openContacts {
            out item condition : MechanicalContactCondition {
                state = ContactState::open;
                contactResistance = openGapResistance;
            }
        }
    }

    part def PullUpNetwork {
        attribute pullUpResistance : ElectricalResistance = 10000.0;
        attribute supplyVoltage : ElectricVoltage = 5.0;
        attribute maximumSignalCurrent : ElectricCurrent = 0.5;

        port supplyInput : ElectricalInputPort;
        port switchedNode : ElectricalOutputPort;
    }

    part def SignalConditioner {
        attribute debounceInterval : TimeDuration = 5.0;
        attribute activeLowOutput : Boolean = true;
        attribute logicHighVoltage : ElectricVoltage = 5.0;
        attribute logicLowVoltage : ElectricVoltage = 0.0;

        port contactInput : ContactSensePort;
        port conditionedOutput : ElectricalOutputPort;

        action conditionContactSignal {
            in item contact : MechanicalContactCondition;
            out item signal : ElectricalSignal;

            if contact.state == ContactState::closed {
                signal.voltage = logicLowVoltage;
                signal.current = 0.5;
                signal.level = SwitchOutputLevel::active;
            } else {
                signal.voltage = logicHighVoltage;
                signal.current = 0.0;
                signal.level = SwitchOutputLevel::inactive;
            }
        }

        state def OutputBehavior {
            state inactiveOutput;
            state debounceToActive;
            state activeOutput;
            state debounceToInactive;

            transition initial then inactiveOutput;

            transition inactive_to_debounce
                first inactiveOutput
                accept MechanicalContactCondition
                if contactInput.condition.state == ContactState::closed
                then debounceToActive;

            transition debounce_to_active
                first debounceToActive
                after debounceInterval
                do conditionContactSignal
                then activeOutput;

            transition active_to_debounce
                first activeOutput
                accept MechanicalContactCondition
                if contactInput.condition.state == ContactState::open
                then debounceToInactive;

            transition debounce_to_inactive
                first debounceToInactive
                after debounceInterval
                do conditionContactSignal
                then inactiveOutput;
        }
    }

    part def ProtectedReedSwitchAssembly {
        attribute operatingTemperatureMinimum : Temperature = -40.0;
        attribute operatingTemperatureMaximum : Temperature = 85.0;
        attribute maximumSwitchingVoltage : ElectricVoltage = 24.0;
        attribute maximumSwitchingCurrent : ElectricCurrent = 100.0;
        attribute primaryFunction : String =
            "Detect the presence of a magnetic field and convert it into an isolated binary electrical signal.";

        part reedContacts : ReedContactPair;
        part pullUp : PullUpNetwork;
        part conditioner : SignalConditioner;

        port magneticFieldInput : MagneticFieldPort;
        port supplyInput : ElectricalInputPort;
        port binaryOutput : ElectricalOutputPort;

        connect magneticFieldInput to reedContacts.magneticInput;
        connect supplyInput to pullUp.supplyInput;
        connect reedContacts.contactSense to conditioner.contactInput;
        connect conditioner.conditionedOutput to binaryOutput;
    }

    part def ReedSwitchBasedPresenceSensor {
        attribute systemName : String = "Reed Switch Magnetic Presence Sensor";
        attribute nominalSupplyVoltage : ElectricVoltage = 5.0;
        attribute nominalActuationFluxDensity : MagneticFluxDensity = 6.0;
        attribute nominalReleaseFluxDensity : MagneticFluxDensity = 3.0;
        attribute responseTimeMaximum : TimeDuration = 10.0;

        part actuatorMagnet : PermanentMagnet;
        part reedSwitchAssembly : ProtectedReedSwitchAssembly;

        port supply : ElectricalInputPort;
        port detectedOutput : ElectricalOutputPort;

        connect actuatorMagnet.magneticOutput to reedSwitchAssembly.magneticFieldInput;
        connect supply to reedSwitchAssembly.supplyInput;
        connect reedSwitchAssembly.binaryOutput to detectedOutput;

        action detectMagnetPresence {
            in item field : MagneticField;
            out item signal : ElectricalSignal;

            if field.fluxDensity >= nominalActuationFluxDensity {
                signal.level = SwitchOutputLevel::active;
                signal.voltage = 0.0;
                signal.current = 0.5;
            } else {
                signal.level = SwitchOutputLevel::inactive;
                signal.voltage = nominalSupplyVoltage;
                signal.current = 0.0;
            }
        }

        state def SensorOperationalBehavior {
            state unpowered;
            state monitoring;
            state magnetDetected;
            state magnetAbsent;

            transition initial then unpowered;

            transition power_applied
                first unpowered
                accept ElectricalSignal
                if supply.supply.voltage >= 4.5
                then monitoring;

            transition begin_absent
                first monitoring
                if actuatorMagnet.magneticOutput.field.fluxDensity < nominalActuationFluxDensity
                then magnetAbsent;

            transition begin_detected
                first monitoring
                if actuatorMagnet.magneticOutput.field.fluxDensity >= nominalActuationFluxDensity
                then magnetDetected;

            transition absent_to_detected
                first magnetAbsent
                accept MagneticField
                if actuatorMagnet.magneticOutput.field.fluxDensity >= nominalActuationFluxDensity
                do detectMagnetPresence
                then magnetDetected;

            transition detected_to_absent
                first magnetDetected
                accept MagneticField
                if actuatorMagnet.magneticOutput.field.fluxDensity <= nominalReleaseFluxDensity
                do detectMagnetPresence
                then magnetAbsent;

            transition power_removed
                first monitoring
                accept ElectricalSignal
                if supply.supply.voltage < 1.0
                then unpowered;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc
            /* The reed switch system shall detect the presence of a magnetic field and provide a binary electrical output representing whether the magnetic actuator is present. */
        subject sensor : ReedSwitchBasedPresenceSensor;

        require constraint {
            sensor.detectedOutput.output.level == SwitchOutputLevel::active
            when sensor.actuatorMagnet.magneticOutput.field.fluxDensity >= sensor.nominalActuationFluxDensity;
        }

        require constraint {
            sensor.detectedOutput.output.level == SwitchOutputLevel::inactive
            when sensor.actuatorMagnet.magneticOutput.field.fluxDensity <= sensor.nominalReleaseFluxDensity;
        }
    }

    requirement def ElectricalInterfaceRequirement {
        subject sensor : ReedSwitchBasedPresenceSensor;

        require constraint {
            sensor.supply.supply.voltage >= 4.5 and sensor.supply.supply.voltage <= 5.5;
        }

        require constraint {
            sensor.detectedOutput.output.current <= 1.0;
        }
    }

    requirement def ContactProtectionRequirement {
        subject assembly : ProtectedReedSwitchAssembly;

        require constraint {
            assembly.maximumSwitchingVoltage <= 24.0;
        }

        require constraint {
            assembly.maximumSwitchingCurrent <= 100.0;
        }
    }

    requirement def ResponseTimeRequirement {
        subject sensor : ReedSwitchBasedPresenceSensor;

        require constraint {
            sensor.responseTimeMaximum <= 10.0;
        }
    }

    requirement def EnvironmentalRequirement {
        subject assembly : ProtectedReedSwitchAssembly;

        require constraint {
            assembly.operatingTemperatureMinimum <= -40.0;
        }

        require constraint {
            assembly.operatingTemperatureMaximum >= 85.0;
        }
    }

    part reedSwitchPresenceSensor : ReedSwitchBasedPresenceSensor;

    satisfy PrimaryFunctionRequirement by reedSwitchPresenceSensor;
    satisfy ElectricalInterfaceRequirement by reedSwitchPresenceSensor;
    satisfy ResponseTimeRequirement by reedSwitchPresenceSensor;
    satisfy ContactProtectionRequirement by reedSwitchPresenceSensor.reedSwitchAssembly;
    satisfy EnvironmentalRequirement by reedSwitchPresenceSensor.reedSwitchAssembly;
}