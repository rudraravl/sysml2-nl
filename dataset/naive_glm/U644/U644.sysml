package Cylinder_Head_Temperature_Gauge_System {

    import ScalarValues::*;

    // ============================================================
    // UNITS
    // ============================================================
    unit degC {
        doc /* Degree Celsius — thermodynamic temperature (SI derived) */;
    }
    unit V {
        doc /* Volt — electric potential difference (SI derived) */;
    }
    unit deg {
        doc /* Degree — planar angle */;
    }

    // ============================================================
    // VALUE TYPES
    // ============================================================
    attribute def Temperature :> Real;
    attribute def Voltage :> Real;
    attribute def NeedleAngle :> Real;

    // ============================================================
    // THRESHOLD CONSTANTS
    // ============================================================
    attribute cautionThreshold : Temperature = 200 [degC];
    attribute overheatThreshold : Temperature = 250 [degC];
    attribute normalMaxVoltage : Voltage = 3.0 [V];
    attribute cautionMaxVoltage : Voltage = 4.0 [V];
    attribute overheatVoltage : Voltage = 4.5 [V];

    // ============================================================
    // ITEMS
    // ============================================================
    item def ThermalEnergy;
    item def ElectricalSignal {
        attribute voltage : Voltage;
    }

    // ============================================================
    // PORTS / INTERFACES
    // ============================================================
    port def ThermalInterface {
        in heat : ThermalEnergy;
        in temperature : Temperature;
    }
    port def ElectricalSignalInterface {
        in signal : ElectricalSignal;
    }

    // ============================================================
    // CONNECTION DEFINITIONS
    // ============================================================
    connection def ThermalConduit {
        end source : ~ThermalInterface;
        end target : ThermalInterface;
    }
    connection def ElectricalConduit {
        end source : ~ElectricalSignalInterface;
        end target : ElectricalSignalInterface;
    }

    // ============================================================
    // ACTION DEFINITIONS
    // ============================================================
    action def ConvertHeatToVoltage {
        in heat : ThermalEnergy;
        in temperature : Temperature;
        out signal : ElectricalSignal;
    }
    action def InterpretVoltageAsTemperature {
        in signal : ElectricalSignal;
        out temperature : Temperature;
    }
    action def DeflectNeedle {
        in temperature : Temperature;
        out angle : NeedleAngle;
    }
    action def ControlWarningLight {
        in voltage : Voltage;
        out isOn : Boolean;
    }

    // ============================================================
    // PART DEFINITIONS
    // ============================================================

    part def CylinderHead {
        attribute headTemperature : Temperature = 25 [degC];
        port heatOut : ~ThermalInterface;

        action emitThermalEnergy {
            out heat : ThermalEnergy = heatOut.heat;
            out temperature : Temperature = heatOut.temperature;
        }
    }

    part def TemperatureSensor {
        port heatIn : ThermalInterface;
        port signalOut : ~ElectricalSignalInterface;
        attribute outputVoltage : Voltage;

        action convert : ConvertHeatToVoltage {
            in heat = heatIn.heat;
            in temperature = heatIn.temperature;
            out signal = signalOut.signal;
        }
    }

    part def IndicatorGauge {
        port signalIn : ElectricalSignalInterface;
        attribute displayedTemperature : Temperature;
        attribute needleAngle : NeedleAngle;

        action interpret : InterpretVoltageAsTemperature {
            in signal = signalIn.signal;
            out temperature = displayedTemperature;
        }
        action deflect : DeflectNeedle {
            in temperature = displayedTemperature;
            out angle = needleAngle;
        }

        state machine GaugeStateMachine {
            state normal {
                entry { /* Needle positioned in green zone — normal operating range */ }
                do { /* Continuously update needle position based on displayedTemperature */ }
            }
            state caution {
                entry { /* Needle positioned in yellow zone — caution range */ }
                do { /* Continuously update needle position based on displayedTemperature */ }
            }
            state overheat {
                entry { /* Needle positioned in red zone — critical overheat */ }
                do { /* Continuously update needle position based on displayedTemperature */ }
            }

            transition from normal to caution
                when displayedTemperature > cautionThreshold;
            transition from caution to normal
                when displayedTemperature <= cautionThreshold;
            transition from caution to overheat
                when displayedTemperature > overheatThreshold;
            transition from overheat to caution
                when displayedTemperature <= overheatThreshold;
        }
    }

    part def WarningLight {
        port signalIn : ElectricalSignalInterface;
        attribute isIlluminated : Boolean = false;
        attribute inputVoltage : Voltage;

        action control : ControlWarningLight {
            in voltage = inputVoltage;
            out isOn = isIlluminated;
        }

        state machine WarningLightStateMachine {
            state off {
                entry { /* Warning light not illuminated */ }
            }
            state on {
                entry { /* Warning light illuminated — red, indicating overheat */ }
            }

            transition from off to on
                when inputVoltage >= overheatVoltage;
            transition from on to off
                when inputVoltage < overheatVoltage;
        }
    }

    part def InstrumentPanel {
        part indicatorGauge : IndicatorGauge;
        part warningLight : WarningLight;
    }

    // ============================================================
    // SYSTEM ASSEMBLY
    // ============================================================
    part def CHTGaugeSystem {
        part cylinderHead : CylinderHead;
        part temperatureSensor : TemperatureSensor;
        part instrumentPanel : InstrumentPanel;

        // Thermal connection: cylinder head transfers heat to sensor
        connect cylinderHead.heatOut to temperatureSensor.heatIn;

        // Electrical signal distributed in parallel to gauge and warning light
        connect temperatureSensor.signalOut to instrumentPanel.indicatorGauge.signalIn;
        connect temperatureSensor.signalOut to instrumentPanel.warningLight.signalIn;
    }

    // ============================================================
    // REQUIREMENTS
    // ============================================================
    requirement <'CHT-001'> ContinuousTemperatureMeasurement {
        doc /*
            The CHT Gauge System shall continuously measure the
            temperature of the engine cylinder head through a
            temperature sensor placed in direct physical contact
            with the cylinder head.
        */;
    }

    requirement <'CHT-002'> HeatToVoltageConversion {
        doc /*
            The temperature sensor shall convert the absorbed
            thermal energy from the cylinder head into a
            proportional electrical voltage signal that varies
            with changes in cylinder head temperature.
        */;
    }

    requirement <'CHT-003'> ParallelSignalDistribution {
        doc /*
            The electrical signal from the temperature sensor
            shall be transmitted simultaneously to both the
            indicator gauge and the dedicated warning light
            on the instrument panel.
        */;
    }

    requirement <'CHT-004'> ContinuousVisualDisplay {
        doc /*
            The indicator gauge shall interpret the incoming
            voltage signal, translate it into a temperature
            reading, and deflect a physical needle to provide
            a continuous visual display of the current cylinder
            head temperature.
        */;
    }

    requirement <'CHT-005'> NormalStateOperation {
        doc /*
            The indicator gauge shall operate in a NORMAL state
            during standard conditions when the cylinder head
            temperature is at or below 200 degC.
        */;
    }

    requirement <'CHT-006'> CautionStateTransition {
        doc /*
            The indicator gauge shall transition from the NORMAL
            state to a CAUTION state when the cylinder head
            temperature exceeds 200 degC.
        */;
    }

    requirement <'CHT-007'> OverheatStateTransition {
        doc /*
            The indicator gauge shall transition from the CAUTION
            state to an OVERHEAT state when the cylinder head
            temperature continues to rise and exceeds 250 degC.
        */;
    }

    requirement <'CHT-008'> WarningLightIllumination {
        doc /*
            The dedicated warning light shall illuminate
            specifically when the cylinder head temperature
            reaches the overheat threshold of 250 degC,
            providing an immediate and unambiguous visual
            alert to the operator that the engine is in a
            dangerous thermal condition requiring immediate
            action.
        */;
    }

    requirement <'CHT-009'> StateRecovery {
        doc /*
            The indicator gauge and warning light shall revert
            to their previous operational states when the
            cylinder head temperature decreases below the
            respective caution and overheat threshold values.
        */;
    }

    // ============================================================
    // SYSTEM INSTANCE AND SATISFACTION
    // ============================================================
    part chtGaugeSystemInstance : CHTGaugeSystem;

    satisfy ContinuousTemperatureMeasurement by chtGaugeSystemInstance;
    satisfy HeatToVoltageConversion by chtGaugeSystemInstance;
    satisfy ParallelSignalDistribution by chtGaugeSystemInstance;
    satisfy ContinuousVisualDisplay by chtGaugeSystemInstance;
    satisfy NormalStateOperation by chtGaugeSystemInstance;
    satisfy CautionStateTransition by chtGaugeSystemInstance;
    satisfy OverheatStateTransition by chtGaugeSystemInstance;
    satisfy WarningLightIllumination by chtGaugeSystemInstance;
    satisfy StateRecovery by chtGaugeSystemInstance;
}
