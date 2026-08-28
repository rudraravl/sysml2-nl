package CES_Device {
    private import ScalarValues::*;
    
    attribute def StartTherapySignal;
    attribute def StopTherapySignal;
    attribute def ImpedanceOKSignal;
    attribute def ImpedanceFailSignal;
    attribute def EmergencyStopSignal;
    attribute def SafetyAlertSignal;
    attribute def AdjustClipAlertSignal;
    attribute def ResetCommand;
    
    attribute def TherapyIntensity :> Real;
    attribute def TherapyDuration :> Real;
    attribute def TherapyFrequency :> Real;
    attribute def SkinImpedance :> Real;
    attribute def MeasuredCurrent :> Real;
    
    port def PowerPort;
    port def ControlSignalPort;
    port def WaveformSignalPort;
    port def StimulationPort;
    port def SensorDataPort;
    port def DisplayDataPort;
    
    part def BatteryPack {
        port powerOut : ~PowerPort;
        attribute chargeLevel : Real;
    }
    
    part def Microcontroller {
        port powerIn : PowerPort;
        port waveformControl : ~ControlSignalPort;
        port safetyMonitorIn : SensorDataPort;
        port uiDataOut : ~DisplayDataPort;
        port uiCommandIn : ControlSignalPort;
        attribute targetIntensity : TherapyIntensity;
        attribute targetDuration : TherapyDuration;
        attribute targetFrequency : TherapyFrequency;
    }
    
    part def WaveformGenerator {
        port powerIn : PowerPort;
        port controlIn : ControlSignalPort;
        port waveformOut : ~WaveformSignalPort;
    }
    
    part def CurrentRegulator {
        port powerIn : PowerPort;
        port waveformIn : WaveformSignalPort;
        port stimulationOut : ~StimulationPort;
        port currentFeedback : ~SensorDataPort;
    }
    
    part def SafetyCircuit {
        port powerIn : PowerPort;
        port currentSensorIn : SensorDataPort;
        port impedanceSensorIn : SensorDataPort;
        port emergencyStopOut : ~ControlSignalPort;
        port alertOut : ~DisplayDataPort;
        attribute minSafeCurrent : MeasuredCurrent = 0.0;
        attribute maxSafeCurrent : MeasuredCurrent = 500.0;
        attribute maxSafeImpedance : SkinImpedance = 50.0;
    }
    
    part def EarClipElectrode {
        port stimulationIn : StimulationPort;
        port impedanceSenseOut : ~SensorDataPort;
        attribute contactImpedance : SkinImpedance;
    }
    
    part def UserInterfacePanel {
        port powerIn : PowerPort;
        port commandOut : ~ControlSignalPort;
        port displayDataIn : DisplayDataPort;
        attribute displayedRemainingTime : TherapyDuration;
        attribute activeAlert : String;
    }
    
    part def HandheldUnit {
        port electrodePortLeft : StimulationPort;
        port electrodePortRight : StimulationPort;
        
        part battery : BatteryPack;
        part microcontroller : Microcontroller;
        part waveformGenerator : WaveformGenerator;
        part currentRegulator : CurrentRegulator;
        part safetyCircuit : SafetyCircuit;
        part uiPanel : UserInterfacePanel;
        part leftElectrode : EarClipElectrode;
        part rightElectrode : EarClipElectrode;
        
        connect battery.powerOut to microcontroller.powerIn;
        connect battery.powerOut to waveformGenerator.powerIn;
        connect battery.powerOut to currentRegulator.powerIn;
        connect battery.powerOut to safetyCircuit.powerIn;
        connect battery.powerOut to uiPanel.powerIn;
        
        connect microcontroller.waveformControl to waveformGenerator.controlIn;
        connect waveformGenerator.waveformOut to currentRegulator.waveformIn;
        
        connect currentRegulator.stimulationOut to leftElectrode.stimulationIn;
        connect currentRegulator.stimulationOut to rightElectrode.stimulationIn;
        
        connect currentRegulator.currentFeedback to safetyCircuit.currentSensorIn;
        connect leftElectrode.impedanceSenseOut to safetyCircuit.impedanceSensorIn;
        connect rightElectrode.impedanceSenseOut to safetyCircuit.impedanceSensorIn;
        
        connect safetyCircuit.emergencyStopOut to microcontroller.safetyMonitorIn;
        connect safetyCircuit.alertOut to uiPanel.displayDataIn;
        
        connect uiPanel.commandOut to microcontroller.uiCommandIn;
        connect microcontroller.uiDataOut to uiPanel.displayDataIn;
    }
    
    state def CESTherapyStates {
        in device : HandheldUnit;
        in controller : Microcontroller;
        in safety : SafetyCircuit;
        in ui : UserInterfacePanel;
        
        entry; then off;
        
        state off;
        accept StartTherapySignal then impedanceCheck;
        
        state impedanceCheck;
        accept ImpedanceOKSignal then running;
        accept ImpedanceFailSignal
            do send new AdjustClipAlertSignal() to ui
            then off;
        
        state running {
            do action deliverTherapy { /* Continuously regulate current based on skin impedance */ }
            exit action stopStimulation { /* Gradually ramp down current */ }
        }
        accept EmergencyStopSignal then emergencyStop;
        accept StopTherapySignal then off;
        
        state emergencyStop;
        accept ResetCommand then off;
    }
    
    requirement def TherapyParameterRequirement {
        doc /* Requirement for configurable therapy parameters */
        subject therapyDevice : HandheldUnit;
        constraint { therapyDevice.microcontroller.targetIntensity >= 0.0 and therapyDevice.microcontroller.targetIntensity <= 500.0 }
        constraint { therapyDevice.microcontroller.targetDuration >= 0.0 and therapyDevice.microcontroller.targetDuration <= 3600000.0 }
        constraint { therapyDevice.microcontroller.targetFrequency >= 0.5 and therapyDevice.microcontroller.targetFrequency <= 100.0 }
    }
    
    requirement def SafetyRequirement {
        doc /* Safety requirements for CES device */
        subject safetyCircuit : SafetyCircuit;
        constraint { safetyCircuit.maxSafeImpedance <= 50.0 }
        constraint { safetyCircuit.maxSafeCurrent <= 500.0 }
    }
    
    requirement def UserInterfaceRequirement {
        doc /* UI requirements for CES device */
        subject uiPanel : UserInterfacePanel;
    }
    
    requirement cesDeviceSpecification {
        doc /* Overall CES device requirements group */
        subject device : HandheldUnit;
        requirement therapyParams : TherapyParameterRequirement { subject = device; }
        requirement safetySpec : SafetyRequirement { subject = device.safetyCircuit; }
        requirement uiSpec : UserInterfaceRequirement { subject = device.uiPanel; }
    }
    
    part cesDevice : HandheldUnit {
        exhibit therapyStates : CESTherapyStates {
            in device = cesDevice;
            in controller = cesDevice.microcontroller;
            in safety = cesDevice.safetyCircuit;
            in ui = cesDevice.uiPanel;
        }
        satisfy cesDeviceSpecification;
    }
}
