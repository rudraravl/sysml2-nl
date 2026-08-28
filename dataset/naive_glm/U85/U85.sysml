package MedipinesRespiratorySystem {
    import ScalarValues::*;
    import ISQ::*;

    value type Volume :> Real { unit 'L'; }
    value type FlowRate :> Real { unit 'L/min'; }
    value type Pressure :> Real { unit 'cmH2O'; }
    value type Fraction :> Real { unit '%'; }
    value type Frequency :> Real { unit 'bpm'; }
    value type Concentration :> Real { unit '%'; }

    item def Gas;
    item def Air :> Gas;
    item def Oxygen :> Gas;
    item def GasMixture :> Gas {
        attribute oxygenConcentration : Concentration;
    }
    item def ExhaledGas :> Gas {
        attribute co2Concentration : Concentration;
        attribute volume : Volume;
    }

    port def GasOutPort {
        out item : Gas;
    }
    port def GasInPort {
        in item : Gas;
    }
    port def ControlOutPort {
        out attribute command : Real;
    }
    port def ControlInPort {
        in attribute command : Real;
    }
    port def DataOutPort {
        out attribute value : Real;
    }
    port def DataInPort {
        in attribute value : Real;
    }
    port def AlarmOutPort {
        out attribute trigger : Boolean;
    }
    port def AlarmInPort {
        in attribute trigger : Boolean;
    }

    part def OxygenBlender {
        port inAir : GasInPort;
        port inO2 : GasInPort;
        port outMix : GasOutPort;
        port controlIn : ControlInPort;
        
        attribute targetO2Concentration : Concentration;
    }

    part def InspiratoryValve {
        port inMix : GasInPort;
        port outToCircuit : GasOutPort;
        port controlIn : ControlInPort;
        attribute valveOpen : Boolean;
    }

    part def PatientCircuit {
        port inInsp : GasInPort;
        port outToPatient : GasOutPort;
        port inFromPatient : GasInPort;
        port outExp : GasOutPort;
    }

    part def InspiratoryFlowSensor {
        port inGas : GasInPort;
        port outGas : GasOutPort;
        port dataOut : DataOutPort;
        attribute flowRate : FlowRate;
        attribute volume : Volume;
    }

    part def AirwayPressureSensor {
        port dataOut : DataOutPort;
        attribute pressure : Pressure;
    }

    part def ExpiratoryValve {
        port inExp : GasInPort;
        port outToAtmosphere : GasOutPort;
        port controlIn : ControlInPort;
        attribute valveOpen : Boolean;
    }

    part def ExpiratoryFlowSensor {
        port inGas : GasInPort;
        port outGas : GasOutPort;
        port dataOut : DataOutPort;
        attribute flowRate : FlowRate;
        attribute volume : Volume;
    }

    part def CO2Monitor {
        port inGas : GasInPort;
        port outGas : GasOutPort;
        port dataOut : DataOutPort;
        attribute co2Concentration : Concentration;
    }

    part def UserInterface {
        port dataIn : DataInPort;
        port alarmIn : AlarmInPort;
        port settingsOut : DataOutPort;
        
        attribute breathRate : Frequency;
        attribute tidalVolume : Volume;
        attribute targetO2 : Concentration;
    }

    part def AlarmSystem {
        port dataIn : DataInPort;
        port alarmOut : AlarmOutPort;
        
        attribute highPressureLimit : Pressure;
        attribute lowPressureLimit : Pressure;
    }

    part def ControlProcessor {
        port settingsIn : DataInPort;
        port inspFlowData : DataInPort;
        port airwayPressureData : DataInPort;
        port expFlowData : DataInPort;
        port co2Data : DataInPort;
        
        port blenderControl : ControlOutPort;
        port inspValveControl : ControlOutPort;
        port expValveControl : ControlOutPort;
        port alarmData : DataOutPort;
        
        attribute targetTidalVolume : Volume;
        attribute expiratoryTime : Real;
        attribute volumeDelivered : Volume;
        attribute elapsedTime : Real;
        attribute selfTestPassed : Boolean;
        attribute startVentilation : Boolean;
        attribute stopVentilation : Boolean;
        attribute criticalFault : Boolean;
        attribute faultCleared : Boolean;
        
        state machine def ControlStateMachine {
            state Startup;
            state SelfTest;
            state Standby;
            state Ventilating {
                state Inspiration;
                state Expiration;
                transition insp_to_exp transition from Inspiration to Expiration when 'volumeDelivered >= targetTidalVolume';
                transition exp_to_insp transition from Expiration to Inspiration when 'elapsedTime >= expiratoryTime';
            }
            state Fault;
            
            transition init_to_test transition from Startup to SelfTest;
            transition test_to_standby transition from SelfTest to Standby when 'selfTestPassed == true';
            transition test_to_fault transition from SelfTest to Fault when 'selfTestPassed == false';
            transition standby_to_vent transition from Standby to Ventilating when 'startVentilation == true';
            transition vent_to_standby transition from Ventilating to Standby when 'stopVentilation == true';
            transition any_to_fault transition from Ventilating to Fault when 'criticalFault == true';
            transition fault_to_standby transition from Fault to Standby when 'faultCleared == true';
        }
    }

    part def MedipinesVentilator {
        part blender : OxygenBlender;
        part inspValve : InspiratoryValve;
        part patientCircuit : PatientCircuit;
        part inspFlowSensor : InspiratoryFlowSensor;
        part airwayPressureSensor : AirwayPressureSensor;
        part expValve : ExpiratoryValve;
        part expFlowSensor : ExpiratoryFlowSensor;
        part co2Monitor : CO2Monitor;
        part ui : UserInterface;
        part alarm : AlarmSystem;
        part processor : ControlProcessor;
        
        connection blenderToInspValve connect blender.outMix to inspValve.inMix;
        connection inspValveToInspSensor connect inspValve.outToCircuit to inspFlowSensor.inGas;
        connection inspSensorToCircuit connect inspFlowSensor.outGas to patientCircuit.inInsp;
        connection circuitToExpSensor connect patientCircuit.outExp to expFlowSensor.inGas;
        connection expSensorToCO2 connect expFlowSensor.outGas to co2Monitor.inGas;
        connection co2ToExpValve connect co2Monitor.outGas to expValve.inExp;
        
        connection procToBlender connect processor.blenderControl to blender.controlIn;
        connection procToInspValve connect processor.inspValveControl to inspValve.controlIn;
        connection procToExpValve connect processor.expValveControl to expValve.controlIn;
        
        connection uiToProc connect ui.settingsOut to processor.settingsIn;
        connection inspSensorToProc connect inspFlowSensor.dataOut to processor.inspFlowData;
        connection airwaySensorToProc connect airwayPressureSensor.dataOut to processor.airwayPressureData;
        connection expSensorToProc connect expFlowSensor.dataOut to processor.expFlowData;
        connection co2ToProc connect co2Monitor.dataOut to processor.co2Data;
        
        connection procToAlarm connect processor.alarmData to alarm.dataIn;
        connection alarmToUI connect alarm.alarmOut to ui.alarmIn;
    }

    requirement def DeliverPreciseMixture {
        doc /* The system shall deliver a precise, controlled mixture of air and oxygen. */
        subject ventilator : MedipinesVentilator;
    }
    
    requirement def MonitorRespiratoryFunctions {
        doc /* The system shall continuously monitor respiratory functions. */
        subject ventilator : MedipinesVentilator;
    }
    
    requirement def TriggerAlarms {
        doc /* The system shall trigger audible and visual alerts if measurements go outside safe ranges. */
        subject ventilator : MedipinesVentilator;
    }
    
    requirement def SafeStateTransitions {
        doc /* The system shall operate in Startup, Standby, Ventilating, and Fault states. */
        subject ventilator : MedipinesVentilator;
    }
}
