package HydraulicRamModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    enum def RamCommandKind {
        enum idle;
        enum extend;
        enum retract;
        enum hold;
        enum stop;
    }

    enum def ValveSpoolPositionKind {
        enum centeredClosed;
        enum extendPosition;
        enum retractPosition;
        enum floatPosition;
    }

    item def HydraulicOil {
        attribute density : MassDensityValue = 860 [kg_per_m3];
        attribute bulkModulus : PressureValue = 1500000000 [Pa];
        attribute nominalTemperature : TemperatureValue = 313.15 [K];
    }

    item def ElectricPower {
        attribute voltage : ElectricPotentialValue = 24 [V];
        attribute current : ElectricCurrentValue = 8 [A];
    }

    item def RamCommand {
        attribute command : RamCommandKind = RamCommandKind::idle;
    }

    item def ValveDriveSignal {
        attribute requestedPosition : ValveSpoolPositionKind = ValveSpoolPositionKind::centeredClosed;
        attribute voltage : ElectricPotentialValue = 24 [V];
    }

    item def PressureSignal {
        attribute measuredPressure : PressureValue = 0 [Pa];
    }

    item def PositionSignal {
        attribute measuredPosition : LengthValue = 0 [m];
    }

    item def LinearMotion {
        attribute displacement : LengthValue = 0 [m];
        attribute velocity : SpeedValue = 0 [m_per_s];
        attribute directionPositiveExtends : Boolean = true;
    }

    item def MechanicalLoad {
        attribute opposingForce : ForceValue = 0 [N];
        attribute loadMass : MassValue = 0 [kg];
    }

    port def HydraulicPort {
        inout item oil : HydraulicOil;
        attribute pressure : PressureValue = 0 [Pa];
        attribute flowRate : VolumeFlowRateValue = 0 [m3_per_s];
    }

    port def HydraulicSupplyPort :> HydraulicPort {
        attribute pressure : PressureValue = 14000000 [Pa];
        attribute flowRate : VolumeFlowRateValue = 0.0008 [m3_per_s];
    }

    port def HydraulicReturnPort :> HydraulicPort {
        attribute pressure : PressureValue = 200000 [Pa];
    }

    port def ElectricalPowerPort {
        in item power : ElectricPower;
    }

    port def CommandPort {
        in item command : RamCommand;
    }

    port def ValveSignalPort {
        in item signal : ValveDriveSignal;
    }

    port def PressureSignalPort {
        out item signal : PressureSignal;
    }

    port def PositionSignalPort {
        out item signal : PositionSignal;
    }

    port def MechanicalTranslationPort {
        out item motion : LinearMotion;
        in item load : MechanicalLoad;
        attribute axialForce : ForceValue = 0 [N];
        attribute strokePosition : LengthValue = 0 [m];
    }

    part def HydraulicReservoir {
        attribute usableVolume : VolumeValue = 0.04 [m3];
        attribute minimumOilVolume : VolumeValue = 0.025 [m3];

        port supplyPort : HydraulicReturnPort;
        port returnPort : HydraulicReturnPort;
    }

    part def SuctionStrainer {
        attribute meshRating : LengthValue = 0.00015 [m];

        port inletPort : HydraulicPort;
        port outletPort : HydraulicPort;
    }

    part def HydraulicPump {
        attribute displacementPerRev : VolumeValue = 0.000025 [m3];
        attribute nominalSpeed : FrequencyValue = 25 [Hz];
        attribute nominalOutletPressure : PressureValue = 14000000 [Pa];
        attribute nominalFlowRate : VolumeFlowRateValue = 0.000625 [m3_per_s];

        port inletPort : HydraulicReturnPort;
        port outletPort : HydraulicSupplyPort;
        port powerIn : ElectricalPowerPort;
    }

    part def PressureLineFilter {
        attribute filtrationRating : LengthValue = 0.00001 [m];
        attribute maximumPressureDrop : PressureValue = 250000 [Pa];

        port inletPort : HydraulicSupplyPort;
        port outletPort : HydraulicSupplyPort;
    }

    part def PressureReliefValve {
        attribute crackingPressure : PressureValue = 15500000 [Pa];
        attribute fullFlowPressure : PressureValue = 16500000 [Pa];

        port inletPort : HydraulicSupplyPort;
        port returnPort : HydraulicReturnPort;
    }

    part def DirectionalControlValve {
        attribute spoolPosition : ValveSpoolPositionKind = ValveSpoolPositionKind::centeredClosed;
        attribute ratedFlow : VolumeFlowRateValue = 0.001 [m3_per_s];
        attribute maximumPressure : PressureValue = 21000000 [Pa];

        port pressurePort : HydraulicSupplyPort;
        port tankPort : HydraulicReturnPort;
        port portA : HydraulicPort;
        port portB : HydraulicPort;
        port commandIn : ValveSignalPort;
    }

    part def HydraulicCylinder {
        attribute boreDiameter : LengthValue = 0.08 [m];
        attribute rodDiameter : LengthValue = 0.04 [m];
        attribute pistonArea : AreaValue = 0.005027 [m2];
        attribute annulusArea : AreaValue = 0.00377 [m2];
        attribute strokeLength : LengthValue = 0.5 [m];
        attribute maximumOperatingPressure : PressureValue = 16000000 [Pa];
        attribute ratedPushForce : ForceValue = 70000 [N];
        attribute ratedPullForce : ForceValue = 52780 [N];

        port capEndPort : HydraulicPort;
        port rodEndPort : HydraulicPort;
        port rodMechanicalPort : MechanicalTranslationPort;
        port rodPositionPort : MechanicalTranslationPort;
    }

    part def PistonRodEndClevis {
        attribute pinDiameter : LengthValue = 0.025 [m];
        attribute ratedTensionCompressionForce : ForceValue = 80000 [N];

        port cylinderSide : MechanicalTranslationPort;
        port loadSide : MechanicalTranslationPort;
    }

    part def PressureTransducer {
        attribute range : PressureValue = 20000000 [Pa];
        attribute accuracy : PressureValue = 50000 [Pa];

        port sensedHydraulicPort : HydraulicPort;
        port pressureSignalOut : PressureSignalPort;
    }

    part def LinearPositionSensor {
        attribute range : LengthValue = 0.55 [m];
        attribute resolution : LengthValue = 0.0005 [m];

        port measuredMotionPort : MechanicalTranslationPort;
        port positionSignalOut : PositionSignalPort;
    }

    part def RamController {
        attribute controlVoltage : ElectricPotentialValue = 24 [V];
        attribute extensionPositionTolerance : LengthValue = 0.002 [m];
        attribute pressureLimit : PressureValue = 15000000 [Pa];

        port powerIn : ElectricalPowerPort;
        port commandIn : CommandPort;
        port capEndPressureIn : PressureSignalPort;
        port rodPositionIn : PositionSignalPort;
        port valveCommandOut : ValveSignalPort;
    }

    action def InterpretRamCommand {
        in command : RamCommand;
        out requestedValveSignal : ValveDriveSignal;
    }

    action def RouteHydraulicFlow {
        in requestedValveSignal : ValveDriveSignal;
        in supplyOil : HydraulicOil;
        out directedOil : HydraulicOil;
    }

    action def DevelopCylinderPressureDifference {
        in directedOil : HydraulicOil;
        in load : MechanicalLoad;
        out pressureSignal : PressureSignal;
    }

    action def MovePistonRod {
        in pressureSignal : PressureSignal;
        in load : MechanicalLoad;
        out motion : LinearMotion;
    }

    action def HoldPosition {
        in motion : LinearMotion;
        out heldMotion : LinearMotion;
    }

    action def ProtectAgainstOverPressure {
        in pressureSignal : PressureSignal;
        out relievedOil : HydraulicOil;
    }

    action def ConvertHydraulicEnergyToLinearActuation {
        in command : RamCommand;
        in supplyOil : HydraulicOil;
        in load : MechanicalLoad;
        out rodMotion : LinearMotion;

        action interpretCommand : InterpretRamCommand;
        action routeFlow : RouteHydraulicFlow;
        action createPressureDifference : DevelopCylinderPressureDifference;
        action moveRod : MovePistonRod;
        action holdRod : HoldPosition;
        action relievePressure : ProtectAgainstOverPressure;

        succession interpretCommand then routeFlow;
        succession routeFlow then createPressureDifference;
        succession createPressureDifference then moveRod;
        succession moveRod then holdRod;
        succession createPressureDifference then relievePressure;
    }

    state def HydraulicRamOperatingStates {
        entry; then idle;

        state idle;
        state extending;
        state holdingExtended;
        state retracting;
        state holdingRetracted;
        state pressureRelief;
        state stopped;

        transition idleToExtending first idle then extending;
        transition extendingToHoldingExtended first extending then holdingExtended;
        transition holdingExtendedToRetracting first holdingExtended then retracting;
        transition retractingToHoldingRetracted first retracting then holdingRetracted;
        transition holdingRetractedToExtending first holdingRetracted then extending;
        transition extendingToPressureRelief first extending then pressureRelief;
        transition retractingToPressureRelief first retracting then pressureRelief;
        transition pressureReliefToIdle first pressureRelief then idle;
        transition idleToStopped first idle then stopped;
    }

    requirement def HydraulicRamPrimaryFunctionRequirement {
        doc /* The hydraulic ram system shall convert pressurized hydraulic oil into controlled linear mechanical motion at the rod output, enabling extension, retraction, and holding of an attached load. */

        subject ram : HydraulicRamSystem;

        require constraint {
            ram.ratedOutputForce >= 50000 [N]
        }

        require constraint {
            ram.ratedStroke >= 0.5 [m]
        }

        require constraint {
            ram.maximumSystemPressure <= 16000000 [Pa]
        }
    }

    requirement def HydraulicRamPressureProtectionRequirement {
        doc /* The hydraulic ram system shall divert hydraulic oil to tank when pressure exceeds the allowable working pressure so that the actuator and lines remain within their rated pressure. */

        subject ram : HydraulicRamSystem;

        require constraint {
            ram.reliefSetPressure <= 16500000 [Pa]
        }
    }

    requirement def HydraulicRamPositionSensingRequirement {
        doc /* The hydraulic ram system shall measure rod displacement over the full usable stroke to support controlled extension, retraction, and holding. */

        subject ram : HydraulicRamSystem;

        require constraint {
            ram.positionMeasurementRange >= ram.ratedStroke
        }
    }

    part def HydraulicRamSystem {
        attribute ratedSupplyPressure : PressureValue = 14000000 [Pa];
        attribute maximumSystemPressure : PressureValue = 16000000 [Pa];
        attribute reliefSetPressure : PressureValue = 15500000 [Pa];
        attribute ratedStroke : LengthValue = 0.5 [m];
        attribute ratedOutputForce : ForceValue = 70000 [N];
        attribute nominalExtensionSpeed : SpeedValue = 0.12 [m_per_s];
        attribute nominalRetractionSpeed : SpeedValue = 0.16 [m_per_s];

        port electricalPowerIn : ElectricalPowerPort;
        port operatorCommandIn : CommandPort;
        port ramOutput : MechanicalTranslationPort;

        part reservoir : HydraulicReservoir;
        part suctionStrainer : SuctionStrainer;
        part pump : HydraulicPump;
        part pressureFilter : PressureLineFilter;
        part reliefValve : PressureReliefValve;
        part directionalValve : DirectionalControlValve;
        part cylinder : HydraulicCylinder;
        part rodClevis : PistonRodEndClevis;
        part capEndPressureSensor : PressureTransducer;
        part positionSensor : LinearPositionSensor;
        part controller : RamController;

        perform action primaryFunction : ConvertHydraulicEnergyToLinearActuation;
        exhibit state operatingState : HydraulicRamOperatingStates;

        connect reservoir.supplyPort to suctionStrainer.inletPort;
        connect suctionStrainer.outletPort to pump.inletPort;
        connect pump.outletPort to pressureFilter.inletPort;
        connect pressureFilter.outletPort to directionalValve.pressurePort;
        connect pressureFilter.outletPort to reliefValve.inletPort;
        connect reliefValve.returnPort to reservoir.returnPort;
        connect directionalValve.tankPort to reservoir.returnPort;
        connect directionalValve.portA to cylinder.capEndPort;
        connect directionalValve.portB to cylinder.rodEndPort;
        connect cylinder.capEndPort to capEndPressureSensor.sensedHydraulicPort;
        connect cylinder.rodMechanicalPort to rodClevis.cylinderSide;
        connect rodClevis.loadSide to ramOutput;
        connect cylinder.rodPositionPort to positionSensor.measuredMotionPort;
        connect electricalPowerIn to pump.powerIn;
        connect electricalPowerIn to controller.powerIn;
        connect operatorCommandIn to controller.commandIn;
        connect capEndPressureSensor.pressureSignalOut to controller.capEndPressureIn;
        connect positionSensor.positionSignalOut to controller.rodPositionIn;
        connect controller.valveCommandOut to directionalValve.commandIn;
    }

    part hydraulicRam : HydraulicRamSystem;

    requirement primaryFunctionRequirement : HydraulicRamPrimaryFunctionRequirement {
        subject ram = hydraulicRam;
    }

    requirement pressureProtectionRequirement : HydraulicRamPressureProtectionRequirement {
        subject ram = hydraulicRam;
    }

    requirement positionSensingRequirement : HydraulicRamPositionSensingRequirement {
        subject ram = hydraulicRam;
    }
}
