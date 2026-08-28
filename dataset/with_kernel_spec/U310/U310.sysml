package MENSDevice {
    private import ScalarValues::*;

    package Definitions {
        package PortDefinitions {
            port def PowerPort {
                out voltage : Real;
                out current : Real;
            }
            port def UIPort {
                out parameters : TherapyParameters;
                in status : DeviceStatus;
            }
            port def ControlPort {
                out parameters : TherapyParameters;
            }
            port def PulsePort {
                out pulses : PulseSignal;
            }
            port def RegulatedPort {
                out current : Real;
                out voltage : Real;
            }
            port def MonitorPort {
                in current : Real;
                in voltage : Real;
            }
            port def FaultPort {
                in fault : FaultSignal;
            }
            port def ElectrodePort {
                inout current : Real;
                inout voltage : Real;
                out impedance : Real;
            }
            port def ImpedancePort {
                in impedance : Real;
            }
        }

        package ItemDefinitions {
            item def TherapyParameters {
                attribute intensity : Real;
                attribute frequency : Real;
                attribute pulseWidth : Real;
                attribute duration : Real;
                attribute mode : TherapyMode;
            }
            item def DeviceStatus {
                attribute batteryLevel : Real;
                attribute therapyProgress : Real;
                attribute deviceState : DeviceStateEnum;
            }
            item def PulseSignal {
                attribute amplitude : Real;
                attribute frequency : Real;
                attribute pulseWidth : Real;
                attribute mode : TherapyMode;
            }
            item def FaultSignal {
                attribute faultType : FaultType;
                attribute faultMessage : String;
            }
            enum def TherapyMode { continuous; burst; modulated; }
            enum def DeviceStateEnum { off; idle; selfTest; ready; therapyActive; fault; }
            enum def FaultType { overCurrent; overVoltage; electrodeDetached; impedanceOutOfRange; }
        }

        package SignalDefinitions {
            attribute def PowerOn;
            attribute def StartTherapy;
            attribute def StopTherapy;
            attribute def TherapyComplete;
            attribute def FaultOccurred;
            attribute def Reset;
            attribute def SelfTestPass;
            attribute def SelfTestFail;
            attribute def ContactOK;
            attribute def ContactFail;
        }

        package ActionDefinitions {
            private import PortDefinitions::*;
            private import ItemDefinitions::*;

            action def SetParameters {
                in params : TherapyParameters;
                out status : DeviceStatus;
            }
            action def PerformSelfTest {
                out result : Boolean;
            }
            action def CheckElectrodeContact {
                in impedance : Real;
                out contactOK : Boolean;
            }
            action def DeliverPulses {
                in params : TherapyParameters;
                out pulses : PulseSignal;
            }
            action def MonitorSafety {
                in current : Real;
                in voltage : Real;
                out fault : FaultSignal;
            }
            action def RegulateCurrent {
                in targetCurrent : Real;
                in impedance : Real;
                out regulatedCurrent : Real;
            }
            action def SenseImpedance {
                in electrodePort : ElectrodePort;
                out impedance : Real;
            }
            action def DisplayStatus {
                in status : DeviceStatus;
            }
            action def GetUserInput {
                out params : TherapyParameters;
            }
            action def StopTherapy {
                out status : DeviceStatus;
            }
        }

        package StateDefinitions {
            private import SignalDefinitions::*;

            state def DeviceStates {
                entry; then off;
                state off;
                accept PowerOn then idle;
                state idle;
                accept StartTherapy then selfTest;
                state selfTest;
                accept SelfTestPass then ready;
                accept SelfTestFail then fault;
                state ready;
                accept ContactOK then therapyActive;
                accept ContactFail then fault;
                state therapyActive;
                accept TherapyComplete then idle;
                accept FaultOccurred then fault;
                state fault;
                accept Reset then idle;
            }
        }

        package PartDefinitions {
            private import PortDefinitions::*;
            private import ItemDefinitions::*;
            private import SignalDefinitions::*;
            private import ActionDefinitions::*;
            private import StateDefinitions::*;

            part def MENSDevice {
                port powerIn : PowerPort;
                port uiPort : UIPort;
                port electrodePort : ElectrodePort;
                port faultIn : FaultPort;
                perform action setParameters : SetParameters;
                perform action performSelfTest : PerformSelfTest;
                perform action checkElectrodeContact : CheckElectrodeContact;
                perform action deliverPulses : DeliverPulses;
                perform action monitorSafety : MonitorSafety;
                perform action regulateCurrent : RegulateCurrent;
                perform action senseImpedance : SenseImpedance;
                perform action stopTherapy : StopTherapy;
                exhibit state deviceStates : DeviceStates;
            }
            part def BatteryModule {
                port powerOut : PowerPort;
                attribute capacity : Real = 2000.0;
                attribute nominalVoltage : Real = 3.7;
            }
            part def UserInterface {
                port uiPort : UIPort;
                perform action displayStatus : DisplayStatus;
                perform action getUserInput : GetUserInput;
            }
            part def PulseGenerator {
                port controlIn : ControlPort;
                port pulseOut : PulsePort;
                attribute mode : TherapyMode;
            }
            part def CurrentRegulator {
                port pulseIn : PulsePort;
                port regulatedOut : RegulatedPort;
                port feedbackIn : ImpedancePort;
            }
            part def SafetyMonitor {
                port monitorIn : MonitorPort;
                port faultOut : FaultPort;
                attribute maxCurrent : Real = 10.0;
                attribute maxVoltage : Real = 50.0;
            }
            part def ElectrodeAssembly {
                port electrodeIn : RegulatedPort;
                port electrodeContact : ElectrodePort;
            }
            part def ImpedanceSensor {
                port senseIn : ElectrodePort;
                port impedanceOut : ImpedancePort;
            }
        }

        package RequirementDefinitions {
            requirement def SafetyShutoff {
                doc /* The device shall stop therapy if the delivered current exceeds 10 mA or voltage exceeds 50 V. */
                attribute maxCurrent : Real = 10.0;
                attribute maxVoltage : Real = 50.0;
            }
            requirement def ElectrodeContactCheck {
                doc /* The device shall check electrode impedance before starting therapy and stop if impedance > 5 kOhm. */
                attribute maxImpedance : Real = 5000.0;
            }
            requirement def TherapyAccuracy {
                doc /* The delivered current shall be within 5 percent of the set intensity. */
                attribute tolerance : Real = 0.05;
            }
        }
    }

    package Usages {
        private import Definitions::*;
        private import Definitions::PortDefinitions::*;
        private import Definitions::ItemDefinitions::*;
        private import Definitions::SignalDefinitions::*;
        private import Definitions::ActionDefinitions::*;
        private import Definitions::StateDefinitions::*;
        private import Definitions::PartDefinitions::*;
        private import Definitions::RequirementDefinitions::*;

        part mensDevice : MENSDevice {
            part battery : BatteryModule;
            part ui : UserInterface;
            part pulseGen : PulseGenerator;
            part currentReg : CurrentRegulator;
            part safetyMon : SafetyMonitor;
            part electrodes : ElectrodeAssembly;
            part impedanceSens : ImpedanceSensor;

            bind mensDevice.powerIn = battery.powerOut;
            bind mensDevice.uiPort = ui.uiPort;
            bind mensDevice.electrodePort = electrodes.electrodeContact;
            bind mensDevice.faultIn = safetyMon.faultOut;

            flow controlFlow of TherapyParameters
                from ui.uiPort.parameters
                to pulseGen.controlIn.parameters;
            flow pulseFlow of PulseSignal
                from pulseGen.pulseOut.pulses
                to currentReg.pulseIn.pulses;
            flow regulatedCurrentFlow of Real
                from currentReg.regulatedOut.current
                to electrodes.electrodeIn.current;
            flow regulatedVoltageFlow of Real
                from currentReg.regulatedOut.voltage
                to electrodes.electrodeIn.voltage;
            bind impedanceSens.senseIn = electrodes.electrodeContact;
            flow impedanceFlow of Real
                from impedanceSens.impedanceOut.impedance
                to currentReg.feedbackIn.impedance;
            flow safetyCurrentFlow of Real
                from currentReg.regulatedOut.current
                to safetyMon.monitorIn.current;
            flow safetyVoltageFlow of Real
                from currentReg.regulatedOut.voltage
                to safetyMon.monitorIn.voltage;

            state deviceStates : DeviceStates {
                in operatingDevice : MENSDevice = mensDevice;
                in controller : MENSDevice = mensDevice;
            }
        }

        requirement safetyShutoffReq : SafetyShutoff {
            doc /* The MENS device shall immediately cease therapy output when monitored current exceeds 10 mA or voltage exceeds 50 V. */
        }
        requirement electrodeContactReq : ElectrodeContactCheck {
            doc /* The MENS device shall verify electrode impedance is below 5 kOhm before initiating therapy and shall halt if exceeded. */
        }
        requirement therapyAccuracyReq : TherapyAccuracy {
            doc /* The MENS device shall regulate delivered current to within 5 percent of the user-specified intensity under varying load impedance. */
        }
    }
}
