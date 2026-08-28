package GrapheneOpticalSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def VoltageValue :> ScalarValue;
    attribute def CurrentValue :> ScalarValue;
    attribute def TemperatureValue :> ScalarValue;
    attribute def FrequencyValue :> ScalarValue;
    attribute def PowerValue :> ScalarValue;
    attribute def LengthValue :> ScalarValue;
    
    item def ElectricalSignal {
        attribute frequency : FrequencyValue;
        attribute amplitude : VoltageValue;
    }
    
    item def OpticalSignal {
        attribute wavelength : LengthValue;
        attribute intensity : PowerValue;
    }
    
    item def Heat {
        attribute temperature : TemperatureValue;
    }
    
    port def ElectricalPort {
        item electricalSignal : ElectricalSignal;
    }
    
    port def OpticalPort {
        item opticalSignal : OpticalSignal;
    }
    
    port def ThermalPort {
        item heat : Heat;
    }
    
    action def AmplifySignal {
        in signal : ElectricalSignal;
        out amplifiedSignal : ElectricalSignal;
    }
    
    action def ModulateLight {
        in control : ElectricalSignal;
        in light : OpticalSignal;
        out modulatedLight : OpticalSignal;
    }
    
    action def DissipateHeat {
        in heat1 : Heat;
        in heat2 : Heat;
    }
    
    action def MonitorTemperature {
        out temp : TemperatureValue;
    }
    
    action def MonitorCurrent {
        out current : CurrentValue;
    }
    
    attribute def CalibrateSignal;
    attribute def ActivateSignal;
    attribute def DeactivateSignal;
    attribute def ResetSignal;
    
    part def GrapheneTransistor {
        in port electricalIn : ElectricalPort;
        out port electricalOut : ElectricalPort;
        out port heatOut : ThermalPort;
        perform action amplify : AmplifySignal;
    }
    
    part def GrapheneOpticalModulator {
        in port controlIn : ElectricalPort;
        in port opticalIn : OpticalPort;
        out port opticalOut : OpticalPort;
        out port heatOut : ThermalPort;
        perform action modulate : ModulateLight;
    }
    
    part def ThermalManagementUnit {
        in port heatIn1 : ThermalPort;
        in port heatIn2 : ThermalPort;
        perform action dissipate : DissipateHeat;
    }
    
    requirement def SystemRequirement {
        doc /* The system shall convert high-speed electrical signals to optical signals using a graphene transistor and a graphene optical modulator, while maintaining temperature below 350 K and current below 0.1 A. */
    }
    
    part def GrapheneSystem {
        in port systemElectricalIn : ElectricalPort;
        in port systemOpticalIn : OpticalPort;
        out port systemOpticalOut : OpticalPort;
        
        part transistor : GrapheneTransistor;
        part modulator : GrapheneOpticalModulator;
        part thermalUnit : ThermalManagementUnit;
        
        attribute Tmax : TemperatureValue = 350;
        attribute Imax : CurrentValue = 0.1;
        
        action monitorTemp : MonitorTemperature;
        action monitorCurr : MonitorCurrent;
        
        connect systemElectricalIn to transistor.electricalIn;
        connect transistor.electricalOut to modulator.controlIn;
        connect systemOpticalIn to modulator.opticalIn;
        connect modulator.opticalOut to systemOpticalOut;
        connect transistor.heatOut to thermalUnit.heatIn1;
        connect modulator.heatOut to thermalUnit.heatIn2;
        
        satisfy requirement systemRequirement : SystemRequirement;
        
        exhibit state systemStates {
            entry; then initialization;
            state initialization;
            accept CalibrateSignal then standby;
            state standby;
            accept CalibrateSignal then calibration;
            state calibration;
            accept ActivateSignal then active;
            state active {
                do transistor.amplify;
                do modulator.modulate;
                do thermalUnit.dissipate;
                do monitorTemp { out temp; }
                do monitorCurr { out current; }
            }
            accept DeactivateSignal then standby;
            accept when monitorTemp.temp > Tmax then fault;
            accept when monitorCurr.current > Imax then fault;
            state fault;
            accept ResetSignal then initialization;
        }
    }
}
