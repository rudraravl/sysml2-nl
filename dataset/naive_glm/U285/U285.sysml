package ExtracorporealLiverSupportSystem {
    public import ISQ::*;
    public import ScalarValues::*;
    public import Time::*;

    // ---- Item Definitions ----
    item def Blood {
        attribute toxinConcentration : MassConcentration;
        attribute temperature : Temperature;
        attribute pressure : Pressure;
    }

    item def WasteFluid {
        attribute toxinConcentration : MassConcentration;
    }

    item def Dialysate {
        attribute temperature : Temperature;
        attribute flowRate : VolumeFlowRate;
    }

    item def AlarmSignal;
    item def ControlCommand;
    item def SensorReading {
        attribute value : Real;
        attribute timestamp : DateTime;
    }

    // ---- Value Types ----
    attribute def BloodFlowRateValue :> VolumeFlowRate {
        doc /* Controlled blood flow rate through the circuit. */
    }

    attribute def CircuitPressureValue :> Pressure {
        doc /* Pressure measured within the blood circuit. */
    }

    attribute def BloodTemperatureValue :> Temperature {
        doc /* Temperature of blood returning to the patient. */
    }

    attribute def ToxinLevelValue :> MassConcentration {
        doc /* Concentration of toxins in the blood. */
    }

    attribute def SessionDurationValue :> Duration {
        doc /* Duration of a continuous treatment session. */
    }

    // ---- Port Definitions ----
    port def BloodInPort {
        in item blood : Blood;
    }

    port def BloodOutPort {
        out item blood : Blood;
    }

    port def WasteOutPort {
        out item waste : WasteFluid;
    }

    port def DialysateInPort {
        in item dialysate : Dialysate;
    }

    port def ControlSignalPort {
        out item command : ControlCommand;
        in item reading : SensorReading;
    }

    port def AlarmPort {
        out item alarm : AlarmSignal;
    }

    // ---- Part Definitions ----
    part def BloodPump {
        attribute nominalFlowRate : BloodFlowRateValue = 200.0 [mL/min];
        attribute currentFlowRate : BloodFlowRateValue;
        port bloodIn : BloodInPort;
        port bloodOut : BloodOutPort;
        port control : ControlSignalPort;

        action def PumpBlood {
            in bloodIn : Blood;
            out bloodOut : Blood;
            in flowRate : BloodFlowRateValue;
        }

        perform action pumpBlood : PumpBlood {
            in bloodIn = bloodIn.blood;
            out bloodOut = bloodOut.blood;
            in flowRate = currentFlowRate;
        }
    }

    part def DialysisFilter {
        attribute membranePermeability : Real = 0.85;
        attribute maxToxinRemovalRate : MassConcentration = 50.0 [mg/L];
        port bloodIn : BloodInPort;
        port bloodOut : BloodOutPort;
        port dialysateIn : DialysateInPort;
        port wasteOut : WasteOutPort;

        action def FilterBlood {
            in bloodIn : Blood;
            in dialysate : Dialysate;
            out bloodOut : Blood;
            out waste : WasteFluid;
        }

        perform action filterBlood : FilterBlood {
            in bloodIn = bloodIn.blood;
            in dialysate = dialysateIn.dialysate;
            out bloodOut = bloodOut.blood;
            out waste = wasteOut.waste;
        }
    }

    part def TemperatureRegulator {
        attribute targetTemperature : BloodTemperatureValue = 37.0 [degC];
        attribute tolerance : Temperature = 0.5 [degC];
        attribute heaterPower : Power = 50.0 [W];
        port bloodIn : BloodInPort;
        port bloodOut : BloodOutPort;
        port control : ControlSignalPort;

        action def RegulateTemperature {
            in bloodIn : Blood;
            in target : Temperature;
            out bloodOut : Blood;
        }

        perform action regulate : RegulateTemperature {
            in bloodIn = bloodIn.blood;
            in target = targetTemperature;
            out bloodOut = bloodOut.blood;
        }
    }

    part def ToxinSensor {
        attribute measurementRange : MassConcentration = 0.0 [mg/L] .. 200.0 [mg/L];
        attribute samplingRate : Frequency = 1.0 [Hz];
        port bloodSample : BloodInPort;
        port control : ControlSignalPort;

        action def MeasureToxins {
            in blood : Blood;
            out reading : SensorReading;
        }

        perform action measure : MeasureToxins {
            in blood = bloodSample.blood;
            out reading = control.reading;
        }
    }

    part def PressureMonitor {
        attribute safeMin : CircuitPressureValue = 50.0 [mmHg];
        attribute safeMax : CircuitPressureValue = 350.0 [mmHg];
        attribute samplingRate : Frequency = 10.0 [Hz];
        port bloodSample : BloodInPort;
        port control : ControlSignalPort;

        action def MeasurePressure {
            in blood : Blood;
            out reading : SensorReading;
        }

        perform action measure : MeasurePressure {
            in blood = bloodSample.blood;
            out reading = control.reading;
        }
    }

    part def ControlUnit {
        attribute minBloodFlow : BloodFlowRateValue = 50.0 [mL/min];
        attribute maxBloodFlow : BloodFlowRateValue = 400.0 [mL/min];
        attribute safePressureMin : CircuitPressureValue = 50.0 [mmHg];
        attribute safePressureMax : CircuitPressureValue = 350.0 [mmHg];
        attribute safeTempMin : BloodTemperatureValue = 36.0 [degC];
        attribute safeTempMax : BloodTemperatureValue = 38.0 [degC];
        attribute maxToxinLevel : ToxinLevelValue = 150.0 [mg/L];
        attribute sessionDuration : SessionDurationValue = 6.0 [h];

        port pumpControl : ControlSignalPort;
        port regulatorControl : ControlSignalPort;
        port toxinInput : ControlSignalPort;
        port pressureInput : ControlSignalPort;
        port alarmOut : AlarmPort;

        state machine def OperatingStates {
            state idle;
            state priming;
            state treating;
            state rinsing;
            state alarm;

            transition init to idle;

            transition idle_to_priming
                from idle to priming
                when (pumpControl.reading.value > 0.0);

            transition priming_to_treating
                from priming to treating
                when (pumpControl.reading.value >= minBloodFlow.value);

            transition treating_to_rinsing
                from treating to rinsing
                when (sessionDuration <= 0.0 [h]);

            transition treating_to_alarm
                from treating to alarm
                when (pressureInput.reading.value < safePressureMin.value
                    or pressureInput.reading.value > safePressureMax.value
                    or toxinInput.reading.value > maxToxinLevel.value);

            transition rinsing_to_idle
                from rinsing to idle
                when (pumpControl.reading.value == 0.0);

            transition alarm_to_idle
                from alarm to idle
                when (pressureInput.reading.value >= safePressureMin.value
                    and pressureInput.reading.value <= safePressureMax.value
                    and toxinInput.reading.value <= maxToxinLevel.value);

            entry action alarm {
                alarmOut.alarm.send();
                pumpControl.command.send(ControlCommand{value = 0.0});
            }
        }

        perform state machine operation : OperatingStates;

        action def EvaluateSafety {
            in pressure : Real;
            in toxin : Real;
            in temperature : Real;
            out safe : Boolean;
        }

        perform action evaluateSafety : EvaluateSafety {
            in pressure = pressureInput.reading.value;
            in toxin = toxinInput.reading.value;
            in temperature = regulatorControl.reading.value;
        }
    }

    part def Patient {
        port bloodOut : BloodOutPort;
        port bloodIn : BloodInPort;
        attribute liverFunction : Real = 0.2;
    }

    // ---- System Assembly ----
    part def LiverSupportSystem {
        attribute systemId : String;
        attribute maxSessionDuration : SessionDurationValue = 8.0 [h];

        part patient : Patient;

        part pump : BloodPump {
            attribute currentFlowRate : BloodFlowRateValue = 200.0 [mL/min];
        }

        part filter : DialysisFilter;

        part regulator : TemperatureRegulator {
            attribute targetTemperature : BloodTemperatureValue = 37.0 [degC];
        }

        part controller : ControlUnit;

        part toxinSensor : ToxinSensor;

        part pressureMonitor : PressureMonitor;

        part dialysateReservoir {
            port dialysateOut : DialysateInPort;
            attribute volume : Volume = 5.0 [L];
        }

        part wasteReservoir {
            port wasteIn : WasteOutPort;
            attribute volume : Volume = 10.0 [L];
        }

        connection patientToPump
            connect patient.bloodOut.blood to pump.bloodIn.blood;

        connection pumpToFilter
            connect pump.bloodOut.blood to filter.bloodIn.blood;

        connection filterToRegulator
            connect filter.bloodOut.blood to regulator.bloodIn.blood;

        connection regulatorToPatient
            connect regulator.bloodOut.blood to patient.bloodIn.blood;

        connection dialysateToFilter
            connect dialysateReservoir.dialysateOut.dialysate to filter.dialysateIn.dialysate;

        connection filterToWaste
            connect filter.wasteOut.waste to wasteReservoir.wasteIn.waste;

        connection pumpControlLink
            connect controller.pumpControl to pump.control;

        connection regulatorControlLink
            connect controller.regulatorControl to regulator.control;

        connection toxinSensorLink
            connect controller.toxinInput to toxinSensor.control;

        connection pressureMonitorLink
            connect controller.pressureInput to pressureMonitor.control;

        connection toxinSampling
            connect pump.bloodOut.blood to toxinSensor.bloodSample.blood;

        connection pressureSampling
            connect pump.bloodOut.blood to pressureMonitor.bloodSample.blood;
    }

    // ---- Requirements ----
    requirement def BloodFlowRequirement {
        doc /* The blood pump shall maintain a controlled flow rate within safe limits. */
        subject system : LiverSupportSystem;
        attribute minFlow : BloodFlowRateValue = 50.0 [mL/min];
        attribute maxFlow : BloodFlowRateValue = 400.0 [mL/min];
        constraint { system.pump.currentFlowRate.value >= minFlow.value
                  and system.pump.currentFlowRate.value <= maxFlow.value }
    }

    requirement def PressureSafetyRequirement {
        doc /* The system shall halt operation if circuit pressure exceeds safe limits. */
        subject system : LiverSupportSystem;
        attribute safeMin : CircuitPressureValue = 50.0 [mmHg];
        attribute safeMax : CircuitPressureValue = 350.0 [mmHg];
        constraint { system.pressureMonitor.safeMin.value == safeMin.value
                  and system.pressureMonitor.safeMax.value == safeMax.value }
    }

    requirement def TemperatureRequirement {
        doc /* Blood returned to the patient shall be within body temperature tolerance. */
        subject system : LiverSupportSystem;
        attribute target : BloodTemperatureValue = 37.0 [degC];
        attribute tolerance : Temperature = 0.5 [degC];
        constraint { system.regulator.targetTemperature.value == target.value
                  and system.regulator.tolerance.value == tolerance.value }
    }

    requirement def ToxinMonitoringRequirement {
        doc /* The toxin sensor shall continuously measure blood impurity levels. */
        subject system : LiverSupportSystem;
        attribute maxLevel : ToxinLevelValue = 150.0 [mg/L];
        constraint { system.toxinSensor.measurementRange.max >= maxLevel.value }
    }

    requirement def SessionDurationRequirement {
        doc /* The system shall support continuous treatment sessions of several hours. */
        subject system : LiverSupportSystem;
        attribute minDuration : SessionDurationValue = 4.0 [h];
        attribute maxDuration : SessionDurationValue = 8.0 [h];
        constraint { system.maxSessionDuration.value >= minDuration.value
                  and system.maxSessionDuration.value <= maxDuration.value }
    }

    requirement def AlarmRequirement {
        doc /* The control unit shall trigger an alarm and halt on unsafe conditions. */
        subject system : LiverSupportSystem;
        constraint { system.controller.alarmOut.alarm.isSent implies
                     system.pump.currentFlowRate.value == 0.0 }
    }

    requirement def StateMachineRequirement {
        doc /* The system shall operate through idle, priming, treating, rinsing, and alarm states. */
        subject system : LiverSupportSystem;
        constraint { system.controller.operation.states.includes("idle")
                  and system.controller.operation.states.includes("priming")
                  and system.controller.operation.states.includes("treating")
                  and system.controller.operation.states.includes("rinsing")
                  and system.controller.operation.states.includes("alarm") }
    }

    requirement def SystemRequirements {
        doc /* Top-level requirements for the extracorporeal liver support system. */
        satisfy bloodFlow : BloodFlowRequirement by LiverSupportSystem.pump;
        satisfy pressureSafety : PressureSafetyRequirement by LiverSupportSystem.pressureMonitor;
        satisfy temperature : TemperatureRequirement by LiverSupportSystem.regulator;
        satisfy toxinMonitoring : ToxinMonitoringRequirement by LiverSupportSystem.toxinSensor;
        satisfy sessionDuration : SessionDurationRequirement by LiverSupportSystem;
        satisfy alarm : AlarmRequirement by LiverSupportSystem.controller;
        satisfy stateMachine : StateMachineRequirement by LiverSupportSystem.controller;
    }
}
