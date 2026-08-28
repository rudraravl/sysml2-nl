package ArtificialHeartSystem {
    import ScalarValues::*;
    import QuantityDimensions::*;
    import SI::*;

    // ─────────────── Value Types ───────────────
    value def PressureValue :> Real { unit = 'Pa'; }
    value def FlowRateValue :> Real { unit = 'm3/s'; }
    value def VolumeValue :> Real { unit = 'm3'; }
    value def FrequencyValue :> Real { unit = '1/s'; }
    value def VoltageValue :> Real { unit = 'V'; }
    value def CurrentValue :> Real { unit = 'A'; }
    value def EnergyValue :> Real { unit = 'J'; }
    value def TemperatureValue :> Real { unit = 'K'; }
    value def PercentValue :> Real { unit = '%'; }
    value def AngularVelocityValue :> Real { unit = 'rad/s'; }
    value def TorqueValue :> Real { unit = 'N*m'; }

    // ─────────────── Item Types ───────────────
    item def DeoxygenatedBlood {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute oxygenSaturation : PercentValue;
    }

    item def OxygenatedBlood {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute oxygenSaturation : PercentValue;
    }

    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    item def ControlSignal {
        attribute targetSpeed : AngularVelocityValue;
        attribute targetTorque : TorqueValue;
    }

    item def SensorData {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute batteryLevel : PercentValue;
        attribute temperature : TemperatureValue;
    }

    item def AlertMessage {
        attribute severity : String;
        attribute description : String;
    }

    // ─────────────── Enumerations ───────────────
    enum def ValveState { open; closed; }
    enum def OperationalMode { normal; warning; critical; }
    enum def CardiacPhase { diastole; systole; }

    // ─────────────── Port Definitions ───────────────
    port def BloodInPort {
        out item deoxygenatedBlood : DeoxygenatedBlood;
        out item oxygenatedBlood : OxygenatedBlood;
    }

    port def BloodOutPort {
        in item deoxygenatedBlood : DeoxygenatedBlood;
        in item oxygenatedBlood : OxygenatedBlood;
    }

    port def ElectricalPowerPort {
        in item power : ElectricalPower;
    }

    port def ControlSignalPort {
        in item signal : ControlSignal;
    }

    port def SensorDataPort {
        out item data : SensorData;
    }

    port def AlertPort {
        out item alert : AlertMessage;
    }

    // ─────────────── Valve Part ───────────────
    part def MechanicalValve {
        attribute name : String;
        attribute valveState : ValveState = ValveState::closed;
        in item bloodIn;
        out item bloodOut;
        action openValve { then closeValve; }
        action closeValve { then openValve; }
        behavior valveStateMachine {
            state Closed {
                entry { valveState = ValveState::closed; }
                transition Closed -> Open when bloodIn.flowRate > 0.0;
            }
            state Open {
                entry { valveState = ValveState::open; }
                transition Open -> Closed when bloodIn.flowRate <= 0.0;
            }
        }
    }

    // ─────────────── Pump Chamber ───────────────
    part def PumpChamber {
        attribute name : String;
        attribute chamberVolume : VolumeValue;
        attribute strokeVolume : VolumeValue;
        attribute currentPhase : CardiacPhase = CardiacPhase::diastole;
        port bloodIn : BloodInPort;
        port bloodOut : BloodOutPort;
        port mechanicalDrive;
        in item inflowBlood;
        out item outflowBlood;
        action fill {
            // Diastole: chamber fills with blood
            currentPhase = CardiacPhase::diastole;
        }
        action eject {
            // Systole: chamber ejects blood
            currentPhase = CardiacPhase::systole;
        }
        behavior cardiacCycle {
            state Diastole {
                entry { currentPhase = CardiacPhase::diastole; }
                do fill;
                transition Diastole -> Systole when chamberVolume >= strokeVolume;
            }
            state Systole {
                entry { currentPhase = CardiacPhase::systole; }
                do eject;
                transition Systole -> Diastole when chamberVolume <= 0.0;
            }
        }
    }

    // ─────────────── Electric Motor ───────────────
    part def ElectricMotor {
        attribute ratedSpeed : AngularVelocityValue;
        attribute ratedTorque : TorqueValue;
        attribute currentSpeed : AngularVelocityValue;
        attribute currentTorque : TorqueValue;
        port powerIn : ElectricalPowerPort;
        port controlIn : ControlSignalPort;
        port mechanicalOut;
        in item controlSignal : ControlSignal;
        in item power : ElectricalPower;
        out item mechanicalDrive;
        action receiveControl {
            currentSpeed = controlSignal.targetSpeed;
            currentTorque = controlSignal.targetTorque;
        }
        action generateForce {
            // Convert electrical energy to mechanical force
        }
        behavior motorOperation {
            state Idle {
                transition Idle -> Running when power.voltage > 0.0;
            }
            state Running {
                do generateForce;
                transition Running -> Idle when power.voltage <= 0.0;
            }
        }
    }

    // ─────────────── Rechargeable Battery ───────────────
    part def RechargeableBattery {
        attribute capacity : EnergyValue;
        attribute currentCharge : EnergyValue;
        attribute chargeLevel : PercentValue;
        attribute nominalVoltage : VoltageValue;
        port powerOut : ElectricalPowerPort;
        out item power : ElectricalPower;
        action discharge {
            // Provide power to system
        }
        action recharge {
            // Accept external charging
        }
        behavior batteryManagement {
            state Full {
                transition Full -> Normal when chargeLevel < 80.0;
            }
            state Normal {
                do discharge;
                transition Normal -> Low when chargeLevel < 30.0;
                transition Normal -> Full when chargeLevel >= 80.0;
            }
            state Low {
                do discharge;
                transition Low -> Depleted when chargeLevel < 10.0;
                transition Low -> Normal when chargeLevel >= 30.0;
            }
            state Depleted {
                // Battery exhausted, system must switch to critical
            }
        }
    }

    // ─────────────── Sensors ───────────────
    part def PressureSensor {
        attribute measuredPressure : PressureValue;
        port sensorOut : SensorDataPort;
        out item sensorData : SensorData;
        action measurePressure {
            sensorData.pressure = measuredPressure;
        }
    }

    part def FlowSensor {
        attribute measuredFlowRate : FlowRateValue;
        port sensorOut : SensorDataPort;
        out item sensorData : SensorData;
        action measureFlow {
            sensorData.flowRate = measuredFlowRate;
        }
    }

    part def BatteryMonitor {
        attribute measuredLevel : PercentValue;
        port sensorOut : SensorDataPort;
        out item sensorData : SensorData;
        action measureBattery {
            sensorData.batteryLevel = measuredLevel;
        }
    }

    part def TemperatureSensor {
        attribute measuredTemperature : TemperatureValue;
        port sensorOut : SensorDataPort;
        out item sensorData : SensorData;
        action measureTemperature {
            sensorData.temperature = measuredTemperature;
        }
    }

    // ─────────────── Electronic Controller ───────────────
    part def ElectronicController {
        attribute targetHeartRate : FrequencyValue;
        attribute targetPressure : PressureValue;
        attribute currentMode : OperationalMode = OperationalMode::normal;
        port sensorIn : SensorDataPort;
        port controlOut : ControlSignalPort;
        port alertOut : AlertPort;
        in item sensorFeedback : SensorData;
        out item controlSignal : ControlSignal;
        out item alert : AlertMessage;
        action processSensorData {
            // Analyze incoming sensor data
        }
        action computeControl {
            // Adjust motor speed and torque based on targets and feedback
            controlSignal.targetSpeed = targetHeartRate * 2.0 * 3.14159;
            controlSignal.targetTorque = targetPressure * 0.001;
        }
        action generateAlert {
            alert.severity = currentMode == OperationalMode::critical ? "critical" : 
                             currentMode == OperationalMode::warning ? "warning" : "normal";
        }
        behavior operationalStateMachine {
            state Normal {
                entry { currentMode = OperationalMode::normal; }
                do computeControl;
                transition Normal -> Warning when sensorFeedback.batteryLevel < 30.0 
                    or sensorFeedback.pressure > targetPressure * 1.5
                    or sensorFeedback.temperature > 310.15;
            }
            state Warning {
                entry { currentMode = OperationalMode::warning; }
                do generateAlert;
                transition Warning -> Critical when sensorFeedback.batteryLevel < 10.0
                    or sensorFeedback.pressure > targetPressure * 2.0;
                transition Warning -> Normal when sensorFeedback.batteryLevel >= 30.0
                    and sensorFeedback.pressure <= targetPressure * 1.5
                    and sensorFeedback.temperature <= 310.15;
            }
            state Critical {
                entry { currentMode = OperationalMode::critical; }
                do generateAlert;
                // Emergency mode: reduce output, alert patient and medical personnel
            }
        }
    }

    // ─────────────── Total Artificial Heart ───────────────
    part def TotalArtificialHeart {
        attribute systemName : String = "TAH-1";
        attribute designHeartRate : FrequencyValue = 1.2; // ~72 bpm
        attribute designCardiacOutput : FlowRateValue = 8.33e-5; // ~5 L/min

        // Central pump chambers
        part rightVentricle : PumpChamber {
            attribute name = "Right Ventricle";
            attribute chamberVolume : VolumeValue = 7.0e-5;
            attribute strokeVolume : VolumeValue = 7.0e-5;
        }
        part leftVentricle : PumpChamber {
            attribute name = "Left Ventricle";
            attribute chamberVolume : VolumeValue = 7.0e-5;
            attribute strokeVolume : VolumeValue = 7.0e-5;
        }

        // Four mechanical valves
        part mitralValve : MechanicalValve {
            attribute name = "Mitral Valve";
        }
        part aorticValve : MechanicalValve {
            attribute name = "Aortic Valve";
        }
        part tricuspidValve : MechanicalValve {
            attribute name = "Tricuspid Valve";
        }
        part pulmonaryValve : MechanicalValve {
            attribute name = "Pulmonary Valve";
        }

        // Electric motor
        part motor : ElectricMotor {
            attribute ratedSpeed : AngularVelocityValue = 7.54; // ~72 rpm
            attribute ratedTorque : TorqueValue = 0.5;
        }

        // Rechargeable battery
        part battery : RechargeableBattery {
            attribute capacity : EnergyValue = 1.296e5; // ~36 Wh
            attribute currentCharge : EnergyValue = 1.296e5;
            attribute chargeLevel : PercentValue = 100.0;
            attribute nominalVoltage : VoltageValue = 12.0;
        }

        // Electronic controller
        part controller : ElectronicController {
            attribute targetHeartRate : FrequencyValue = 1.2;
            attribute targetPressure : PressureValue = 16000.0; // ~120 mmHg
        }

        // Sensor suite
        part systemicPressureSensor : PressureSensor;
        part pulmonaryPressureSensor : PressureSensor;
        part systemicFlowSensor : FlowSensor;
        part pulmonaryFlowSensor : FlowSensor;
        part batteryMonitor : BatteryMonitor;
        part temperatureSensor : TemperatureSensor;

        // External ports
        port bodyReturn : BloodInPort;   // Deoxygenated blood from body
        port bodyDelivery : BloodOutPort; // Oxygenated blood to body
        port lungDelivery : BloodOutPort; // Deoxygenated blood to lungs
        port lungReturn : BloodInPort;   // Oxygenated blood from lungs
        port externalAlert : AlertPort;
        port externalCharge : ElectricalPowerPort;

        // Connections: blood flow path
        // Body -> Right Atrium -> Tricuspid Valve -> Right Ventricle -> Pulmonary Valve -> Lungs
        connection bodyToTricuspid : FlowConnection connect bodyReturn.deoxygenatedBlood to tricuspidValve.bloodIn;
        connection tricuspidToRV : FlowConnection connect tricuspidValve.bloodOut to rightVentricle.inflowBlood;
        connection rvToPulmonary : FlowConnection connect rightVentricle.outflowBlood to pulmonaryValve.bloodIn;
        connection pulmonaryToLungs : FlowConnection connect pulmonaryValve.bloodOut to lungDelivery.deoxygenatedBlood;

        // Lungs -> Left Atrium -> Mitral Valve -> Left Ventricle -> Aortic Valve -> Body
        connection lungsToMitral : FlowConnection connect lungReturn.oxygenatedBlood to mitralValve.bloodIn;
        connection mitralToLV : FlowConnection connect mitralValve.bloodOut to leftVentricle.inflowBlood;
        connection lvToAortic : FlowConnection connect leftVentricle.outflowBlood to aorticValve.bloodIn;
        connection aorticToBody : FlowConnection connect aorticValve.bloodOut to bodyDelivery.oxygenatedBlood;

        // Electrical power connections
        connection batteryToMotor : PowerConnection connect battery.powerOut to motor.powerIn;
        connection batteryToController : PowerConnection connect battery.powerOut to controller.powerIn;

        // Control signal connections
        connection controllerToMotor : ControlConnection connect controller.controlOut to motor.controlIn;

        // Sensor data connections
        connection systemicPressureToController : DataConnection connect systemicPressureSensor.sensorOut to controller.sensorIn;
        connection pulmonaryPressureToController : DataConnection connect pulmonaryPressureSensor.sensorOut to controller.sensorIn;
        connection systemicFlowToController : DataConnection connect systemicFlowSensor.sensorOut to controller.sensorIn;
        connection pulmonaryFlowToController : DataConnection connect pulmonaryFlowSensor.sensorOut to controller.sensorIn;
        connection batteryMonitorToController : DataConnection connect batteryMonitor.sensorOut to controller.sensorIn;
        connection temperatureToController : DataConnection connect temperatureSensor.sensorOut to controller.sensorIn;

        // Alert connection
        connection controllerAlert : AlertConnection connect controller.alertOut to externalAlert;

        // Mechanical drive
        connection motorToRV : MechanicalConnection connect motor.mechanicalOut to rightVentricle.mechanicalDrive;
        connection motorToLV : MechanicalConnection connect motor.mechanicalOut to leftVentricle.mechanicalDrive;

        // External charging
        connection chargeToBattery : PowerConnection connect externalCharge to battery.powerOut;

        // System-level cardiac cycle behavior
        behavior systemCardiacCycle {
            state Diastole {
                // Filling phase: tricuspid and mitral valves open, pulmonary and aortic close
                entry {
                    tricuspidValve.valveState = ValveState::open;
                    mitralValve.valveState = ValveState::open;
                    pulmonaryValve.valveState = ValveState::closed;
                    aorticValve.valveState = ValveState::closed;
                }
                transition Diastole -> Systole when rightVentricle.chamberVolume >= rightVentricle.strokeVolume
                    and leftVentricle.chamberVolume >= leftVentricle.strokeVolume;
            }
            state Systole {
                // Ejection phase: pulmonary and aortic valves open, tricuspid and mitral close
                entry {
                    tricuspidValve.valveState = ValveState::closed;
                    mitralValve.valveState = ValveState::closed;
                    pulmonaryValve.valveState = ValveState::open;
                    aorticValve.valveState = ValveState::open;
                }
                transition Systole -> Diastole when rightVentricle.chamberVolume <= 0.0
                    and leftVentricle.chamberVolume <= 0.0;
            }
        }
    }

    // ─────────────── Connection Definitions ───────────────
    connection def FlowConnection {
        end source;
        end target;
    }
    connection def PowerConnection {
        end source;
        end target;
    }
    connection def ControlConnection {
        end source;
        end target;
    }
    connection def DataConnection {
        end source;
        end target;
    }
    connection def AlertConnection {
        end source;
        end target;
    }
    connection def MechanicalConnection {
        end source;
        end target;
    }

    // ─────────────── Requirements ───────────────
    requirement def CirculationRequirement {
        doc /* The system must maintain continuous blood circulation. */
        attribute minCardiacOutput : FlowRateValue = 5.0e-5; // ~3 L/min minimum
        attribute targetCardiacOutput : FlowRateValue = 8.33e-5; // ~5 L/min
        satisfy by TotalArtificialHeart;
    }

    requirement def ValveSequenceRequirement {
        doc /* Valves must open and close in correct sequence to prevent backflow. */
        attribute maxBackflow : FlowRateValue = 1.0e-7;
        satisfy by TotalArtificialHeart;
    }

    requirement def BatteryLifeRequirement {
        doc /* Internal battery must provide several hours of continuous operation. */
        attribute minOperationHours : Real = 4.0;
        satisfy by TotalArtificialHeart.battery;
    }

    requirement def PressureRegulationRequirement {
        doc /* Controller must regulate blood pressure within physiological range. */
        attribute minSystemicPressure : PressureValue = 12000.0; // ~90 mmHg
        attribute maxSystemicPressure : PressureValue = 18000.0; // ~135 mmHg
        satisfy by TotalArtificialHeart.controller;
    }

    requirement def OperationalModeRequirement {
        doc /* System must support normal, warning, and critical operational modes. */
        satisfy by TotalArtificialHeart.controller;
    }

    requirement def HeartRateRequirement {
        doc /* System must simulate natural heartbeat rate. */
        attribute minRate : FrequencyValue = 1.0;  // ~60 bpm
        attribute maxRate : FrequencyValue = 1.67; // ~100 bpm
        satisfy by TotalArtificialHeart;
    }

    requirement def SelfMonitoringRequirement {
        doc /* System must monitor its own health including battery and performance. */
        satisfy by TotalArtificialHeart;
    }

    requirement def AdaptiveResponseRequirement {
        doc /* Controller must adjust motor speed and force based on physiological needs. */
        satisfy by TotalArtificialHeart.controller;
    }

    // ─────────────── Requirement Group ───────────────
    requirement group ArtificialHeartRequirements {
        requirement circulation : CirculationRequirement;
        requirement valveSequence : ValveSequenceRequirement;
        requirement batteryLife : BatteryLifeRequirement;
        requirement pressureRegulation : PressureRegulationRequirement;
        requirement operationalModes : OperationalModeRequirement;
        requirement heartRate : HeartRateRequirement;
        requirement selfMonitoring : SelfMonitoringRequirement;
        requirement adaptiveResponse : AdaptiveResponseRequirement;
    }
}
