package TransdermalOxygenTherapySystem {
    private import ISQ::*;
    private import ScalarValues::*;
    
    item def Air;
    item def ConcentratedOxygen;
    item def RegulatedOxygen;
    item def ControlledOxygenFlow;
    item def SensorData {
        attribute spo2 : Real;
        attribute skinTemp : ISQ::temperature;
    }
    item def ControlCommand {
        attribute targetFlow : ISQ::volumeFlowRate;
        attribute targetPressure : ISQ::pressure;
    }
    item def ElectricalPower;
    item def StartTherapySignal;
    item def PauseTherapySignal;
    item def ResumeTherapySignal;
    item def FaultSignal;
    item def ResetSignal;
    
    port def AirInPort { in air : Air; }
    port def OxygenOutPort { out oxygen : ConcentratedOxygen; }
    port def OxygenInPort { in oxygen : ConcentratedOxygen; }
    port def RegulatedOxygenOutPort { out oxygen : RegulatedOxygen; }
    port def RegulatedOxygenInPort { in oxygen : RegulatedOxygen; }
    port def ControlledFlowOutPort { out oxygenFlow : ControlledOxygenFlow; }
    port def ControlledFlowInPort { in oxygenFlow : ControlledOxygenFlow; }
    port def SensorDataOutPort { out data : SensorData; }
    port def SensorDataInPort { in data : SensorData; }
    port def ControlCommandOutPort { out cmd : ControlCommand; }
    port def ControlCommandInPort { in cmd : ControlCommand; }
    port def PowerOutPort { out pwr : ElectricalPower; }
    port def PowerInPort { in pwr : ElectricalPower; }
    
    action def GenerateOxygen {
        in air : Air;
        out oxygen : ConcentratedOxygen;
    }
    action def RegulatePressure {
        in oxygen : ConcentratedOxygen;
        in cmd : ControlCommand;
        out regulatedOxygen : RegulatedOxygen;
    }
    action def ControlFlowAction {
        in oxygen : RegulatedOxygen;
        in cmd : ControlCommand;
        out oxygenFlow : ControlledOxygenFlow;
    }
    action def DeliverOxygen {
        in oxygenFlow : ControlledOxygenFlow;
    }
    action def MonitorPatient {
        out data : SensorData;
    }
    action def CalculateTherapy {
        in data : SensorData;
        out flowCmd : ControlCommand;
        out pressureCmd : ControlCommand;
    }
    
    part def OxygenConcentrator {
        port airIn : AirInPort;
        port o2Out : OxygenOutPort;
        port pwrIn : PowerInPort;
        attribute powerConsumption : ISQ::power = 50 [W];
        perform action generateOxygen : GenerateOxygen;
    }
    
    part def ReservoirTank {
        port o2In : OxygenInPort;
        port o2Out : OxygenOutPort;
        attribute capacity : ISQ::volume = 0.5 [L];
        attribute currentPressure : ISQ::pressure;
    }
    
    part def PressureRegulatorValve {
        port o2In : OxygenInPort;
        port o2Out : RegulatedOxygenOutPort;
        port cmdIn : ControlCommandInPort;
        port pwrIn : PowerInPort;
        attribute regulatedPressure : ISQ::pressure;
        perform action regulatePressure : RegulatePressure;
    }
    
    part def FlowControlModule {
        port o2In : RegulatedOxygenInPort;
        port flowOut : ControlledFlowOutPort;
        port cmdIn : ControlCommandInPort;
        port pwrIn : PowerInPort;
        attribute flowRate : ISQ::volumeFlowRate;
        perform action controlFlow : ControlFlowAction;
    }
    
    part def TransdermalDeliveryPatch {
        port flowIn : ControlledFlowInPort;
        attribute applicationArea : ISQ::area = 20 [cm^2];
        perform action deliverOxygen : DeliverOxygen;
    }
    
    part def PhysiologicalSensorArray {
        port dataOut : SensorDataOutPort;
        port pwrIn : PowerInPort;
        attribute spo2SensorRangeMin : Real = 70;
        attribute spo2SensorRangeMax : Real = 100;
        perform action monitorPatient : MonitorPatient;
    }
    
    part def PowerSupplyModule {
        port pwrOut : PowerOutPort;
        attribute batteryCapacity : ISQ::energy = 100 [Wh];
        attribute chargeLevel : Real;
    }
    
    part def TherapyControlUnit {
        port dataIn : SensorDataInPort;
        port flowCmdOut : ControlCommandOutPort;
        port pressureCmdOut : ControlCommandOutPort;
        port pwrIn : PowerInPort;
        
        attribute targetSpo2 : Real = 95;
        attribute maxSkinTemp : ISQ::temperature = 40 [degC];
        attribute maxPressure : ISQ::pressure = 50 [kPa];
        
        perform action calculateTherapy : CalculateTherapy;
        
        exhibit state controlStates {
            entry action initial;
            state standby;
            state activeTherapy {
                do calculateTherapy;
            }
            state paused;
            state fault;
            
            transition initial then standby;
            transition standby_to_active
                first standby
                accept StartTherapySignal
                then activeTherapy;
            transition active_to_paused
                first activeTherapy
                accept PauseTherapySignal
                then paused;
            transition paused_to_active
                first paused
                accept ResumeTherapySignal
                then activeTherapy;
            transition active_to_fault
                first activeTherapy
                accept FaultSignal
                then fault;
            transition paused_to_fault
                first paused
                accept FaultSignal
                then fault;
            transition fault_to_standby
                first fault
                accept ResetSignal
                then standby;
        }
    }
    
    part def TransdermalOxygenTherapyDevice {
        port airIn : AirInPort;
        
        part powerSupply : PowerSupplyModule;
        part concentrator : OxygenConcentrator;
        part reservoir : ReservoirTank;
        part regulator : PressureRegulatorValve;
        part flowControl : FlowControlModule;
        part patch : TransdermalDeliveryPatch;
        part sensorArray : PhysiologicalSensorArray;
        part controller : TherapyControlUnit;
        
        bind airIn = concentrator.airIn;
        
        flow powerToController of ElectricalPower
            from powerSupply.pwrOut.pwr to controller.pwrIn.pwr;
        flow powerToConcentrator of ElectricalPower
            from powerSupply.pwrOut.pwr to concentrator.pwrIn.pwr;
        flow powerToRegulator of ElectricalPower
            from powerSupply.pwrOut.pwr to regulator.pwrIn.pwr;
        flow powerToFlowControl of ElectricalPower
            from powerSupply.pwrOut.pwr to flowControl.pwrIn.pwr;
        flow powerToSensorArray of ElectricalPower
            from powerSupply.pwrOut.pwr to sensorArray.pwrIn.pwr;
        
        flow o2ToReservoir of ConcentratedOxygen
            from concentrator.o2Out.oxygen to reservoir.o2In.oxygen;
        flow o2ToRegulator of ConcentratedOxygen
            from reservoir.o2Out.oxygen to regulator.o2In.oxygen;
        flow o2ToFlowControl of RegulatedOxygen
            from regulator.o2Out.oxygen to flowControl.o2In.oxygen;
        flow o2ToPatch of ControlledOxygenFlow
            from flowControl.flowOut.oxygenFlow to patch.flowIn.oxygenFlow;
        
        flow sensorDataFlow of SensorData
            from sensorArray.dataOut.data to controller.dataIn.data;
        
        flow pressureCmdFlow of ControlCommand
            from controller.pressureCmdOut.cmd to regulator.cmdIn.cmd;
        flow flowCmdFlow of ControlCommand
            from controller.flowCmdOut.cmd to flowControl.cmdIn.cmd;
    }
    
    requirement def MaintainTherapeuticRange {
        doc /* The system shall maintain the patient's blood oxygen saturation within the desired therapeutic range. */
        attribute minSpo2 : Real = 90;
        attribute maxSpo2 : Real = 100;
        subject sensor : PhysiologicalSensorArray;
        constraint { sensor.dataOut.data.spo2 >= minSpo2 and sensor.dataOut.data.spo2 <= maxSpo2 }
    }
    
    requirement def SafetyShutdown {
        doc /* The system shall automatically shut down if skin temperature or delivery pressure exceed safe limits. */
        attribute maxSafeTemp : ISQ::temperature = 40 [degC];
        attribute maxSafePressure : ISQ::pressure = 50 [kPa];
        subject system : TransdermalOxygenTherapyDevice;
        constraint { system.sensorArray.dataOut.data.skinTemp <= maxSafeTemp and system.reservoir.currentPressure <= maxSafePressure }
    }
    
    requirement def ContinuousOperation {
        doc /* The system shall operate continuously for at least 8 hours on a single full charge. */
        attribute minDuration : ISQ::time = 8 [h];
        subject powerSupply : PowerSupplyModule;
        constraint { powerSupply.batteryCapacity >= 100 [Wh] }
    }
}
