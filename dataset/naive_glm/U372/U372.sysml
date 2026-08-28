import ScalarValues::*;

package SAHRA_System {
    // Units
    unit def mL;
    unit def L_per_min;
    unit def cmH2O;
    unit def Percent;
    unit def bpm;
    unit def s;

    // Value Types
    value type Volume :> Real [mL];
    value type FlowRate :> Real [L_per_min];
    value type Pressure :> Real [cmH2O];
    value type O2Concentration :> Real [Percent];
    value type RespRate :> Integer [bpm];
    value type Duration :> Real [s];

    // Items
    item def Air;
    item def O2;
    item def BreathGas;
    item def StartSignal;
    item def ResetSignal;

    // Ports
    port def AirInPort { in item air : Air; }
    port def AirOutPort { out item air : Air; }
    port def O2InPort { in item o2 : O2; }
    port def O2OutPort { out item o2 : O2; }
    port def GasInPort { in item gas : BreathGas; }
    port def GasOutPort { out item gas : BreathGas; }
    port def PatientPort {
        out item inhaledGas : BreathGas;
        in item exhaledGas : BreathGas;
    }
    port def PressureSignalPort { out value : Pressure; }
    port def FlowSignalPort { out value : FlowRate; }
    port def CompressorCmdPort { in on : Boolean; }
    port def BlenderCmdPort { in ratio : O2Concentration; }
    port def ValveCmdPort { in position : Real; }
    port def AlarmCmdPort { in trigger : Boolean; }
    port def SettingsPort {
        in item startSignal : StartSignal;
        in item resetSignal : ResetSignal;
        in o2Setting : O2Concentration;
        in tidalVolumeSetting : Volume;
        in respRateSetting : RespRate;
    }

    // Requirements
    requirement def BreathingSupportRequirement {
        doc "The system shall provide life-sustaining breathing support by delivering controlled breaths of oxygen-enriched air.";
    }
    
    requirement def OxygenBlendingRequirement {
        doc "The system shall blend ambient air with pure oxygen to deliver a precise gas mixture adjustable from 21% to 100%.";
        attribute minO2 : O2Concentration = 21.0;
        attribute maxO2 : O2Concentration = 100.0;
        constraint { minO2 >= 21.0 and maxO2 <= 100.0 }
    }
    
    requirement def VentilationControlRequirement {
        doc "The system shall control the volume of air per breath (tidal volume) and the number of breaths per minute.";
    }
    
    requirement def SafetyMonitoringRequirement {
        doc "The system shall monitor pressure and flow, and trigger audible and visual alerts on high pressure or disconnection.";
        attribute pressureLimit : Pressure = 40.0;
        attribute flowLimit : FlowRate = 2.0;
    }

    // Parts
    part def Compressor {
        port airIn : AirInPort;
        port airOut : AirOutPort;
        port cmdIn : CompressorCmdPort;
        attribute maxPressure : Pressure = 100.0;
        state machine Operation {
            state Off;
            state On;
            transition Off to On when cmdIn.on == true;
            transition On to Off when cmdIn.on == false;
        }
    }

    part def O2Supply {
        port o2Out : O2OutPort;
        attribute capacity : Volume = 10000;
    }

    part def Blender {
        port airIn : AirInPort;
        port o2In : O2InPort;
        port gasOut : GasOutPort;
        port cmdIn : BlenderCmdPort;
    }

    part def InspiratoryValve {
        port gasIn : GasInPort;
        port gasOut : GasOutPort;
        port cmdIn : ValveCmdPort;
        attribute openThreshold : Real = 0.5;
        state machine ValveStates {
            state Closed;
            state Open;
            transition Closed to Open when cmdIn.position > openThreshold;
            transition Open to Closed when cmdIn.position <= openThreshold;
        }
    }

    part def ExpiratoryValve {
        port gasIn : GasInPort;
        port gasOut : GasOutPort;
        port cmdIn : ValveCmdPort;
        attribute openThreshold : Real = 0.5;
        state machine ValveStates {
            state Closed;
            state Open;
            transition Closed to Open when cmdIn.position > openThreshold;
            transition Open to Closed when cmdIn.position <= openThreshold;
        }
    }

    part def PressureSensor {
        port pressureOut : PressureSignalPort;
        attribute accuracy : Real = 0.01;
    }

    part def FlowSensor {
        port flowOut : FlowSignalPort;
        attribute accuracy : Real = 0.01;
    }

    part def AlarmModule {
        port cmdIn : AlarmCmdPort;
        attribute audibleLevel : Real = 80.0;
        attribute visualActive : Boolean = false;
        state machine AlarmStates {
            state Idle;
            state Alarming;
            transition Idle to Alarming when cmdIn.trigger == true;
            transition Alarming to Idle when cmdIn.trigger == false;
        }
    }

    part def Controller {
        port pressureIn : ~PressureSignalPort;
        port flowIn : ~FlowSignalPort;
        port settingsIn : SettingsPort;

        port compressorOut : ~CompressorCmdPort;
        port blenderOut : ~BlenderCmdPort;
        port inspValveOut : ~ValveCmdPort;
        port expValveOut : ~ValveCmdPort;
        port alarmOut : ~AlarmCmdPort;

        attribute maxPressure : Pressure = 40.0;
        attribute minFlow : FlowRate = 2.0;
        attribute inspiratoryTime : Duration = 2.0;
        attribute expiratoryTime : Duration = 3.0;

        state machine ControlLogic {
            state Standby;
            state ActiveVentilation {
                state Inspiration;
                state Expiration;
                
                transition Inspiration to Expiration
                    after inspiratoryTime;
                transition Expiration to Inspiration
                    after expiratoryTime;
            }
            state CriticalAlarm;
            
            transition Standby to ActiveVentilation
                accept StartSignal;
            transition ActiveVentilation to CriticalAlarm
                when (pressureIn.value > maxPressure) or (flowIn.value < minFlow);
            transition CriticalAlarm to Standby
                accept ResetSignal;
        }
    }

    part def PatientCircuit {
        port gasIn : GasInPort;
        port gasOut : GasOutPort;
        port patientPort : ~PatientPort;
        port pressureData : PressureSignalPort;
        port flowData : FlowSignalPort;

        part pressureSensor : PressureSensor;
        part flowSensor : FlowSensor;

        connect pressureSensor.pressureOut to pressureData;
        connect flowSensor.flowOut to flowData;
    }

    part def SAHRA {
        port ambientAirIn : AirInPort;
        port exhaustOut : GasOutPort;
        port patientConnection : PatientPort;
        port settingsIn : SettingsPort;

        part compressor : Compressor;
        part o2Source : O2Supply;
        part blender : Blender;
        part inspValve : InspiratoryValve;
        part expValve : ExpiratoryValve;
        part circuit : PatientCircuit;
        part controller : Controller;
        part alarm : AlarmModule;

        connect ambientAirIn to compressor.airIn;
        connect compressor.airOut to blender.airIn;
        connect o2Source.o2Out to blender.o2In;
        connect blender.gasOut to inspValve.gasIn;
        connect inspValve.gasOut to circuit.gasIn;

        connect circuit.gasOut to expValve.gasIn;
        connect expValve.gasOut to exhaustOut;

        connect patientConnection to circuit.patientPort;

        connect circuit.pressureData to controller.pressureIn;
        connect circuit.flowData to controller.flowIn;

        connect controller.compressorOut to compressor.cmdIn;
        connect controller.blenderOut to blender.cmdIn;
        connect controller.inspValveOut to inspValve.cmdIn;
        connect controller.expValveOut to expValve.cmdIn;
        connect controller.alarmOut to alarm.cmdIn;

        connect settingsIn to controller.settingsIn;

        satisfy BreathingSupportRequirement;
        satisfy OxygenBlendingRequirement;
        satisfy VentilationControlRequirement;
        satisfy SafetyMonitoringRequirement;
    }
}
