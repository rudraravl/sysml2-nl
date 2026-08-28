package TransdermalOxygenTherapySystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value type PressureValue :> Real { unit 'kPa'; }
    value type FlowRateValue :> Real { unit 'mL/min'; }
    value type TemperatureValue :> Real { unit 'degC'; }
    value type SpO2Value :> Real { unit '%'; }
    value type ConcentrationValue :> Real { unit '%'; }
    value type PowerValue :> Real { unit 'W'; }
    value type EnergyValue :> Real { unit 'J'; }
    value type VoltageValue :> Real { unit 'V'; }

    // ===== Item Types =====
    item def Air {
        attribute oxygenConcentration : ConcentrationValue = 21.0;
        attribute nitrogenConcentration : ConcentrationValue = 78.0;
    }

    item def MedicalOxygen {
        attribute purity : ConcentrationValue;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute temperature : TemperatureValue;
    }

    item def SensorData {
        attribute spo2 : SpO2Value;
        attribute skinTemp : TemperatureValue;
        attribute timestamp : Real;
    }

    item def ControlCommand {
        attribute targetFlowRate : FlowRateValue;
        attribute targetPressure : PressureValue;
        attribute emergencyShutdown : Boolean;
    }

    item def PowerSignal {
        attribute voltage : VoltageValue;
        attribute current : Real;
        attribute active : Boolean;
    }

    // ===== Port Definitions =====
    port def OxygenFlowPort {
        out oxygen : MedicalOxygen;
    }

    port def OxygenInPort {
        in oxygen : MedicalOxygen;
    }

    port def AirIntakePort {
        in air : Air;
    }

    port def SensorDataPort {
        out data : SensorData;
    }

    port def ControlCommandPort {
        in command : ControlCommand;
    }

    port def FeedbackPort {
        in data : SensorData;
    }

    port def PowerPort {
        out power : PowerSignal;
    }

    port def PowerInPort {
        in power : PowerSignal;
    }

    // ===== Requirements =====
    requirement def OxygenPurityRequirement {
        doc /* The oxygen concentrator shall produce medical-grade oxygen with purity >= 90%. */
        attribute minPurity : ConcentrationValue = 90.0;
        subject concentratorPurity : ConcentrationValue;
        require concentratorPurity >= minPurity;
    }

    requirement def SpO2TherapeuticRangeRequirement {
        doc /* The system shall maintain patient SpO2 between 92% and 99%. */
        attribute minSpO2 : SpO2Value = 92.0;
        attribute maxSpO2 : SpO2Value = 99.0;
        subject patientSpO2 : SpO2Value;
        require patientSpO2 >= minSpO2 and patientSpO2 <= maxSpO2;
    }

    requirement def SkinTemperatureSafetyRequirement {
        doc /* The system shall shut down if skin temperature exceeds 42 degC. */
        attribute maxSkinTemp : TemperatureValue = 42.0;
        subject measuredSkinTemp : TemperatureValue;
        require measuredSkinTemp <= maxSkinTemp;
    }

    requirement def DeliveryPressureSafetyRequirement {
        doc /* The system shall shut down if delivery pressure exceeds 50 kPa. */
        attribute maxDeliveryPressure : PressureValue = 50.0;
        subject measuredDeliveryPressure : PressureValue;
        require measuredDeliveryPressure <= maxDeliveryPressure;
    }

    requirement def BatteryLifeRequirement {
        doc /* The power supply shall support continuous operation for at least 8 hours. */
        attribute minRuntimeHours : Real = 8.0;
        subject actualRuntimeHours : Real;
        require actualRuntimeHours >= minRuntimeHours;
    }

    requirement def FlowRateRangeRequirement {
        doc /* The flow control module shall deliver oxygen between 1 and 50 mL/min. */
        attribute minFlow : FlowRateValue = 1.0;
        attribute maxFlow : FlowRateValue = 50.0;
        subject deliveredFlow : FlowRateValue;
        require deliveredFlow >= minFlow and deliveredFlow <= maxFlow;
    }

    // ===== Part Definitions =====

    part def OxygenConcentrator {
        port in airIntake : AirIntakePort;
        port out oxygenOut : OxygenFlowPort;
        port in powerIn : PowerInPort;

        attribute outputPurity : ConcentrationValue = 93.0;
        attribute outputPressure : PressureValue = 150.0;
        attribute powerConsumption : PowerValue = 15.0;

        satisfy OxygenPurityRequirement by outputPurity;

        action def ConcentrateOxygen {
            in incomingAir : Air;
            out concentratedO2 : MedicalOxygen;
            /* PSA-based separation: adsorbs nitrogen, enriches oxygen */
        }

        action concentrate : ConcentrateOxygen {
            in incomingAir = airIntake.air;
            out concentratedO2 = oxygenOut.oxygen;
        }
    }

    part def ReservoirTank {
        port in oxygenIn : OxygenInPort;
        port out oxygenOut : OxygenFlowPort;
        port in powerIn : PowerInPort;

        attribute capacity : Real = 500.0; // mL volume
        attribute storedPressure : PressureValue;
        attribute storedPurity : ConcentrationValue;
        attribute maxPressure : PressureValue = 200.0;

        action def StoreOxygen {
            in incomingO2 : MedicalOxygen;
            out outgoingO2 : MedicalOxygen;
            /* Accumulates oxygen until pressure reaches max, then passes through */
        }

        action store : StoreOxygen {
            in incomingO2 = oxygenIn.oxygen;
            out outgoingO2 = oxygenOut.oxygen;
        }
    }

    part def PressureRegulatorValve {
        port in oxygenIn : OxygenInPort;
        port out oxygenOut : OxygenFlowPort;
        port in powerIn : PowerInPort;

        attribute inputPressure : PressureValue;
        attribute outputPressure : PressureValue = 30.0;
        attribute maxOutputPressure : PressureValue = 50.0;

        satisfy DeliveryPressureSafetyRequirement by outputPressure;

        action def RegulatePressure {
            in incomingO2 : MedicalOxygen;
            in targetPressure : PressureValue;
            out regulatedO2 : MedicalOxygen;
            /* Reduces high input pressure to safe therapeutic output pressure */
        }

        action regulate : RegulatePressure {
            in incomingO2 = oxygenIn.oxygen;
            in targetPressure = outputPressure;
            out regulatedO2 = oxygenOut.oxygen;
        }
    }

    part def FlowControlModule {
        port in oxygenIn : OxygenInPort;
        port out oxygenOut : OxygenFlowPort;
        port in commandIn : ControlCommandPort;
        port in powerIn : PowerInPort;

        attribute currentFlowRate : FlowRateValue;
        attribute targetFlowRate : FlowRateValue;
        attribute minFlow : FlowRateValue = 1.0;
        attribute maxFlow : FlowRateValue = 50.0;

        satisfy FlowRateRangeRequirement by currentFlowRate;

        action def ControlFlow {
            in incomingO2 : MedicalOxygen;
            in targetFlow : FlowRateValue;
            out controlledO2 : MedicalOxygen;
            /* Uses proportional valve to set precise flow rate */
        }

        action controlFlow : ControlFlow {
            in incomingO2 = oxygenIn.oxygen;
            in targetFlow = commandIn.command.targetFlowRate;
            out controlledO2 = oxygenOut.oxygen;
        }
    }

    part def TransdermalDeliveryPatch {
        port in oxygenIn : OxygenInPort;
        port out sensorOut : SensorDataPort;

        attribute contactArea : Real = 50.0; // cm^2
        attribute membranePermeability : Real = 0.8;
        attribute skinContactTemp : TemperatureValue;
        attribute deliveryPressure : PressureValue;

        action def DeliverOxygen {
            in incomingO2 : MedicalOxygen;
            out absorbedO2 : MedicalOxygen;
            /* Facilitates transdermal diffusion of oxygen through skin */
        }

        action def MonitorSkin {
            out skinData : SensorData;
            /* Measures skin temperature at contact site */
        }

        action deliver : DeliverOxygen {
            in incomingO2 = oxygenIn.oxygen;
        }

        action monitorSkin : MonitorSkin {
            out skinData = sensorOut.data;
        }
    }

    part def PhysiologicalSensorArray {
        port out sensorOut : SensorDataPort;
        port in powerIn : PowerInPort;

        attribute measuredSpO2 : SpO2Value;
        attribute measuredSkinTemp : TemperatureValue;
        attribute samplingRate : Real = 1.0; // Hz

        action def MonitorPatient {
            out patientData : SensorData;
            /* Uses pulse oximetry for SpO2 and thermistor for skin temperature */
        }

        action monitor : MonitorPatient {
            out patientData = sensorOut.data;
        }
    }

    part def TherapyControlUnit {
        port in sensorFeedback : FeedbackPort;
        port out flowCommand : ControlCommandPort;
        port out regulatorCommand : ControlCommandPort;
        port in powerIn : PowerInPort;

        attribute targetSpO2 : SpO2Value = 96.0;
        attribute minSpO2 : SpO2Value = 92.0;
        attribute maxSpO2 : SpO2Value = 99.0;
        attribute maxSkinTemp : TemperatureValue = 42.0;
        attribute maxDeliveryPressure : PressureValue = 50.0;
        attribute currentFlowSetting : FlowRateValue;
        attribute currentPressureSetting : PressureValue;

        satisfy SpO2TherapeuticRangeRequirement by targetSpO2;

        action def ProcessSensorData {
            in data : SensorData;
            out command : ControlCommand;
            /* PID-like controller: adjusts flow rate based on SpO2 error */
        }

        action def EvaluateSafety {
            in data : SensorData;
            out emergencyStop : Boolean;
            /* Triggers shutdown if skin temp or pressure exceeds limits */
        }

        action process : ProcessSensorData {
            in data = sensorFeedback.data;
            out command = flowCommand.command;
        }

        action safetyCheck : EvaluateSafety {
            in data = sensorFeedback.data;
            out emergencyStop = flowCommand.command.emergencyShutdown;
        }
    }

    part def PowerSupplyModule {
        port out powerOut : PowerPort;

        attribute batteryCapacity : EnergyValue = 432000.0; // ~120 Wh
        attribute currentCharge : EnergyValue;
        attribute outputVoltage : VoltageValue = 12.0;
        attribute maxRuntimeHours : Real = 8.0;
        attribute charging : Boolean = false;

        satisfy BatteryLifeRequirement by maxRuntimeHours;

        action def SupplyPower {
            out power : PowerSignal;
            /* Provides regulated DC power to all subsystems */
        }

        action supply : SupplyPower {
            out power = powerOut.power;
        }
    }

    // ===== System-Level Part =====
    part def TransdermalOxygenTherapySystem {
        port in airIntake : AirIntakePort;
        port out patientSensorData : SensorDataPort;

        // Sub-components
        part concentrator : OxygenConcentrator {
            port in airIntake : AirIntakePort;
            port out oxygenOut : OxygenFlowPort;
            port in powerIn : PowerInPort;
        }
        part reservoir : ReservoirTank {
            port in oxygenIn : OxygenInPort;
            port out oxygenOut : OxygenFlowPort;
            port in powerIn : PowerInPort;
        }
        part regulator : PressureRegulatorValve {
            port in oxygenIn : OxygenInPort;
            port out oxygenOut : OxygenFlowPort;
            port in powerIn : PowerInPort;
        }
        part flowControl : FlowControlModule {
            port in oxygenIn : OxygenInPort;
            port out oxygenOut : OxygenFlowPort;
            port in commandIn : ControlCommandPort;
            port in powerIn : PowerInPort;
        }
        part patch : TransdermalDeliveryPatch {
            port in oxygenIn : OxygenInPort;
            port out sensorOut : SensorDataPort;
        }
        part sensorArray : PhysiologicalSensorArray {
            port out sensorOut : SensorDataPort;
            port in powerIn : PowerInPort;
        }
        part controlUnit : TherapyControlUnit {
            port in sensorFeedback : FeedbackPort;
            port out flowCommand : ControlCommandPort;
            port out regulatorCommand : ControlCommandPort;
            port in powerIn : PowerInPort;
        }
        part powerSupply : PowerSupplyModule {
            port out powerOut : PowerPort;
        }

        // Connections - Oxygen path
        connection concentratorToReservoir connect concentrator.oxygenOut to reservoir.oxygenIn;
        connection reservoirToRegulator connect reservoir.oxygenOut to regulator.oxygenIn;
        connection regulatorToFlowControl connect regulator.oxygenOut to flowControl.oxygenIn;
        connection flowControlToPatch connect flowControl.oxygenOut to patch.oxygenIn;

        // Connections - Sensor data path
        connection patchToControl connect patch.sensorOut to controlUnit.sensorFeedback;
        connection sensorArrayToControl connect sensorArray.sensorOut to controlUnit.sensorFeedback;
        connection sensorArrayToExternal connect sensorArray.sensorOut to patientSensorData;

        // Connections - Control commands
        connection controlToFlow connect controlUnit.flowCommand to flowControl.commandIn;
        connection controlToRegulator connect controlUnit.regulatorCommand to regulator.oxygenIn;

        // Connections - Power distribution
        connection powerToConcentrator connect powerSupply.powerOut to concentrator.powerIn;
        connection powerToReservoir connect powerSupply.powerOut to reservoir.powerIn;
        connection powerToRegulator connect powerSupply.powerOut to regulator.powerIn;
        connection powerToFlowControl connect powerSupply.powerOut to flowControl.powerIn;
        connection powerToSensorArray connect powerSupply.powerOut to sensorArray.powerIn;
        connection powerToControlUnit connect powerSupply.powerOut to controlUnit.powerIn;

        // External air intake
        connection externalAir connect airIntake to concentrator.airIntake;

        // ===== System State Machine =====
        attribute systemState : String;
        attribute faultCode : Integer;
        attribute emergencyShutdownActive : Boolean = false;

        state def SystemStates {
            entry; then Standby;

            state Standby {
                entry action { systemState = "standby"; }
                do action { /* Monitor battery, verify component integrity */ }
                transition to ActiveTherapy when powerSupply.currentCharge > 0.0;
            }

            state ActiveTherapy {
                entry action { systemState = "active"; }
                do action {
                    /* Concentrator produces oxygen, reservoir stores,
                       regulator controls pressure, flow control delivers,
                       sensors monitor, control unit adjusts */
                }
                transition to Paused when controlUnit.flowCommand.command.targetFlowRate == 0.0;
                transition to Fault when emergencyShutdownActive == true;
            }

            state Paused {
                entry action { systemState = "paused"; }
                do action { /* Maintain reservoir pressure, continue monitoring sensors */ }
                transition to ActiveTherapy when controlUnit.flowCommand.command.targetFlowRate > 0.0;
                transition to Fault when emergencyShutdownActive == true;
                transition to Standby when powerSupply.currentCharge <= 0.0;
            }

            state Fault {
                entry action {
                    systemState = "fault";
                    emergencyShutdownActive = true;
                }
                do action { /* Isolate oxygen flow, alert user, log fault code */ }
                transition to Standby when faultCode == 0 and powerSupply.currentCharge > 0.0;
            }
        }

        state machine : SystemStates;

        // ===== System-level Requirements =====
        satisfy SpO2TherapeuticRangeRequirement by sensorArray.measuredSpO2;
        satisfy SkinTemperatureSafetyRequirement by sensorArray.measuredSkinTemp;
        satisfy DeliveryPressureSafetyRequirement by regulator.outputPressure;
    }

    // ===== Top-level instantiation =====
    part therapySystem : TransdermalOxygenTherapySystem {
        // Realized as a complete portable device
    }
}
