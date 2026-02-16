package 'DripChamberInfusionSystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def FluidTypeAttribute;
    attribute def DropSizeAttribute;
    
    attribute def FlowRateValue :> Real;
    attribute def DropRateValue :> Real;
    attribute def VolumeValue :> Real;
    attribute def PressureValue :> Real;
    attribute def LengthValue :> Real;
    
    item def IntravenousFluid {
        attribute fluidType : FluidTypeAttribute;
        attribute volume : VolumeValue;
        attribute viscosity : Real;
        attribute sterile : Boolean;
    }
    
    port def FluidInletPort {
        in item fluid : IntravenousFluid;
        attribute inletPressure : PressureValue;
    }
    
    port def FluidOutletPort {
        out item fluid : IntravenousFluid;
        attribute outletFlowRate : FlowRateValue;
    }
    
    port def MonitoringPort {
        out attribute dropRate : DropRateValue;
        out attribute chamberLevel : LengthValue;
        out attribute alarmStatus : AlarmCondition;
    }
    
    part def IVBag {
        doc /* Sterile fluid reservoir suspended above the drip chamber */
        attribute capacity : VolumeValue;
        attribute currentVolume : VolumeValue;
        attribute height : LengthValue;
        port outlet : FluidOutletPort;
        
        constraint volumeLimit {
            currentVolume <= capacity
        }
    }
    
    part def DripChamber {
        doc /* Transparent chamber that forms visible drops for flow rate monitoring */
        attribute chamberVolume : VolumeValue;
        attribute dropFactor : Real;
        attribute currentFillLevel : LengthValue;
        attribute minFillLevel : LengthValue;
        attribute maxFillLevel : LengthValue;
        
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
        port monitor : MonitoringPort;
        
        part transparentBody : ChamberBody {
            attribute material : String = "medical-grade plastic";
            attribute transparency : Real = 1.0;
        }
        
        part dropOrifice : DropFormationDevice {
            attribute orificeSize : LengthValue;
            attribute dropSize : DropSizeAttribute;
        }
        
        part airFilter : AirVent {
            attribute filterPoreSize : LengthValue;
            attribute isOpen : Boolean = true;
        }
        
        constraint fillLevelRange {
            currentFillLevel >= minFillLevel and currentFillLevel <= maxFillLevel
        }
    }
    
    part def ChamberBody {
        attribute material : String;
        attribute transparency : Real;
        attribute internalVolume : VolumeValue;
    }
    
    part def DropFormationDevice {
        attribute orificeSize : LengthValue;
        attribute dropSize : DropSizeAttribute;
        attribute surfaceTension : Real;
    }
    
    part def AirVent {
        attribute filterPoreSize : LengthValue;
        attribute isOpen : Boolean;
        attribute allowsAirflow : Boolean = true;
    }
    
    part def FlowControlClamp {
        doc /* Manual roller clamp for adjusting flow rate */
        attribute clampPosition : Real;
        attribute minPosition : Real = 0.0;
        attribute maxPosition : Real = 1.0;
        attribute currentRestriction : Real;
        
        constraint positionRange {
            clampPosition >= minPosition and clampPosition <= maxPosition
        }
    }
    
    part def DeliveryTubing {
        doc /* Flexible tubing connecting drip chamber to patient */
        attribute tubeLength : LengthValue;
        attribute innerDiameter : LengthValue;
        attribute flowResistance : Real;
        
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
        
        part clamp : FlowControlClamp;
    }
    
    part def PatientConnection {
        doc /* Catheter interface for patient delivery */
        attribute connectionType : String;
        attribute isSecure : Boolean;
        port inlet : FluidInletPort;
    }
    
    action def FormDrops {
        in fluidInput : IntravenousFluid;
        in gravityPressure : PressureValue;
        in orificeSize : LengthValue;
        out dropFormed : Boolean;
        out dropVolume : VolumeValue;
    }
    
    action def CountDrops {
        in observationPeriod : Real;
        in dropEvents : Integer;
        out dropRate : DropRateValue;
        out calculatedFlowRate : FlowRateValue;
    }
    
    action def MonitorChamberLevel {
        in currentLevel : LengthValue;
        in minLevel : LengthValue;
        in maxLevel : LengthValue;
        out levelStatus : String;
        out alarm : AlarmCondition;
    }
    
    action def AdjustFlowRate {
        in targetFlowRate : FlowRateValue;
        in currentFlowRate : FlowRateValue;
        in currentClampPosition : Real;
        out newClampPosition : Real;
    }
    
    action def DeliverInfusion {
        doc /* Primary action coordinating fluid delivery through the system */
        in prescribedRate : FlowRateValue;
        in totalVolume : VolumeValue;
        out deliveredVolume : VolumeValue;
        out actualRate : FlowRateValue;
        
        first start;
        then merge continuousDelivery;
        
        then action monitorLevel : MonitorChamberLevel {
            in currentLevel : LengthValue;
            in minLevel : LengthValue;
            in maxLevel : LengthValue;
            out levelStatus : String;
            out alarm : AlarmCondition;
        }
        
        then decide;
            if monitorLevel.alarm == AlarmCondition::chamberEmpty then handleEmptyChamber;
            if monitorLevel.alarm == AlarmCondition::chamberOverfilled then handleOverfill;
            if monitorLevel.alarm == AlarmCondition::none then countAndDeliver;
        
        action handleEmptyChamber : GenerateAlarm {
            in alarmType = AlarmCondition::chamberEmpty;
        }
        then done;
        
        action handleOverfill : GenerateAlarm {
            in alarmType = AlarmCondition::chamberOverfilled;
        }
        then done;
        
        action countAndDeliver {
            action countDrops : CountDrops {
                in observationPeriod : Real;
                in dropEvents : Integer;
                out dropRate : DropRateValue;
                out calculatedFlowRate : FlowRateValue;
            }
            then action adjustFlow : AdjustFlowRate {
                in targetFlowRate = prescribedRate;
                in currentFlowRate = countDrops.calculatedFlowRate;
                in currentClampPosition : Real;
                out newClampPosition : Real;
            }
        }
        then continuousDelivery;
    }
    
    action def GenerateAlarm {
        in alarmType : AlarmCondition;
    }
    
    enum def AlarmCondition {
        enum none;
        enum chamberEmpty;
        enum chamberOverfilled;
        enum flowTooSlow;
        enum flowTooFast;
        enum airInLine;
    }
    
    action def PrimeSystem {
        in fluidSource : IntravenousFluid;
        out chamberPrimed : Boolean;
        out lineCleared : Boolean;
    }
    
    attribute def StartPriming;
    attribute def StartInfusion;
    attribute def PauseInfusion;
    attribute def ResumeInfusion;
    attribute def StopInfusion;
    attribute def AcknowledgeAlarm;
    attribute def ResetSystem;
    
    part dripChamberInfusionSystem {
        doc /* Complete gravity-fed IV infusion system with drip chamber for controlled fluid delivery */
        
        part ivBag : IVBag {
            attribute :>> capacity = 1000.0;
            attribute :>> currentVolume = 1000.0;
            attribute :>> height = 1.5;
        }
        
        part dripChamber : DripChamber {
            attribute :>> chamberVolume = 20.0;
            attribute :>> dropFactor = 20.0;
            attribute :>> currentFillLevel = 10.0;
            attribute :>> minFillLevel = 5.0;
            attribute :>> maxFillLevel = 15.0;
        }
        
        part tubing : DeliveryTubing {
            attribute :>> tubeLength = 2.0;
            attribute :>> innerDiameter = 0.004;
            attribute :>> flowResistance = 0.5;
        }
        
        part patientConnection : PatientConnection {
            attribute :>> connectionType = "luer lock";
            attribute :>> isSecure = true;
        }
        
        connect ivBag.outlet to dripChamber.inlet;
        connect dripChamber.outlet to tubing.inlet;
        connect tubing.outlet to patientConnection.inlet;
        
        perform action deliveryAction : DeliverInfusion {
            in prescribedRate : FlowRateValue;
            in totalVolume : VolumeValue;
            out deliveredVolume : VolumeValue;
            out actualRate : FlowRateValue;
        }
    }
    
    state def InfusionSystemStates {
        entry; then idle;
        
        state idle {
            doc /* System is prepared but not actively infusing */
        }
        
        accept StartPriming
        then state priming {
            doc /* Filling drip chamber and purging air from tubing */
            do action primingAction : PrimeSystem;
        }
        
        accept when primingAction.chamberPrimed and primingAction.lineCleared
        then state ready {
            doc /* System primed and ready to begin infusion */
        }
        
        accept StartInfusion
        then state infusing {
            doc /* Active fluid delivery to patient */
            
            state normalFlow {
                do action deliverFluid : DeliverInfusion;
            }
            
            state adjustingFlow {
                do action adjustRate : AdjustFlowRate;
            }
        }
        
        accept PauseInfusion
        then state paused {
            doc /* Infusion temporarily stopped by user */
        }
        
        accept ResumeInfusion
        then infusing;
        
        accept StopInfusion
        then state stopped {
            doc /* Infusion completed or terminated */
        }
        
        accept ResetSystem
        then idle;
    }
    
    requirement def <'REQ-DC-001'> PrimaryFunctionRequirement {
        doc /* The drip chamber infusion system shall deliver intravenous fluids to a patient 
               at a controlled, gravity-driven flow rate with visual monitoring capability. */
        
        subject system : dripChamberInfusionSystem;
        
        require constraint controlledDelivery {
            doc /* System must maintain flow rate within acceptable tolerance */
            system.deliveryAction.actualRate >= system.deliveryAction.prescribedRate * 0.9 and
            system.deliveryAction.actualRate <= system.deliveryAction.prescribedRate * 1.1
        }
        
        require constraint visualMonitoring {
            doc /* Drip chamber must allow visual drop counting */
            system.dripChamber.transparentBody.transparency >= 0.95
        }
        
        require constraint sterileFluidPath {
            doc /* All fluid contact surfaces must maintain sterility */
            system.ivBag.outlet.fluid.sterile == true
        }
    }
    
    requirement def <'REQ-DC-002'> DropFormationRequirement {
        doc /* The drip chamber shall form discrete, countable drops for accurate flow monitoring. */
        
        subject chamber : DripChamber;
        
        require constraint consistentDropSize {
            doc /* Drop size must be consistent based on drop factor */
            chamber.dropFactor >= 10.0 and chamber.dropFactor <= 60.0
        }
        
        require constraint visibleDrops {
            chamber.transparentBody.transparency >= 0.95
        }
    }
    
    requirement def <'REQ-DC-003'> ChamberLevelRequirement {
        doc /* The drip chamber shall maintain fluid level within operational range. */
        
        subject chamber : DripChamber;
        
        require constraint levelRange {
            chamber.currentFillLevel >= chamber.minFillLevel and
            chamber.currentFillLevel <= chamber.maxFillLevel
        }
        
        require constraint airVentFunction {
            doc /* Air vent must maintain atmospheric pressure in chamber */
            chamber.airFilter.isOpen == true
        }
    }
    
    requirement def <'REQ-DC-004'> FlowControlRequirement {
        doc /* The system shall provide manual flow rate adjustment capability. */
        
        subject tubing : DeliveryTubing;
        
        require constraint clampAdjustability {
            tubing.clamp.clampPosition >= tubing.clamp.minPosition and
            tubing.clamp.clampPosition <= tubing.clamp.maxPosition
        }
    }
    
    requirement def <'REQ-DC-005'> SafetyRequirement {
        doc /* The system shall detect and alarm on unsafe conditions. */
        
        subject system : dripChamberInfusionSystem;
        
        require constraint emptyDetection {
            doc /* System must detect when chamber is empty */
            system.dripChamber.currentFillLevel < system.dripChamber.minFillLevel
        }
        
        require constraint overfillDetection {
            doc /* System must detect when chamber is overfilled */
            system.dripChamber.currentFillLevel > system.dripChamber.maxFillLevel
        }
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for drip chamber infusion system */
        
        require PrimaryFunctionRequirement;
        require DropFormationRequirement;
        require ChamberLevelRequirement;
        require FlowControlRequirement;
        require SafetyRequirement;
    }
}
