package NeuromuscularStimulationDevice {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        attribute def StimulationCurrent;
        attribute def StimulationFrequency;
        attribute def PulseDuration;
        attribute def SessionDuration;
        attribute def TherapyCommand;
        attribute def StartCommand;
        attribute def StopCommand;
        attribute def AdjustCommand;
        attribute def EmergencyStop;
        attribute def ResetCommand;
        attribute def SessionComplete;
        attribute def SafetyAlert;
        attribute def StatusUpdate;
        attribute def TherapySettings;
        attribute def StimulationFeedback;
        attribute def ElectricalWaveform;

        enum def StimulationPatternKind {
            tonic;
            burst;
            ramp;
        }

        action def RunPreOpCheck {
            out checkPassed : Boolean;
        }
        action def GenerateStimulation {
            in settings : TherapySettings;
            out waveform : ElectricalWaveform;
        }
        action def DeliverTherapy {
            in waveform : ElectricalWaveform;
        }
        action def MonitorStimulation {
            in feedback : StimulationFeedback;
            out adjustedCurrent : StimulationCurrent;
        }
        action def MonitorBattery {
            out level : Real;
        }
        action def ManageCharging {
            out chargeComplete : Boolean;
        }
        action def SenseTemperature {
            out temp : Real;
        }
        action def SensePressure {
            out pressure : Real;
        }
        action def EvaluateSafety {
            in temp : Real;
            in pressure : Real;
            out safe : Boolean;
        }
        action def EmergencyShutdownAction;
        action def SendStatus {
            in status : StatusUpdate;
        }

        state def DeviceStates;
        state def ControllerStates;
        state def SafetyMonitorStates;
        state def PowerManagementStates;

        part def BiocompatibleEnclosure {
            attribute material : String = "Medical-grade silicone";
            attribute coating : String = "Antimicrobial";
        }

        part def BluetoothModule {
            attribute protocol : String = "Bluetooth Low Energy";
            port cmdOut {
                out attribute cmd : TherapyCommand;
            }
            port statusIn {
                in attribute status : StatusUpdate;
            }
        }

        part def Battery {
            attribute capacity : Real = 100;
            port powerOut {
                out attribute voltage : Real;
                out attribute batteryLevel : Real;
            }
        }

        part def ControllerUnit {
            port cmdIn {
                in attribute cmd : TherapyCommand;
            }
            port statusOut {
                out attribute status : StatusUpdate;
            }
            port settingsOut {
                out attribute settings : TherapySettings;
            }
            port feedbackIn {
                in attribute feedback : StimulationFeedback;
            }
            port safetyOverrideIn {
                in attribute emergencyStop : EmergencyStop;
            }
            port powerIn {
                in attribute voltage : Real;
                in attribute batteryLevel : Real;
            }
            exhibit state controllerStates : ControllerStates;
            attribute maxCurrent : Real = 100;
            attribute maxFrequency : Real = 150;
        }

        part def StimulationGenerator {
            port settingsIn {
                in attribute settings : TherapySettings;
            }
            port stimOut {
                out attribute waveform : ElectricalWaveform;
            }
            port feedbackOut {
                out attribute feedback : StimulationFeedback;
            }
            port powerIn {
                in attribute voltage : Real;
            }
            perform action generate : GenerateStimulation;
            perform action monitor : MonitorStimulation;
            perform action deliver : DeliverTherapy;
        }

        part def PowerManagementSystem {
            port powerOut {
                out attribute voltage : Real;
                out attribute batteryLevel : Real;
            }
            port batteryIn {
                in attribute voltage : Real;
                in attribute batteryLevel : Real;
            }
            exhibit state powerStates : PowerManagementStates;
            attribute minOperationHours : Real = 3;
            perform action monitorBattery : MonitorBattery;
            perform action manageCharging : ManageCharging;
        }

        part def SafetyMonitoringSystem {
            port sensorTempIn {
                in attribute temperature : Real;
            }
            port sensorPressIn {
                in attribute pressure : Real;
            }
            port overrideOut {
                out attribute emergencyStop : EmergencyStop;
            }
            port powerIn {
                in attribute voltage : Real;
            }
            exhibit state safetyStates : SafetyMonitorStates;
            attribute maxTemperature : Real = 42;
            attribute maxPressure : Real = 50;
            perform action senseTemp : SenseTemperature;
            perform action sensePress : SensePressure;
            perform action evaluate : EvaluateSafety;
            perform action emergencyShutdown : EmergencyShutdownAction;
        }

        part def TemperatureSensor {
            port tempOut {
                out attribute temperature : Real;
            }
            perform action sense : SenseTemperature;
        }

        part def PressureSensor {
            port pressOut {
                out attribute pressure : Real;
            }
            perform action sense : SensePressure;
        }

        part def ElectrodeArray {
            port stimIn {
                in attribute waveform : ElectricalWaveform;
            }
        }

        part def NeuromuscularStimulator {
            perform action 'deliver therapy' : DeliverTherapy;
            exhibit state 'device states' : DeviceStates;
            part enclosure : BiocompatibleEnclosure;
            part bluetoothModule : BluetoothModule;
            part battery : Battery;
            part controllerUnit : ControllerUnit;
            part stimulationGenerator : StimulationGenerator;
            part powerManagement : PowerManagementSystem;
            part safetyMonitoring : SafetyMonitoringSystem;
            part temperatureSensor : TemperatureSensor;
            part pressureSensor : PressureSensor;
            part electrodeArray : ElectrodeArray;
        }

        requirement def BiocompatibilityRequirement {
            doc
            /* The device enclosure shall be made of medical-grade silicone
               with an antimicrobial coating for safe prolonged tissue contact. */
            subject device : BiocompatibleEnclosure;
        }

        requirement def BatteryLifeRequirement {
            doc
            /* The device shall provide at least 3 hours of continuous operation
               on a full charge. */
            subject pms : PowerManagementSystem;
        }

        requirement def SafetyOverrideRequirement {
            doc
            /* The safety monitoring system shall override the controller and
               trigger an immediate shutdown when safety thresholds are exceeded. */
            subject sms : SafetyMonitoringSystem;
        }

        requirement def WirelessCommandRequirement {
            doc
            /* The controller shall receive therapy commands via Bluetooth Low Energy
               and shall reject invalid commands. */
            subject bt : BluetoothModule;
        }

        requirement def StimulationLimitRequirement {
            doc
            /* The controller shall enforce maximum current and frequency limits. */
            subject cu : ControllerUnit;
        }
    }

    package Usages {
        private import Definitions::*;

        action 'run pre-op check' : RunPreOpCheck;
        action 'generate stimulation' : GenerateStimulation;
        action 'deliver therapy' : DeliverTherapy;
        action 'sense temperature' : SenseTemperature;
        action 'sense pressure' : SensePressure;
        action 'evaluate safety' : EvaluateSafety;
        action 'emergency shutdown' : EmergencyShutdownAction;
        action 'monitor battery' : MonitorBattery;
        action 'manage charging' : ManageCharging;

        part stimulator : NeuromuscularStimulator {
            :>> battery.capacity = 100;

            connect bluetoothModule.cmdOut to controllerUnit.cmdIn;
            connect controllerUnit.statusOut to bluetoothModule.statusIn;
            connect controllerUnit.settingsOut to stimulationGenerator.settingsIn;
            connect stimulationGenerator.stimOut to electrodeArray.stimIn;
            connect stimulationGenerator.feedbackOut to controllerUnit.feedbackIn;
            connect battery.powerOut to powerManagement.batteryIn;
            connect powerManagement.powerOut to controllerUnit.powerIn;
            connect powerManagement.powerOut to stimulationGenerator.powerIn;
            connect powerManagement.powerOut to safetyMonitoring.powerIn;
            connect temperatureSensor.tempOut to safetyMonitoring.sensorTempIn;
            connect pressureSensor.pressOut to safetyMonitoring.sensorPressIn;
            connect safetyMonitoring.overrideOut to controllerUnit.safetyOverrideIn;
        }

        state 'device states' : DeviceStates parallel {
            state 'operational states' {
                entry; then idle;
                state idle;
                accept StartCommand
                    then preOpCheck;
                state preOpCheck {
                    entry 'run pre-op check' { out checkPassed; }
                }
                accept when 'run pre-op check'.checkPassed
                    then delivering;
                accept StopCommand
                    then idle;
                state delivering {
                    entry 'generate stimulation';
                    do 'deliver therapy';
                }
                accept StopCommand
                    then idle;
                accept SessionComplete
                    then idle;
                accept EmergencyStop
                    then emergency;
                state emergency {
                    entry 'emergency shutdown';
                }
                accept ResetCommand
                    then idle;
            }

            state 'health states' {
                entry; then normal;
                do 'sense temperature' { out temp; }
                do 'sense pressure' { out pressure; }
                state normal;
                accept when 'sense temperature'.temp > stimulator.safetyMonitoring.maxTemperature
                    then degraded;
                accept when 'sense pressure'.pressure > stimulator.safetyMonitoring.maxPressure
                    then degraded;
                state degraded;
                accept ResetCommand
                    then normal;
            }
        }

        state controllerStates : ControllerStates parallel {
            state 'command processing' {
                entry; then waiting;
                state waiting;
                accept TherapyCommand
                    then processing;
                state processing;
                accept StopCommand
                    then waiting;
            }
            state 'status reporting' {
                entry; then idle;
                state idle;
                accept StimulationFeedback
                    then idle;
            }
        }

        state safetyStates : SafetyMonitorStates parallel {
            state 'monitoring states' {
                entry; then normal;
                state normal;
                accept EmergencyStop
                    then alertState;
                state alertState {
                    entry 'emergency shutdown';
                }
                accept ResetCommand
                    then normal;
            }
        }

        state powerStates : PowerManagementStates parallel {
            state 'power states' {
                entry; then operating;
                state operating;
                accept when stimulator.battery.capacity < 20
                    then lowBattery;
                state lowBattery;
                accept when stimulator.battery.capacity < 5
                    then charging;
                state charging {
                    do 'manage charging' { out chargeComplete; }
                }
                accept when stimulator.battery.capacity >= 20
                    then operating;
            }
        }

        requirement biocompatibilityReq : BiocompatibilityRequirement {
            subject device = stimulator.enclosure;
        }
        requirement batteryLifeReq : BatteryLifeRequirement {
            subject pms = stimulator.powerManagement;
        }
        requirement safetyOverrideReq : SafetyOverrideRequirement {
            subject sms = stimulator.safetyMonitoring;
        }
        requirement wirelessCommandReq : WirelessCommandRequirement {
            subject bt = stimulator.bluetoothModule;
        }
        requirement stimulationLimitReq : StimulationLimitRequirement {
            subject cu = stimulator.controllerUnit;
        }
    }
}
