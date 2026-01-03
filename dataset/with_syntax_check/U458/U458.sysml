package YankauerSuctionSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;

    doc /* 
     * This model describes a Yankauer suction system used in surgical and medical procedures.
     * The system's primary function is to remove fluids, blood, and debris from a surgical site
     * or airway through continuous vacuum-assisted aspiration. The system operates by creating
     * negative pressure that draws fluids through the rigid Yankauer tip, along tubing, and into
     * a collection canister, maintaining a clear operative field for medical personnel.
     */

    attribute def SuctionPressureValue :> PressureValue;
    attribute def FlowRateValue :> VolumeFlowRateValue;
    attribute def TipDiameterValue :> LengthValue;

    enum def VentPosition {
        open;
        closed;
    }

    enum def SystemState {
        idle;
        active;
        obstructed;
        canisterFull;
    }

    item def Biofluid {
        attribute viscosity : Real;
        attribute volume : VolumeValue;
    }

    item def Debris {
        attribute particleSize : LengthValue;
    }

    port def FluidInletPort {
        in fluid : Biofluid[0..*];
        in debris : Debris[0..*];
    }

    port def FluidOutletPort {
        out fluid : Biofluid[0..*];
        out debris : Debris[0..*];
    }

    port def VacuumPort {
        in negativePressure : SuctionPressureValue;
    }

    port def VentControlPort {
        in ventPosition : VentPosition;
    }

    part def YankauerTip {
        doc /* Rigid suction tip with bulbous end and side holes for atraumatic aspiration. */
        
        attribute tipDiameter : TipDiameterValue = 5.0 [SI::mm];
        attribute numberOfHoles : Integer = 2;
        attribute tipLength : LengthValue = 25.0 [SI::mm];
        
        port suctionInlet : FluidInletPort;
        port fluidOutlet : FluidOutletPort;
        port ventControl : VentControlPort;
        
        assert constraint tipSizeConstraint {
            tipDiameter >= 3.0 [SI::mm] and tipDiameter <= 7.0 [SI::mm]
        }
    }

    part def SuctionTubing {
        doc /* Flexible tubing connecting tip to collection system. */
        
        attribute innerDiameter : LengthValue = 6.5 [SI::mm];
        attribute length : LengthValue = 1.8 [SI::m];
        attribute wallThickness : LengthValue = 1.5 [SI::mm];
        
        port inlet : FluidOutletPort;
        port outlet : FluidOutletPort;
        
        assert constraint tubingConstraint {
            length >= 1.5 [SI::m] and length <= 3.0 [SI::m]
        }
    }

    part def CollectionCanister {
        doc /* Container for collecting aspirated fluids with overflow protection. */
        
        attribute capacity : VolumeValue = 1.5 [SI::L];
        attribute currentVolume : VolumeValue = 0.0 [SI::L];
        attribute fillLevel : Real = 0.0;
        
        port fluidInlet : FluidOutletPort;
        port vacuumConnection : VacuumPort;
        port overflowShutoff;
        
        assert constraint capacityConstraint {
            capacity >= 0.5 [SI::L] and capacity <= 3.0 [SI::L]
        }
        
        assert constraint fillConstraint {
            fillLevel == currentVolume / capacity
        }
    }

    part def VacuumRegulator {
        doc /* Adjustable vacuum source providing controlled negative pressure. */
        
        attribute setPressure : SuctionPressureValue = -60.0 [SI::kPa];
        attribute maxPressure : SuctionPressureValue = -80.0 [SI::kPa];
        attribute currentPressure : SuctionPressureValue;
        
        port vacuumOutput : VacuumPort;
        
        assert constraint pressureRange {
            setPressure >= -80.0 [SI::kPa] and setPressure <= -40.0 [SI::kPa]
        }
    }

    part def BacterialFilter {
        doc /* Hydrophobic filter preventing contamination of vacuum source. */
        
        attribute filtrationEfficiency : Real = 0.9999;
        
        port inlet : FluidOutletPort;
        port outlet : VacuumPort;
    }

    part def YankauerSuctionAssembly {
        doc /* Complete Yankauer suction system assembly. */
        
        attribute operatingPressure : SuctionPressureValue;
        attribute flowRate : FlowRateValue;
        attribute systemState : SystemState = SystemState::idle;
        
        part tip : YankauerTip {
            attribute :>> tipDiameter = 5.0 [SI::mm];
            attribute :>> numberOfHoles = 2;
        }
        
        part tubing : SuctionTubing {
            attribute :>> innerDiameter = 6.5 [SI::mm];
            attribute :>> length = 1.8 [SI::m];
        }
        
        part canister : CollectionCanister {
            attribute :>> capacity = 1.5 [SI::L];
            attribute :>> currentVolume : VolumeValue;
        }
        
        part bacterialFilter : BacterialFilter;
        
        part regulator : VacuumRegulator {
            attribute :>> setPressure = -60.0 [SI::kPa];
            attribute :>> currentPressure : SuctionPressureValue;
        }
        
        connection tipToTubing connect tip.fluidOutlet to tubing.inlet;
        connection tubingToCanister connect tubing.outlet to canister.fluidInlet;
        connection canisterToFilter connect canister.vacuumConnection to bacterialFilter.inlet;
        connection filterToRegulator connect bacterialFilter.outlet to regulator.vacuumOutput;
        
        assert constraint operatingPressureMatch {
            operatingPressure == regulator.currentPressure
        }
        
        assert constraint flowRateConstraint {
            flowRate >= 15.0 [SI::L/SI::min] and flowRate <= 30.0 [SI::L/SI::min]
        }
        
        perform action suctionCycle[*] ordered references performSuctionCycle;
    }

    action def InitializeSystem {
        out systemReady : ScalarValues::Boolean;
        out initialPressure : SuctionPressureValue;
    }

    action def ActivateSuction {
        in targetPressure : SuctionPressureValue;
        out achievedPressure : SuctionPressureValue;
        out flowRate : FlowRateValue;
    }

    action def AspirateFluid {
        in ventOpen : ScalarValues::Boolean;
        in currentPressure : SuctionPressureValue;
        out fluidVolume : VolumeValue;
        out debrisRemoved : ScalarValues::Boolean;
    }

    action def MonitorCanisterLevel {
        in currentVolume : VolumeValue;
        in capacity : VolumeValue;
        out fillPercentage : ScalarValues::Real;
        out isFull : ScalarValues::Boolean;
    }

    action def CheckObstruction {
        in flowRate : FlowRateValue;
        in expectedFlow : FlowRateValue;
        out isObstructed : ScalarValues::Boolean;
    }

    action def DeactivateSuction {
        out systemStopped : ScalarValues::Boolean;
    }

    action def PerformSuctionCycle {
        doc /* Primary operational cycle for Yankauer suction system. */
        
        first start;
        
        then action initialize : InitializeSystem {
            out systemReady : ScalarValues::Boolean;
        }
        
        then merge continueSuction;
        
        then action monitorLevel : MonitorCanisterLevel {
            in currentVolume = canisterVolume;
            in capacity = canisterCapacity;
            out canisterFull : ScalarValues::Boolean;
        }
        
        then action checkFlow : CheckObstruction {
            in flowRate = currentFlow;
            in expectedFlow = nominalFlow;
            out blocked : ScalarValues::Boolean;
        }
        
        then decide;
            if monitorLevel.canisterFull == true then stopSuction;
            if checkFlow.blocked == true then clearObstruction;
            if monitorLevel.canisterFull == false and checkFlow.blocked == false then activateSuction;
        
        action activateSuction : ActivateSuction {
            in targetPressure = operatingPressure;
            then action aspirate : AspirateFluid {
                in ventOpen = false;
                in currentPressure = activateSuction.achievedPressure;
            }
        }
        then continueSuction;
        
        action clearObstruction : AspirateFluid {
            in ventOpen = true;
            in currentPressure = reducedPressure;
        }
        then continueSuction;
        
        action stopSuction : DeactivateSuction;
        then done;
        
        private attribute canisterVolume : VolumeValue;
        private attribute canisterCapacity : VolumeValue;
        private attribute currentFlow : FlowRateValue;
        private attribute nominalFlow : FlowRateValue = 20.0 [SI::L/SI::min];
        private attribute operatingPressure : SuctionPressureValue = -60.0 [SI::kPa];
        private attribute reducedPressure : SuctionPressureValue = -30.0 [SI::kPa];
    }

    state def SuctionSystemStateMachine {
        doc /* State machine governing Yankauer suction system operation. */
        
        entry; then idle;
        
        state idle {
            entry assign currentState = YankauerSuctionSystem::SystemState::idle;
        }
        
        transition idle_to_active
            first idle
            accept startSuction
            then active;
        
        state active {
            entry assign currentState = YankauerSuctionSystem::SystemState::active;
            do action activeSuction : ActivateSuction;
        }
        
        transition active_to_obstructed
            first active
            accept blockageDetected
            if flowRate < 10.0 [SI::L/SI::min]
            then obstructed;
        
        state obstructed {
            entry assign currentState = YankauerSuctionSystem::SystemState::obstructed;
        }
        
        transition obstructed_to_active
            first obstructed
            accept blockageCleared
            then active;
        
        transition active_to_canisterFull
            first active
            accept canisterFull
            if fillLevel >= 0.95
            then canisterFull;
        
        state canisterFull {
            entry assign currentState = YankauerSuctionSystem::SystemState::canisterFull;
        }
        
        transition canisterFull_to_idle
            first canisterFull
            accept canisterReplaced
            then idle;
        
        transition active_to_idle
            first active
            accept stopSuction
            then idle;
        
        transition obstructed_to_idle
            first obstructed
            accept stopSuction
            then idle;
        
        private attribute currentState : SystemState;
        private attribute flowRate : FlowRateValue;
        private attribute fillLevel : ScalarValues::Real;
    }

    requirement def FluidRemovalRequirement {
        doc /* System shall effectively remove fluids and debris from surgical site. */
        subject system : YankauerSuctionAssembly;
        require constraint {
            system.flowRate >= 15.0 [SI::L/SI::min]
        }
    }

    requirement def SuctionPressureRequirement {
        doc /* System shall maintain safe and effective suction pressure. */
        subject system : YankauerSuctionAssembly;
        require constraint {
            system.operatingPressure >= -80.0 [SI::kPa] and
            system.operatingPressure <= -40.0 [SI::kPa]
        }
    }

    requirement def TipSafetyRequirement {
        doc /* Tip design shall prevent tissue trauma during aspiration. */
        subject tip : YankauerTip;
        require constraint {
            tip.tipDiameter >= 3.0 [SI::mm] and
            tip.numberOfHoles >= 1
        }
    }

    requirement def CanisterCapacityRequirement {
        doc /* Collection canister shall have adequate capacity for typical procedures. */
        subject canister : CollectionCanister;
        require constraint {
            canister.capacity >= 0.5 [SI::L]
        }
    }

    requirement def ContaminationPreventionRequirement {
        doc /* System shall prevent contamination of vacuum source. */
        subject bacterialFilter : BacterialFilter;
        require constraint {
            bacterialFilter.filtrationEfficiency >= 0.999
        }
    }

    requirement <'REQ-YS-001'> primaryFunction {
        doc /* The Yankauer suction system shall remove fluids, blood, and debris from 
             * surgical sites and airways through continuous vacuum-assisted aspiration,
             * maintaining a clear operative field and ensuring patient safety during
             * medical procedures.
             */
        subject yankauer : YankauerSuctionAssembly;
        
        require fluidRemoval : FluidRemovalRequirement {
            subject system = yankauer;
        }
        
        require suctionPressure : SuctionPressureRequirement {
            subject system = yankauer;
        }
        
        require tipSafety : TipSafetyRequirement {
            subject tip = yankauer.tip;
        }
        
        require canisterCapacity : CanisterCapacityRequirement {
            subject canister = yankauer.canister;
        }
        
        require contaminationPrevention : ContaminationPreventionRequirement {
            subject bacterialFilter = yankauer.bacterialFilter;
        }
    }

    part yankauerSystem : YankauerSuctionAssembly {
        attribute :>> operatingPressure = -60.0 [SI::kPa];
        attribute :>> flowRate = 20.0 [SI::L/SI::min];
        
        part redefines tip {
            attribute :>> tipDiameter = 5.0 [SI::mm];
            attribute :>> numberOfHoles = 2;
        }
        
        part redefines canister {
            attribute :>> capacity = 1.5 [SI::L];
        }
        
        part redefines regulator {
            attribute :>> setPressure = -60.0 [SI::kPa];
        }
        
        exhibit state operationalBehavior : SuctionSystemStateMachine;
    }

    satisfy primaryFunction by yankauerSystem;
}
