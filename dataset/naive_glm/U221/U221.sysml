package ECMO_System {
    import ScalarValues::*;
    import ISQ::*;
    import ISQVolume::*;
    import ISQFlowRate::*;
    import ISQPressure::*;
    import ISQTemperature::*;
    import ISQFrequency::*;
    import ISQMass::*;

    // ---------- Value Types ----------
    value def BloodFlowRate :> VolumeFlowRate;
    value def PumpSpeed :> RotationalFrequency;
    value def BloodPressure :> Pressure;
    value def BloodTemperature :> Temperature;
    value def OxygenConcentration :> Real { unit 'percent'; }
    value def CarbonDioxideConcentration :> Real { unit 'percent'; }
    value def GasFlowRate :> VolumeFlowRate;

    // ---------- Items ----------
    item def Blood;
    item def DeoxygenatedBlood :> Blood;
    item def OxygenatedBlood :> Blood;
    item def OxygenGas;
    item def ExhaustGas;

    // ---------- Attributes ----------
    attribute def SafeLimits {
        attribute minFlow : BloodFlowRate = 1.0 [L/min];
        attribute maxFlow : BloodFlowRate = 6.0 [L/min];
        attribute minPressure : BloodPressure = 50 [mmHg];
        attribute maxPressure : BloodPressure = 350 [mmHg];
        attribute minTemperature : BloodTemperature = 35 ['°C'];
        attribute maxTemperature : BloodTemperature = 39 ['°C'];
        attribute minOxygen : OxygenConcentration = 95;
        attribute maxOxygen : OxygenConcentration = 100;
    }

    // ---------- Ports ----------
    port def BloodInPort {
        in item blood : Blood;
    }
    port def BloodOutPort {
        out item blood : Blood;
    }
    port def GasInPort {
        in item gas : OxygenGas;
    }
    port def GasOutPort {
        out item gas : ExhaustGas;
    }
    port def SignalPort {
        in attribute value : Real;
        out attribute command : Real;
    }
    port def AlarmPort {
        out attribute triggered : Boolean;
        out attribute message : String;
    }

    // ---------- Interfaces ----------
    interface def BloodFlow {
        end supplier : BloodOutPort;
        end consumer : BloodInPort;
    }
    interface def GasSupply {
        end supplier : GasInPort;
        end consumer : GasOutPort;
    }
    interface def SensorSignal {
        end sensor : SignalPort;
        end controller : SignalPort;
    }
    interface def AlarmSignal {
        end controller : AlarmPort;
        end alarm : AlarmPort;
    }

    // ---------- Requirements ----------
    requirement def ECMORequirement {
        doc "The ECMO system shall circulate, oxygenate, and thermoregulate a patient's blood outside the body."
    }

    requirement def CirculationRequirement :> ECMORequirement {
        doc "The system shall maintain blood flow between safe limits."
        attribute targetFlow : BloodFlowRate = 4.0 [L/min];
        constraint { targetFlow >= 1.0 [L/min] and targetFlow <= 6.0 [L/min] }
    }

    requirement def OxygenationRequirement :> ECMORequirement {
        doc "The system shall oxygenate blood to at least 95% oxygen saturation."
        attribute minSaturation : OxygenConcentration = 95;
    }

    requirement def ThermoregulationRequirement :> ECMORequirement {
        doc "The system shall warm blood to approximately 37°C before return."
        attribute targetTemp : BloodTemperature = 37 ['°C'];
    }

    requirement def SafetyRequirement :> ECMORequirement {
        doc "The system shall trigger an alarm when any parameter deviates from safe limits."
        attribute limits : SafeLimits;
    }

    // ---------- Components ----------
    part def VenousCannula {
        port bloodIn : BloodInPort;
        port bloodOut : BloodOutPort;
        attribute diameter : Length = 0.024 [m];
        attribute length : Length = 0.5 [m];
        flow through bloodIn to bloodOut;
    }

    part def CentrifugalPump {
        port bloodIn : BloodInPort;
        port bloodOut : BloodOutPort;
        port control : SignalPort;
        attribute speed : PumpSpeed = 3000 [rev/min];
        attribute maxSpeed : PumpSpeed = 4000 [rev/min];
        attribute flowRate : BloodFlowRate = 4.0 [L/min];

        action def PumpOperation {
            in speedCmd : PumpSpeed;
            out flow : BloodFlowRate;
        }

        action operate : PumpOperation {
            bind speedCmd = control.command;
            bind flow = flowRate;
        }
    }

    part def MembraneOxygenator {
        port bloodIn : BloodInPort;
        port bloodOut : BloodOutPort;
        port gasIn : GasInPort;
        port gasOut : GasOutPort;
        attribute membraneArea : Area = 1.8 [m^2];
        attribute oxygenTransferRate : MassFlowRate = 0.0002 [kg/s];
        attribute gasFlow : GasFlowRate = 10.0 [L/min];

        action def OxygenationProcess {
            in deoxyBlood : DeoxygenatedBlood;
            in oxygen : OxygenGas;
            out oxyBlood : OxygenatedBlood;
            out exhaust : ExhaustGas;
        }

        action oxygenate : OxygenationProcess {
            bind deoxyBlood = bloodIn.blood;
            bind oxygen = gasIn.gas;
            bind oxyBlood = bloodOut.blood;
            bind exhaust = gasOut.gas;
        }
    }

    part def HeatExchanger {
        port bloodIn : BloodInPort;
        port bloodOut : BloodOutPort;
        attribute targetTemp : BloodTemperature = 37 ['°C'];
        attribute heatingPower : Power = 200 [W];

        action def HeatExchangeProcess {
            in inBlood : Blood;
            out outBlood : Blood;
        }

        action regulate : HeatExchangeProcess {
            bind inBlood = bloodIn.blood;
            bind outBlood = bloodOut.blood;
        }
    }

    part def ArterialCannula {
        port bloodIn : BloodInPort;
        port bloodOut : BloodOutPort;
        attribute diameter : Length = 0.020 [m];
        attribute length : Length = 0.5 [m];
        flow through bloodIn to bloodOut;
    }

    part def FlowSensor {
        port bloodIn : BloodInPort;
        port bloodOut : BloodOutPort;
        port signal : SignalPort;
        attribute measuredFlow : BloodFlowRate;
        attribute accuracy : Real = 0.05;
    }

    part def OxygenSensor {
        port bloodIn : BloodInPort;
        port bloodOut : BloodOutPort;
        port signal : SignalPort;
        attribute measuredOxygen : OxygenConcentration;
        attribute accuracy : Real = 0.02;
    }

    part def PressureSensor {
        port bloodIn : BloodInPort;
        port bloodOut : BloodOutPort;
        port signal : SignalPort;
        attribute measuredPressure : BloodPressure;
        attribute accuracy : Real = 0.03;
    }

    part def TemperatureSensor {
        port bloodIn : BloodInPort;
        port bloodOut : BloodOutPort;
        port signal : SignalPort;
        attribute measuredTemp : BloodTemperature;
        attribute accuracy : Real = 0.1;
    }

    part def OxygenSupply {
        port gasOut : GasOutPort;
        attribute supplyPressure : Pressure = 50 [kPa];
        attribute flowRate : GasFlowRate = 10.0 [L/min];
        out item oxygen : OxygenGas;
    }

    part def AlarmSystem {
        port alarmIn : AlarmPort;
        port alarmOut : AlarmPort;
        attribute active : Boolean = false;
        attribute message : String;
        attribute audibleLevel : Real = 80 [dB];

        action def TriggerAlarm {
            in msg : String;
            out triggered : Boolean;
        }

        action trigger : TriggerAlarm {
            bind msg = alarmIn.message;
            bind triggered = active;
        }
    }

    part def ControlUnit {
        port flowSignal : SignalPort;
        port oxygenSignal : SignalPort;
        port pressureSignal : SignalPort;
        port tempSignal : SignalPort;
        port pumpControl : SignalPort;
        port alarmOut : AlarmPort;

        attribute targetFlow : BloodFlowRate = 4.0 [L/min];
        attribute targetOxygen : OxygenConcentration = 98;
        attribute targetTemp : BloodTemperature = 37 ['°C'];
        attribute limits : SafeLimits;
        attribute currentFlow : BloodFlowRate;
        attribute currentOxygen : OxygenConcentration;
        attribute currentPressure : BloodPressure;
        attribute currentTemp : BloodTemperature;
        attribute pumpCommand : PumpSpeed = 3000 [rev/min];

        action def MonitorAndAdjust {
            in flow : BloodFlowRate;
            in oxygen : OxygenConcentration;
            in pressure : BloodPressure;
            in temp : BloodTemperature;
            out speedCmd : PumpSpeed;
            out alarmTriggered : Boolean;
            out alarmMsg : String;
        }

        action control : MonitorAndAdjust {
            bind flow = flowSignal.value;
            bind oxygen = oxygenSignal.value;
            bind pressure = pressureSignal.value;
            bind temp = tempSignal.value;
            bind speedCmd = pumpControl.command;
            bind alarmTriggered = alarmOut.triggered;
            bind alarmMsg = alarmOut.message;
        }
    }

    // ---------- State Machine ----------
    state def ECMOStateMachine {
        state off {
            entry action { /* System powered off */ }
        }
        state priming {
            entry action { /* Remove air from circuit */ }
            do action { /* Circulate priming solution */ }
        }
        state standby {
            entry action { /* Ready for patient connection */ }
        }
        state active {
            entry action { /* Begin life-support therapy */ }
            do action { /* Continuously monitor and adjust */ }
        }

        transition off_to_priming first off then priming
            when true;
        transition priming_to_standby priming then standby
            when true;
        transition standby_to_active standby then active
            when true;
        transition active_to_standby active then standby
            when true;
        transition any_to_off standby then off
            when true;
    }

    // ---------- ECMO System Assembly ----------
    part def ECMOSystem {
        satisfy ECMORequirement;
        satisfy CirculationRequirement;
        satisfy OxygenationRequirement;
        satisfy ThermoregulationRequirement;
        satisfy SafetyRequirement;

        part venousCannula : VenousCannula;
        part centrifugalPump : CentrifugalPump;
        part membraneOxygenator : MembraneOxygenator;
        part heatExchanger : HeatExchanger;
        part arterialCannula : ArterialCannula;
        part oxygenSupply : OxygenSupply;
        part controlUnit : ControlUnit;
        part alarmSystem : AlarmSystem;

        part flowSensor : FlowSensor;
        part oxygenSensor : OxygenSensor;
        part pressureSensor : PressureSensor;
        part tempSensor : TemperatureSensor;

        // Blood circuit connections
        interface venousToPump : BloodFlow connect venousCannula.bloodOut to centrifugalPump.bloodIn;
        interface pumpToFlowSensor : BloodFlow connect centrifugalPump.bloodOut to flowSensor.bloodIn;
        interface flowSensorToOxygenator : BloodFlow connect flowSensor.bloodOut to membraneOxygenator.bloodIn;
        interface oxygenatorToOxygenSensor : BloodFlow connect membraneOxygenator.bloodOut to oxygenSensor.bloodIn;
        interface oxygenSensorToPressureSensor : BloodFlow connect oxygenSensor.bloodOut to pressureSensor.bloodIn;
        interface pressureSensorToHeatExchanger : BloodFlow connect pressureSensor.bloodOut to heatExchanger.bloodIn;
        interface heatExchangerToTempSensor : BloodFlow connect heatExchanger.bloodOut to tempSensor.bloodIn;
        interface tempSensorToArterial : BloodFlow connect tempSensor.bloodOut to arterialCannula.bloodIn;

        // Gas connections
        interface gasToOxygenator : GasSupply connect oxygenSupply.gasOut to membraneOxygenator.gasIn;

        // Sensor to control unit connections
        interface flowToControl : SensorSignal connect flowSensor.signal to controlUnit.flowSignal;
        interface oxygenToControl : SensorSignal connect oxygenSensor.signal to controlUnit.oxygenSignal;
        interface pressureToControl : SensorSignal connect pressureSensor.signal to controlUnit.pressureSignal;
        interface tempToControl : SensorSignal connect tempSensor.signal to controlUnit.tempSignal;

        // Control to pump
        interface controlToPump : SensorSignal connect controlUnit.pumpControl to centrifugalPump.control;

        // Alarm connections
        interface controlToAlarm : AlarmSignal connect controlUnit.alarmOut to alarmSystem.alarmIn;
        interface alarmOutput : AlarmSignal connect alarmSystem.alarmOut to alarmSystem.alarmIn;

        // State machine
        exhibit state ecmoState : ECMOStateMachine;
    }
}
