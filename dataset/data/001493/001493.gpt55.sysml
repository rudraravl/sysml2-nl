package MatterBasedSystemModel {

    import ScalarValues::*;

    enum def MatterPhase {
        enum solid;
        enum liquid;
        enum gas;
        enum plasma;
        enum mixed;
    }

    enum def MatterQuality {
        enum unknown;
        enum raw;
        enum acceptable;
        enum conditioned;
        enum rejected;
    }

    enum def OperatingCommand {
        enum start;
        enum stop;
        enum hold;
        enum resume;
        enum resetFault;
        enum emergencyStop;
    }

    enum def FaultCode {
        enum none;
        enum blockedFlow;
        enum overTemperature;
        enum overPressure;
        enum sensorDisagreement;
        enum contaminationDetected;
        enum powerLoss;
    }

    attribute def Mass :> Real {
        doc /* Unit: kilogram (kg). */
    }

    attribute def Temperature :> Real {
        doc /* Unit: kelvin (K). */
    }

    attribute def Pressure :> Real {
        doc /* Unit: pascal (Pa). */
    }

    attribute def Volume :> Real {
        doc /* Unit: cubic meter (m^3). */
    }

    attribute def MassFlowRate :> Real {
        doc /* Unit: kilogram per second (kg/s). */
    }

    attribute def Power :> Real {
        doc /* Unit: watt (W). */
    }

    attribute def Energy :> Real {
        doc /* Unit: joule (J). */
    }

    attribute def TimeDuration :> Real {
        doc /* Unit: second (s). */
    }

    attribute def Fraction :> Real {
        doc /* Unit: dimensionless fraction from 0.0 to 1.0. */
    }

    attribute def RotationalSpeed :> Real {
        doc /* Unit: revolutions per minute (r/min). */
    }

    item def Matter {
        doc /* General item type representing physical matter handled by the system. */
        attribute mass : Mass;
        attribute volume : Volume;
        attribute temperature : Temperature;
        attribute pressure : Pressure;
        attribute phase : MatterPhase;
        attribute purity : Fraction;
        attribute quality : MatterQuality;
    }

    item def RawMatter :> Matter {
        attribute initialContaminationFraction : Fraction;
        attribute sourceBatchIdentifier : String;
    }

    item def ConditionedMatter :> Matter {
        attribute achievedHomogeneity : Fraction;
        attribute stabilityDuration : TimeDuration;
        attribute releaseBatchIdentifier : String;
    }

    item def WasteMatter :> Matter {
        attribute rejectionReason : FaultCode;
    }

    item def MatterSample :> Matter {
        attribute sampleMass : Mass;
        attribute measuredAtTime : TimeDuration;
    }

    item def ElectricalEnergy {
        attribute deliveredPower : Power;
        attribute accumulatedEnergy : Energy;
    }

    item def ControlMessage {
        attribute command : OperatingCommand;
        attribute requestedMassFlowRate : MassFlowRate;
        attribute requestedTemperature : Temperature;
        attribute requestedPressure : Pressure;
    }

    item def StatusMessage {
        attribute currentMode : String;
        attribute actualMassFlowRate : MassFlowRate;
        attribute actualTemperature : Temperature;
        attribute actualPressure : Pressure;
        attribute actualPurity : Fraction;
        attribute activeFault : FaultCode;
    }

    item def DesiredMatterState {
        attribute targetPhase : MatterPhase;
        attribute targetTemperature : Temperature;
        attribute targetPressure : Pressure;
        attribute minimumPurity : Fraction;
        attribute targetMassFlowRate : MassFlowRate;
    }

    port def RawMatterInputPort {
        in item rawMatter : RawMatter;
    }

    port def ConditionedMatterOutputPort {
        out item conditionedMatter : ConditionedMatter;
    }

    port def WasteMatterOutputPort {
        out item wasteMatter : WasteMatter;
    }

    port def MatterTransferPort {
        inout item matter : Matter;
    }

    port def MatterSamplePort {
        out item sample : MatterSample;
    }

    port def EnergyInputPort {
        in item energy : ElectricalEnergy;
    }

    port def ControlInputPort {
        in item control : ControlMessage;
    }

    port def StatusOutputPort {
        out item status : StatusMessage;
    }

    constraint def MassBalanceConstraint {
        in inputMass : Mass;
        in productMass : Mass;
        in wasteMass : Mass;
        in retainedMass : Mass;
        constraint massIsConserved {
            inputMass == productMass + wasteMass + retainedMass
        }
    }

    constraint def SafeThermalConstraint {
        in actualTemperature : Temperature;
        in maximumTemperature : Temperature;
        constraint belowMaximumTemperature {
            actualTemperature <= maximumTemperature
        }
    }

    constraint def SafePressureConstraint {
        in actualPressure : Pressure;
        in maximumPressure : Pressure;
        constraint belowMaximumPressure {
            actualPressure <= maximumPressure
        }
    }

    constraint def ProductPurityConstraint {
        in actualPurity : Fraction;
        in requiredPurity : Fraction;
        constraint purityMeetsRequirement {
            actualPurity >= requiredPurity
        }
    }

    action def AcceptRawMatter {
        in item incoming : RawMatter;
        out item accepted : RawMatter;
        attribute acceptanceFlowRate : MassFlowRate;
    }

    action def SenseMatterProperties {
        in item sensedMatter : Matter;
        out item sample : MatterSample;
        out item status : StatusMessage;
        attribute sensingInterval : TimeDuration;
    }

    action def MeterMatterFlow {
        in item unmeteredMatter : Matter;
        in item desiredState : DesiredMatterState;
        out item meteredMatter : Matter;
        attribute commandedFlowRate : MassFlowRate;
        attribute actualFlowRate : MassFlowRate;
    }

    action def ConditionMatter {
        in item inputMatter : Matter;
        in item energyInput : ElectricalEnergy;
        in item desiredState : DesiredMatterState;
        out item outputMatter : ConditionedMatter;
        out item rejectedMatter : WasteMatter;
        attribute appliedPower : Power;
        attribute residenceTime : TimeDuration;
    }

    action def VerifyConditionedMatter {
        in item candidateMatter : ConditionedMatter;
        in item desiredState : DesiredMatterState;
        out item verifiedMatter : ConditionedMatter;
        out item rejectedMatter : WasteMatter;
        attribute verificationPurity : Fraction;
    }

    action def DeliverConditionedMatter {
        in item releasedMatter : ConditionedMatter;
        out item deliveredMatter : ConditionedMatter;
        attribute deliveryFlowRate : MassFlowRate;
    }

    action def ProvideConditionedMatter {
        doc /* Primary high-level function: receive raw matter, regulate its flow and state, transform it into conditioned matter, verify acceptability, and deliver conditioned matter for downstream use. */
        in item rawInput : RawMatter;
        in item desiredState : DesiredMatterState;
        in item energySupply : ElectricalEnergy;
        out item productOutput : ConditionedMatter;
        out item wasteOutput : WasteMatter;

        action accept : AcceptRawMatter {
            in item incoming = rawInput;
        }

        action meter : MeterMatterFlow {
            in item unmeteredMatter = accept.accepted;
            in item desiredState = desiredState;
        }

        action condition : ConditionMatter {
            in item inputMatter = meter.meteredMatter;
            in item energyInput = energySupply;
            in item desiredState = desiredState;
        }

        action verify : VerifyConditionedMatter {
            in item candidateMatter = condition.outputMatter;
            in item desiredState = desiredState;
        }

        action deliver : DeliverConditionedMatter {
            in item releasedMatter = verify.verifiedMatter;
        }

        bind productOutput = deliver.deliveredMatter;
        bind wasteOutput = condition.rejectedMatter;
    }

    state def MatterSystemOperatingStates {
        doc /* Operating behavior for a matter-based system performing its primary function. */

        state off;
        state initializing;
        state ready;
        state acceptingMatter;
        state conditioningMatter;
        state verifyingProduct;
        state deliveringProduct;
        state holding;
        state faulted;
        state shuttingDown;

        transition initialTransition first off;

        transition startRequested
            from off
            to initializing
            accept OperatingCommand::start;

        transition initializationComplete
            from initializing
            to ready;

        transition matterAvailable
            from ready
            to acceptingMatter;

        transition acceptedBatch
            from acceptingMatter
            to conditioningMatter;

        transition conditionedBatch
            from conditioningMatter
            to verifyingProduct;

        transition productAccepted
            from verifyingProduct
            to deliveringProduct;

        transition deliveryComplete
            from deliveringProduct
            to ready;

        transition holdRequestedFromReady
            from ready
            to holding
            accept OperatingCommand::hold;

        transition holdRequestedFromProcessing
            from conditioningMatter
            to holding
            accept OperatingCommand::hold;

        transition resumeRequested
            from holding
            to ready
            accept OperatingCommand::resume;

        transition stopRequested
            from ready
            to shuttingDown
            accept OperatingCommand::stop;

        transition shutdownComplete
            from shuttingDown
            to off;

        transition emergencyStopFromAnyProcessing
            from conditioningMatter
            to faulted
            accept OperatingCommand::emergencyStop;

        transition contaminationFault
            from verifyingProduct
            to faulted
            accept FaultCode::contaminationDetected;

        transition blockedFlowFault
            from acceptingMatter
            to faulted
            accept FaultCode::blockedFlow;

        transition resetAfterFault
            from faulted
            to initializing
            accept OperatingCommand::resetFault;
    }

    part def IntakeAssembly {
        doc /* Receives externally supplied raw matter and isolates the system boundary from uncontrolled inflow. */
        port inlet : RawMatterInputPort;
        port outlet : MatterTransferPort;
        port sampleOut : MatterSamplePort;
        port statusOut : StatusOutputPort;

        attribute maximumIntakeFlowRate : MassFlowRate = 5.0;
        attribute inletVolumeCapacity : Volume = 0.20;
        attribute minimumAcceptedPurity : Fraction = 0.80;

        perform action acceptRawMatter : AcceptRawMatter;
        perform action senseIncomingMatter : SenseMatterProperties;
    }

    part def MeteringPump {
        doc /* Moves matter at a controlled flow rate from the intake assembly to the conditioner. */
        port suction : MatterTransferPort;
        port discharge : MatterTransferPort;
        port energyIn : EnergyInputPort;
        port controlIn : ControlInputPort;
        port statusOut : StatusOutputPort;

        attribute ratedFlowRate : MassFlowRate = 3.0;
        attribute minimumFlowRate : MassFlowRate = 0.1;
        attribute maximumDischargePressure : Pressure = 500000.0;
        attribute nominalSpeed : RotationalSpeed = 1800.0;

        perform action meterFlow : MeterMatterFlow;
    }

    part def MatterConditioner {
        doc /* Applies controlled energy and residence time to place matter into the desired high-level state. */
        port matterIn : MatterTransferPort;
        port matterOut : MatterTransferPort;
        port wasteOut : WasteMatterOutputPort;
        port energyIn : EnergyInputPort;
        port controlIn : ControlInputPort;
        port statusOut : StatusOutputPort;

        attribute chamberVolume : Volume = 0.50;
        attribute maximumTemperature : Temperature = 450.0;
        attribute maximumPressure : Pressure = 750000.0;
        attribute nominalResidenceTime : TimeDuration = 30.0;
        attribute nominalPower : Power = 12000.0;

        perform action condition : ConditionMatter;

        constraint safeTemperature : SafeThermalConstraint {
            in maximumTemperature = maximumTemperature;
        }

        constraint safePressure : SafePressureConstraint {
            in maximumPressure = maximumPressure;
        }
    }

    part def ProductVerifier {
        doc /* Measures conditioned matter and determines whether it satisfies the requested matter state. */
        port candidateIn : MatterTransferPort;
        port acceptedOut : ConditionedMatterOutputPort;
        port rejectedOut : WasteMatterOutputPort;
        port statusOut : StatusOutputPort;

        attribute minimumVerificationPurity : Fraction = 0.98;
        attribute verificationInterval : TimeDuration = 2.0;
        attribute sampleMass : Mass = 0.01;

        perform action verify : VerifyConditionedMatter;

        constraint productPurity : ProductPurityConstraint {
            in requiredPurity = minimumVerificationPurity;
        }
    }

    part def ProductDeliveryAssembly {
        doc /* Releases verified conditioned matter to the external user or downstream process. */
        port productIn : MatterTransferPort;
        port productOut : ConditionedMatterOutputPort;
        port statusOut : StatusOutputPort;

        attribute maximumDeliveryFlowRate : MassFlowRate = 3.0;
        attribute outletHoldVolume : Volume = 0.10;

        perform action deliver : DeliverConditionedMatter;
    }

    part def WasteHandlingAssembly {
        doc /* Collects rejected or purged matter and exports it through a controlled waste boundary. */
        port wasteInFromConditioner : WasteMatterOutputPort;
        port wasteInFromVerifier : WasteMatterOutputPort;
        port wasteOut : WasteMatterOutputPort;
        port statusOut : StatusOutputPort;

        attribute wasteCapacity : Volume = 0.30;
        attribute maximumWasteTemperature : Temperature = 360.0;
        attribute retainedWasteMass : Mass;
    }

    part def SensorSuite {
        doc /* Provides independent sensing of matter temperature, pressure, flow, phase, and purity. */
        port intakeSampleIn : MatterSamplePort;
        port conditionerStatusIn : StatusOutputPort;
        port verifierStatusIn : StatusOutputPort;
        port statusOut : StatusOutputPort;

        attribute temperatureAccuracy : Temperature = 0.5;
        attribute pressureAccuracy : Pressure = 1000.0;
        attribute purityAccuracy : Fraction = 0.005;
        attribute flowAccuracy : MassFlowRate = 0.02;

        perform action senseMatter : SenseMatterProperties;
    }

    part def Controller {
        doc /* Coordinates the matter-based system according to commands, sensed state, and safety limits. */
        port externalControlIn : ControlInputPort;
        port intakeStatusIn : StatusOutputPort;
        port pumpStatusIn : StatusOutputPort;
        port conditionerStatusIn : StatusOutputPort;
        port verifierStatusIn : StatusOutputPort;
        port deliveryStatusIn : StatusOutputPort;
        port systemStatusOut : StatusOutputPort;
        port pumpControlOut : ControlInputPort;
        port conditionerControlOut : ControlInputPort;

        attribute controlCycleTime : TimeDuration = 0.10;
        attribute commandedFlowRate : MassFlowRate = 1.5;
        attribute commandedTemperature : Temperature = 350.0;
        attribute commandedPressure : Pressure = 250000.0;
        attribute activeFault : FaultCode = FaultCode::none;
    }

    part def ElectricalPowerInterface {
        doc /* Distributes electrical energy to active parts that move, sense, and condition matter. */
        port externalEnergyIn : EnergyInputPort;
        port pumpEnergyOut : EnergyInputPort;
        port conditionerEnergyOut : EnergyInputPort;

        attribute maximumInputPower : Power = 20000.0;
        attribute nominalInputPower : Power = 14000.0;
        attribute storedEnergyCapacity : Energy = 500000.0;
    }

    part def MatterBasedSystem {
        doc /* System definition based on Matter. Its primary high-level function is to transform incoming RawMatter into verified ConditionedMatter while controlling state, conserving mass, rejecting unacceptable matter, and reporting status. */

        item basisMatter : Matter;
        item desiredState : DesiredMatterState;

        port rawMatterIn : RawMatterInputPort;
        port productOut : ConditionedMatterOutputPort;
        port wasteOut : WasteMatterOutputPort;
        port electricalEnergyIn : EnergyInputPort;
        port controlIn : ControlInputPort;
        port statusOut : StatusOutputPort;

        part intake : IntakeAssembly;
        part pump : MeteringPump;
        part conditioner : MatterConditioner;
        part verifier : ProductVerifier;
        part delivery : ProductDeliveryAssembly;
        part wasteHandler : WasteHandlingAssembly;
        part sensors : SensorSuite;
        part controller : Controller;
        part powerInterface : ElectricalPowerInterface;

        attribute designInputCapacity : Mass = 100.0;
        attribute nominalProductFlowRate : MassFlowRate = 1.5;
        attribute maximumSystemTemperature : Temperature = 450.0;
        attribute maximumSystemPressure : Pressure = 750000.0;
        attribute minimumProductPurity : Fraction = 0.98;
        attribute maximumStartupTime : TimeDuration = 60.0;
        attribute nominalOperatingPower : Power = 14000.0;

        connect rawMatterIn to intake.inlet;
        connect intake.outlet to pump.suction;
        connect pump.discharge to conditioner.matterIn;
        connect conditioner.matterOut to verifier.candidateIn;
        connect verifier.acceptedOut to delivery.productIn;
        connect delivery.productOut to productOut;
        connect conditioner.wasteOut to wasteHandler.wasteInFromConditioner;
        connect verifier.rejectedOut to wasteHandler.wasteInFromVerifier;
        connect wasteHandler.wasteOut to wasteOut;

        connect electricalEnergyIn to powerInterface.externalEnergyIn;
        connect powerInterface.pumpEnergyOut to pump.energyIn;
        connect powerInterface.conditionerEnergyOut to conditioner.energyIn;

        connect controlIn to controller.externalControlIn;
        connect controller.pumpControlOut to pump.controlIn;
        connect controller.conditionerControlOut to conditioner.controlIn;
        connect controller.systemStatusOut to statusOut;

        connect intake.statusOut to controller.intakeStatusIn;
        connect pump.statusOut to controller.pumpStatusIn;
        connect conditioner.statusOut to controller.conditionerStatusIn;
        connect verifier.statusOut to controller.verifierStatusIn;
        connect delivery.statusOut to controller.deliveryStatusIn;

        connect intake.sampleOut to sensors.intakeSampleIn;
        connect conditioner.statusOut to sensors.conditionerStatusIn;
        connect verifier.statusOut to sensors.verifierStatusIn;

        perform action primaryFunction : ProvideConditionedMatter;

        exhibit state operatingStates : MatterSystemOperatingStates;

        constraint systemMassBalance : MassBalanceConstraint;
        constraint systemSafeThermalLimit : SafeThermalConstraint {
            in maximumTemperature = maximumSystemTemperature;
        }
        constraint systemSafePressureLimit : SafePressureConstraint {
            in maximumPressure = maximumSystemPressure;
        }
        constraint systemProductPurity : ProductPurityConstraint {
            in requiredPurity = minimumProductPurity;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall be based on Matter and shall provide the high-level function of accepting RawMatter, controlling its state, transforming it into ConditionedMatter, verifying acceptability, and delivering the ConditionedMatter through the product output. */
        subject system : MatterBasedSystem;
    }

    requirement def MatterBasisRequirement {
        doc /* The system shall define Matter as the basis item handled at the system boundary and throughout internal processing. */
        subject system : MatterBasedSystem;
    }

    requirement def ProductPurityRequirement {
        doc /* Delivered ConditionedMatter shall have purity greater than or equal to 0.98 dimensionless fraction. */
        subject system : MatterBasedSystem;
        require constraint {
            system.minimumProductPurity >= 0.98
        }
    }

    requirement def ThroughputRequirement {
        doc /* The system shall support nominal conditioned matter delivery of at least 1.5 kg/s. */
        subject system : MatterBasedSystem;
        require constraint {
            system.nominalProductFlowRate >= 1.5
        }
    }

    requirement def ThermalSafetyRequirement {
        doc /* The system shall maintain controlled matter temperature at or below 450 K during normal operation. */
        subject system : MatterBasedSystem;
        require constraint {
            system.maximumSystemTemperature <= 450.0
        }
    }

    requirement def PressureSafetyRequirement {
        doc /* The system shall maintain controlled matter pressure at or below 750000 Pa during normal operation. */
        subject system : MatterBasedSystem;
        require constraint {
            system.maximumSystemPressure <= 750000.0
        }
    }

    requirement def StatusReportingRequirement {
        doc /* The system shall provide status containing operating mode, flow rate, temperature, pressure, purity, and active fault. */
        subject system : MatterBasedSystem;
    }

    requirement primaryFunctionRequirement : PrimaryFunctionRequirement;
    requirement matterBasisRequirement : MatterBasisRequirement;
    requirement productPurityRequirement : ProductPurityRequirement;
    requirement throughputRequirement : ThroughputRequirement;
    requirement thermalSafetyRequirement : ThermalSafetyRequirement;
    requirement pressureSafetyRequirement : PressureSafetyRequirement;
    requirement statusReportingRequirement : StatusReportingRequirement;

    part matterBasedSystem : MatterBasedSystem {
        attribute designInputCapacity = 100.0;
        attribute nominalProductFlowRate = 1.5;
        attribute maximumSystemTemperature = 450.0;
        attribute maximumSystemPressure = 750000.0;
        attribute minimumProductPurity = 0.98;
        attribute maximumStartupTime = 60.0;
        attribute nominalOperatingPower = 14000.0;

        satisfy primaryFunctionRequirement;
        satisfy matterBasisRequirement;
        satisfy productPurityRequirement;
        satisfy throughputRequirement;
        satisfy thermalSafetyRequirement;
        satisfy pressureSafetyRequirement;
        satisfy statusReportingRequirement;
    }
}
