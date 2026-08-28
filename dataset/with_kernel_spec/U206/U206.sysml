package DLT_System {
    private import ScalarValues::*;
    
    attribute def cmH2O :> Real;
    attribute def mL :> Real;
    attribute def bpm :> Real;
    attribute def percent :> Real;
    
    item def GasMixture {
        attribute oxygenFraction : percent;
        attribute volume : mL;
    }
    
    enum def VentilationMode {
        bothLungs;
        leftLungOnly;
        rightLungOnly;
    }
    
    enum def CuffState {
        deflated;
        inflated;
    }
    
    port def GasFlowPort {
        inout item gas : GasMixture;
    }
    
    port def CuffInflationPort {
        in pressure : cmH2O;
        out cuffState : CuffState;
    }
    
    interface def GasFlowInterface {
        end source : ~GasFlowPort;
        end target : GasFlowPort;
    }
    
    interface def CuffInflationInterface {
        end source : ~CuffInflationPort;
        end target : CuffInflationPort;
    }
    
    part def Cuff {
        attribute cuffState : CuffState = CuffState::deflated;
        port inflationPort : CuffInflationPort;
    }
    
    part def Lumen {
        port inflow : GasFlowPort;
        port outflow : GasFlowPort;
        flow lumenGas from inflow.gas to outflow.gas;
    }
    
    part def Lung {
        attribute isVentilated : Boolean = true;
        port airway : GasFlowPort;
    }
    
    part def DoubleLumenTube {
        part trachealLumen : Lumen;
        part bronchialLumen : Lumen;
        part trachealCuff : Cuff;
        part bronchialCuff : Cuff;
        
        port trachealProximalPort : GasFlowPort;
        port bronchialProximalPort : GasFlowPort;
        port trachealDistalPort : GasFlowPort;
        port bronchialDistalPort : GasFlowPort;
        port trachealCuffPort : ~CuffInflationPort;
        port bronchialCuffPort : ~CuffInflationPort;
        
        flow trachealProximalGas from trachealProximalPort.gas to trachealLumen.inflow.gas;
        flow trachealDistalGas from trachealLumen.outflow.gas to trachealDistalPort.gas;
        flow bronchialProximalGas from bronchialProximalPort.gas to bronchialLumen.inflow.gas;
        flow bronchialDistalGas from bronchialLumen.outflow.gas to bronchialDistalPort.gas;
        
        flow trachealCuffPressureFlow from trachealCuffPort.pressure to trachealCuff.inflationPort.pressure;
        flow bronchialCuffPressureFlow from bronchialCuffPort.pressure to bronchialCuff.inflationPort.pressure;
        flow trachealCuffStateFlow from trachealCuff.inflationPort.cuffState to trachealCuffPort.cuffState;
        flow bronchialCuffStateFlow from bronchialCuff.inflationPort.cuffState to bronchialCuffPort.cuffState;
    }
    
    part def Ventilator {
        attribute mode : VentilationMode = VentilationMode::bothLungs;
        attribute rate : bpm;
        attribute tidalVolume : mL;
        attribute peakPressure : cmH2O;
        
        port leftVentPort : GasFlowPort;
        port rightVentPort : GasFlowPort;
        
        perform action ventilate {
            out leftGas : GasMixture;
            out rightGas : GasMixture;
            
            decide selectMode;
            if mode == VentilationMode::bothLungs then deliverBoth;
            if mode == VentilationMode::leftLungOnly then deliverLeft;
            else deliverRight;
            
            action deliverBoth;
            action deliverLeft;
            action deliverRight;
        }
        
        flow leftVentGas from ventilate.leftGas to leftVentPort.gas;
        flow rightVentGas from ventilate.rightGas to rightVentPort.gas;
    }
    
    part def Patient {
        part leftLung : Lung;
        part rightLung : Lung;
        
        port leftBronchus : GasFlowPort;
        port rightBronchus : GasFlowPort;
        
        flow leftBronchialGas from leftBronchus.gas to leftLung.airway.gas;
        flow rightBronchialGas from rightBronchus.gas to rightLung.airway.gas;
    }
    
    part def DLT_MedicalSystem {
        part tube : DoubleLumenTube;
        part ventilator : Ventilator;
        part patient : Patient;
        
        interface leftVentInterface : GasFlowInterface connect ventilator.leftVentPort to tube.bronchialProximalPort {
            flow leftInterfaceGas from leftVentInterface.source.gas to leftVentInterface.target.gas;
        }
        
        interface rightVentInterface : GasFlowInterface connect ventilator.rightVentPort to tube.trachealProximalPort {
            flow rightInterfaceGas from rightVentInterface.source.gas to rightVentInterface.target.gas;
        }
        
        interface leftPatientInterface : GasFlowInterface connect tube.bronchialDistalPort to patient.leftBronchus {
            flow leftPatientGas from leftPatientInterface.source.gas to leftPatientInterface.target.gas;
        }
        
        interface rightPatientInterface : GasFlowInterface connect tube.trachealDistalPort to patient.rightBronchus {
            flow rightPatientGas from rightPatientInterface.source.gas to rightPatientInterface.target.gas;
        }
    }
    
    state def DLTProcedure {
        entry;
        then unprepared;
        
        action def PositionTube;
        action def InflateCuffs;
        action def StartVentilation;
        action def Extubate;
        
        state unprepared;
        transition unprepared_to_positioned
            first unprepared
            accept PositionTube
            then positioned;
        state positioned;
        transition positioned_to_isolated
            first positioned
            accept InflateCuffs
            then isolated;
        state isolated;
        transition isolated_to_ventilating
            first isolated
            accept StartVentilation
            then ventilating;
        state ventilating;
        transition ventilating_to_done
            first ventilating
            accept Extubate
            then done;
    }
    
    requirement def LungIsolationRequirement {
        doc /* The DLT_MedicalSystem shall isolate the left and right lungs during thoracic surgery. */
        attribute minCuffPressure : cmH2O = 20;
        attribute maxCuffPressure : cmH2O = 30;
    }
    
    requirement def SelectiveVentilationRequirement {
        doc /* The DLT_MedicalSystem shall ventilate the non-operated lung while the operated lung is collapsed. */
    }
    
    requirement def OxygenationRequirement {
        doc /* During one-lung ventilation, the ventilated lung must maintain adequate oxygenation (SpO2 > 90%). */
        attribute minSpO2 : percent = 90;
    }
    
    satisfy LungIsolationRequirement by DoubleLumenTube;
    satisfy SelectiveVentilationRequirement by Ventilator;
    satisfy OxygenationRequirement by DLT_MedicalSystem;
}
