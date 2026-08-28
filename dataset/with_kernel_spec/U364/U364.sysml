package 'Puritan Bennett Ventilator' {
    private import ScalarValues::*;
    
    attribute def Pressure :> Real;
    attribute def FlowRate :> Real;
    attribute def Volume :> Real;
    attribute def O2Concentration :> Real;
    attribute def TimeValue :> Real;
    
    item def MedicalGas {
        attribute o2Concentration : O2Concentration;
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
    }
    
    item def BreathSettings {
        attribute targetPressure : Pressure;
        attribute targetVolume : Volume;
        attribute respiratoryRate : Real;
        attribute ieRatio : Real;
        attribute targetO2 : O2Concentration;
        attribute peep : Pressure;
    }
    
    item def SensorReading {
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
        attribute volume : Volume;
        attribute o2Concentration : O2Concentration;
    }
    
    item def AlarmEvent {
        attribute alarmType : String;
        attribute severity : Integer;
    }
    
    item def ControlCommand {
        attribute openInspiratory : Boolean;
        attribute openExpiratory : Boolean;
        attribute targetPressure : Pressure;
    }
    
    attribute def StartVentilation;
    attribute def HighPressureSignal;
    attribute def EndInspirationSignal;
    attribute def PatientEffortSignal;
    attribute def ResetAlarmSignal;
    
    port def GasOutPort {
        out item gas : MedicalGas;
    }
    port def GasInPort {
        in item gas : MedicalGas;
    }
    port def ControlOutPort {
        out item command : ControlCommand;
    }
    port def ControlInPort {
        in item command : ControlCommand;
    }
    port def SensorDataOutPort {
        out item data : SensorReading;
    }
    port def SensorDataInPort {
        in item data : SensorReading;
    }
    port def AlarmOutPort {
        out item alarm : AlarmEvent;
    }
    port def AlarmInPort {
        in item alarm : AlarmEvent;
    }
    port def UIOutPort {
        out item settings : BreathSettings;
    }
    port def UIInPort {
        in item settings : BreathSettings;
    }
    
    part def AirCompressor {
        port gasOut : GasOutPort;
    }
    part def OxygenSource {
        port gasOut : GasOutPort;
    }
    part def GasMixer {
        port airIn : GasInPort;
        port oxygenIn : GasInPort;
        port mixedGasOut : GasOutPort;
        port controlIn : ControlInPort;
    }
    part def InspiratoryValve {
        port gasIn : GasInPort;
        port gasOut : GasOutPort;
        port controlIn : ControlInPort;
    }
    part def ExpiratoryValve {
        port gasIn : GasInPort;
        port gasOut : GasOutPort;
        port controlIn : ControlInPort;
    }
    part def PatientCircuit {
        port inspiratoryIn : GasInPort;
        port expiratoryOut : GasOutPort;
        port patientConnection : GasOutPort;
    }
    part def PressureTransducer {
        port gasIn : GasInPort;
        port sensorOut : SensorDataOutPort;
    }
    part def FlowTransducer {
        port gasIn : GasInPort;
        port gasOut : GasOutPort;
        port sensorOut : SensorDataOutPort;
    }
    part def OxygenSensor {
        port gasIn : GasInPort;
        port sensorOut : SensorDataOutPort;
    }
    part def VolumeMonitor {
        port flowIn : SensorDataInPort;
        port volumeOut : SensorDataOutPort;
    }
    part def AlarmModule {
        port sensorIn : SensorDataInPort;
        port alarmOut : AlarmOutPort;
    }
    part def UserInterface {
        port settingsOut : UIOutPort;
    }
    
    state def BreathControllerStates;
    
    part def BreathController {
        port settingsIn : UIInPort;
        port sensorIn : SensorDataInPort;
        port controlOut : ControlOutPort;
        port alarmIn : AlarmInPort;
        
        state breathStates : BreathControllerStates {
            entry; then standby;
            state standby;
            accept StartVentilation then inspiration;
            state inspiration {
                do action deliverBreath { /* deliver targeted volume at controlled pressure */ }
            }
            accept HighPressureSignal then alarm;
            accept EndInspirationSignal then expiration;
            state expiration {
                do action maintainPEEP { /* regulate expiratory valve to hold PEEP */ }
            }
            accept PatientEffortSignal then inspiration;
            state alarm {
                do action triggerAlarm { /* activate audiovisual alarm */ }
            }
            accept ResetAlarmSignal then standby;
        }
    }
    
    part ventilatorSystem {
        part airCompressor : AirCompressor;
        part oxygenSource : OxygenSource;
        part gasMixer : GasMixer;
        part inspiratoryValve : InspiratoryValve;
        part expiratoryValve : ExpiratoryValve;
        part patientCircuit : PatientCircuit;
        part pressureTransducer : PressureTransducer;
        part flowTransducer : FlowTransducer;
        part oxygenSensor : OxygenSensor;
        part volumeMonitor : VolumeMonitor;
        part alarmModule : AlarmModule;
        part userInterface : UserInterface;
        part breathController : BreathController;
        
        connect airCompressor.gasOut to gasMixer.airIn;
        connect oxygenSource.gasOut to gasMixer.oxygenIn;
        connect gasMixer.mixedGasOut to inspiratoryValve.gasIn;
        connect inspiratoryValve.gasOut to flowTransducer.gasIn;
        connect flowTransducer.gasOut to patientCircuit.inspiratoryIn;
        connect patientCircuit.expiratoryOut to expiratoryValve.gasIn;
        
        connect inspiratoryValve.gasOut to pressureTransducer.gasIn;
        connect gasMixer.mixedGasOut to oxygenSensor.gasIn;
        connect flowTransducer.sensorOut to volumeMonitor.flowIn;
        
        connect userInterface.settingsOut to breathController.settingsIn;
        connect pressureTransducer.sensorOut to breathController.sensorIn;
        connect flowTransducer.sensorOut to breathController.sensorIn;
        connect oxygenSensor.sensorOut to breathController.sensorIn;
        connect volumeMonitor.volumeOut to breathController.sensorIn;
        
        connect breathController.controlOut to gasMixer.controlIn;
        connect breathController.controlOut to inspiratoryValve.controlIn;
        connect breathController.controlOut to expiratoryValve.controlIn;
        
        connect pressureTransducer.sensorOut to alarmModule.sensorIn;
        connect flowTransducer.sensorOut to alarmModule.sensorIn;
        connect oxygenSensor.sensorOut to alarmModule.sensorIn;
        connect volumeMonitor.volumeOut to alarmModule.sensorIn;
        connect alarmModule.alarmOut to breathController.alarmIn;
        
        flow airFlow of MedicalGas from airCompressor.gasOut.gas to gasMixer.airIn.gas;
        flow oxygenFlow of MedicalGas from oxygenSource.gasOut.gas to gasMixer.oxygenIn.gas;
        flow mixedGasFlow of MedicalGas from gasMixer.mixedGasOut.gas to inspiratoryValve.gasIn.gas;
        flow inspiratoryFlow of MedicalGas from inspiratoryValve.gasOut.gas to flowTransducer.gasIn.gas;
        flow patientFlow of MedicalGas from flowTransducer.gasOut.gas to patientCircuit.inspiratoryIn.gas;
        flow expiratoryFlow of MedicalGas from patientCircuit.expiratoryOut.gas to expiratoryValve.gasIn.gas;
        
        flow pressureData of SensorReading from pressureTransducer.sensorOut.data to breathController.sensorIn.data;
        flow flowData of SensorReading from flowTransducer.sensorOut.data to breathController.sensorIn.data;
        flow o2Data of SensorReading from oxygenSensor.sensorOut.data to breathController.sensorIn.data;
        flow volumeData of SensorReading from volumeMonitor.volumeOut.data to breathController.sensorIn.data;
        
        flow controlCommand1 of ControlCommand from breathController.controlOut.command to gasMixer.controlIn.command;
        flow controlCommand2 of ControlCommand from breathController.controlOut.command to inspiratoryValve.controlIn.command;
        flow controlCommand3 of ControlCommand from breathController.controlOut.command to expiratoryValve.controlIn.command;
        
        flow alarmData of AlarmEvent from alarmModule.alarmOut.alarm to breathController.alarmIn.alarm;
    }
    
    requirement def SafeVentilation {
        doc /* The ventilator must deliver precise mechanical breaths and trigger alarms for dangerous conditions. */
    }
    requirement def PEEPRequirement {
        doc /* The system shall maintain a constant positive end-expiratory pressure (PEEP) as configured by the clinician. */
        attribute minPEEP : Pressure = 5;
    }
    requirement def FiO2AccuracyRequirement {
        doc /* The delivered oxygen concentration shall be within +/- 2% of the prescribed FiO2 setting. */
        attribute maxDeviation : O2Concentration = 2;
    }
    requirement def HighPressureAlarmRequirement {
        doc /* An immediate audiovisual alarm shall be triggered if airway pressure exceeds 40 cmH2O. */
        attribute threshold : Pressure = 40;
    }
    requirement def ApneaAlarmRequirement {
        doc /* The system shall detect apnea and trigger an alarm if no patient breath is detected for more than 20 seconds. */
        attribute apneaTimeout : TimeValue = 20;
    }
    
    requirement ventilatorSafety : SafeVentilation;
    requirement ventilatorPEEP : PEEPRequirement;
    requirement ventilatorFiO2 : FiO2AccuracyRequirement;
    requirement ventilatorHighPressure : HighPressureAlarmRequirement;
    requirement ventilatorApnea : ApneaAlarmRequirement;
}
