package PortableOxygenConcentratorModel {
    public import ISQ::*;
    public import ScalarValues::*;

    package Definitions {
        private import ISQ::*;
        private import ScalarValues::*;

        item def AmbientAir {
            attribute pressure : ISQ::pressure;
            attribute temperature : ISQ::temperature;
        }
        item def CompressedAir :> AmbientAir;
        item def ConcentratedOxygen {
            attribute purity : Real;
            attribute flowRate : ISQ::volumeFlowRate;
            attribute pressure : ISQ::pressure;
        }
        item def NitrogenWaste {
            attribute flowRate : ISQ::volumeFlowRate;
        }
        item def ElectricalPower {
            attribute power : ISQ::power;
        }

        attribute def StartSignal;
        attribute def StopSignal;
        attribute def SetModeSignal {
            attribute mode : String;
        }
        attribute def LowBatteryAlert;
        attribute def LowPurityAlert;
        attribute def HighPressureAlert;
        attribute def ClearAlarmSignal;

        port def AirFlowPort {
            inout item air : AmbientAir;
        }
        port def CompressedAirPort {
            inout item air : CompressedAir;
        }
        port def OxygenFlowPort {
            inout item oxygen : ConcentratedOxygen;
        }
        port def NitrogenVentPort {
            out item waste : NitrogenWaste;
        }
        port def PowerPort {
            inout item power : ElectricalPower;
        }
        port def ControlPort {
            inout attribute command : Boolean;
            inout attribute status : Real;
        }
        port def SensorPort {
            inout attribute reading : Real;
        }
        port def UserInterfacePort {
            inout attribute start : StartSignal;
            inout attribute stop : StopSignal;
            inout attribute setMode : SetModeSignal;
            inout attribute clearAlarm : ClearAlarmSignal;
            inout attribute displayInfo : String;
            inout attribute alarmActive : Boolean;
        }

        action def FilterAir {
            in air : AmbientAir;
            out filteredAir : AmbientAir;
        }
        action def CompressAir {
            in air : AmbientAir;
            out compressedAir : CompressedAir;
        }
        action def SeparateGases {
            in compressedAir : CompressedAir;
            out oxygen : ConcentratedOxygen;
            out waste : NitrogenWaste;
        }
        action def RegulateFlow {
            in oxygen : ConcentratedOxygen;
            out regulatedOxygen : ConcentratedOxygen;
        }
        action def SensePurity {
            in oxygen : ConcentratedOxygen;
            out reading : Real;
        }
        action def SensePressure {
            in air : CompressedAir;
            out reading : Real;
        }
        action def SenseFlow {
            in oxygen : ConcentratedOxygen;
            out reading : Real;
        }
        action def ProvidePower {
            out power : ElectricalPower;
        }
        action def ConvertPower {
            in acPower : ElectricalPower;
            out dcPower : ElectricalPower;
        }
        action def ReadUserInput;
        action def DisplayInfo {
            in info : String;
        }
        action def SoundAlarm;

        part def AirIntake {
            port airOut : AirFlowPort;
            perform action filterAir : FilterAir;
        }
        part def Compressor {
            port airIn : AirFlowPort;
            port airOut : CompressedAirPort;
            port ctrlPort : ControlPort;
            port powerIn : PowerPort;
            perform action compressAir : CompressAir;
        }
        part def MolecularSieve {
            port airIn : CompressedAirPort;
            port oxygenOut : OxygenFlowPort;
            port nitrogenOut : NitrogenVentPort;
            perform action separateGases : SeparateGases;
        }
        part def FlowRegulator {
            port oxygenIn : OxygenFlowPort;
            port oxygenOut : OxygenFlowPort;
            port ctrlPort : ControlPort;
            perform action regulateFlow : RegulateFlow;
        }
        part def OxygenSensor {
            port oxygenIn : OxygenFlowPort;
            port oxygenOut : OxygenFlowPort;
            port dataOut : SensorPort;
            perform action sensePurity : SensePurity;
        }
        part def PressureSensor {
            port airIn : CompressedAirPort;
            port dataOut : SensorPort;
            perform action sensePressure : SensePressure;
        }
        part def FlowSensor {
            port oxygenIn : OxygenFlowPort;
            port oxygenOut : OxygenFlowPort;
            port dataOut : SensorPort;
            perform action senseFlow : SenseFlow;
        }
        part def ControlModule {
            port powerIn : PowerPort;
            port oxygenSensorPort : SensorPort;
            port pressureSensorPort : SensorPort;
            port flowSensorPort : SensorPort;
            port batteryPort : SensorPort;
            port uiPort : UserInterfacePort;
            port compressorCtrlPort : ControlPort;
            port regulatorCtrlPort : ControlPort;
            port alarmPort : ControlPort;
            
            perform action processInputs;
            perform action controlCompressor;
            perform action adjustRegulator;
            perform action triggerAlarm;
        }
        part def Battery {
            port powerOut : PowerPort;
            port dataOut : SensorPort;
            port chargePort : PowerPort;
            attribute chargeLevel : Real;
            perform action discharge : ProvidePower;
            perform action charge : ProvidePower;
        }
        part def ACAdapter {
            port acInput : PowerPort;
            port dcOutput : PowerPort;
            perform action convertPower : ConvertPower;
        }
        part def UserInterface {
            port uiPort : UserInterfacePort;
            perform action getUserInput : ReadUserInput;
            perform action displayInfo : DisplayInfo;
        }
        part def AlarmUnit {
            port alarmInput : ControlPort;
            perform action soundAlarm : SoundAlarm;
        }

        part def PortableOxygenConcentrator {
            attribute mass :> ISQ::mass;
            attribute currentFlowRate :> ISQ::volumeFlowRate;
            attribute currentPurity : Real;
            attribute batteryLevel : Real;
            
            port powerInPort : PowerPort;
            port oxygenOutPort : OxygenFlowPort;
            port nitrogenOutPort : NitrogenVentPort;
            port uiPort : UserInterfacePort;
            
            part airIntake : AirIntake;
            part compressor : Compressor;
            part molecularSieve : MolecularSieve;
            part flowRegulator : FlowRegulator;
            part oxygenSensor : OxygenSensor;
            part pressureSensor : PressureSensor;
            part flowSensor : FlowSensor;
            part controlModule : ControlModule;
            part battery : Battery;
            part acAdapter : ACAdapter;
            part userInterface : UserInterface;
            part alarmUnit : AlarmUnit;
            
            connect airIntake.airOut to compressor.airIn;
            connect compressor.airOut to molecularSieve.airIn;
            connect molecularSieve.oxygenOut to flowRegulator.oxygenIn;
            connect flowRegulator.oxygenOut to oxygenSensor.oxygenIn;
            connect oxygenSensor.oxygenOut to flowSensor.oxygenIn;
            connect flowSensor.oxygenOut to oxygenOutPort;
            connect molecularSieve.nitrogenOut to nitrogenOutPort;
            connect compressor.airOut to pressureSensor.airIn;
            
            connect oxygenSensor.dataOut to controlModule.oxygenSensorPort;
            connect pressureSensor.dataOut to controlModule.pressureSensorPort;
            connect flowSensor.dataOut to controlModule.flowSensorPort;
            connect battery.dataOut to controlModule.batteryPort;
            connect userInterface.uiPort to controlModule.uiPort;
            connect controlModule.compressorCtrlPort to compressor.ctrlPort;
            connect controlModule.regulatorCtrlPort to flowRegulator.ctrlPort;
            connect controlModule.alarmPort to alarmUnit.alarmInput;
            
            connect powerInPort to acAdapter.acInput;
            connect acAdapter.dcOutput to battery.chargePort;
            connect battery.powerOut to controlModule.powerIn;
            connect battery.powerOut to compressor.powerIn;
            connect acAdapter.dcOutput to controlModule.powerIn;
            
            exhibit state operatingStates parallel {
                state operationalStates {
                    entry; then off;
                    state off;
                    transition off_to_standby
                        first off
                        accept start : StartSignal via uiPort
                        then standby;
                    state standby;
                    transition standby_to_continuous
                        first standby
                        accept setMode : SetModeSignal via uiPort if setMode.mode == "continuous"
                        then continuousFlow;
                    transition standby_to_pulse
                        first standby
                        accept setMode : SetModeSignal via uiPort if setMode.mode == "pulse"
                        then pulseDose;
                    state continuousFlow;
                    state pulseDose;
                    transition continuous_to_standby
                        first continuousFlow
                        accept setMode : SetModeSignal via uiPort if setMode.mode == "standby"
                        then standby;
                    transition pulse_to_standby
                        first pulseDose
                        accept setMode : SetModeSignal via uiPort if setMode.mode == "standby"
                        then standby;
                    transition standby_to_off
                        first standby
                        accept stop : StopSignal via uiPort
                        then off;
                    transition continuous_to_off
                        first continuousFlow
                        accept stop : StopSignal via uiPort
                        then off;
                    transition pulse_to_off
                        first pulseDose
                        accept stop : StopSignal via uiPort
                        then off;
                }
                state healthStates {
                    entry; then normal;
                    state normal;
                    state alarm;
                    transition normal_to_alarm_lowBatt
                        first normal
                        accept LowBatteryAlert
                        then alarm;
                    transition normal_to_alarm_lowPurity
                        first normal
                        accept LowPurityAlert
                        then alarm;
                    transition normal_to_alarm_highPress
                        first normal
                        accept HighPressureAlert
                        then alarm;
                    transition alarm_to_normal
                        first alarm
                        accept clear : ClearAlarmSignal via uiPort
                        then normal;
                }
            }
        }
        
        requirement def ProvideOxygen {
            doc /* The POC shall provide supplemental oxygen to the patient. */
            subject poc : PortableOxygenConcentrator;
        }
        requirement def MonitorPurity {
            doc /* The POC shall monitor oxygen purity. */
            subject poc : PortableOxygenConcentrator;
        }
        requirement def Portability {
            doc /* The POC shall be compact and battery-powered. */
            subject poc : PortableOxygenConcentrator;
        }
    }

    package Usages {
        private import Definitions::*;
        part poc : PortableOxygenConcentrator;
    }
}
