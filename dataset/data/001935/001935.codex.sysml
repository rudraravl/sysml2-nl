package TouchSensingUnitModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Probability : Real {
        doc "Dimensionless probability in the closed interval [0, 1]."
    }

    attribute def Force_N : Force {
        unit = newton;
    }

    attribute def Time_s : Time {
        unit = second;
    }

    attribute def Voltage_V : ElectricPotential {
        unit = volt;
    }

    attribute def Current_A : ElectricCurrent {
        unit = ampere;
    }

    attribute def Frequency_Hz : Frequency {
        unit = hertz;
    }

    attribute def Temperature_C : Real {
        doc "Temperature in degrees Celsius."
    }

    enum def ContactState {
        enum noContact;
        enum contactDetected;
        enum pressed;
        enum released;
        enum fault;
    }

    item def MechanicalContact {
        attribute normalForce : Force_N;
        attribute contactDuration : Time_s;
        attribute contactArea_mm2 : Real;
    }

    item def ElectricalPower {
        attribute supplyVoltage : Voltage_V;
        attribute supplyCurrent : Current_A;
    }

    item def RawTouchSignal {
        attribute measuredVoltage : Voltage_V;
        attribute sampleTime : Time_s;
        attribute adcCounts : Integer;
    }

    item def TouchMeasurement {
        attribute touched : Boolean;
        attribute forceEstimate : Force_N;
        attribute confidence : Probability;
        attribute state : ContactState;
        attribute timestamp : Time_s;
    }

    item def DiagnosticStatus {
        attribute sensorOpenCircuit : Boolean;
        attribute sensorShortCircuit : Boolean;
        attribute outOfRange : Boolean;
        attribute degraded : Boolean;
        attribute messageCode : Integer;
    }

    port def MechanicalContactPort {
        in item contact : MechanicalContact;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def RawSignalPort {
        out item signal : RawTouchSignal;
    }

    port def MeasurementOutputPort {
        out item measurement : TouchMeasurement;
    }

    port def DiagnosticOutputPort {
        out item diagnostic : DiagnosticStatus;
    }

    port def ProcessorSignalInputPort {
        in item signal : RawTouchSignal;
    }

    part def TouchSensor {
        attribute sensingRangeMin : Force_N = 0.2 [N];
        attribute sensingRangeMax : Force_N = 20.0 [N];
        attribute activationThreshold : Force_N = 0.5 [N];
        attribute overloadLimit : Force_N = 30.0 [N];
        attribute responseTime : Time_s = 0.010 [s];
        attribute nominalSupplyVoltage : Voltage_V = 3.3 [V];
        attribute outputVoltageNoTouch : Voltage_V = 0.15 [V];
        attribute outputVoltageFullScale : Voltage_V = 3.0 [V];

        port contactPort : MechanicalContactPort;
        port powerPort : PowerInputPort;
        port rawSignalPort : RawSignalPort;

        action senseContact {
            in item appliedContact : MechanicalContact;
            out item rawSignal : RawTouchSignal;

            first start;
            then validateForce;
            then convertForceToVoltage;
            then publishRawSignal;
            then done;

            action validateForce {
                in item appliedContact : MechanicalContact;
                out attribute valid : Boolean;
            }

            action convertForceToVoltage {
                in item appliedContact : MechanicalContact;
                out item rawSignal : RawTouchSignal;
            }

            action publishRawSignal {
                in item rawSignal : RawTouchSignal;
            }
        }

        state def SensorOperatingState {
            entry; then idle;

            state idle;
            state active;
            state overloaded;
            state failed;

            transition idle_to_active
                first idle
                accept item c : MechanicalContact
                if c.normalForce >= activationThreshold
                then active;

            transition active_to_idle
                first active
                accept item c : MechanicalContact
                if c.normalForce < activationThreshold
                then idle;

            transition active_to_overloaded
                first active
                accept item c : MechanicalContact
                if c.normalForce > overloadLimit
                then overloaded;

            transition overloaded_to_failed
                first overloaded
                accept after 0.100 [s]
                then failed;
        }
    }

    part def SignalConditioner {
        attribute lowPassCutoffFrequency : Frequency_Hz = 50.0 [Hz];
        attribute gain : Real = 1.0;
        attribute offsetVoltage : Voltage_V = 0.0 [V];
        attribute adcResolutionBits : Integer = 12;
        attribute samplePeriod : Time_s = 0.005 [s];

        port rawInput : ProcessorSignalInputPort;
        port conditionedOutput : RawSignalPort;

        action conditionSignal {
            in item rawSignal : RawTouchSignal;
            out item conditionedSignal : RawTouchSignal;

            first acquire;
            then filterNoise;
            then scaleSignal;
            then digitize;
            then publish;

            action acquire {
                in item rawSignal : RawTouchSignal;
            }

            action filterNoise {
                in item rawSignal : RawTouchSignal;
                out item filteredSignal : RawTouchSignal;
            }

            action scaleSignal {
                in item filteredSignal : RawTouchSignal;
                out item scaledSignal : RawTouchSignal;
            }

            action digitize {
                in item scaledSignal : RawTouchSignal;
                out item conditionedSignal : RawTouchSignal;
            }

            action publish {
                in item conditionedSignal : RawTouchSignal;
            }
        }
    }

    part def TouchMeasurementProcessor {
        attribute detectionThresholdVoltage : Voltage_V = 0.40 [V];
        attribute releaseThresholdVoltage : Voltage_V = 0.25 [V];
        attribute debounceTime : Time_s = 0.030 [s];
        attribute measurementUpdatePeriod : Time_s = 0.010 [s];
        attribute minimumConfidence : Probability = 0.95;

        port signalInput : ProcessorSignalInputPort;
        port measurementOutput : MeasurementOutputPort;
        port diagnosticOutput : DiagnosticOutputPort;

        action estimateTouch {
            in item conditionedSignal : RawTouchSignal;
            out item measurement : TouchMeasurement;
            out item diagnostic : DiagnosticStatus;

            first readSample;
            then checkRange;
            then applyDebounce;
            then classifyContact;
            then estimateForce;
            then emitMeasurement;

            action readSample {
                in item conditionedSignal : RawTouchSignal;
            }

            action checkRange {
                in item conditionedSignal : RawTouchSignal;
                out item diagnostic : DiagnosticStatus;
            }

            action applyDebounce {
                in item conditionedSignal : RawTouchSignal;
                out attribute stable : Boolean;
            }

            action classifyContact {
                in item conditionedSignal : RawTouchSignal;
                in attribute stable : Boolean;
                out attribute state : ContactState;
            }

            action estimateForce {
                in item conditionedSignal : RawTouchSignal;
                out attribute forceEstimate : Force_N;
            }

            action emitMeasurement {
                in attribute state : ContactState;
                in attribute forceEstimate : Force_N;
                out item measurement : TouchMeasurement;
            }
        }

        state def MeasurementStateMachine {
            entry; then monitoring;

            state monitoring;
            state debouncingPress;
            state touchConfirmed;
            state debouncingRelease;
            state diagnosticFault;

            transition monitor_to_press_debounce
                first monitoring
                accept item s : RawTouchSignal
                if s.measuredVoltage >= detectionThresholdVoltage
                then debouncingPress;

            transition press_debounce_to_confirmed
                first debouncingPress
                accept after debounceTime
                then touchConfirmed;

            transition confirmed_to_release_debounce
                first touchConfirmed
                accept item s : RawTouchSignal
                if s.measuredVoltage <= releaseThresholdVoltage
                then debouncingRelease;

            transition release_debounce_to_monitor
                first debouncingRelease
                accept after debounceTime
                then monitoring;

            transition any_to_fault
                first monitoring
                accept item d : DiagnosticStatus
                if d.sensorOpenCircuit or d.sensorShortCircuit or d.outOfRange
                then diagnosticFault;
        }
    }

    part def PowerRegulator {
        attribute inputVoltage : Voltage_V = 5.0 [V];
        attribute regulatedVoltage : Voltage_V = 3.3 [V];
        attribute maxOutputCurrent : Current_A = 0.050 [A];

        port powerIn : PowerInputPort;
        port regulatedPowerOut : PowerInputPort;
    }

    part def TouchSensingUnit {
        attribute operatingTemperatureMin : Temperature_C = -20.0;
        attribute operatingTemperatureMax : Temperature_C = 70.0;
        attribute endToEndLatency : Time_s = 0.050 [s];
        attribute measurementAccuracy : Force_N = 0.2 [N];

        port externalContact : MechanicalContactPort;
        port externalPower : PowerInputPort;
        port touchMeasurement : MeasurementOutputPort;
        port diagnosticStatus : DiagnosticOutputPort;

        part regulator : PowerRegulator;
        part sensor : TouchSensor;
        part conditioner : SignalConditioner;
        part processor : TouchMeasurementProcessor;

        connect externalPower to regulator.powerIn;
        connect regulator.regulatedPowerOut to sensor.powerPort;
        connect externalContact to sensor.contactPort;
        connect sensor.rawSignalPort to conditioner.rawInput;
        connect conditioner.conditionedOutput to processor.signalInput;
        connect processor.measurementOutput to touchMeasurement;
        connect processor.diagnosticOutput to diagnosticStatus;

        action performTouchMeasurement {
            in item contact : MechanicalContact;
            out item measurement : TouchMeasurement;
            out item diagnostic : DiagnosticStatus;

            first receiveContact;
            then senseByTouchSensor;
            then conditionRawSignal;
            then computeMeasurement;
            then publishResult;

            action receiveContact {
                in item contact : MechanicalContact;
            }

            action senseByTouchSensor {
                in item contact : MechanicalContact;
                out item rawSignal : RawTouchSignal;
            }

            action conditionRawSignal {
                in item rawSignal : RawTouchSignal;
                out item conditionedSignal : RawTouchSignal;
            }

            action computeMeasurement {
                in item conditionedSignal : RawTouchSignal;
                out item measurement : TouchMeasurement;
                out item diagnostic : DiagnosticStatus;
            }

            action publishResult {
                in item measurement : TouchMeasurement;
                in item diagnostic : DiagnosticStatus;
            }
        }
    }

    requirement def ReqTouchSensingUnit {
        subject sensingUnit : TouchSensingUnit;

        require constraint {
            sensingUnit.endToEndLatency <= 0.050 [s]
        }

        doc "The sensing unit shall measure physical touch contact using a touch sensor and shall output a debounced touch measurement with force estimate, confidence, timestamp, and diagnostic status."
    }

    requirement def ReqUsesTouchSensor {
        subject sensingUnit : TouchSensingUnit;

        require constraint {
            sensingUnit.sensor.activationThreshold <= 0.5 [N]
        }

        doc "The sensing unit shall use a TouchSensor as the primary sensing element for the relevant measured quantity, physical touch contact."
    }

    requirement def ReqMeasurementRange {
        subject sensor : TouchSensor;

        require constraint {
            sensor.sensingRangeMin <= 0.2 [N] and sensor.sensingRangeMax >= 20.0 [N]
        }

        doc "The touch sensor shall detect normal contact force from 0.2 N through at least 20 N."
    }

    requirement def ReqDebouncedDetection {
        subject processor : TouchMeasurementProcessor;

        require constraint {
            processor.debounceTime >= 0.020 [s] and processor.debounceTime <= 0.050 [s]
        }

        doc "The processor shall debounce press and release transitions before publishing a changed touch state."
    }

    requirement def ReqConfidence {
        subject processor : TouchMeasurementProcessor;

        require constraint {
            processor.minimumConfidence >= 0.95
        }

        doc "The measurement processor shall publish touch detections with confidence of at least 0.95 under nominal operating conditions."
    }

    requirement def ReqPower {
        subject regulator : PowerRegulator;

        require constraint {
            regulator.regulatedVoltage == 3.3 [V] and regulator.maxOutputCurrent >= 0.020 [A]
        }

        doc "The power regulator shall provide regulated electrical power compatible with the touch sensor and measurement processor."
    }

    requirement def ReqDiagnostics {
        subject processor : TouchMeasurementProcessor;

        doc "The sensing unit shall report diagnostic status for open circuit, short circuit, out-of-range signal, and degraded operation."
    }

    requirement def ReqEnvironmentalOperation {
        subject sensingUnit : TouchSensingUnit;

        require constraint {
            sensingUnit.operatingTemperatureMin <= -20.0 and sensingUnit.operatingTemperatureMax >= 70.0
        }

        doc "The sensing unit shall operate across the required environmental temperature range."
    }

    part touchSensingUnit : TouchSensingUnit;

    satisfy ReqTouchSensingUnit by touchSensingUnit;
    satisfy ReqUsesTouchSensor by touchSensingUnit;
    satisfy ReqMeasurementRange by touchSensingUnit.sensor;
    satisfy ReqDebouncedDetection by touchSensingUnit.processor;
    satisfy ReqConfidence by touchSensingUnit.processor;
    satisfy ReqPower by touchSensingUnit.regulator;
    satisfy ReqDiagnostics by touchSensingUnit.processor;
    satisfy ReqEnvironmentalOperation by touchSensingUnit;
}