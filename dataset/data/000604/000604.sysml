package ECMOSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;

    attribute def BloodFlowRate :> VolumeFlowValue;

    attribute def OxygenSaturation :> Real;

    attribute def PressureValue :> PressureValue;

    attribute def TemperatureValue :> TemperatureValue;

    attribute def RotationalSpeed :> Real;

    enum def ECMOMode {
        venoarterial;
        venovenous;
    }

    enum def SystemState {
        off;
        priming;
        standby;
        active;
        alarm;
    }

    item def Blood {
        attribute oxygenSaturation : OxygenSaturation;
        attribute flowRate : BloodFlowRate;
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
    }

    item def Oxygen {
        attribute flowRate : BloodFlowRate;
        attribute concentration : Real;
    }

    port def BloodPort {
        in item bloodIn : Blood;
        out item bloodOut : Blood;
    }

    port def OxygenPort {
        in item oxygenSupply : Oxygen;
        out item oxygenExhaust : Oxygen;
    }

    port def SensorPort {
        out attribute measuredValue : Real;
    }

    port def ControlPort {
        in attribute commandSignal : Real;
        out attribute statusSignal : Real;
    }

    part def VenousCannula {
        attribute diameter : Real;
        attribute length : Real;
        port bloodInterface : BloodPort;
    }

    part def ArterialCannula {
        attribute diameter : Real;
        attribute length : Real;
        port bloodInterface : BloodPort;
    }

    part def CentrifugalPump {
        attribute maxFlowRate : BloodFlowRate;
        attribute currentFlowRate : BloodFlowRate;
        attribute rotationSpeed : RotationalSpeed;
        port inlet : BloodPort;
        port outlet : BloodPort;
        port control : ControlPort;

        action pumpBlood {
            in targetFlow : BloodFlowRate;
            in bloodInput : Blood;
            out bloodOutput : Blood;
            out actualFlow : BloodFlowRate;
        }
    }

    part def MembraneOxygenator {
        attribute membraneArea : Real;
        attribute gasExchangeEfficiency : Real;
        port bloodInlet : BloodPort;
        port bloodOutlet : BloodPort;
        port oxygenInlet : OxygenPort;

        action oxygenateBlood {
            in deoxygenatedBlood : Blood;
            in oxygenSupply : Oxygen;
            out oxygenatedBlood : Blood;
        }
    }

    part def HeatExchanger {
        attribute targetTemperature : TemperatureValue;
        attribute currentTemperature : TemperatureValue;
        port bloodInlet : BloodPort;
        port bloodOutlet : BloodPort;

        action regulateTemperature {
            in bloodInput : Blood;
            in targetTemp : TemperatureValue;
            out bloodOutput : Blood;
        }
    }

    part def FlowSensor {
        attribute measuredFlow : BloodFlowRate;
        port sensing : BloodPort;
        port data : SensorPort;
    }

    part def OxygenSensor {
        attribute measuredSaturation : OxygenSaturation;
        port sensing : BloodPort;
        port data : SensorPort;
    }

    part def PressureSensor {
        attribute measuredPressure : PressureValue;
        port sensing : BloodPort;
        port data : SensorPort;
    }

    part def TemperatureSensor {
        attribute measuredTemperature : TemperatureValue;
        port sensing : BloodPort;
        port data : SensorPort;
    }

    part def ControlUnit {
        attribute operatingMode : ECMOMode;
        attribute currentState : SystemState;
        attribute targetSaturation : OxygenSaturation;
        attribute targetFlowRate : BloodFlowRate;
        port flowSensorInput : SensorPort;
        port oxygenSensorInput : SensorPort;
        port pressureSensorInput : SensorPort;
        port temperatureSensorInput : SensorPort;
        port pumpControl : ControlPort;
        port alarmOutput;

        action monitorAndControl {
            in flowData : BloodFlowRate;
            in saturationData : OxygenSaturation;
            in pressureData : PressureValue;
            in temperatureData : TemperatureValue;
            out pumpCommand : Real;
            out alarmStatus : Boolean;
        }

        state controlStateMachine {
            entry; then powerOff;

            state powerOff;
            
            state priming;
            
            state standby;
            
            state active {
                entry; then monitoring;
                
                state monitoring;
                state adjusting;

                transition monitoring_to_adjusting
                    first monitoring
                    accept at parametersOutOfRange
                    then adjusting;

                transition adjusting_to_monitoring
                    first adjusting
                    accept at parametersNormalized
                    then monitoring;
            }

            state alarm;

            transition powerOff_to_priming
                first powerOff
                accept at systemStart
                then priming;

            transition priming_to_standby
                first priming
                accept at primingComplete
                then standby;

            transition standby_to_active
                first standby
                accept at startTherapy
                then active;

            transition active_to_alarm
                first active
                accept at criticalCondition
                then alarm;

            transition alarm_to_active
                first alarm
                accept at conditionResolved
                then active;

            transition active_to_standby
                first active
                accept at stopTherapy
                then standby;

            transition standby_to_powerOff
                first standby
                accept at systemShutdown
                then powerOff;
        }
    }

    part def AlarmSystem {
        attribute alarmActive : Boolean;
        attribute alarmType : String;
        port alarmInput;

        action triggerAlarm {
            in condition : Boolean;
            in severity : String;
        }
    }

    part def ECMOCircuit {
        attribute mode : ECMOMode;
        attribute targetSaturation : OxygenSaturation;
        attribute targetFlowRate : BloodFlowRate;
        attribute targetTemperature : TemperatureValue;

        part venousCannula : VenousCannula {
            attribute :>> diameter = 21.0;
            attribute :>> length = 38.0;
        }

        part arterialCannula : ArterialCannula {
            attribute :>> diameter = 17.0;
            attribute :>> length = 38.0;
        }

        part pump : CentrifugalPump {
            attribute :>> maxFlowRate : BloodFlowRate = 7.0 [L/min];
        }

        part oxygenator : MembraneOxygenator {
            attribute :>> membraneArea = 1.8;
            attribute :>> gasExchangeEfficiency = 0.95;
        }

        part heatExchanger : HeatExchanger {
            attribute :>> targetTemperature : TemperatureValue = 37.0 [°C];
        }

        part flowSensor : FlowSensor;
        part oxygenSensor : OxygenSensor;
        part pressureSensor : PressureSensor;
        part temperatureSensor : TemperatureSensor;

        part controller : ControlUnit {
            attribute :>> operatingMode = ECMOMode::venovenous;
            attribute :>> targetSaturation = 92.0;
            attribute :>> targetFlowRate : BloodFlowRate = 4.5 [L/min];
        }

        part alarms : AlarmSystem;

        connection drainageFlow connect
            venousCannula.bloodInterface to pump.inlet;

        connection pumpToOxygenator connect
            pump.outlet to oxygenator.bloodInlet;

        connection oxygenatorToHeatExchanger connect
            oxygenator.bloodOutlet to heatExchanger.bloodInlet;

        connection heatExchangerToReturn connect
            heatExchanger.bloodOutlet to arterialCannula.bloodInterface;

        connection flowMonitoring connect
            flowSensor.data to controller.flowSensorInput;

        connection saturationMonitoring connect
            oxygenSensor.data to controller.oxygenSensorInput;

        connection pressureMonitoring connect
            pressureSensor.data to controller.pressureSensorInput;

        connection temperatureMonitoring connect
            temperatureSensor.data to controller.temperatureSensorInput;

        connection pumpControlConnection connect
            controller.pumpControl to pump.control;

        connection alarmConnection connect
            controller.alarmOutput to alarms.alarmInput;
    }

    action def InitializeCircuit {
        first start;
        then action primeCircuit {
            doc /* Fill circuit with priming solution to remove air */
        }
        then action checkConnections {
            doc /* Verify all connections are secure and leak-free */
        }
        then action calibrateSensors {
            doc /* Calibrate flow, pressure, oxygen, and temperature sensors */
        }
        then done;
    }

    action def ProvideCardiopulmonarySupport {
        first start;
        then merge continuousSupport;

        then action monitorPatient {
            out patientSaturation : OxygenSaturation;
            out bloodFlow : BloodFlowRate;
            out systemPressure : PressureValue;
            out bloodTemperature : TemperatureValue;
        }

        then decide;
            if monitorPatient.patientSaturation < 88.0 then increaseSupport;
            if monitorPatient.patientSaturation >= 88.0 and
               monitorPatient.patientSaturation <= 95.0 then maintainSupport;
            if monitorPatient.patientSaturation > 95.0 then decreaseSupport;

        action increaseSupport {
            doc /* Increase blood flow rate to improve oxygenation */
        }
        then continuousSupport;

        action maintainSupport {
            doc /* Continue current support level */
        }
        then continuousSupport;

        action decreaseSupport {
            doc /* Reduce blood flow rate gradually */
        }
        then continuousSupport;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The ECMO system shall provide temporary cardiac and/or respiratory support
             * by circulating blood outside the body, oxygenating it through a membrane
             * oxygenator, and returning it to the patient's circulation.
             */
        subject ecmo : ECMOCircuit;
    }

    requirement def OxygenationRequirement {
        doc /* The ECMO system shall maintain patient blood oxygen saturation
             * between 88% and 95% during active therapy.
             */
        subject ecmo : ECMOCircuit;
        require constraint {
            ecmo.oxygenSensor.measuredSaturation >= 88.0 and
            ecmo.oxygenSensor.measuredSaturation <= 95.0
        }
    }

    requirement def FlowRateRequirement {
        doc /* The blood pump shall provide adjustable flow rates
             * from 0.5 to 7.0 liters per minute.
             */
        subject pump : CentrifugalPump;
    }

    requirement def TemperatureRegulationRequirement {
        doc /* The heat exchanger shall maintain blood temperature
             * at 37°C ± 0.5°C during circulation.
             */
        subject heatEx : HeatExchanger;
    }

    requirement def SafetyRequirement {
        doc /* The system shall activate alarms when pressure exceeds
             * 400 mmHg or flow rate deviates more than 20% from target.
             */
        subject circuit : ECMOCircuit;
    }

    requirement <'ECMO-001'> primaryFunction {
        doc /* The ECMO system shall provide extracorporeal life support
             * by oxygenating and circulating blood to maintain systemic
             * oxygen delivery when the patient's heart and/or lungs cannot
             * adequately perform this function.
             */
        subject ecmoSystem : ECMOCircuit;

        require PrimaryFunctionRequirement;
        require OxygenationRequirement;
        require FlowRateRequirement;
        require TemperatureRegulationRequirement;
        require SafetyRequirement;
    }

    part ecmoSystemInstance : ECMOCircuit {
        attribute :>> mode = ECMOMode::venovenous;
        attribute :>> targetSaturation = 92.0;
        attribute :>> targetFlowRate : BloodFlowRate = 4.5 [L/min];
        attribute :>> targetTemperature : TemperatureValue = 37.0 [°C];

        perform action lifeSupportOperation : ProvideCardiopulmonarySupport;
    }

    satisfy primaryFunction by ecmoSystemInstance;
}
