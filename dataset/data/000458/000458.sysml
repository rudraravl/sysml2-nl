package HypothermiaCapSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def TemperatureSetpoint :> TemperatureValue;
    attribute def FlowRateValue :> VolumeFlowRateValue;
    attribute def PressureValue :> ISQ::PressureValue;
    attribute def DurationValue :> TimeValue;
    attribute def PowerValue :> ISQ::PowerValue;

    item def Coolant {
        attribute temperature : TemperatureValue;
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
    }

    port def CoolantPort {
        in item coolantIn : Coolant;
        out item coolantOut : Coolant;
    }

    port def TemperatureMonitorPort {
        out attribute reading : TemperatureValue;
    }

    port def ControlSignalPort {
        in attribute command : ControlCommand;
        out attribute status : SystemStatus;
    }

    enum def SystemStatus {
        idle;
        cooling;
        maintaining;
        alarm;
    }

    enum def ControlCommand {
        start;
        stop;
        emergency_stop;
    }

    attribute def StartTreatmentSignal;
    attribute def StopTreatmentSignal;
    attribute def AlarmSignal;

    part def TherapeuticCap {
        port coolantInlet : CoolantPort;
        port coolantOutlet : CoolantPort;
        attribute surfaceArea : AreaValue;
        attribute thermalConductivity : Real;
    }

    part def TemperatureSensor {
        port monitorPort : TemperatureMonitorPort;
        attribute accuracy : TemperatureValue;
        attribute responseTime : DurationValue;
    }

    part def CoolingUnit {
        port coolantIn : CoolantPort;
        port coolantOut : CoolantPort;
        attribute coolingCapacity : PowerValue;
        attribute targetTemperature : TemperatureSetpoint;
    }

    part def CirculationPump {
        port inlet : CoolantPort;
        port outlet : CoolantPort;
        attribute maxFlowRate : FlowRateValue;
        attribute operatingPressure : PressureValue;
    }

    part def ControlModule {
        port sensorInput : TemperatureMonitorPort;
        port controlInterface : ControlSignalPort;
        attribute setpoint : TemperatureSetpoint;
        attribute toleranceBand : TemperatureValue;
        attribute currentStatus : SystemStatus;
        attribute targetReached : Boolean;
    }

    action def MonitorScalpTemperature {
        in currentTemp : TemperatureValue;
        in targetTemp : TemperatureSetpoint;
        out temperatureError : TemperatureValue;
        out withinTolerance : Boolean;
    }

    action def AdjustCoolingPower {
        in temperatureError : TemperatureValue;
        in currentPower : PowerValue;
        out newPower : PowerValue;
    }

    action def CirculateCoolant {
        in flowRate : FlowRateValue;
        in temperature : TemperatureValue;
        out cooledCoolant : Coolant;
    }

    action def ProvideTherapeuticCooling {
        in targetTemperature : TemperatureSetpoint;
        in treatmentDuration : DurationValue;
        out scalpTemperature : TemperatureValue;

        first start;
        then merge controlLoop;

        then action monitor : MonitorScalpTemperature {
            in currentTemp;
            in targetTemp = targetTemperature;
            out temperatureError;
            out withinTolerance;
        }

        then decide;
            if not monitor.withinTolerance then adjustCooling;
            if monitor.withinTolerance then maintainCooling;

        action adjustCooling : AdjustCoolingPower {
            in temperatureError = monitor.temperatureError;
            in currentPower;
            out newPower;
        }
        then controlLoop;

        action maintainCooling : CirculateCoolant {
            in flowRate;
            in temperature;
            out cooledCoolant;
        }
        then controlLoop;
    }

    state def TherapeuticCoolingStateMachine {
        in attribute statusRef : SystemStatus;
        in attribute targetReachedRef : Boolean;

        entry; then idle;

        state idle {
            entry assign statusRef := SystemStatus::idle;
        }
        transition idle_to_cooling
            first idle
            accept startSignal : StartTreatmentSignal
            then cooling;

        state cooling {
            entry assign statusRef := SystemStatus::cooling;
            do action initiateScalpCooling : AdjustCoolingPower;
        }
        transition cooling_to_maintaining
            first cooling
            if targetReachedRef
            then maintaining;

        state maintaining {
            entry assign statusRef := SystemStatus::maintaining;
            do action maintainTherapeuticTemperature : ProvideTherapeuticCooling;
        }
        transition maintaining_to_idle
            first maintaining
            accept stopSignal : StopTreatmentSignal
            then idle;

        state alarm {
            entry assign statusRef := SystemStatus::alarm;
        }
        transition any_to_alarm
            accept alarmSignal : AlarmSignal
            then alarm;
    }

    part def HypothermiaCapSystem {
        attribute therapeuticSetpoint : TemperatureSetpoint;
        attribute sessionDuration : DurationValue;

        part cap : TherapeuticCap {
            port coolantInlet;
            port coolantOutlet;
        }

        part sensor : TemperatureSensor {
            port monitorPort;
        }

        part cooler : CoolingUnit {
            port coolantIn;
            port coolantOut;
        }

        part pump : CirculationPump {
            port inlet;
            port outlet;
        }

        part controller : ControlModule {
            port sensorInput;
            port controlInterface;

            perform action therapeuticCooling : ProvideTherapeuticCooling {
                in targetTemperature = therapeuticSetpoint;
                in treatmentDuration = sessionDuration;
                out scalpTemperature;
            }

            exhibit state coolingControl : TherapeuticCoolingStateMachine {
                in statusRef = controller.currentStatus;
                in targetReachedRef = controller.targetReached;
            }
        }

        connection coolantSupply connect pump.outlet to cooler.coolantIn;
        connection cooledSupply connect cooler.coolantOut to cap.coolantInlet;
        connection coolantReturn connect cap.coolantOutlet to pump.inlet;
        connection temperatureFeedback connect sensor.monitorPort to controller.sensorInput;
    }

    requirement def TherapeuticCoolingRequirement {
        doc /* The hypothermia cap system shall provide controlled scalp cooling 
               to reduce chemotherapy-induced alopecia by maintaining scalp temperature 
               within a therapeutic range during treatment. */

        subject system : HypothermiaCapSystem;

        require temperatureControlRequirement;
        require safetyRequirement;
        require comfortRequirement;
    }

    requirement <'REQ-001'> temperatureControlRequirement {
        doc /* The system shall reduce scalp temperature to between 18 degC and 22 degC 
               and maintain it within plus or minus 1 degC of the setpoint during treatment. */

        subject system : HypothermiaCapSystem;

        require constraint {
            system.sensor.monitorPort.reading >= 18.0 [Celsius] and
            system.sensor.monitorPort.reading <= 22.0 [Celsius]
        }
    }

    requirement <'REQ-002'> safetyRequirement {
        doc /* The system shall prevent scalp temperature from dropping below 15 degC 
               to avoid tissue damage and shall trigger an alarm if exceeded. */

        subject system : HypothermiaCapSystem;

        require constraint {
            system.sensor.monitorPort.reading >= 15.0 [Celsius]
        }
    }

    requirement <'REQ-003'> comfortRequirement {
        doc /* The system shall maintain coolant pressure below 50 kPa and flow rate 
               within comfortable limits to ensure patient tolerance. */

        subject system : HypothermiaCapSystem;

        require constraint {
            system.cap.coolantInlet.coolantIn.pressure <= 50.0 [SI::kPa]
        }
    }

    requirement <'REQ-004'> treatmentDurationRequirement {
        doc /* The system shall operate continuously for the duration of chemotherapy 
               infusion plus a minimum of 90 minutes post-infusion. */

        subject system : HypothermiaCapSystem;
    }

    part hypothermiaCapSystem : HypothermiaCapSystem {
        satisfy therapeuticCoolingReq : TherapeuticCoolingRequirement {
            subject system = hypothermiaCapSystem;
        }
        satisfy tempControlReq : temperatureControlRequirement {
            subject system = hypothermiaCapSystem;
        }
        satisfy safetyReq : safetyRequirement {
            subject system = hypothermiaCapSystem;
        }
        satisfy comfortReq : comfortRequirement {
            subject system = hypothermiaCapSystem;
        }
        satisfy durationReq : treatmentDurationRequirement {
            subject system = hypothermiaCapSystem;
        }
    }
}
