package 'IV Therapy System' {
    private import ScalarValues::*;
    
    attribute def VolumeValue :> Real;
    attribute def FlowRateValue :> Real;
    attribute def PressureValue :> Real;
    attribute def DurationValue :> Real;
    
    item def Fluid;
    item def Infusate :> Fluid {
        attribute medicationName : String;
    }
    item def SalineSolution :> Fluid;
    item def Blood :> Fluid;
    item def BloodSample :> Blood;
    item def WasteBlood :> Blood;
    
    port def FluidPort {
        inout fluid : Fluid;
    }
    port def FluidInletPort {
        in fluid : Fluid;
    }
    port def FluidOutletPort {
        out fluid : Fluid;
    }
    port def PressureOutPort {
        out pressure : PressureValue;
    }
    port def PressureInPort {
        in pressure : PressureValue;
    }
    
    requirement def BiocompatibleMaterials {
        attribute material : String;
        constraint { material == "polyurethane" }
    }
    requirement def NeedlestickPrevention {
        attribute retracted : Boolean;
        constraint { retracted }
    }
    requirement def AccurateFlowControl {
        attribute deliveredRate : FlowRateValue;
        attribute programmedRate : FlowRateValue;
        constraint { deliveredRate >= 0.95 * programmedRate and deliveredRate <= 1.05 * programmedRate }
    }
    requirement def OcclusionDetection {
        attribute currentPressure : PressureValue;
        attribute threshold : PressureValue = 40000.0;
        constraint { currentPressure <= threshold }
    }
    requirement def MaintainPatency {
        attribute flushInterval : DurationValue;
        constraint { flushInterval <= 8.0 }
    }
    
    part def Vein {
        attribute veinName : String;
    }
    part def Patient {
        part veins : Vein[2..*];
        port veinAccess : FluidInletPort;
    }
    
    part def VenousCatheter {
        attribute material : String = "polyurethane";
        attribute gauge : Integer;
        attribute length : Real;
        attribute deployed : Boolean = false;
        port hubConnection : FluidInletPort;
        port veinConnection : FluidOutletPort;
    }
    
    part def SafetyNeedle {
        attribute retracted : Boolean = false;
        action engageRetraction;
        ref guidesCatheter : VenousCatheter;
    }
    
    part def Hub {
        port infusionPort : FluidInletPort;
        port bloodDrawPort : FluidPort;
        port flushPort : FluidPort;
        port toCatheter : FluidOutletPort;
    }
    
    part def VenousAccessDevice {
        part catheter : VenousCatheter;
        part safetyNeedle : SafetyNeedle;
        part hub : Hub;
        connect hub.toCatheter to catheter.hubConnection;
    }
    
    part def FlowRegulator {
        attribute currentFlowRate : FlowRateValue;
        attribute commandedFlowRate : FlowRateValue;
        port flowInPort : FluidInletPort;
        port flowOutPort : FluidOutletPort;
        port pressureOutPort : PressureOutPort;
    }
    
    part def PressureSensor {
        attribute currentPressure : PressureValue;
        attribute threshold : PressureValue = 40000.0;
        port pressureInPort : PressureInPort;
    }
    
    part def InfusionPump {
        attribute batteryLevel : Real;
        attribute totalVolumeDelivered : VolumeValue = 0.0;
        attribute programmedVolume : VolumeValue;
        attribute programmedFlowRate : FlowRateValue;
        attribute alarmActive : Boolean = false;
        
        part regulator : FlowRegulator;
        part sensor : PressureSensor;
        
        port fluidInPort : FluidInletPort;
        port fluidOutPort : FluidOutletPort;
    }
    
    part def Tubing {
        port pumpEnd : FluidInletPort;
        port hubEnd : FluidOutletPort;
    }
    
    part def FluidSource {
        attribute totalVolume : VolumeValue;
        attribute remainingVolume : VolumeValue;
        port outlet : FluidOutletPort;
    }
    
    part def IVTherapySystem {
        part patient : Patient;
        part accessDevice : VenousAccessDevice;
        part pump : InfusionPump;
        part tubing : Tubing;
        part fluidSource : FluidSource;
        
        connect fluidSource.outlet to pump.fluidInPort;
        connect pump.fluidOutPort to tubing.pumpEnd;
        connect tubing.hubEnd to accessDevice.hub.infusionPort;
        connect accessDevice.hub.toCatheter to accessDevice.catheter.hubConnection;
        connect accessDevice.catheter.veinConnection to patient.veinAccess;
        connect pump.regulator.pressureOutPort to pump.sensor.pressureInPort;
    }
    
    action def LocateVeinAction;
    action def ConfirmBloodReturnAction;
    action def AdvanceCatheterAction;
    
    action def InsertCatheterAction {
        action locateVein : LocateVeinAction;
        then action insertNeedle;
        then action confirmBloodReturn : ConfirmBloodReturnAction;
        then action advanceCatheter : AdvanceCatheterAction;
        then action withdrawAndRetract;
    }
    
    action def AdministerInfusionAction {
        action programPump;
        then action startPump;
        then action monitorPressure;
        then action stopPump;
    }
    
    action def AspirateFluidAction;
    action def FlushCatheterAction;
    
    action def DrawBloodSampleAction {
        action discardInitialVolume : AspirateFluidAction;
        then action collectSample : AspirateFluidAction;
        then action flushWithSaline : FlushCatheterAction;
    }
    
    action def RemoveCatheterAction;
    action def DisposeAction;
    
    state def IVSystemLifecycle {
        entry;
        then packaged;
        
        state packaged;
        transition packaged_to_locating first packaged accept LocateVeinAction then locating;
        
        state locating;
        transition locating_to_inserting first locating accept InsertCatheterAction then inserting;
        
        state inserting;
        transition inserting_to_confirming first inserting accept ConfirmBloodReturnAction then confirming;
        
        state confirming;
        transition confirming_to_deployed first confirming accept AdvanceCatheterAction then deployed;
        
        state deployed;
        transition deployed_to_removing first deployed accept RemoveCatheterAction then removing;
        
        state removing;
        transition removing_to_disposed first removing accept DisposeAction then disposed;
        
        state disposed;
    }
    
    individual def TypicalPatient :> Patient {
        part vein_cephalic : Vein { :>> veinName = "cephalic"; }
        part vein_antecubital : Vein { :>> veinName = "antecubital"; }
    }
    
    individual def NormalSalineBag :> FluidSource {
        :>> totalVolume = 1000.0;
        :>> remainingVolume = 1000.0;
    }
    
    individual def TypicalAccessDevice :> VenousAccessDevice;
    individual def TypicalPump :> InfusionPump;
    
    individual def TypicalIVSystem :> IVTherapySystem {
        part accessDevice :>> TypicalAccessDevice;
        part pump :>> TypicalPump;
        part fluidSource :>> NormalSalineBag;
        part patient :>> TypicalPatient;
    }
    
    individual typicalUse : TypicalIVSystem {
        action locateVeinAction : LocateVeinAction;
        action insertCatheterAction : InsertCatheterAction;
        action administerInfusionAction : AdministerInfusionAction;
        action drawBloodSampleAction : DrawBloodSampleAction;
        action flushCatheterAction : FlushCatheterAction;
        action removeCatheterAction : RemoveCatheterAction;
        action disposeAction : DisposeAction;
        
        timeslice setup {
            perform locateVeinAction;
            then perform insertCatheterAction;
        }
        then timeslice infusion {
            perform administerInfusionAction;
        }
        then timeslice bloodDraw {
            perform drawBloodSampleAction;
        }
        then timeslice maintenance {
            perform flushCatheterAction;
        }
        then timeslice removal {
            perform removeCatheterAction;
            then perform disposeAction;
        }
    }
}
