package CoolantTemperatureSensingUnit {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value types with units ----
    package Units {
        attribute def TemperatureUnit :> Unit;
        attribute def ResistanceUnit :> Unit;
        attribute def VoltageUnit :> Unit;
        attribute def CurrentUnit :> Unit;
    }

    value type Temperature :> Real {
        unit :> Units::TemperatureUnit;
    }
    value type Resistance :> Real {
        unit :> Units::ResistanceUnit;
    }
    value type Voltage :> Real {
        unit :> Units::VoltageUnit;
    }
    value type Current :> Real {
        unit :> Units::CurrentUnit;
    }

    // ---- Item types ----
    item def Coolant;
    item def CoolantFlow {
        attribute temperature : Temperature;
    }
    item def ResistanceReading {
        attribute value : Resistance;
    }
    item def VoltageSignal {
        attribute value : Voltage;
    }
    item def TemperatureReport {
        attribute temperature : Temperature;
        attribute timestamp : Integer;
        attribute status : String;
    }
    item def DiagnosticFlag {
        attribute faultType : String;
        attribute active : Boolean;
    }

    // ---- Port definitions ----
    port def CoolantPort {
        attribute temperature : Temperature;
        in item coolantFlow : CoolantFlow;
    }
    port def ElectricalSignalPort {
        out item signal : VoltageSignal;
    }
    port def DiagnosticPort {
        out item diagnostic : DiagnosticFlag;
    }
    port def ECMInputPort {
        in item tempReport : TemperatureReport;
    }
    port def ControlPort {
        out item command : String;
    }

    // ---- Requirements ----
    requirement def AccurateTemperatureMeasurement {
        doc "The sensor shall measure coolant temperature accurately.";
        attribute measurementRangeMin : Temperature = -40 [Temperature];
        attribute measurementRangeMax : Temperature = 150 [Temperature];
        attribute accuracyTolerance : Temperature = 2 [Temperature];
        require constraint { (measurement >= measurementRangeMin) and (measurement <= measurementRangeMax) }
    }

    requirement def ReliableSignalConditioning {
        doc "The signal conditioning circuit shall convert resistance to a calibrated voltage.";
        attribute outputVoltageMin : Voltage = 0 [Voltage];
        attribute outputVoltageMax : Voltage = 5 [Voltage];
        require constraint { (outputSignal.value >= outputVoltageMin) and (outputSignal.value <= outputVoltageMax) }
    }

    requirement def FaultDetectionCapability {
        doc "The sensor shall detect open circuit, short circuit, and out-of-range faults.";
        require constraint { faultState implies (openCircuitDetected or shortCircuitDetected or outOfRangeDetected) }
    }

    requirement def ECMResponseRequirement {
        doc "The ECM shall use temperature data to adjust fuel mixture, control cooling fan, and trigger warning light.";
        require constraint { overheating implies warningLightActivated }
    }

    // ---- Thermistor element ----
    part def Thermistor {
        attribute nominalResistance : Resistance = 2400 [Resistance];
        attribute betaCoefficient : Real = 3950;
        port in coolantPort : CoolantPort;
        port out resistanceOut : ElectricalSignalPort;
        attribute currentResistance : Resistance;
        attribute currentTemperature : Temperature;

        action def UpdateResistance {
            in temp : Temperature;
            out resistance : Resistance;
        }
        action def MeasureTemperature {
            in coolantTemp : Temperature;
            out resistance : Resistance;
        }
    }

    // ---- Signal conditioning circuit ----
    part def SignalConditioningCircuit {
        attribute supplyVoltage : Voltage = 5 [Voltage];
        attribute pullupResistance : Resistance = 2400 [Resistance];
        port in resistanceIn : ElectricalSignalPort;
        port out voltageOut : ElectricalSignalPort;
        attribute outputVoltage : Voltage;

        action def ConvertResistanceToVoltage {
            in resistance : Resistance;
            out voltage : Voltage;
        }
    }

    // ---- Engine Coolant Temperature Sensor ----
    part def EngineCoolantTemperatureSensor {
        attribute casingMaterial : String = "brass";
        attribute connectorType : String = "2-pin weatherproof";
        attribute threadStandard : String = "M12x1.5";
        attribute operational : Boolean = true;
        attribute faultState : Boolean = false;
        attribute openCircuitDetected : Boolean = false;
        attribute shortCircuitDetected : Boolean = false;
        attribute outOfRangeDetected : Boolean = false;

        port in coolantInterface : CoolantPort;
        port out ecmSignal : ElectricalSignalPort;
        port out diagPort : DiagnosticPort;

        part thermistor : Thermistor;
        part conditioningCircuit : SignalConditioningCircuit;

        connection thermistorToConditioning connect thermistor.resistanceOut to conditioningCircuit.resistanceIn;
        connection conditioningToOutput connect conditioningCircuit.voltageOut to ecmSignal;

        satisfy AccurateTemperatureMeasurement;
        satisfy ReliableSignalConditioning;
        satisfy FaultDetectionCapability;

        state machine SensorStateMachine {
            entry action { operational = true; faultState = false; }
            state idle {
                entry action { /* sensor powered but not actively measuring */ }
                on coolantInterface do action { send TemperatureReport; }
            }
            state measuring {
                entry action { thermistor.MeasureTemperature; conditioningCircuit.ConvertResistanceToVoltage; }
                do action { send TemperatureReport; }
                transition measuring to measuring;
            }
            state fault {
                entry action { faultState = true; operational = false; send DiagnosticFlag; }
                transition fault to idle when !faultState;
            }
            transition idle to measuring when operational;
            transition measuring to fault when openCircuitDetected or shortCircuitDetected or outOfRangeDetected;
            transition measuring to idle when !operational;
            transition idle to fault when openCircuitDetected or shortCircuitDetected or outOfRangeDetected;
        }
    }

    // ---- Engine Control Module ----
    part def EngineControlModule {
        attribute coldEngineThreshold : Temperature = 40 [Temperature];
        attribute overheatingThreshold : Temperature = 110 [Temperature];
        attribute optimalTemp : Temperature = 90 [Temperature];
        attribute warningLightActivated : Boolean = false;
        attribute coolingFanCommand : String = "off";
        attribute fuelMixtureMode : String = "normal";

        port in sensorInput : ECMInputPort;
        port out fanControl : ControlPort;
        port out warningControl : ControlPort;
        port out fuelControl : ControlPort;

        action def ProcessTemperatureData {
            in report : TemperatureReport;
            out fanCmd : String;
            out warningCmd : String;
            out fuelCmd : String;
        }

        satisfy ECMResponseRequirement;
    }

    // ---- Supporting engine components ----
    part def CoolingFan {
        attribute speed : Integer = 0;
        attribute maxSpeed : Integer = 100;
        port in fanCommand : ControlPort;
        action def ActivateFan {
            in command : String;
            out speed : Integer;
        }
    }

    part def WarningLight {
        attribute illuminated : Boolean = false;
        port in warningCommand : ControlPort;
        action def Illuminate {
            in command : String;
            out illuminated : Boolean;
        }
    }

    part def FuelInjector {
        attribute mixtureRatio : Real = 14.7;
        port in fuelCommand : ControlPort;
        action def AdjustMixture {
            in command : String;
            out mixtureRatio : Real;
        }
    }

    part def EngineCoolantCircuit {
        attribute coolantType : String = "ethylene glycol";
        attribute coolantLevel : Real = 100;
        port out coolantFlowPort : CoolantPort;
        part coolant : Coolant;
    }

    // ---- Top-level system ----
    part CoolantTemperatureSensingSystem {
        part engineCoolantCircuit : EngineCoolantCircuit;
        part sensor : EngineCoolantTemperatureSensor;
        part ecm : EngineControlModule;
        part coolingFan : CoolingFan;
        part warningLight : WarningLight;
        part fuelInjector : FuelInjector;

        connection coolantToSensor connect engineCoolantCircuit.coolantFlowPort to sensor.coolantInterface;
        connection sensorToECM connect sensor.ecmSignal to ecm.sensorInput;
        connection ecmToFan connect ecm.fanControl to coolingFan.fanCommand;
        connection ecmToWarning connect ecm.warningControl to warningLight.warningCommand;
        connection ecmToFuel connect ecm.fuelControl to fuelInjector.fuelCommand;

        action def SystemOperation {
            perform sensor.SensorStateMachine;
            perform ecm.ProcessTemperatureData;
        }
    }
}
