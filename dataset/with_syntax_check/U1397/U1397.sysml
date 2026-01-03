package 'Concrete Pumping Subsystem Design' {
    import ScalarValues::*;
    import Quantities::*;
    import MeasurementReferences::*;
    import ISQ::*;
    import SI::*;
    
    attribute def VolumeFlowRateValue :> Real;
    attribute def PressureValue :> Real;
    attribute def PowerValue :> Real;
    attribute def VolumeValue :> Real;
    attribute def LengthValue :> Real;
    attribute def DensityValue :> Real;
    attribute def ViscosityValue :> Real;
    
    enum def VolumeFlowRateUnit {
        enum cubic_meter_per_hour;
        enum cubic_meter_per_second;
        enum liter_per_minute;
    }
    
    item def Fluid {
        attribute density : DensityValue;
        attribute viscosity : ViscosityValue;
        attribute volume : VolumeValue;
    }
    
    item def ConcreteMixture :> Fluid {
        attribute :>> density : DensityValue = 2400.0;
        attribute :>> viscosity : ViscosityValue = 0.05;
        attribute cementRatio : Real;
        attribute waterRatio : Real;
        attribute aggregateSize : LengthValue;
        attribute slump : LengthValue;
    }
    
    port def FluidInletPort {
        in item fluidIn : Fluid;
        attribute inletPressure : PressureValue;
        attribute inletFlowRate : VolumeFlowRateValue;
    }
    
    port def FluidOutletPort {
        out item fluidOut : Fluid;
        attribute outletPressure : PressureValue;
        attribute outletFlowRate : VolumeFlowRateValue;
    }
    
    port def PowerSupplyPort {
        in attribute voltage : Real;
        in attribute current : Real;
        attribute powerConsumed : PowerValue;
    }
    
    port def ControlSignalPort {
        in attribute commandSpeed : Real;
        in attribute commandStart : Boolean;
        in attribute commandStop : Boolean;
        out attribute statusRunning : Boolean;
        out attribute statusFault : Boolean;
    }
    
    action def PumpConcrete {
        in concreteIn : ConcreteMixture;
        in powerInput : PowerValue;
        in targetFlowRate : VolumeFlowRateValue;
        out concreteOut : ConcreteMixture;
        out actualFlowRate : VolumeFlowRateValue;
        out dischargePressure : PressureValue;
    }
    
    action def MonitorPumpOperation {
        in currentPressure : PressureValue;
        in currentFlowRate : VolumeFlowRateValue;
        in maxAllowedPressure : PressureValue;
        in minRequiredFlowRate : VolumeFlowRateValue;
        out faultDetected : Boolean;
    }
    
    action def PrimePumpSystem {
        in pumpReference : ConcretePump;
        out primingSuccessful : Boolean;
    }
    
    action def CleanPumpSystem {
        in pumpReference : ConcretePump;
        out cleaningComplete : Boolean;
    }
    
    enum def PumpState {
        enum Stopped;
        enum Starting;
        enum Priming;
        enum Operating;
        enum Stopping;
        enum Cleaning;
        enum Faulted;
    }
    
    state def ConcretePumpStateMachine {
        entry; then stopped;
        
        state stopped {
            entry assign currentState = PumpState::Stopped;
        }
        
        transition stopped_to_starting
            first stopped
            accept StartPumpCommand
            then starting;
        
        state starting {
            entry assign currentState = PumpState::Starting;
        }
        
        transition starting_to_priming
            first starting
            if powerAvailable == true
            then priming;
        
        state priming {
            entry assign currentState = PumpState::Priming;
            entry perform action primingAction : PrimePumpSystem;
        }
        
        transition priming_to_operating
            first priming
            if primingAction.primingSuccessful == true
            then operating;
        
        transition priming_to_faulted
            first priming
            if primingAction.primingSuccessful == false
            then faulted;
        
        state operating {
            entry assign currentState = PumpState::Operating;
            do perform action pumpingAction : PumpConcrete;
            do perform action monitoringAction : MonitorPumpOperation;
        }
        
        transition operating_to_stopping
            first operating
            accept StopPumpCommand
            then stopping;
        
        transition operating_to_faulted
            first operating
            if monitoringAction.faultDetected == true
            then faulted;
        
        state stopping {
            entry assign currentState = PumpState::Stopping;
        }
        
        transition stopping_to_cleaning
            first stopping
            if cleaningRequired == true
            then cleaning;
        
        transition stopping_to_stopped
            first stopping
            if cleaningRequired == false
            then stopped;
        
        state cleaning {
            entry assign currentState = PumpState::Cleaning;
            entry perform action cleaningAction : CleanPumpSystem;
        }
        
        transition cleaning_to_stopped
            first cleaning
            if cleaningAction.cleaningComplete == true
            then stopped;
        
        state faulted {
            entry assign currentState = PumpState::Faulted;
        }
        
        transition faulted_to_stopped
            first faulted
            accept ResetFaultCommand
            then stopped;
    }
    
    signal StartPumpCommand;
    signal StopPumpCommand;
    signal ResetFaultCommand;
    
    part def ConcretePump {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
        port powerInput : PowerSupplyPort;
        port controlInterface : ControlSignalPort;
        
        attribute maxPressure : PressureValue = 20000000.0;
        attribute maxFlowRate : VolumeFlowRateValue = 150.0;
        attribute ratedPower : PowerValue = 75000.0;
        attribute efficiency : Real = 0.82;
        attribute currentPressure : PressureValue;
        attribute currentFlowRate : VolumeFlowRateValue;
        attribute currentState : PumpState;
        attribute powerAvailable : Boolean;
        attribute cleaningRequired : Boolean;
        
        perform state behavior pumpBehavior : ConcretePumpStateMachine;
    }
    
    part def ConcreteHopper {
        port concreteInput : FluidInletPort;
        port concreteOutput : FluidOutletPort;
        
        attribute capacity : VolumeValue = 0.8;
        attribute currentLevel : VolumeValue;
        attribute mixingEnabled : Boolean;
        
        item storedConcrete : ConcreteMixture {
            attribute :>> volume : VolumeValue;
        }
    }
    
    part def DeliveryHose {
        port hoseInlet : FluidInletPort;
        port hoseOutlet : FluidOutletPort;
        
        attribute hoseLength : LengthValue = 30.0;
        attribute hoseDiameter : LengthValue = 0.125;
        attribute pressureLoss : PressureValue;
        attribute wearLevel : Real;
    }
    
    part def DischargePoint {
        port dischargeInlet : FluidInletPort;
        
        attribute dischargeHeight : LengthValue;
        attribute dischargeRate : VolumeFlowRateValue;
    }
    
    part def HydraulicPowerPack {
        port hydraulicPowerOut : PowerSupplyPort;
        port electricalPowerIn : PowerSupplyPort;
        
        attribute hydraulicPressure : PressureValue = 25000000.0;
        attribute oilFlowRate : VolumeFlowRateValue = 200.0;
        attribute tankCapacity : VolumeValue = 0.15;
        attribute oilTemperature : Real;
    }
    
    part def PumpController {
        port pumpControlOut : ControlSignalPort;
        port operatorInput : ControlSignalPort;
        
        attribute targetFlowRate : VolumeFlowRateValue;
        attribute targetPressure : PressureValue;
        attribute emergencyStopActive : Boolean;
        attribute autoShutdownEnabled : Boolean;
        
        perform action controlLogic : MonitorPumpOperation;
    }
    
    part def PressureTransducer {
        attribute measuredPressure : PressureValue;
        attribute accuracy : Real = 0.01;
        attribute calibrationDate : String;
    }
    
    part def FlowSensor {
        attribute measuredFlowRate : VolumeFlowRateValue;
        attribute accuracy : Real = 0.02;
        attribute sensorType : String;
    }
    
    part def ConcretePumpingSubsystem {
        part hopper : ConcreteHopper;
        part concretePump : ConcretePump;
        part deliveryHose : DeliveryHose;
        part dischargePoint : DischargePoint;
        part hydraulicPowerPack : HydraulicPowerPack;
        part controller : PumpController;
        part pressureSensor : PressureTransducer;
        part flowSensor : FlowSensor;
        
        flow of concrete : ConcreteMixture
            from hopper.concreteOutput.fluidOut
            to concretePump.inlet.fluidIn;
        
        flow of concrete : ConcreteMixture
            from concretePump.outlet.fluidOut
            to deliveryHose.hoseInlet.fluidIn;
        
        flow of concrete : ConcreteMixture
            from deliveryHose.hoseOutlet.fluidOut
            to dischargePoint.dischargeInlet.fluidIn;
        
        connect hydraulicPowerPack.hydraulicPowerOut to concretePump.powerInput;
        connect controller.pumpControlOut to concretePump.controlInterface;
        
        binding pressureSensor.measuredPressure = concretePump.currentPressure;
        binding flowSensor.measuredFlowRate = concretePump.currentFlowRate;
    }
    
    part concretePumpingSystem : ConcretePumpingSubsystem {
        part :>> concretePump {
            attribute :>> maxPressure = 18000000.0;
            attribute :>> maxFlowRate = 120.0;
            attribute :>> ratedPower = 60000.0;
            attribute :>> efficiency = 0.85;
        }
        
        part :>> hopper {
            attribute :>> capacity = 1.0;
            item :>> storedConcrete {
                attribute :>> density = 2350.0;
                attribute :>> cementRatio = 0.15;
                attribute :>> waterRatio = 0.45;
                attribute :>> aggregateSize = 0.02;
                attribute :>> slump = 0.12;
            }
        }
        
        part :>> deliveryHose {
            attribute :>> hoseLength = 40.0;
            attribute :>> hoseDiameter = 0.15;
        }
        
        part :>> hydraulicPowerPack {
            attribute :>> hydraulicPressure = 22000000.0;
            attribute :>> oilFlowRate = 180.0;
        }
    }
    
    requirement def FlowRateRequirement {
        doc /* The concrete pumping subsystem shall deliver concrete at a minimum flow rate. */
        
        subject pumpingSystem : ConcretePumpingSubsystem;
        
        require constraint {
            pumpingSystem.concretePump.currentFlowRate >= 80.0
        }
    }
    
    requirement def PressureCapabilityRequirement {
        doc /* The concrete pump shall generate sufficient pressure for delivery. */
        
        subject pump : ConcretePump;
        
        require constraint {
            pump.currentPressure >= 10000000.0 and
            pump.currentPressure <= pump.maxPressure
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The pumping subsystem shall operate safely within design limits. */
        
        subject pumpingSystem : ConcretePumpingSubsystem;
        
        require constraint {
            pumpingSystem.concretePump.currentPressure <= pumpingSystem.concretePump.maxPressure
        }
        
        require constraint {
            pumpingSystem.controller.emergencyStopActive == true implies
            pumpingSystem.concretePump.currentState == PumpState::Stopping or
            pumpingSystem.concretePump.currentState == PumpState::Stopped
        }
    }
    
    requirement def EfficiencyRequirement {
        doc /* The concrete pump shall operate at specified efficiency. */
        
        subject pump : ConcretePump;
        
        require constraint {
            pump.efficiency >= 0.80
        }
    }
    
    requirement def ReliabilityRequirement {
        doc /* The pumping subsystem shall maintain continuous operation. */
        
        subject pumpingSystem : ConcretePumpingSubsystem;
        
        attribute meanTimeBetweenFailures : Real = 600.0;
        attribute targetAvailability : Real = 0.92;
    }
    
    requirement def MaterialHandlingRequirement {
        doc /* The subsystem shall handle concrete with specified properties. */
        
        subject pumpingSystem : ConcretePumpingSubsystem;
        
        require constraint {
            pumpingSystem.hopper.storedConcrete.aggregateSize <= 0.025
        }
        
        require constraint {
            pumpingSystem.hopper.storedConcrete.slump >= 0.08 and
            pumpingSystem.hopper.storedConcrete.slump <= 0.18
        }
    }
    
    satisfy flowRateReq : FlowRateRequirement {
        subject testSystem = concretePumpingSystem;
    }
    
    satisfy pressureReq : PressureCapabilityRequirement {
        subject testPump = concretePumpingSystem.concretePump;
    }
    
    satisfy safetyReq : SafetyRequirement {
        subject testSystem = concretePumpingSystem;
    }
    
    satisfy efficiencyReq : EfficiencyRequirement {
        subject testPump = concretePumpingSystem.concretePump;
    }
    
    satisfy reliabilityReq : ReliabilityRequirement {
        subject testSystem = concretePumpingSystem;
    }
    
    satisfy materialReq : MaterialHandlingRequirement {
        subject testSystem = concretePumpingSystem;
    }
}
