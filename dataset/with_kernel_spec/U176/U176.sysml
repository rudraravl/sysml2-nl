package BubbleOxygenatorSystemModel {
    private import ScalarValues::*;
    private import ISQ::*;
    
    item def Blood;
    item def VenousBlood :> Blood;
    item def OxygenatedBlood :> Blood;
    item def OxygenGas;
    item def WasteGas;
    
    attribute def BloodTemperatureValue :> TemperatureValue;
    attribute def FlowRateValue :> VolumeFlowRateValue;
    attribute def O2SaturationValue :> Real;
    attribute def CO2LevelValue :> Real;
    
    port def BloodInPort {
        in blood: Blood;
    }
    port def BloodOutPort {
        out blood: Blood;
    }
    port def GasInPort {
        in gas: OxygenGas;
    }
    port def GasOutPort {
        out gas: WasteGas;
    }
    port def OxygenGasOutPort {
        out gas: OxygenGas;
    }
    port def ControlInPort {
        in targetTemp: BloodTemperatureValue;
        in targetFlow: FlowRateValue;
    }
    port def MonitorOutPort {
        out o2Saturation: O2SaturationValue;
        out co2Level: CO2LevelValue;
    }
    
    action def GenerateBubbles {
        in oxygen: OxygenGas;
        out bubbles: OxygenGas;
    }
    action def PerformGasExchange {
        in venousBlood: VenousBlood;
        in oxygenBubbles: OxygenGas;
        out oxygenatedBlood: OxygenatedBlood;
    }
    action def RemoveBubbles {
        in bubblyBlood: OxygenatedBlood;
        out cleanBlood: OxygenatedBlood;
        out wasteGas: WasteGas;
    }
    action def RegulateTemperatureAction {
        out temp: BloodTemperatureValue;
    }
    action def RegulateFlowAction {
        out rate: FlowRateValue;
    }
    action def MonitorBloodAction {
        in blood: OxygenatedBlood;
        out o2: O2SaturationValue;
        out co2: CO2LevelValue;
    }
    
    part def BubbleGenerationModule {
        port gasIn: GasInPort;
        port bubbleOut: OxygenGasOutPort;
        perform action generateBubbles: GenerateBubbles;
    }
    
    part def OxygenationColumn {
        port bloodIn: BloodInPort;
        port bubbleIn: GasInPort;
        port bloodOut: BloodOutPort;
        port controlIn: ~ControlInPort;
        perform action gasExchange: PerformGasExchange;
    }
    
    part def DefoamingUnit {
        port bloodIn: BloodInPort;
        port bloodOut: BloodOutPort;
        port gasOut: GasOutPort;
        perform action removeBubbles: RemoveBubbles;
    }
    
    part def TemperatureControlUnit {
        port bloodIn: BloodInPort;
        port bloodOut: BloodOutPort;
        port controlIn: ~ControlInPort;
        perform action regulateTemp: RegulateTemperatureAction;
    }
    
    part def FlowRegulator {
        port bloodIn: BloodInPort;
        port bloodOut: BloodOutPort;
        port controlIn: ~ControlInPort;
        perform action regulateFlow: RegulateFlowAction;
    }
    
    part def OxygenationMonitor {
        port bloodSamplePort: BloodInPort;
        port feedbackPort: MonitorOutPort;
        perform action monitorBlood: MonitorBloodAction;
    }
    
    requirement def OxygenationRequirement {
        doc /* The system shall oxygenate venous blood to an O2 saturation of at least 95%. */
    }
    requirement def DefoamingRequirement {
        doc /* The system shall remove all gas bubbles from the oxygenated blood. */
    }
    requirement def TemperatureControlRequirement {
        doc /* The system shall maintain blood temperature within a safe physiological range. */
    }
    requirement def FlowRegulationRequirement {
        doc /* The system shall regulate blood flow rate appropriate for the patient. */
    }
    requirement def MonitoringRequirement {
        doc /* The system shall continuously monitor O2 and CO2 levels in the outgoing blood. */
    }
    
    attribute def StartSignal;
    attribute def StopSignal;
    
    part def BubbleOxygenatorSystem {
        port venousBloodIn: BloodInPort;
        port arterialBloodOut: BloodOutPort;
        port oxygenIn: GasInPort;
        port exhaustGasOut: GasOutPort;
        port controlIn: ControlInPort;
        port monitorOut: MonitorOutPort;
        
        part bubbleGenerator: BubbleGenerationModule;
        part oxygenationColumn: OxygenationColumn;
        part defoamingUnit: DefoamingUnit;
        part tempControl: TemperatureControlUnit;
        part flowRegulator: FlowRegulator;
        part o2Monitor: OxygenationMonitor;
        
        requirement oxygenationReq: OxygenationRequirement;
        requirement defoamingReq: DefoamingRequirement;
        requirement tempControlReq: TemperatureControlRequirement;
        requirement flowRegulationReq: FlowRegulationRequirement;
        requirement monitoringReq: MonitoringRequirement;
        
        connect venousBloodIn to flowRegulator.bloodIn;
        connect flowRegulator.bloodOut to oxygenationColumn.bloodIn;
        connect oxygenIn to bubbleGenerator.gasIn;
        connect bubbleGenerator.bubbleOut to oxygenationColumn.bubbleIn;
        connect oxygenationColumn.bloodOut to defoamingUnit.bloodIn;
        connect defoamingUnit.bloodOut to tempControl.bloodIn;
        connect tempControl.bloodOut to arterialBloodOut;
        connect tempControl.bloodOut to o2Monitor.bloodSamplePort;
        connect defoamingUnit.gasOut to exhaustGasOut;
        connect controlIn to flowRegulator.controlIn;
        connect controlIn to tempControl.controlIn;
        connect o2Monitor.feedbackPort to monitorOut;
        
        flow venousBloodFlow of VenousBlood 
            from venousBloodIn.blood to flowRegulator.bloodIn.blood;
        flow regulatedVenousFlow of VenousBlood
            from flowRegulator.bloodOut.blood to oxygenationColumn.bloodIn.blood;
        flow oxygenFlow of OxygenGas 
            from oxygenIn.gas to bubbleGenerator.gasIn.gas;
        flow bubbleFlow of OxygenGas 
            from bubbleGenerator.bubbleOut.gas to oxygenationColumn.bubbleIn.gas;
        flow oxygenatedBloodFlow of OxygenatedBlood 
            from oxygenationColumn.bloodOut.blood to defoamingUnit.bloodIn.blood;
        flow cleanBloodFlow of OxygenatedBlood 
            from defoamingUnit.bloodOut.blood to tempControl.bloodIn.blood;
        flow tempRegulatedFlow of OxygenatedBlood 
            from tempControl.bloodOut.blood to arterialBloodOut.blood;
        flow sampleFlow of OxygenatedBlood 
            from tempControl.bloodOut.blood to o2Monitor.bloodSamplePort.blood;
        flow wasteGasFlow of WasteGas 
            from defoamingUnit.gasOut.gas to exhaustGasOut.gas;
        
        satisfy oxygenationReq by oxygenationColumn;
        satisfy defoamingReq by defoamingUnit;
        satisfy tempControlReq by tempControl;
        satisfy flowRegulationReq by flowRegulator;
        satisfy monitoringReq by o2Monitor;
        
        exhibit state operationalState {
            state idle;
            state running;
            transition idle_to_running first idle accept StartSignal then running;
            transition running_to_idle first running accept StopSignal then idle;
        }
    }
}
