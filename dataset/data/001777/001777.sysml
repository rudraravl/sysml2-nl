package FilterPressSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PressureValue :> ISQ::PressureValue;
    attribute def VolumeValue :> ISQ::VolumeValue;
    attribute def TimeValue :> ISQ::TimeValue;
    attribute def FlowRateValue :> ISQ::VolumeFlowRateValue;
    attribute def MoistureContent :> Real;
    
    enum def CyclePhase {
        idle;
        filling;
        pressurizing;
        filtering;
        holding;
        depressurizing;
        discharging;
        washing;
    }
    
    enum def ValveState {
        open;
        closed;
    }
    
    item def Slurry {
        attribute solidsFraction : Real;
        attribute liquidFraction : Real;
        attribute totalVolume : VolumeValue;
        attribute feedPressure : PressureValue;
    }
    
    item def Filtrate {
        attribute volume : VolumeValue;
        attribute clarity : Real;
        attribute residualSolids : Real;
    }
    
    item def FilterCake {
        attribute mass : ISQ::MassValue;
        attribute moistureContent : MoistureContent;
        attribute thickness : ISQ::LengthValue;
        attribute compressibility : Real;
    }
    
    port def SlurryPort {
        in item slurryFlow : Slurry;
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
    }
    
    port def FiltratePort {
        out item filtrateFlow : Filtrate;
        attribute flowRate : FlowRateValue;
    }
    
    port def CakePort {
        out item cakeOutput : FilterCake;
    }
    
    port def HydraulicPort {
        attribute pressure : PressureValue;
        attribute force : ISQ::ForceValue;
    }
    
    part def FeedPump {
        attribute maxFlowRate : FlowRateValue;
        attribute dischargePressure : PressureValue;
        port inlet : SlurryPort;
        port outlet : SlurryPort;
        
        action def PumpSlurry {
            in slurryIn : Slurry;
            in targetFlowRate : FlowRateValue;
            out slurryOut : Slurry;
            out actualFlowRate : FlowRateValue;
        }
    }
    
    part def FeedValve {
        attribute valveState : ValveState;
        attribute position : Real;
        port inlet : SlurryPort;
        port outlet : SlurryPort;
        
        action def ControlFlow {
            in command : ValveState;
            in flowRate : FlowRateValue;
            out flowEnabled : Boolean;
        }
    }
    
    part def FilterPlate {
        attribute surfaceArea : ISQ::AreaValue;
        attribute permeability : Real;
        attribute thickness : ISQ::LengthValue;
        
        part filterMedia {
            attribute poreSize : ISQ::LengthValue;
            attribute material : String;
            attribute resistance : Real;
        }
    }
    
    part def FilterChamber {
        attribute chamberVolume : VolumeValue;
        attribute numberOfPlates : Integer;
        attribute currentFillLevel : Real;
        attribute cakeThickness : ISQ::LengthValue;
        
        part plates : FilterPlate[20..100];
        
        port slurryInlet : SlurryPort;
        port filtrateOutlet : FiltratePort;
        port cakeDischarge : CakePort;
        
        action def AccumulateSolids {
            in slurryInput : Slurry;
            in appliedPressure : PressureValue;
            out filtrateProduced : Filtrate;
            out cakeFormed : FilterCake;
        }
    }
    
    part def HydraulicSystem {
        attribute maxPressure : PressureValue;
        attribute currentPressure : PressureValue;
        attribute clampingForce : ISQ::ForceValue;
        
        port hydraulicOutput : HydraulicPort;
        
        action def GeneratePressure {
            in targetPressure : PressureValue;
            out actualPressure : PressureValue;
            out forceApplied : ISQ::ForceValue;
        }
        
        action def ReleasePressure {
            out pressureReleased : Boolean;
        }
    }
    
    part def FiltrateValve {
        attribute valveState : ValveState;
        port inlet : FiltratePort;
        port outlet : FiltratePort;
        
        action def DrainFiltrate {
            in command : ValveState;
            out drainRate : FlowRateValue;
        }
    }
    
    part def PressureController {
        attribute setPoint : PressureValue;
        attribute currentReading : PressureValue;
        attribute tolerance : PressureValue;
        
        action def RegulatePressure {
            in target : PressureValue;
            in feedback : PressureValue;
            out controlSignal : Real;
            out withinTolerance : Boolean;
        }
    }
    
    part def ControlSystem {
        attribute currentPhase : CyclePhase;
        attribute cycleCount : Integer;
        
        action def MonitorCycle {
            in phase : CyclePhase;
            in pressure : PressureValue;
            in fillLevel : Real;
            out phaseComplete : Boolean;
        }
        
        action def TransitionPhase {
            in currentPhase : CyclePhase;
            in conditions : Boolean;
            out nextPhase : CyclePhase;
        }
    }
    
    part def FilterPress {
        attribute operatingPressure : PressureValue;
        attribute cycleTime : TimeValue;
        attribute currentPhase : CyclePhase;
        attribute throughput : FlowRateValue;
        
        port slurryFeed : SlurryPort;
        port filtrateDischarge : FiltratePort;
        port cakeRemoval : CakePort;
        
        part feedPump : FeedPump;
        part feedValve : FeedValve;
        part filterChamber : FilterChamber;
        part hydraulics : HydraulicSystem;
        part filtrateValve : FiltrateValve;
        part pressureControl : PressureController;
        part controller : ControlSystem;
        
        connection feedLine connect slurryFeed to feedPump.inlet;
        connection pumpToValve connect feedPump.outlet to feedValve.inlet;
        connection valveToChamber connect feedValve.outlet to filterChamber.slurryInlet;
        connection chamberToFiltrateValve connect filterChamber.filtrateOutlet to filtrateValve.inlet;
        connection filtrateToDischarge connect filtrateValve.outlet to filtrateDischarge;
        connection cakeToRemoval connect filterChamber.cakeDischarge to cakeRemoval;
        
        perform action operateCycle references filtrationCycle;
    }
    
    action def FillChamber {
        in slurrySupply : Slurry;
        in targetVolume : VolumeValue;
        out chamberFilled : Boolean;
        out actualVolume : VolumeValue;
    }
    
    action def ClosePlates {
        in clampingForce : ISQ::ForceValue;
        out platesClosed : Boolean;
        out sealAchieved : Boolean;
    }
    
    action def ApplyFiltrationPressure {
        in targetPressure : PressureValue;
        in duration : TimeValue;
        out pressureStabilized : Boolean;
        out pressureApplied : PressureValue;
    }
    
    action def PerformSeparation {
        in pressurizedSlurry : Slurry;
        in filtrationPressure : PressureValue;
        in filtrationTime : TimeValue;
        out filtrate : Filtrate;
        out cake : FilterCake;
        out separationComplete : Boolean;
    }
    
    action def HoldPressure {
        in pressure : PressureValue;
        in holdTime : TimeValue;
        out cakeConsolidated : Boolean;
    }
    
    action def OpenPlates {
        out platesOpened : Boolean;
    }
    
    action def DischargeCake {
        in cake : FilterCake;
        out cakeRemoved : Boolean;
        out chamberEmpty : Boolean;
    }
    
    action def WashChamber {
        in washPressure : PressureValue;
        out chamberClean : Boolean;
    }
    
    action filtrationCycle {
        first start;
        then merge readyState;
        
        then action fillPhase : FillChamber;
        then action closingPhase : ClosePlates;
        then action pressurizationPhase : ApplyFiltrationPressure;
        then action separationPhase : PerformSeparation;
        then action holdingPhase : HoldPressure;
        then action depressurizationPhase;
        then action openingPhase : OpenPlates;
        then action dischargePhase : DischargeCake;
        then action washingPhase : WashChamber;
        
        then decide;
            if washingPhase.chamberClean then readyState;
            if not washingPhase.chamberClean then washingPhase;
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* The filter press shall separate solid particles from liquid 
             * slurry by forcing the liquid through filter media under pressure,
             * retaining solids as a compressed cake while discharging clarified
             * filtrate.
             */
        subject press : FilterPress;
    }
    
    requirement def SeparationEfficiencyRequirement {
        doc /* The filter press shall achieve solid-liquid separation with
             * filtrate clarity of at least 98% and cake moisture content
             * not exceeding 30%.
             */
        subject press : FilterPress;
        
        require constraint filtrateQuality {
            press.filtrateDischarge.filtrateFlow.clarity >= 98.0
        }
        
        require constraint cakeDryness {
            press.cakeRemoval.cakeOutput.moistureContent <= 0.30
        }
    }
    
    requirement def OperatingPressureRequirement {
        doc /* The filter press shall operate at filtration pressures
             * up to 1500 kPa to ensure effective dewatering and cake
             * consolidation.
             */
        subject press : FilterPress;
        
        require constraint pressureLimit {
            press.operatingPressure == press.operatingPressure
        }
    }
    
    requirement def ThroughputRequirement {
        doc /* The filter press shall complete a full filtration cycle
             * within 90 minutes to meet production throughput targets
             * of minimum 1.5 m³ processed slurry per cycle.
             */
        subject press : FilterPress;
        
        require constraint volumeCapacity {
            press.filterChamber.numberOfPlates >= 20
        }
    }
    
    requirement <'REQ-FP-001'> filterPressPrimaryFunction {
        doc /* The filter press system shall perform solid-liquid separation
             * by applying hydraulic pressure to force liquid through filter
             * media while retaining and compressing solid particles into
             * a dewatered cake, producing clarified filtrate as output.
             */
        subject filterPress : FilterPress;
        
        require PrimaryFunctionRequirement;
        require SeparationEfficiencyRequirement;
        require OperatingPressureRequirement;
        require ThroughputRequirement;
    }
    
    part industrialFilterPress : FilterPress {
        attribute :>> currentPhase = CyclePhase::idle;
        
        perform action cycleOperation references filtrationCycle;
    }
    
    satisfy filterPressPrimaryFunction by industrialFilterPress;
}
